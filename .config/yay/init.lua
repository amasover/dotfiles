-- AUR quarantine (Story 2.6) — yay UpgradeSelect hook.
--
-- Defense against freshly-weaponized AUR packages (June 2026 AUR malware):
-- holds AUR upgrades that are too new, orphaned, or whose maintainer changed,
-- by excluding them from every `yay -Syu`. Runs in-flow — yay's payload already
-- carries maintainer + last_modified, so no AUR RPC calls are made here.
--
-- Held packages are reported inline (yay.log.warn) with the AUR link and the
-- exact copy-paste command, and the same report is written to
--   ${XDG_STATE_HOME:-~/.local/state}/aur-quarantine/last-report.txt
-- which `setup/update` prints at the end of an unattended run.
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

    for _, up in ipairs(event.data.upgrades or {}) do
      if up.repository == "aur" then
        local pkg = up.name
        local mt = up.maintainer or ""
        local known = trusted[pkg]  -- nil = never seeded (fresh install); "" = trusted-as-orphan
        local age_days = nil
        if up.last_modified and up.last_modified > 0 then
          age_days = math.floor((now - up.last_modified) / 86400)
        end

        if known ~= nil and known ~= mt then
          -- Maintainer changed vs the trusted baseline: hard stop, even if exempted.
          hold(pkg,
            string.format("MAINTAINER CHANGED ('%s' -> '%s'); possible takeover",
              known ~= "" and known or "ORPHANED", mt ~= "" and mt or "ORPHANED"),
            { "trust:  aur-quarantine accept " .. pkg .. "   (after verifying on the AUR)" })
        elseif mt == "" and known == nil then
          -- Orphaned and never explicitly trusted (an accept records the orphan
          -- state as "", which clears this hold): adoption-attack vector.
          hold(pkg, "ORPHANED (no maintainer); adoption-attack risk",
            { "trust:  aur-quarantine accept " .. pkg .. "   (after verifying on the AUR)" })
        elseif exempt[pkg] then
          yay.log.info("aur-quarantine: " .. pkg .. " is auto-exempt; taking latest")
        elseif days > 0 and (age_days == nil or age_days < days) then
          hold(pkg,
            string.format("version %s is %s old (< %dd quarantine)",
              up.remote_version or "?",
              age_days and (age_days .. "d") or "of unknown age", days),
            { "step:   aur-quarantine update " .. pkg .. "   (newest vetted older version, if any)",
              "auto:   aur-quarantine auto "   .. pkg .. "   (always take immediately; maintainer changes still held)" })
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
