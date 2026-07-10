-- quarantine-policy — the AUR trust decision ladder, single source (Story 2.28).
--
-- Consumers:
--   * ~/.config/yay/init.lua      require("quarantine-policy") — UpgradeSelect
--                                 and AURPreInstall hooks (in-process, hot path)
--   * tools/chaotic-quarantine-gate  one-shot CLI: gates chaotic-aur binaries
--                                 at pacman PreTransaction (cold path)
--
-- Pure Lua 5.1, no yay globals — callers do their own logging/reporting.
-- Docs: knowledge/reference/aur-malware-mitigation.md
--
-- classify(pkg, mt, known, is_exempt, age_days, days, version)
--   pkg       package name
--   mt        current maintainer ("" = orphaned)
--   known     baseline entry: nil = never seen (TOFU), "" = trusted-as-orphan
--   is_exempt truthy when the package skips the age delay
--   age_days  integer age of the current version, or nil = unknown
--   days      quarantine window (<=0 disables the age gate)
--   version   display-only version string
-- Returns nil (allow; second value "exempt" when the exemption decided it),
-- or a hold table { code, why, remedies }. Precedence: maintainer-change
-- (hard stop, even if exempted) > unaccepted orphan > exempt > age.

local M = {}

function M.classify(pkg, mt, known, is_exempt, age_days, days, version)
  if known ~= nil and known ~= mt then
    return { code = "maintainer-change",
      why = string.format("MAINTAINER CHANGED ('%s' -> '%s'); possible takeover",
        known ~= "" and known or "ORPHANED", mt ~= "" and mt or "ORPHANED"),
      remedies = { "trust:  aur-quarantine accept " .. pkg .. "   (after verifying on the AUR)" } }
  end
  if mt == "" and known == nil then
    return { code = "orphan", why = "ORPHANED (no maintainer); adoption-attack risk",
      remedies = { "trust:  aur-quarantine accept " .. pkg .. "   (after verifying on the AUR)" } }
  end
  if is_exempt then
    return nil, "exempt"
  end
  if days > 0 and (age_days == nil or age_days < days) then
    return { code = "age",
      why = string.format("version %s is %s old (< %dd quarantine)",
        version or "?", age_days and (age_days .. "d") or "of unknown age", days),
      remedies = {
        "step:   aur-quarantine update " .. pkg .. "   (newest vetted older version, if any)",
        "auto:   aur-quarantine auto "   .. pkg .. "   (always take immediately; maintainer changes still held)" } }
  end
  return nil
end

-- CLI adapter (bash callers):
--   lua5.1 quarantine-policy.lua PKG MT KNOWN EXEMPT AGE DAYS [VERSION]
--     MT      current maintainer, "@orphan" for none
--     KNOWN   baseline entry, "@never" if absent, "@orphan" for trusted-orphan
--     EXEMPT  0/1
--     AGE     integer days, "@nil" if unknown
-- Exit 0 = allow. Exit 1 = hold; stdout line 1 is "code<TAB>why", then one
-- remedy per line. Exit 2 = usage error.
if arg and arg[0] and arg[0]:match("quarantine%-policy%.lua$") and #arg >= 6 then
  local function dec(v, sentinel) if v == sentinel then return nil end return v end
  local pkg    = arg[1]
  local mt     = arg[2] == "@orphan" and "" or arg[2]
  local known  = dec(arg[3], "@never"); if known == "@orphan" then known = "" end
  local exempt = arg[4] == "1"
  local age    = dec(arg[5], "@nil"); age = age and tonumber(age) or nil
  local days   = tonumber(arg[6]) or 14
  local hold = M.classify(pkg, mt, known, exempt, age, days, arg[7])
  if hold then
    io.write(hold.code, "\t", hold.why, "\n")
    for _, r in ipairs(hold.remedies) do io.write(r, "\n") end
    os.exit(1)
  end
  os.exit(0)
end

return M
