-- Harness for the AURPreInstall install gate (Story 2.10).
-- Stubs the yay API, fakes the AUR RPC via io.popen monkey-patch, and drives
-- the hook through the policy matrix. Run: lua5.1 hook-harness.lua <init.lua>
-- Exit 0 = all cases pass.

local init_path = arg[1] or error("usage: lua5.1 hook-harness.lua <path-to-init.lua>")

-- --- stub state ------------------------------------------------------------
local state_home = os.getenv("PWD") and (os.getenv("PWD") .. "/harness-state") or "harness-state"
os.execute("rm -rf '" .. state_home .. "' && mkdir -p '" .. state_home .. "'")
-- hook reads XDG_STATE_HOME at call time via os.getenv — override getenv.
local real_getenv = os.getenv
local env_override = { XDG_STATE_HOME = state_home }
os.getenv = function(k)
  if env_override[k] ~= nil then
    if env_override[k] == false then return nil end
    return env_override[k]
  end
  return real_getenv(k)
end

local sdir = state_home .. "/aur-quarantine"

-- fake RPC: rpc_response holds the JSON body curl would print ("" = failure)
local rpc_response = ""
local real_popen = io.popen
io.popen = function(cmd, ...)
  if cmd:match("aur%.archlinux%.org/rpc") then
    return real_popen("printf '%s' '" .. rpc_response:gsub("'", "'\\''") .. "'")
  end
  return real_popen(cmd, ...)
end

-- --- stub yay --------------------------------------------------------------
local hooks = {}
local aborted, logged
yay = {
  create_autocmd = function(event, spec) hooks[event] = spec.callback end,
  abort = function(msg) aborted = msg; error({ harness_abort = msg }) end,
  log = {
    warn = function(...) logged = table.concat({...}, " ") end,
    info = function() end,
    error = function() end,
    debug = function() end,
  },
}

dofile(init_path)
assert(hooks["AURPreInstall"], "AURPreInstall hook did not register")
assert(hooks["UpgradeSelect"], "UpgradeSelect hook missing (regression)")
local gate = hooks["AURPreInstall"]

-- --- helpers ---------------------------------------------------------------
local now = os.time()
local function days_ago(d) return now - d * 86400 end

local function rpc_json(entries) -- { {name=, maint=|nil} }
  local objs = {}
  for _, e in ipairs(entries) do
    local m = e.maint and ('"' .. e.maint .. '"') or "null"
    table.insert(objs, string.format(
      '{"Name":"%s","PackageBase":"%s","Maintainer":%s,"LastModified":%d,"License":["MIT"]}',
      e.name, e.name, m, days_ago(30)))
  end
  return '{"resultcount":' .. #entries .. ',"results":[' .. table.concat(objs, ",") .. '],"type":"multiinfo","version":5}'
end

local function write_file(path, content)
  os.execute("mkdir -p '" .. sdir .. "'")
  local f = assert(io.open(path, "w")); f:write(content); f:close()
end

local function event_for(name, last_mod)
  return { event = "AURPreInstall", match = name, data = {
    base = name, version = "1.0-1", last_modified = last_mod, installed = false,
    packages = { { name = name, version = "1.0-1", local_version = "", reason = "explicit", upgrade = false, devel = false } },
  } }
end

local function run_case(label, opts, expect_hold, expect_code)
  aborted, logged = nil, nil
  os.execute("rm -f '" .. sdir .. "/held-install.tsv'")
  os.execute("rm -f '" .. sdir .. "/maintainers.tsv' '" .. sdir .. "/exempt.txt'")
  if opts.baseline then write_file(sdir .. "/maintainers.tsv", opts.baseline) end
  if opts.exempt then write_file(sdir .. "/exempt.txt", opts.exempt) end
  env_override.AUR_QUARANTINE_BYPASS = opts.bypass and "1" or false
  env_override.AUR_QUARANTINE_DAYS = false
  rpc_response = opts.rpc
  local ok, err = pcall(gate, opts.event)
  local held = not ok and type(err) == "table" and err.harness_abort ~= nil
  if held ~= expect_hold then
    print(string.format("FAIL %-38s expected %s, got %s%s", label,
      expect_hold and "HOLD" or "PASS", held and "HOLD" or "PASS",
      (not ok and not held) and (" (lua error: " .. tostring(err) .. ")") or ""))
    return false
  end
  if held and expect_code then
    local hf = io.open(sdir .. "/held-install.tsv", "r")
    local line = hf and hf:read("*l") or ""
    if hf then hf:close() end
    local code = line:match("\t(%S+)$")
    if code ~= expect_code then
      print(string.format("FAIL %-38s held-install code: expected %s, got %s", label, expect_code, tostring(code)))
      return false
    end
  end
  print(string.format("ok   %-38s %s", label, held and "HOLD (" .. (expect_code or "?") .. ")" or "PASS"))
  return true
end

-- --- policy matrix -----------------------------------------------------------
local all = true
local function case(...) all = run_case(...) and all end

-- fresh, aged, maintained, no baseline: TOFU pass
case("fresh aged maintained (TOFU)", {
  event = event_for("goodpkg", days_ago(30)),
  rpc = rpc_json({ { name = "goodpkg", maint = "alice" } }),
}, false)

-- fresh, young version: age hold
case("fresh young version", {
  event = event_for("youngpkg", days_ago(3)),
  rpc = rpc_json({ { name = "youngpkg", maint = "alice" } }),
}, true, "age")

-- young but exempt: pass
case("young + exempt", {
  event = event_for("fastpkg", days_ago(3)),
  exempt = "fastpkg\n",
  rpc = rpc_json({ { name = "fastpkg", maint = "alice" } }),
}, false)

-- orphan, never seen: hold
case("orphan never-seen", {
  event = event_for("orphanpkg", days_ago(30)),
  rpc = rpc_json({ { name = "orphanpkg", maint = nil } }),
}, true, "orphan")

-- orphan, accepted in baseline (empty maintainer): pass
case("orphan accepted in baseline", {
  event = event_for("orphanpkg", days_ago(30)),
  baseline = "orphanpkg\t\n",
  rpc = rpc_json({ { name = "orphanpkg", maint = nil } }),
}, false)

-- maintainer changed vs baseline: hold, even when exempt
case("maintainer change (exempt ignored)", {
  event = event_for("takenpkg", days_ago(30)),
  baseline = "takenpkg\talice\n",
  exempt = "takenpkg\n",
  rpc = rpc_json({ { name = "takenpkg", maint = "mallory" } }),
}, true, "maintainer-change")

-- unknown age (last_modified 0): hold as too new
case("unknown age", {
  event = event_for("agelesspkg", 0),
  rpc = rpc_json({ { name = "agelesspkg", maint = "alice" } }),
}, true, "age")

-- RPC failure: fail closed
case("rpc unreachable", {
  event = event_for("anypkg", days_ago(30)),
  rpc = "",
}, true, "rpc")

-- package missing from RPC results: fail closed
case("pkg missing from rpc", {
  event = event_for("ghostpkg", days_ago(30)),
  rpc = rpc_json({ { name = "otherpkg", maint = "alice" } }),
}, true, "rpc")

-- bypass env: everything passes
case("bypass env", {
  event = event_for("youngpkg", days_ago(1)),
  bypass = true,
  rpc = "",
}, false)

-- split package: second name violates
local split_event = { event = "AURPreInstall", match = "basepkg", data = {
  base = "basepkg", version = "1.0-1", last_modified = days_ago(30), installed = false,
  packages = {
    { name = "basepkg-cli", version = "1.0-1", local_version = "", reason = "explicit", upgrade = false, devel = false },
    { name = "basepkg-gui", version = "1.0-1", local_version = "", reason = "explicit", upgrade = false, devel = false },
  },
} }
case("split pkg, one orphaned", {
  event = split_event,
  rpc = rpc_json({ { name = "basepkg-cli", maint = "alice" }, { name = "basepkg-gui", maint = nil } }),
}, true, "orphan")

-- --- UpgradeSelect coverage (shared classify regression) ---------------------
local upsel = hooks["UpgradeSelect"]

local function up_entry(name, repo, maint, last_mod, local_v, remote_v)
  return { id = 1, name = name, base = name, repository = repo,
    local_version = local_v or "1.0-1", remote_version = remote_v or "1.1-1",
    reason = "explicit", last_modified = last_mod, maintainer = maint }
end

local function run_upsel(label, opts, expect_excluded)
  os.execute("rm -f '" .. sdir .. "/maintainers.tsv' '" .. sdir .. "/exempt.txt'")
  if opts.baseline then write_file(sdir .. "/maintainers.tsv", opts.baseline) end
  if opts.exempt then write_file(sdir .. "/exempt.txt", opts.exempt) end
  env_override.AUR_QUARANTINE_BYPASS = opts.bypass and "1" or false
  env_override.AUR_QUARANTINE_DAYS = false
  local ok, res = pcall(upsel, { event = "UpgradeSelect", data = { upgrades = opts.upgrades } })
  if not ok then print("FAIL " .. label .. " (lua error: " .. tostring(res) .. ")"); return false end
  local excluded = {}
  for _, n in ipairs((res or {}).exclude or {}) do excluded[n] = true end
  for _, name in ipairs(expect_excluded) do
    if not excluded[name] then print(string.format("FAIL %-38s expected %s excluded", label, name)); return false end
    excluded[name] = nil
  end
  local leftover = next(excluded)
  if leftover then print(string.format("FAIL %-38s unexpected exclusion: %s", label, leftover)); return false end
  print(string.format("ok   %-38s excludes [%s]", label, table.concat(expect_excluded, ",")))
  return true
end

local function ucase(...) all = run_upsel(...) and all end

ucase("upsel: aged maintained kept", {
  upgrades = { up_entry("goodpkg", "aur", "alice", days_ago(30)) },
}, {})

ucase("upsel: young excluded", {
  upgrades = { up_entry("youngpkg", "aur", "alice", days_ago(3)) },
}, { "youngpkg" })

ucase("upsel: young + exempt kept", {
  exempt = "fastpkg\n",
  upgrades = { up_entry("fastpkg", "aur", "alice", days_ago(3)) },
}, {})

ucase("upsel: maintainer change beats exempt", {
  baseline = "takenpkg\talice\n",
  exempt = "takenpkg\n",
  upgrades = { up_entry("takenpkg", "aur", "mallory", days_ago(30)) },
}, { "takenpkg" })

ucase("upsel: orphan never-seen excluded", {
  upgrades = { up_entry("orphanpkg", "aur", "", days_ago(30)) },
}, { "orphanpkg" })

ucase("upsel: accepted orphan kept", {
  baseline = "orphanpkg\t\n",
  upgrades = { up_entry("orphanpkg", "aur", "", days_ago(30)) },
}, {})

ucase("upsel: repo package untouched", {
  upgrades = { up_entry("systemd", "core", "", days_ago(1)) },
}, {})

ucase("upsel: bypass excludes nothing", {
  bypass = true,
  upgrades = { up_entry("youngpkg", "aur", "alice", days_ago(1)) },
}, {})

os.getenv = real_getenv
io.popen = real_popen
os.execute("rm -rf '" .. state_home .. "'")
if all then print("ALL CASES PASS") os.exit(0) else os.exit(1) end
