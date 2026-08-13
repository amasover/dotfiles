# vm-harness-vmware — disposable VMware Workstation validation harness (Windows host).
#
# PowerShell sibling of the libvirt/QEMU vm-harness (Story 2.36, #119): fresh-
# installs Arch unattended in a throwaway VMware Workstation VM, runs the repo
# bootstrap inside it, and asserts the result. Same pipeline vocabulary and
# logging contract as the bash harness; hypervisor plumbing differs. Thin
# driver by design — logic lives in Python (vm-harness-seed / -vmx / -leases),
# guest-side bash is shared with the libvirt harness.
#
# Subcommands (remaining for slice 4: --progress display + ANSI scrub):
#   fetch      download + sha256-verify the latest Arch ISO into the local cache
#   seed       generate the cloud-init NoCloud seed (vm-harness-seed, hypervisor
#              vmware: NVMe device path, open-vm-tools, live-ISO ssh for exec)
#   create     VM directory: fresh seed, growable NVMe disk (vdiskmanager),
#              .vmx via vm-harness-vmx (UEFI, serial-to-file, NAT). Dies if the
#              VM already exists — destroy is always explicit
#   install    power on headless; archinstall runs via cloud-init and streams
#              to the serial log, mirrored here live; VM powers itself off;
#              media is then ejected so later boots hit the disk
#   boot       start the installed VM headless; wait for an authenticated ssh
#              login, then print the IP
#   up         everything to a green check: create → install → boot →
#              bootstrap → check, resuming past phases live state proves done
#              (vm-harness-vmx resume). Never destroys; a died install stops
#              it with the remedy
#   bootstrap  clone + converge the repo inside the guest via the shared
#              vm-harness-guest glue (scp'd fresh each run); class/repo/branch
#              from the env overrides below
#   check      assert the end state (metapac unmanaged empty is the hard gate)
#              via vm-harness-guest check
#   exec CMD   run a command in the guest over ssh (root while the live ISO is
#              up, $VmUser once installed); remote exit code propagated
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
# VM_HARNESS_TRUST_DIR overrides where the AUR trust baseline is read from
# (default ~\.local\state\aur-quarantine) — see Send-TrustBaseline.

$ErrorActionPreference = 'Stop'

# The guest talks UTF-8 (ssh, serial); decode native command output as such —
# the Windows default (OEM CP437) turns every guest em-dash into 'ΓÇö', on the
# console and in the phase log alike. Process-wide, which is fine: sessions
# that dot-run this get UTF-8 native decoding, an improvement either way.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

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
$Repo = if ($env:VM_HARNESS_REPO) { $env:VM_HARNESS_REPO } else { 'https://github.com/amasover/dotfiles.git' }
$Branch = $env:VM_HARNESS_BRANCH  # guest clones this branch (default: repo default = main);
                                  # set it to validate guest-side bootstrap changes pre-merge
$Class = if ($env:VM_HARNESS_CLASS) { $env:VM_HARNESS_CLASS } else { 'workstation' }
# The harness-owned guest hardware set (interim home until 2.30's split, #96) —
# the one per-hypervisor difference the shared guest glue takes as a parameter.
$HardwarePkgs = 'open-vm-tools zram-generator'
$SshOpts = @('-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL',
             '-o', 'LogLevel=ERROR')
$Vmx = Join-Path $VmDir "$VmName.vmx"
$DiskVmdk = Join-Path $VmDir 'disk.vmdk'
$SerialLog = Join-Path $VmDir 'install-serial.log'
$RunStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Python = 'C:\Python314\python.exe'
$SeedTool = Join-Path $PSScriptRoot 'vm-harness-seed'
$VmxTool = Join-Path $PSScriptRoot 'vm-harness-vmx'
$LeasesTool = Join-Path $PSScriptRoot 'vm-harness-leases'
$GuestTool = Join-Path $PSScriptRoot 'vm-harness-guest'
# Workstation's install root moved between releases (26H1: Program Files;
# 25H2: Program Files (x86)) — take whichever actually has vmrun.
$VmwareDir = @("$env:ProgramFiles\VMware\VMware Workstation",
               "${env:ProgramFiles(x86)}\VMware\VMware Workstation") |
    Where-Object { Test-Path (Join-Path $_ 'vmrun.exe') } | Select-Object -First 1
if (-not $VmwareDir) { $VmwareDir = "$env:ProgramFiles\VMware\VMware Workstation" }
$VmRun = Join-Path $VmwareDir 'vmrun.exe'
$VdiskMgr = Join-Path $VmwareDir 'vmware-vdiskmanager.exe'
$InstallTimeoutMin = 60

# One writer owns the phase log (Invoke-Phase). Everything else appends
# through it — a second Add-Content writer would fight the open handle, which
# is exactly the crash the first live `up` hit.
function Write-PhaseLog([string]$Text, [switch]$NoNewline) {
    if (-not $script:PhaseWriter) { return }
    if ($NoNewline) { $script:PhaseWriter.Write($Text) }
    else { $script:PhaseWriter.WriteLine($Text) }
}

function Say([string]$msg) {
    # Write-Host is invisible to the phase pipeline (information stream), so
    # narrative markers reach the log through the phase writer.
    Write-Host "`n==> $msg"
    Write-PhaseLog "`n==> $msg"
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
# The log has exactly one writer — a shared-read StreamWriter this function
# owns (AutoFlush keeps `tail` near-live); pipeline output, Say markers, and
# serial chunks all append through it, so nothing fights over the handle.
function Invoke-Phase([string]$Phase, [scriptblock]$Body) {
    New-Item -ItemType Directory -Force $LogDir | Out-Null
    $log = Join-Path $LogDir "$RunStamp-$Phase.log"
    $fs = [System.IO.File]::Open($log, [System.IO.FileMode]::Append,
        [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
    $script:PhaseWriter = [System.IO.StreamWriter]::new($fs)
    $script:PhaseWriter.AutoFlush = $true
    $rc = 0
    try {
        & $Body 2>&1 | ForEach-Object { Write-PhaseLog "$_"; $_ }
        if ($LASTEXITCODE -is [int] -and $LASTEXITCODE -ne 0) { $rc = $LASTEXITCODE }
    } catch {
        $msg = $_ | Out-String
        Write-PhaseLog $msg
        Write-Host $msg
        $rc = 1
    }
    Write-PhaseLog "=== $Phase done rc=$rc"
    "=== $Phase done rc=$rc"
    $script:PhaseWriter.Close()
    $script:PhaseWriter = $null
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
    Write-PhaseLog $Text -NoNewline
}

# vm-harness-vmx owns the vmx format; the driver only asks.
function Get-MediaState {
    $s = & $Python $VmxTool media --vmx $Vmx
    if ($LASTEXITCODE -ne 0) { throw "vm-harness-vmx media failed (rc=$LASTEXITCODE)" }
    $s
}

# Live ISO (media attached) carries root + the seeded key; the installed
# system carries $VmUser. ssh targets follow the VM's state, no flag.
function Get-GuestUser { if ((Get-MediaState) -eq 'attached') { 'root' } else { $VmUser } }

# Poll for an authenticated login — not an open port: a login is what the next
# phase needs (ported from the bash harness's wait_ssh; also closes the
# stale-lease gap — the vmnet lease predates a reboot, same MAC, so an IP
# alone proves nothing about the guest).
function Wait-Ssh {
    $user = Get-GuestUser
    Say 'Waiting for ssh (up to ~2 min)'
    for ($i = 0; $i -lt 40; $i++) {
        $ip = Get-GuestIp
        if ($ip) {
            $out = & ssh -o BatchMode=yes -o ConnectTimeout=2 @SshOpts "$user@$ip" true 2>&1
            if ($LASTEXITCODE -eq 0) { Say "ssh ready: $user@$ip"; return $ip }
            if ("$out" -match 'Permission denied') {
                Say "sshd up at $ip (key auth refused — expect password prompts)"
                return $ip
            }
        }
        Start-Sleep -Seconds 3
    }
    throw 'no ssh after ~2 minutes — check: status, tail install'
}

# scp the host's AUR trust state (maintainers.tsv + exempt.txt) into the VM
# before bootstrap, same baseline a decrypt-restored machine would have
# (Story 2.10). Windows has no Arch state dir to read, so the source is
# overridable (VM_HARNESS_TRUST_DIR) and populated once by extracting just
# those two members from the yadm archive — recipe:
# knowledge/recipes/windows-trust-baseline.md. Without it the guest runs
# fresh TOFU, which trusts whatever it sees: fine for fast iteration, wrong
# for runs meant to predict a real rebuild (design note on #119).
function Send-TrustBaseline([string]$Ip) {
    $sdir = if ($env:VM_HARNESS_TRUST_DIR) { $env:VM_HARNESS_TRUST_DIR }
            else { Join-Path $env:USERPROFILE '.local\state\aur-quarantine' }
    $have = @('maintainers.tsv', 'exempt.txt') |
        ForEach-Object { Join-Path $sdir $_ } | Where-Object { Test-Path $_ }
    if (-not $have) {
        Say "Trust baseline: none on host ($sdir) — VM runs fresh (TOFU)"
        return
    }
    Say "Trust baseline: injecting $(($have | Split-Path -Leaf) -join ' ') into the VM"
    & ssh @SshOpts "$VmUser@$Ip" 'mkdir -p ~/.local/state/aur-quarantine'
    & scp @SshOpts -q @have "$VmUser@${Ip}:.local/state/aur-quarantine/"
    if ($LASTEXITCODE -ne 0) { throw "trust baseline scp failed (rc=$LASTEXITCODE)" }
}

# Push the shared guest glue (fresh each run — the guest executes the host
# checkout's version) and run one of its subcommands, streaming output.
function Invoke-GuestGlue([string]$Ip, [string]$RemoteCmd) {
    & scp @SshOpts -q $GuestTool "$VmUser@${Ip}:vm-harness-guest"
    if ($LASTEXITCODE -ne 0) { throw "scp vm-harness-guest failed (rc=$LASTEXITCODE)" }
    & ssh @SshOpts "$VmUser@$Ip" $RemoteCmd 2>&1
    if ($LASTEXITCODE -ne 0) { throw "guest command failed (rc=$LASTEXITCODE): $RemoteCmd" }
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
        $ip = Wait-Ssh
        Say "Up. ssh $VmUser@$ip   (password: $VmPass, or the seeded host key)"
    }
}

function Cmd-Bootstrap {
    Invoke-Phase 'bootstrap' {
        if (-not (Test-Path $Vmx)) { throw 'run: create first' }
        if ((Get-MediaState) -ne 'ejected') { throw 'not installed yet — run: install' }
        if (-not (Test-VmRunning)) { throw 'VM not running — run: boot' }
        $ip = Wait-Ssh
        Send-TrustBaseline $ip
        Say "Running repo bootstrap inside the VM (class: $Class, unattended; AUR builds take a while)"
        $cmd = "bash vm-harness-guest bootstrap --class '$Class' --repo '$Repo' --hardware-pkgs '$HardwarePkgs'"
        if ($Branch) { $cmd += " --branch '$Branch'" }
        Invoke-GuestGlue $ip $cmd
    }
}

function Cmd-Check {
    Invoke-Phase 'check' {
        if (-not (Test-Path $Vmx)) { throw 'run: create first' }
        if ((Get-MediaState) -ne 'ejected') { throw 'not installed yet — run: install' }
        if (-not (Test-VmRunning)) { throw 'VM not running — run: boot' }
        $ip = Wait-Ssh
        Say 'Asserting VM end state'
        Invoke-GuestGlue $ip 'bash vm-harness-guest check'
    }
}

function Cmd-Exec([string[]]$Command) {
    if (-not (Test-Path $Vmx)) { Die 'no VM — run: create' }
    if (-not $Command) { Die 'usage: exec CMD [ARGS...]' }
    $ip = Get-GuestIp
    if (-not $ip) { Die 'no IP known (VM off, or no lease yet)' }
    $user = Get-GuestUser
    & ssh @SshOpts "$user@$ip" -- @Command
    exit $LASTEXITCODE
}

# Facts in, phase out — the decision table lives in vm-harness-vmx (pytest).
function Get-ResumePoint {
    $media = if (Test-Path $Vmx) { Get-MediaState } else { 'absent' }
    $p = & $Python $VmxTool resume --media $media `
        --disk $(if (Test-Path $DiskVmdk) { 'yes' } else { 'no' }) `
        --seed $(if (Test-Path (Join-Path $SeedDir 'seed.iso')) { 'yes' } else { 'no' }) `
        --serial-log $(if (Test-Path $SerialLog) { 'yes' } else { 'no' }) `
        --running $(if (Test-VmRunning) { 'yes' } else { 'no' })
    if ($LASTEXITCODE -ne 0) { throw "vm-harness-vmx resume failed (rc=$LASTEXITCODE)" }
    $p
}

function Cmd-Up {
    $from = Get-ResumePoint
    if ($from -eq 'dead-install') {
        Die "VM powered on before but install media is still attached — it died mid-install (up never auto-destroys).
Next:  vm-harness-vmware install   (safe re-install in place)   or:  destroy"
    }
    if ($from -eq 'install-running') {
        Die 'an install appears to be running right now — watch it (tail install) or vmrun stop first'
    }
    $phases = @('create', 'install', 'boot', 'bootstrap', 'check')
    $idx = [array]::IndexOf($phases, $from)
    if ($idx -gt 0) {
        Say "resume: skipped $($phases[0..($idx - 1)] -join ' ') (probed complete) — starting at $from"
    }
    # create boots nothing, but install boots the ISO straight from the cache —
    # both need it present. An explicit `fetch` stays the force-refresh.
    if (-not (Test-Path $Iso) -and $idx -le 1) { Cmd-Fetch }
    foreach ($p in $phases[$idx..($phases.Count - 1)]) {
        switch ($p) {
            'create'    { Cmd-Create }
            'install'   { Cmd-Install }
            'boot'      { Cmd-Boot }
            'bootstrap' { Cmd-Bootstrap }
            'check'     { Cmd-Check }
        }
    }
    Say 'up complete — all phases green'
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
    'fetch'     { Cmd-Fetch }
    'seed'      { Cmd-Seed }
    'create'    { Cmd-Create }
    'install'   { Cmd-Install }
    'boot'      { Cmd-Boot }
    'up'        { Cmd-Up }
    'bootstrap' { Cmd-Bootstrap }
    'check'     { Cmd-Check }
    'exec'      { Cmd-Exec @(@($args) | Select-Object -Skip 1) }
    'ip'        { Cmd-Ip }
    'status'    { Cmd-Status }
    'destroy'   { Cmd-Destroy }
    'tail'      { Cmd-Tail $args[1] }
    'help'    { Usage }
    $null     { Usage; exit 2 }
    default   { Write-Host "vm-harness-vmware: unknown subcommand '$($args[0])'" -ForegroundColor Red; Usage; exit 2 }
}
