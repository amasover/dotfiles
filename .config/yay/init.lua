-- AUR quarantine (Stories 2.6 + 2.10) — yay UpgradeSelect + AURPreInstall hooks.
--
-- Defense against freshly-weaponized AUR packages (June 2026 AUR malware):
--
--  * UpgradeSelect (2.6): holds AUR *upgrades* that are too new, orphaned, or
--    maintainer-changed, by excluding them from every `yay -Syu`. Runs in-flow —
--    yay's payload already carries maintainer + last_modified, no RPC here.
--  * AURPreInstall (2.10): applies the same policy to every AUR package base
--    reaching a build — fresh installs (`yay -S`, bootstrap's metapac sync) and
--    targeted upgrades that never pass through UpgradeSelect. This event can
--    only allow or abort (no exclusion), so a violation aborts the whole
--    transaction *before any source download or build*. The payload carries
--    last_modified but not maintainer, so this hook makes one AUR RPC call per
--    base (curl; JSON parsed with Lua patterns — no jq on a fresh machine).
--    RPC failure fails closed. TOFU is preserved: a never-seen, maintained,
--    aged package passes and is recorded by the next `seed`.
--
-- Held upgrades are reported inline (yay.log.warn) with the AUR link and the
-- exact copy-paste command, and the same report is written to
--   ${XDG_STATE_HOME:-~/.local/state}/aur-quarantine/last-report.txt
-- which `setup/update` prints at the end of an unattended run. An install-time
-- abort additionally writes the held package to
--   ${XDG_STATE_HOME:-~/.local/state}/aur-quarantine/held-install.tsv
-- ("pkg<TAB>reason" — one line, overwritten per abort) which bootstrap's
-- unattended sync loop reads to auto-step age holds via `aur-quarantine update`.
--
-- Companion CLI: ~/.local/bin/tools/aur-quarantine
--   seed / accept PKG / auto PKG / auto-off PKG / update PKG (manual stepping)
-- Docs: knowledge/reference/aur-malware-mitigation.md
--
-- Env:
--   AUR_QUARANTINE_BYPASS=1   skip all quarantine checks this run
--   AUR_QUARANTINE_DAYS=N     age threshold in days (default 14; <=0 disables age gate)
--
-- Requires yay >= 13.0.0 (Lua hooks). Lua 5.1.

local function state_dir()
  local x = os.getenv("XDG_STATE_HOME")
  if x == nil or x == "" then x = (os.getenv("HOME") or "") .. "/.local/state" end
  return x .. "/aur-quarantine"
end

-- maintainers.tsv: "<pkg>\t<maintainer>" per line (maintainer may be empty).
-- Returns nil when the file doesn't exist (baseline never seeded).
local function read_baseline(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local t = {}
  for line in f:lines() do
    local k, v = line:match("^([^\t]+)\t?(.*)$")
    if k then t[k] = v end
  end
  f:close()
  return t
end

-- exempt.txt: one package name per line.
local function read_set(path)
  local t = {}
  local f = io.open(path, "r")
  if not f then return t end
  for line in f:lines() do
    if line ~= "" then t[line] = true end
  end
  f:close()
  return t
end

-- The shared trust policy lives in quarantine-policy.lua (Story 2.28), so the
-- chaotic-aur PreTransaction gate applies the identical ladder. Thin wrapper
-- keeps the exempt-pass log line (the module is yay-global-free by design).
-- yay prepends this file's directory to package.path (>= 13.0.1).
local policy = require("quarantine-policy")
local function classify(pkg, mt, known, is_exempt, age_days, days, version)
  local hold, pass = policy.classify(pkg, mt, known, is_exempt, age_days, days, version)
  if pass == "exempt" then
    yay.log.info("aur-quarantine: " .. pkg .. " is auto-exempt; allowing latest")
  end
  return hold
end

-- Chaotic-AUR ships the repo's own two infra packages that never exist in the
-- AUR — identity checks can't apply; they are vouched for by the lsigned repo
-- key instead (Story 2.28).
local chaotic_infra = { ["chaotic-keyring"] = true, ["chaotic-mirrorlist"] = true }

-- One batched AUR RPC call. Returns { [name] = { mt = maintainer ("" = orphan),
-- lm = last_modified or nil } } or nil on any failure (callers fail closed).
-- AUR pkgnames are [a-z0-9@._+-] only; anything shell-unsafe is refused.
local function rpc_info(names)
  local args = {}
  for _, n in ipairs(names) do
    if n:match("[^%w@._+-]") then return nil end
    table.insert(args, "--data-urlencode 'arg[]=" .. n .. "'")
  end
  local p = io.popen("curl -fsG --max-time 20 " .. table.concat(args, " ")
    .. " 'https://aur.archlinux.org/rpc/v5/info' 2>/dev/null")
  if not p then return nil end
  local resp = p:read("*a") or ""
  p:close()
  -- v5 info results are flat objects (inner arrays use [], never {}), so
  -- %b{} splits the results array cleanly. Greedy (.*)%] is anchored by the
  -- results array's own closing bracket — no later field is an array.
  local body = resp:match('"results":%s*%[(.*)%]')
  if not body then return nil end
  local by_name = {}
  for obj in body:gmatch("%b{}") do
    local name = obj:match('"Name":"([^"]+)"')
    if name then
      by_name[name] = {
        mt = obj:match('"Maintainer":"([^"]*)"') or "",
        lm = tonumber(obj:match('"LastModified":(%d+)')),
      }
    end
  end
  return by_name
end

yay.create_autocmd("UpgradeSelect", {
  desc = "AUR quarantine: hold too-new / orphaned / maintainer-changed AUR upgrades",
  callback = function(event)
    local sdir = state_dir()
    local report_path = sdir .. "/last-report.txt"

    if os.getenv("AUR_QUARANTINE_BYPASS") == "1" then
      yay.log.warn("aur-quarantine: BYPASSED for this run (AUR_QUARANTINE_BYPASS=1)")
      os.remove(report_path)
      return {}
    end

    local days = tonumber(os.getenv("AUR_QUARANTINE_DAYS") or "") or 14
    local trusted = read_baseline(sdir .. "/maintainers.tsv")
    local exempt = read_set(sdir .. "/exempt.txt")
    if trusted == nil then
      yay.log.warn("aur-quarantine: no trusted-maintainer baseline — run 'aur-quarantine seed' (age gate still active)")
      trusted = {}
    end

    local now = os.time()
    local exclude = {}
    local report = {}

    -- One block per held package, shown both inline during the yay run and in the
    -- end-of-run report file: reason, AUR link to inspect, then copy-paste command(s).
    local function hold(name, why, actions)
      table.insert(exclude, name)
      local url = "https://aur.archlinux.org/packages/" .. name
      local block = string.format("%s — %s\n     check:  %s\n     %s",
        name, why, url, table.concat(actions, "\n     "))
      yay.log.warn("aur-quarantine: HOLD " .. block .. "\n")
      table.insert(report, " [!] " .. block)
    end

    -- chaotic-aur candidates first (Story 2.28): repo payloads carry no AUR
    -- metadata, so one batched RPC supplies maintainer + age for all of them.
    local chaotic_names = {}
    for _, up in ipairs(event.data.upgrades or {}) do
      if up.repository == "chaotic-aur" and not chaotic_infra[up.name] then
        table.insert(chaotic_names, up.name)
      end
    end
    local cinfo = {}
    if #chaotic_names > 0 then
      cinfo = rpc_info(chaotic_names)
      if cinfo == nil then
        cinfo = {}
        yay.log.warn("aur-quarantine: AUR RPC unreachable — holding all chaotic-aur upgrades (fail-closed)")
      end
    end

    for _, up in ipairs(event.data.upgrades or {}) do
      if up.repository == "aur" then
        local age_days = nil
        if up.last_modified and up.last_modified > 0 then
          age_days = math.floor((now - up.last_modified) / 86400)
        end
        local verdict = classify(up.name, up.maintainer or "", trusted[up.name],
          exempt[up.name], age_days, days, up.remote_version)
        if verdict then hold(up.name, verdict.why, verdict.remedies) end
      elseif up.repository == "chaotic-aur" and not chaotic_infra[up.name] then
        local info = cinfo[up.name]
        if info == nil then
          hold(up.name, "chaotic-aur binary not verifiable via AUR RPC (failing closed)",
            { "transient? retry later — or bypass this run:  AUR_QUARANTINE_BYPASS=1 yay ..." })
        else
          local age_days = info.lm and math.floor((now - info.lm) / 86400) or nil
          local verdict = classify(up.name, info.mt, trusted[up.name],
            exempt[up.name], age_days, days, up.remote_version)
          if verdict then hold(up.name, verdict.why, verdict.remedies) end
        end
      end
    end

    -- Persist the report for setup/update to print at the end (empty file = all clear).
    os.execute("mkdir -p '" .. sdir .. "'")
    local rf = io.open(report_path, "w")
    if rf then
      if #report > 0 then
        rf:write("==============================================================\n")
        rf:write(" AUR quarantine — held this run (" .. os.date("%Y-%m-%d %H:%M") .. ")\n")
        rf:write("==============================================================\n")
        rf:write(table.concat(report, "\n\n"), "\n")
        rf:write("\n Tip: 'aur-quarantine auto <pkg>' always takes a fully-trusted\n")
        rf:write("      package's updates immediately (maintainer changes still held).\n")
      end
      rf:close()
    end

    return { exclude = exclude }
  end,
})

-- Install-time gate (Story 2.10) — yay AURPreInstall hook.
--
-- Fires once per AUR package base after PKGBUILDs are downloaded, before the
-- clean/diff/edit menus and before any source download or build. It cannot
-- exclude a single base (upstream design) — a policy violation aborts the
-- whole transaction via yay.abort(), so nothing partial happens. Bootstrap's
-- unattended sync loop reads held-install.tsv and auto-steps age holds.

yay.create_autocmd("AURPreInstall", {
  desc = "AUR quarantine: gate installs on age / orphan / maintainer vs baseline",
  callback = function(event)
    if os.getenv("AUR_QUARANTINE_BYPASS") == "1" then
      yay.log.warn("aur-quarantine: install gate BYPASSED for " .. event.match
        .. " (AUR_QUARANTINE_BYPASS=1)")
      return
    end

    local sdir = state_dir()
    local days = tonumber(os.getenv("AUR_QUARANTINE_DAYS") or "") or 14
    local trusted = read_baseline(sdir .. "/maintainers.tsv") or {}
    local exempt = read_set(sdir .. "/exempt.txt")

    -- Reason codes are machine-read by bootstrap: only "age" is auto-steppable.
    local function hold(pkg, code, why, remedies)
      os.execute("mkdir -p '" .. sdir .. "'")
      local hf = io.open(sdir .. "/held-install.tsv", "w")
      if hf then hf:write(pkg, "\t", code, "\n") hf:close() end
      local msg = string.format(
        "aur-quarantine: HOLD %s — %s\n     check:  https://aur.archlinux.org/packages/%s\n     %s",
        pkg, why, pkg, table.concat(remedies, "\n     "))
      yay.log.warn(msg)
      yay.abort(msg)
    end

    local names = {}
    for _, p in ipairs(event.data.packages or {}) do table.insert(names, p.name) end
    if #names == 0 then return end

    local maint = rpc_info(names)
    if maint == nil then
      hold(names[1], "rpc",
        "AUR RPC unreachable — cannot verify maintainer/orphan state (failing closed)",
        { "retry, or bypass this run:  AUR_QUARANTINE_BYPASS=1 yay ..." })
    end

    local age_days = nil
    if event.data.last_modified and event.data.last_modified > 0 then
      age_days = math.floor((os.time() - event.data.last_modified) / 86400)
    end

    for _, pkg in ipairs(names) do
      local info = maint[pkg]
      if info == nil then
        hold(pkg, "rpc", "not found in AUR RPC — cannot verify (failing closed)",
          { "retry, or bypass this run:  AUR_QUARANTINE_BYPASS=1 yay ..." })
      end
      local verdict = classify(pkg, info.mt, trusted[pkg], exempt[pkg], age_days, days,
        event.data.version)
      if verdict then hold(pkg, verdict.code, verdict.why, verdict.remedies) end
    end
  end,
})

-- metapac inbox auto-capture (Story 2.9) — yay PostInstall hook.
--
-- Fresh *explicit* installs (local_version == "" — upgrades and reinstalls are
-- skipped) that are not declared in any metapac group are appended to this
-- machine's inbox group, ~/.config/metapac/groups/inbox-<class>.toml, so ad-hoc
-- installs never silently drift out of the manifest. Triage nudge: the
-- metapac-drift-report tool (run by setup/update) lists inbox contents until
-- each package is moved to a purpose group or dropped.
-- Raw `pacman -S` bypasses yay hooks; `metapac unmanaged` is the backstop.
-- Docs: docs/decision-bootstrap-architecture.md (auto-capture; drift loop).

local function metapac_dir()
  return (os.getenv("HOME") or "") .. "/.config/metapac"
end

-- The single inbox-*.toml in the groups dir names this machine's inbox
-- (one per machine by design; the filename carries the yadm class).
local function find_inbox()
  local p = io.popen('ls "' .. metapac_dir() .. '/groups/inbox-"*.toml 2>/dev/null')
  if not p then return nil end
  local matches = {}
  for line in p:lines() do table.insert(matches, line) end
  p:close()
  if #matches == 1 then return matches[1] end
  return nil, #matches
end

-- Set of every package name declared in any group: all groups-dir files plus
-- absolute-path groups referenced from the rendered config.toml (machine-local).
local function declared_set()
  local set = {}
  local files = {}
  local p = io.popen('ls "' .. metapac_dir() .. '/groups/"*.toml 2>/dev/null')
  if p then
    for line in p:lines() do table.insert(files, line) end
    p:close()
  end
  local cfg = io.open(metapac_dir() .. "/config.toml", "r")
  if cfg then
    for line in cfg:lines() do
      for abs in line:gmatch('"(/[^"]+)"') do
        local f = io.open(abs, "r") and abs or (abs .. ".toml")
        table.insert(files, f)
      end
    end
    cfg:close()
  end
  for _, path in ipairs(files) do
    local f = io.open(path, "r")
    if f then
      for line in f:lines() do
        local name = line:match('^%s*"([^"]+)"')
        if name then set[name] = true end
      end
      f:close()
    end
  end
  return set
end

-- Insert `"pkg",` before the closing `]` of the inbox packages array.
local function append_to_inbox(inbox, pkgs)
  local f = io.open(inbox, "r")
  if not f then return false end
  local lines = {}
  for line in f:lines() do table.insert(lines, line) end
  f:close()
  local close_idx = nil
  for i = #lines, 1, -1 do
    if lines[i]:match("^%s*%]") then close_idx = i break end
  end
  if not close_idx then return false end
  for n, pkg in ipairs(pkgs) do
    table.insert(lines, close_idx + n - 1, string.format('  "%s",', pkg))
  end
  local tmp = inbox .. ".tmp"
  local out = io.open(tmp, "w")
  if not out then return false end
  out:write(table.concat(lines, "\n"), "\n")
  out:close()
  return os.rename(tmp, inbox)
end

yay.create_autocmd("PostInstall", {
  desc = "metapac inbox: capture fresh explicit installs not declared in any group",
  callback = function(event)
    local fresh = {}
    for _, pkg in ipairs(event.data.packages or {}) do
      if pkg.reason == "explicit" and (pkg.local_version == nil or pkg.local_version == "") then
        table.insert(fresh, pkg.name)
      end
    end
    if #fresh == 0 then return end

    local inbox, count = find_inbox()
    if not inbox then
      yay.log.warn(string.format(
        "metapac-inbox: expected exactly one groups/inbox-*.toml, found %d — not capturing: %s",
        count or 0, table.concat(fresh, " ")))
      return
    end

    local declared = declared_set()
    local capture = {}
    for _, name in ipairs(fresh) do
      if not declared[name] then table.insert(capture, name) end
    end
    if #capture == 0 then return end

    if append_to_inbox(inbox, capture) then
      for _, name in ipairs(capture) do
        yay.log.info("metapac-inbox: captured " .. name ..
          " -> " .. inbox:match("[^/]+$") .. " (triage: move to a purpose group)")
      end
    else
      yay.log.warn("metapac-inbox: failed to update " .. inbox ..
        " — add manually: " .. table.concat(capture, " "))
    end
  end,
})
