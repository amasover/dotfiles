# vm-harness-vmware — disposable VMware Workstation validation harness (Windows host).
#
# PowerShell sibling of the libvirt/QEMU vm-harness (Story 2.36, #119): fresh-
# installs Arch unattended in a throwaway VMware Workstation VM, runs the repo
# bootstrap inside it, and asserts the result. Same pipeline vocabulary and
# logging contract as the bash harness; hypervisor plumbing differs. Thin
# driver by design — logic lives in Python (vm-harness-seed / -vmx / -leases),
# guest-side bash is shared with the libvirt harness.
#
# Subcommands (bootstrap/check/up arrive in the next slice):
#   fetch      download + sha256-verify the latest Arch ISO into the local cache
#   seed       generate the cloud-init NoCloud seed (vm-harness-seed, hypervisor
#              vmware: NVMe device path, open-vm-tools, live-ISO ssh for exec)
#   create     VM directory: fresh seed, growable NVMe disk (vdiskmanager),
#              .vmx via vm-harness-vmx (UEFI, serial-to-file, NAT). Dies if the
#              VM already exists — destroy is always explicit
#   install    power on headless; archinstall runs via cloud-init and streams
#              to the serial log, mirrored here live; VM powers itself off;
#              media is then ejected so later boots hit the disk
#   boot       start the installed VM headless; wait for the NAT IP + sshd,
#              then print the IP
#   ip         print the VM's IPv4 (vmrun guest-tools query, falling back to
#              the vmnet DHCP leases via vm-harness-leases — works for the
#              live ISO too)
#   status     what exists: cache, seed, VM state, vmrun list, newest log
#   destroy    stop the VM if running and delete the VM directory (cached ISO
#              and logs survive — logs live outside the VM dir)
#   tail [P]   print the newest log's tail (or phase P's newest)
#
# Logging: every phase writes an append-only log to  $LogDir\<stamp>-<phase>.log
# ending with "=== <phase> done rc=N" — the same trailer contract the bash
# harness's tooling (status/tail/resume probes, progress display) keys on.
# Serial output streams raw to the console and into the install phase log this
# slice (the bash harness's ANSI scrub ports with the progress-display work).
#
# Env overrides mirror the bash harness where they apply:
#   VM_HARNESS_DIR, VM_HARNESS_DISK (GiB, bare number), VM_HARNESS_RAM (MiB),
#   VM_HARNESS_CPUS, VM_HARNESS_CLASS, VM_HARNESS_REPO, VM_HARNESS_BRANCH.

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
$RamMib = if ($env:VM_HARNESS_RAM) { [int]$env:VM_HARNESS_RAM } else { 12288 }
$Cpus = if ($env:VM_HARNESS_CPUS) { [int]$env:VM_HARNESS_CPUS } else { 16 }
$VmUser = 'aaron'
$VmPass = 'vm'    # throwaway VM only; reachable only from this host's NAT
$Vmx = Join-Path $VmDir "$VmName.vmx"
$DiskVmdk = Join-Path $VmDir 'disk.vmdk'
$SerialLog = Join-Path $VmDir 'install-serial.log'
$RunStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Python = 'C:\Python314\python.exe'
$SeedTool = Join-Path $PSScriptRoot 'vm-harness-seed'
$VmxTool = Join-Path $PSScriptRoot 'vm-harness-vmx'
$LeasesTool = Join-Path $PSScriptRoot 'vm-harness-leases'
# Workstation's install root moved between releases (26H1: Program Files;
# 25H2: Program Files (x86)) — take whichever actually has vmrun.
$VmwareDir = @("$env:ProgramFiles\VMware\VMware Workstation",
               "${env:ProgramFiles(x86)}\VMware\VMware Workstation") |
    Where-Object { Test-Path (Join-Path $_ 'vmrun.exe') } | Select-Object -First 1
if (-not $VmwareDir) { $VmwareDir = "$env:ProgramFiles\VMware\VMware Workstation" }
$VmRun = Join-Path $VmwareDir 'vmrun.exe'
$VdiskMgr = Join-Path $VmwareDir 'vmware-vdiskmanager.exe'
$InstallTimeoutMin = 60

function Say([string]$msg) {
    # Write-Host bypasses Invoke-Phase's pipeline Tee (information stream), so
    # mirror narrative markers into the active phase log by hand.
    Write-Host "`n==> $msg"
    if ($script:PhaseLog) { Add-Content -Path $script:PhaseLog -Value "`n==> $msg" }
}
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
    $script:PhaseLog = $log
    $rc = 0
    try {
        & $Body 2>&1 | Tee-Object -FilePath $log -Append
        if ($LASTEXITCODE -is [int] -and $LASTEXITCODE -ne 0) { $rc = $LASTEXITCODE }
    } catch {
        $_ | Out-String | Tee-Object -FilePath $log -Append | Write-Host
        $rc = 1
    }
    "=== $Phase done rc=$rc" | Tee-Object -FilePath $log -Append
    $script:PhaseLog = $null
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

function Test-VmRunning {
    if (-not (Test-Path $Vmx)) { return $false }
    ((& $VmRun -T ws list) -join "`n") -match [regex]::Escape($Vmx)
}

# Read the serial log past $Offset without fighting VMware's open handle.
function Read-NewSerial([ref]$Offset) {
    if (-not (Test-Path $SerialLog)) { return '' }
    $fs = [System.IO.File]::Open($SerialLog, 'Open', 'Read', 'ReadWrite')
    try {
        if ($fs.Length -le $Offset.Value) { return '' }
        $fs.Position = $Offset.Value
        $buf = New-Object byte[] ($fs.Length - $Offset.Value)
        $read = 0
        while ($read -lt $buf.Length) {
            $n = $fs.Read($buf, $read, $buf.Length - $read)
            if ($n -le 0) { break }
            $read += $n
        }
        $Offset.Value += $read
        [System.Text.Encoding]::UTF8.GetString($buf, 0, $read)
    } finally { $fs.Close() }
}

# Serial chunks reach the console AND the phase log — Write-Host alone never
# lands in the log (see Say).
function Write-Serial([string]$Text) {
    if (-not $Text) { return }
    Write-Host $Text -NoNewline
    if ($script:PhaseLog) { Add-Content -Path $script:PhaseLog -Value $Text -NoNewline }
}

# vm-harness-vmx owns the vmx format; the driver only asks.
function Get-MediaState {
    $s = & $Python $VmxTool media --vmx $Vmx
    if ($LASTEXITCODE -ne 0) { throw "vm-harness-vmx media failed (rc=$LASTEXITCODE)" }
    $s
}

function Test-TcpPort([string]$Ip, [int]$Port) {
    $c = [System.Net.Sockets.TcpClient]::new()
    try { $c.ConnectAsync($Ip, $Port).Wait(2000) -and $c.Connected }
    catch { $false }
    finally { $c.Dispose() }
}

function New-Seed {
    Say 'Generating cloud-init seed (fresh answers each time)'
    if (Test-Path $SeedDir) { Remove-Item -Recurse -Force $SeedDir }
    $pk = Get-HostPubkey
    $seedArgs = @('--out', $SeedDir, '--hypervisor', 'vmware',
                  '--disk-size', $DiskGib, '--password', $VmPass, '--user', $VmUser)
    if ($pk) { $seedArgs += @('--pubkey', $pk, '--live-ssh') }
    & $Python $SeedTool @seedArgs
    if ($LASTEXITCODE -ne 0) { throw "vm-harness-seed failed (rc=$LASTEXITCODE)" }
}

function Get-GuestIp {
    # Tools answer once the installed system is up; the live ISO has no tools,
    # so fall back to the vmnet DHCP lease for the VM's generated MAC.
    $ip = & $VmRun -T ws getGuestIPAddress $Vmx 2>$null
    if ($LASTEXITCODE -eq 0 -and $ip -match '^\d+\.\d+\.\d+\.\d+$') { return $ip }
    $mac = & $Python $VmxTool mac --vmx $Vmx 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    $ip = & $Python $LeasesTool --mac $mac 2>$null
    if ($LASTEXITCODE -eq 0) { return $ip }
    $null
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

function Cmd-Seed { Invoke-Phase 'seed' { New-Seed } }

function Cmd-Create {
    Invoke-Phase 'create' {
        if (-not (Test-Path $Iso)) { throw 'no cached ISO — run: fetch' }
        if (Test-Path $Vmx) { throw "VM '$VmName' exists — run: destroy first" }
        New-Item -ItemType Directory -Force $VmDir | Out-Null
        New-Seed
        Say "Creating VM (disk ${DiskGib}G, ram ${RamMib}M, $Cpus vcpus)"
        # No vmx (checked above), so a disk here is a failed create's debris.
        if (Test-Path $DiskVmdk) { Remove-Item -Force $DiskVmdk }
        & $VdiskMgr -c -s "${DiskGib}GB" -a lsilogic -t 0 $DiskVmdk 2>&1
        if ($LASTEXITCODE -ne 0) { throw "vdiskmanager failed (rc=$LASTEXITCODE)" }
        & $Python $VmxTool generate --out $Vmx --name $VmName --disk $DiskVmdk `
            --iso $Iso --seed-iso (Join-Path $SeedDir 'seed.iso') `
            --serial-log $SerialLog --ram $RamMib --cpus $Cpus
        if ($LASTEXITCODE -ne 0) { throw "vm-harness-vmx failed (rc=$LASTEXITCODE)" }
        Say 'Ready. Next: install'
    }
}

function Cmd-Install {
    Invoke-Phase 'install' {
        if (-not (Test-Path $Vmx)) { throw 'run: create first' }
        if ((Get-MediaState) -eq 'ejected') {
            throw 'media already ejected — installed. Next: boot (or destroy for a fresh install)'
        }
        if (Test-VmRunning) { throw 'VM already running — vmrun stop it (or destroy) first' }
        # A dead run's log could satisfy the exit-marker check below.
        if (Test-Path $SerialLog) { Remove-Item -Force $SerialLog }
        Say 'Unattended install — serial console streams below (also: tail install)'
        & $VmRun -T ws start $Vmx nogui 2>&1
        if ($LASTEXITCODE -ne 0) { throw "vmrun start failed (rc=$LASTEXITCODE)" }
        $offset = [long]0
        $deadline = (Get-Date).AddMinutes($InstallTimeoutMin)
        do {
            Start-Sleep -Seconds 5
            Write-Serial (Read-NewSerial ([ref]$offset))
            if ((Get-Date) -gt $deadline) {
                throw "install still running after $InstallTimeoutMin min — inspect: tail install, or vmrun stop + destroy"
            }
        } while (Test-VmRunning)
        Write-Serial (Read-NewSerial ([ref]$offset))
        $serial = if (Test-Path $SerialLog) { Get-Content $SerialLog -Raw } else { '' }
        if ($serial -notmatch 'HARNESS-ARCHINSTALL-EXIT:0') {
            throw 'VM powered off without a clean archinstall exit — read the serial output above'
        }
        Say 'Install done — ejecting media so later boots hit the disk'
        & $Python $VmxTool eject --vmx $Vmx
        if ($LASTEXITCODE -ne 0) { throw "media eject failed (rc=$LASTEXITCODE)" }
        if ((Get-MediaState) -ne 'ejected') { throw 'eject did not take — inspect the vmx' }
        Say 'Next: boot'
    }
}

function Cmd-Boot {
    Invoke-Phase 'boot' {
        if (-not (Test-Path $Vmx)) { throw 'run: create first' }
        if ((Get-MediaState) -ne 'ejected') {
            throw 'not installed yet — run: install'
        }
        if (Test-VmRunning) { Say 'Already running' }
        else {
            & $VmRun -T ws start $Vmx nogui 2>&1
            if ($LASTEXITCODE -ne 0) { throw "vmrun start failed (rc=$LASTEXITCODE)" }
        }
        # The lease can predate this boot (same MAC since the install phase),
        # so an IP alone doesn't prove the guest came up — wait for sshd.
        Say 'Waiting for the NAT lease + sshd'
        $deadline = (Get-Date).AddMinutes(3)
        $ip = $null
        $ssh = $false
        do {
            Start-Sleep -Seconds 5
            $ip = Get-GuestIp
            $ssh = ($null -ne $ip) -and (Test-TcpPort $ip 22)
        } until ($ssh -or (Get-Date) -gt $deadline)
        if (-not $ip) { throw 'no IP after 3 min — vmnet DHCP lease missing; check: status' }
        if (-not $ssh) { throw "guest has IP $ip but never opened ssh (22) — check: status, tail install" }
        Say "Up. ssh $VmUser@$ip   (password: $VmPass, or the seeded host key)"
    }
}

function Cmd-Ip {
    if (-not (Test-Path $Vmx)) { Die 'no VM — run: create' }
    $ip = Get-GuestIp
    if (-not $ip) { Die 'no IP known (VM off, or no lease yet)' }
    $ip
}

function Cmd-Status {
    Say 'vm-harness-vmware status'
    "  cached ISO:  " + $(if (Test-Path $Iso) { "yes ({0:N0} MB)" -f ((Get-Item $Iso).Length / 1MB) } else { 'no — run: fetch' })
    "  seed:        " + $(if (Test-Path (Join-Path $SeedDir 'seed.iso')) { 'yes' } else { 'no — run: seed' })
    if (Test-Path $Vmx) {
        $installed = (Get-MediaState) -eq 'ejected'
        "  VM:          $Vmx"
        "  installed:   " + $(if ($installed) { 'yes (media ejected)' } else { 'no — next: install' })
        "  running:     " + $(if (Test-VmRunning) { "yes (ip: $(Get-GuestIp))" } else { 'no' })
    } else {
        "  VM:          none — next: create"
    }
    if (-not (Test-Path $VmRun)) { "  vmrun:       NOT FOUND at $VmRun" }
    $newest = Get-ChildItem $LogDir -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
    if ($newest) {
        "  newest log:  $($newest.FullName)"
        Get-Content $newest.FullName -Tail 5 | ForEach-Object { "    $_" }
    }
}

function Cmd-Destroy {
    if (-not (Test-Path $VmDir)) { Say 'Nothing to destroy (no VM dir)'; return }
    if ((Test-Path $Vmx) -and (Test-VmRunning)) {
        Say "Stopping $VmName"
        & $VmRun -T ws stop $Vmx hard 2>&1 | Out-Null
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
    'create'  { Cmd-Create }
    'install' { Cmd-Install }
    'boot'    { Cmd-Boot }
    'ip'      { Cmd-Ip }
    'status'  { Cmd-Status }
    'destroy' { Cmd-Destroy }
    'tail'    { Cmd-Tail $args[1] }
    'help'    { Usage }
    $null     { Usage; exit 2 }
    default   { Write-Host "vm-harness-vmware: unknown subcommand '$($args[0])'" -ForegroundColor Red; Usage; exit 2 }
}
