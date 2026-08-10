# vm-harness-vmware — disposable VMware Workstation validation harness (Windows host).
#
# PowerShell sibling of the libvirt/QEMU vm-harness (Story 2.36, #119): fresh-
# installs Arch unattended in a throwaway VMware Workstation VM, runs the repo
# bootstrap inside it, and asserts the result. Same pipeline vocabulary and
# logging contract as the bash harness; hypervisor plumbing differs. Thin
# driver by design — logic lives in Python (vm-harness-seed and friends),
# guest-side bash is shared with the libvirt harness.
#
# Subcommands (foundation slice — install/boot/bootstrap/check/up arrive next):
#   fetch      download + sha256-verify the latest Arch ISO into the local cache
#   seed       generate the cloud-init NoCloud seed (vm-harness-seed, hypervisor
#              vmware: NVMe device path, open-vm-tools, live-ISO ssh for exec)
#   status     what exists: cache, seed, VM dir, vmrun's running list, newest log
#   destroy    stop the VM if running and delete the VM directory (cached ISO
#              and logs survive — logs live outside the VM dir)
#   tail [P]   print the newest log's tail (or phase P's newest)
#
# Logging: every phase writes an append-only log to  $LogDir\<stamp>-<phase>.log
# ending with "=== <phase> done rc=N" — the same trailer contract the bash
# harness's tooling (status/tail/resume probes, progress display) keys on.
#
# Env overrides mirror the bash harness where they apply:
#   VM_HARNESS_DIR, VM_HARNESS_DISK (GiB, bare number), VM_HARNESS_CLASS,
#   VM_HARNESS_REPO, VM_HARNESS_BRANCH.

$ErrorActionPreference = 'Stop'

$VmName = 'arch-harness'
$WorkDir = if ($env:VM_HARNESS_DIR) { $env:VM_HARNESS_DIR } else { Join-Path $env:LOCALAPPDATA 'bootstrap-harness-vmware' }
$CacheDir = Join-Path $WorkDir 'cache'
$SeedDir = Join-Path $WorkDir 'seed'
$VmDir = Join-Path $WorkDir 'vm'
$LogDir = Join-Path $WorkDir 'logs'
$Iso = Join-Path $CacheDir 'archlinux-x86_64.iso'
$Mirror = 'https://geo.mirror.pkgbuild.com/iso/latest'
$DiskGib = if ($env:VM_HARNESS_DISK) { [int]$env:VM_HARNESS_DISK } else { 80 }
$VmUser = 'aaron'
$VmPass = 'vm'    # throwaway VM only; reachable only from this host's NAT
$RunStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Python = 'C:\Python314\python.exe'
$SeedTool = Join-Path $PSScriptRoot 'vm-harness-seed'
$VmRun = "$env:ProgramFiles\VMware\VMware Workstation\vmrun.exe"

function Say([string]$msg) { Write-Host "`n==> $msg" }
function Die([string]$msg) { Write-Host "vm-harness-vmware: FATAL: $msg" -ForegroundColor Red; exit 1 }

function Usage {
    # The header is the help, same convention as the bash harness.
    Get-Content $PSCommandPath | Select-Object -Skip 1 |
        ForEach-Object { if ($_ -match '^#\s?(.*)$') { $Matches[1] } else { break } } |
        Where-Object { $_ -ne $null }
}

# Run one phase with host-side logging: console gets the live stream, the log
# gets an append-only copy ending in the rc trailer the tooling contract needs.
function Invoke-Phase([string]$Phase, [scriptblock]$Body) {
    New-Item -ItemType Directory -Force $LogDir | Out-Null
    $log = Join-Path $LogDir "$RunStamp-$Phase.log"
    $rc = 0
    try {
        & $Body 2>&1 | Tee-Object -FilePath $log -Append
        if ($LASTEXITCODE -is [int] -and $LASTEXITCODE -ne 0) { $rc = $LASTEXITCODE }
    } catch {
        $_ | Out-String | Tee-Object -FilePath $log -Append | Write-Host
        $rc = 1
    }
    "=== $Phase done rc=$rc" | Tee-Object -FilePath $log -Append
    if ($rc -ne 0) {
        Die "phase '$Phase' failed (rc=$rc) — VM left as-is for inspection. Log: $log"
    }
}

function Get-HostPubkey {
    $k = Get-ChildItem "$env:USERPROFILE\.ssh\id_*.pub" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($k) { (Get-Content $k.FullName -Raw).Trim() }
    else {
        Say "WARNING: no ~/.ssh/id_*.pub on the host — ssh steps will password-prompt ($VmPass)"
        ''
    }
}

function Cmd-Fetch {
    Invoke-Phase 'fetch' {
        New-Item -ItemType Directory -Force $CacheDir | Out-Null
        Say "Fetching latest Arch ISO + checksum from $Mirror"
        Invoke-WebRequest -Uri "$Mirror/archlinux-x86_64.iso" -OutFile "$Iso.new"
        Invoke-WebRequest -Uri "$Mirror/sha256sums.txt" -OutFile (Join-Path $CacheDir 'sha256sums.txt')
        # Verify BEFORE renaming into place: a failed check must not leave a
        # bad ISO at the path later phases trust with a bare existence test.
        $line = Select-String -Path (Join-Path $CacheDir 'sha256sums.txt') -Pattern ' archlinux-x86_64\.iso$' | Select-Object -First 1
        if (-not $line) { throw 'no archlinux-x86_64.iso entry in sha256sums.txt' }
        $expected = ($line.Line -split '\s+')[0]
        $actual = (Get-FileHash "$Iso.new" -Algorithm SHA256).Hash.ToLower()
        if ($actual -ne $expected.ToLower()) {
            Remove-Item "$Iso.new" -Force
            throw 'ISO checksum verification failed (bad download discarded)'
        }
        Move-Item "$Iso.new" $Iso -Force
        Say ("ISO cached: {0:N0} MB" -f ((Get-Item $Iso).Length / 1MB))
    }
}

function Cmd-Seed {
    Invoke-Phase 'seed' {
        Say 'Generating cloud-init seed (fresh answers each time)'
        if (Test-Path $SeedDir) { Remove-Item -Recurse -Force $SeedDir }
        $pk = Get-HostPubkey
        $seedArgs = @('--out', $SeedDir, '--hypervisor', 'vmware',
                      '--disk-size', $DiskGib, '--password', $VmPass, '--user', $VmUser)
        if ($pk) { $seedArgs += @('--pubkey', $pk, '--live-ssh') }
        & $Python $SeedTool @seedArgs
        if ($LASTEXITCODE -ne 0) { throw "vm-harness-seed failed (rc=$LASTEXITCODE)" }
    }
}

function Cmd-Status {
    Say 'vm-harness-vmware status'
    "  cached ISO:  " + $(if (Test-Path $Iso) { "yes ({0:N0} MB)" -f ((Get-Item $Iso).Length / 1MB) } else { 'no — run: fetch' })
    "  seed:        " + $(if (Test-Path (Join-Path $SeedDir 'seed.iso')) { 'yes' } else { 'no — run: seed' })
    "  VM dir:      " + $(if (Test-Path $VmDir) { $VmDir } else { 'none' })
    if (Test-Path $VmRun) {
        "  running VMs: "
        & $VmRun list 2>&1 | ForEach-Object { "    $_" }
    } else {
        "  vmrun:       not found at $VmRun"
    }
    $newest = Get-ChildItem $LogDir -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
    if ($newest) {
        "  newest log:  $($newest.FullName)"
        Get-Content $newest.FullName -Tail 5 | ForEach-Object { "    $_" }
    }
}

function Cmd-Destroy {
    if (-not (Test-Path $VmDir)) { Say 'Nothing to destroy (no VM dir)'; return }
    $vmx = Get-ChildItem $VmDir -Filter '*.vmx' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($vmx -and (Test-Path $VmRun)) {
        $running = & $VmRun list 2>$null
        if ($running -match [regex]::Escape($vmx.FullName)) {
            Say "Stopping $VmName"
            & $VmRun stop $vmx.FullName hard 2>&1 | Out-Null
        }
    }
    Say 'Destroying VM directory (cached ISO + logs kept)'
    Remove-Item -Recurse -Force $VmDir -Confirm:$false
    if (Test-Path $SeedDir) { Remove-Item -Recurse -Force $SeedDir -Confirm:$false }
}

function Cmd-Tail([string]$Phase) {
    $filter = if ($Phase) { "*-$Phase.log" } else { '*.log' }
    $newest = Get-ChildItem $LogDir -Filter $filter -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
    if (-not $newest) { Die "no logs under $LogDir" }
    Write-Host "==> $($newest.FullName)"
    Get-Content $newest.FullName -Tail 40
}

switch ($args[0]) {
    'fetch'   { Cmd-Fetch }
    'seed'    { Cmd-Seed }
    'status'  { Cmd-Status }
    'destroy' { Cmd-Destroy }
    'tail'    { Cmd-Tail $args[1] }
    'help'    { Usage }
    $null     { Usage; exit 2 }
    default   { Write-Host "vm-harness-vmware: unknown subcommand '$($args[0])'" -ForegroundColor Red; Usage; exit 2 }
}
