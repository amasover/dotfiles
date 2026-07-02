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

    local function hold(name, why, action)
      table.insert(exclude, name)
      local url = "https://aur.archlinux.org/packages/" .. name
      yay.log.warn(string.format("aur-quarantine: HOLD %s — %s", name, why))
      table.insert(report, string.format(" [!] %s — %s\n     check:  %s\n     %s", name, why, url, action))
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
            "trust:  aur-quarantine accept " .. pkg)
        elseif mt == "" and known == nil then
          -- Orphaned and never explicitly trusted (an accept records the orphan
          -- state as "", which clears this hold): adoption-attack vector.
          hold(pkg, "ORPHANED (no maintainer); adoption-attack risk",
            "trust:  aur-quarantine accept " .. pkg)
        elseif exempt[pkg] then
          yay.log.info("aur-quarantine: " .. pkg .. " is auto-exempt; taking latest")
        elseif days > 0 and (age_days == nil or age_days < days) then
          hold(pkg,
            string.format("version %s is %s old (< %dd quarantine)",
              up.remote_version or "?",
              age_days and (age_days .. "d") or "of unknown age", days),
            "step:   aur-quarantine update " .. pkg ..
            "   (installs the newest vetted older version, if any)")
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
