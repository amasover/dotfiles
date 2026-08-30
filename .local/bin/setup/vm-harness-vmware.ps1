# vm-harness-vmware — disposable VMware Workstation validation harness (Windows host).
#
# PowerShell sibling of the libvirt/QEMU vm-harness (Story 2.36, #119): fresh-
# installs Arch unattended in a throwaway VMware Workstation VM, runs the repo
# bootstrap inside it, and asserts the result. Same pipeline vocabulary and
# logging contract as the bash harness; hypervisor plumbing differs. Thin
# driver by design — logic lives in Python (vm-harness-seed / -vmx / -leases),
# guest-side bash is shared with the libvirt harness.
#
# Flags (before the subcommand, same vocabulary as the bash harness):
#   --progress compact display instead of the stream: three live rows (phase
#              breadcrumb · bootstrap step strip · latest anchor); a failing
#              phase prints its log tail. Needs a console; rejects --plain.
#   --plain    bare raw stream — no bottom bar.
# Default with an interactive console: the raw stream plus the pinned bottom
# rows rendered by the shared tools/vm-harness-display (python-rich styling
# when present, unstyled otherwise). Redirected stdout falls back to plain
# and the log-side scrub still applies.
#
# Subcommands:
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
#              up, aaron once installed); remote exit code propagated
#   trust-import
#              one-time host setup: extract the AUR trust baseline from the
#              yadm archive into the trust dir (gpg prompts; only the two
#              identity files land — knowledge/recipes/windows-trust-baseline.md)
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
# The log copy is scrubbed (ANSI escapes stripped, CR redraws flattened) by
# the shared display tool, which owns the whole phase output path: the driver
# feeds it the raw stream on stdin, it appends the scrubbed copy to the log
# (--log) and renders the console leg per the mode above. Same filter as the
# bash harness's `scrub`; test seam: vm-harness-display --mode scrub.
#
# The guest glue runs under a pty when one is available (`ssh -t`, revising
# the slice-4 no-pty call — attended runs came out colorless, the cost that
# decision underestimated): with the local console as stdin, the guest tools
# see a tty and emit color; without one, ssh warns and proceeds pty-less —
# the same arms the bash harness's vm_ssh has. The slice-4 caveats hold but
# are absorbed downstream: the scrub drops the pty's CR-frames and caret
# echo from the logs, and PowerShell's line-oriented native pipeline means
# redraw bursts reach the console one line at a time (final frame, in color)
# rather than animating — colors yes, live bars no.
#
# Env overrides mirror the bash harness where they apply:
#   VM_HARNESS_DIR, VM_HARNESS_DISK (GiB, bare number), VM_HARNESS_RAM (MiB),
#   VM_HARNESS_CPUS, VM_HARNESS_CLASS, VM_HARNESS_REPO, VM_HARNESS_BRANCH.
# VM_HARNESS_TRUST_DIR overrides where the AUR trust baseline lives — both
# where trust-import writes it and where bootstrap reads it (default
# ~\.local\state\aur-quarantine); see Get-TrustDir.

$ErrorActionPreference = 'Stop'

# The guest talks UTF-8 (ssh, serial); decode native command output as such —
# the Windows default (OEM CP437) turns every guest em-dash into 'ΓÇö', on the
# console and in the phase log alike. Process-wide, which is fine: sessions
# that dot-run this get UTF-8 native decoding, an improvement either way.
# Both encodings are the BOM-less instance: $OutputEncoding governs the bytes
# PowerShell feeds a native command's stdin, and [System.Text.Encoding]::UTF8
# carries a preamble that would arrive as a BOM on the far side.
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = $Utf8NoBom
$OutputEncoding = $Utf8NoBom

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
$Class = if ($env:VM_HARNESS_CLASS) { $env:VM_HARNESS_CLASS } else { 'daily-vm' }
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
$TrustTool = Join-Path $PSScriptRoot 'vm-harness-trust'
# .local/bin/setup -> .local/bin/tools: the display/scrub tool both harnesses share.
$DisplayTool = Join-Path $PSScriptRoot '..\tools\vm-harness-display'
$script:DisplayMode = 'plain'   # resolved at dispatch: bar | compact | plain
$script:PhasesStatus = ''       # Cmd-Up breadcrumb for the display: name:done|current|pending,...
$script:ResumeHeader = ''       # set by a resuming up; Invoke-Phase logs it once
$script:SinkDied = $false       # display child died mid-phase — output was lost
# .local/bin/setup -> .local/share/yadm/archive, in whichever checkout runs.
$Archive = Join-Path $PSScriptRoot '..\..\share\yadm\archive'
# Workstation's install root moved between releases (26H1: Program Files;
# 25H2: Program Files (x86)) — take whichever actually has vmrun.
$VmwareDir = @("$env:ProgramFiles\VMware\VMware Workstation",
               "${env:ProgramFiles(x86)}\VMware\VMware Workstation") |
    Where-Object { Test-Path (Join-Path $_ 'vmrun.exe') } | Select-Object -First 1
if (-not $VmwareDir) { $VmwareDir = "$env:ProgramFiles\VMware\VMware Workstation" }
$VmRun = Join-Path $VmwareDir 'vmrun.exe'
$VdiskMgr = Join-Path $VmwareDir 'vmware-vdiskmanager.exe'
$InstallTimeoutMin = 60

# One sink owns the phase output (Invoke-Phase): the display child's stdin.
# Everything a phase emits goes through it — the child scrubs into the log
# (its append handle is the log's only writer until it exits) and renders the
# console leg, so nothing fights over the file and nothing corrupts the
# pinned rows by writing to the console directly.
function Write-PhaseLog([string]$Text, [switch]$NoNewline) {
    if (-not $script:PhaseWriter) { return }
    try {
        if ($NoNewline) { $script:PhaseWriter.Write($Text) }
        else { $script:PhaseWriter.WriteLine($Text) }
    } catch {
        # Display child gone mid-phase (it shouldn't be — it exits 0 even on
        # render failure; only a --log failure is fatal by contract). Drop the
        # sink so the phase still reaches its rc trailer, and REMEMBER: every
        # byte from here on is lost, so Invoke-Phase must fail the phase (the
        # bash harness fails it via pipefail) instead of reporting a clean rc
        # over a truncated log.
        $script:PhaseWriter = $null
        $script:SinkDied = $true
    }
}

function Say([string]$msg) {
    # Inside a phase the display child renders the marker (bar/plain mirror
    # their stdin) — a Write-Host here would double it and corrupt compact's
    # pinned rows. Outside a phase there is no sink, so speak directly.
    if ($script:PhaseWriter) { Write-PhaseLog "`n==> $msg" }
    else { Write-Host "`n==> $msg" }
}
function Die([string]$msg) { Write-Host "vm-harness-vmware: FATAL: $msg" -ForegroundColor Red; exit 1 }

function Usage {
    # The header is the help, same convention as the bash harness. A real
    # foreach, not ForEach-Object: `break` inside a pipeline has no loop to
    # leave, so it unwound the whole script and the caller's `exit 2` never
    # ran — `vm-harness-vmware frobnicate` reported success.
    foreach ($line in (Get-Content $PSCommandPath | Select-Object -Skip 1)) {
        if ($line -match '^#\s?(.*)$') { $Matches[1] } else { break }
    }
}

# Run one phase with host-side logging (2.36 slice 4: through the shared
# display tool). The tool takes the raw stream on stdin, appends the scrubbed
# copy to the log (--log, write-through — `tail` stays near-live) and renders
# the console leg per $DisplayMode: bar mirrors raw plus the pinned rows,
# compact renders rows only, plain passes through (raw on a console, scrubbed
# into a redirect). The child is the log's only writer until it exits; the rc
# trailer is appended after WaitForExit, so the trailer contract holds and
# nothing fights over the handle.
function Invoke-Phase([string]$Phase, [scriptblock]$Body) {
    # The sink is every phase's only output path — a missing interpreter or
    # tool must die HERE with a name, not lose the whole phase to a dead sink
    # (adversarial review, 2026-08-16: the spawn was unconditional and a dead
    # child silently swallowed all output while the phase reported rc=0).
    if (-not (Test-Path $Python)) { Die "python not found at $Python — every phase logs through the display tool" }
    if (-not (Test-Path $DisplayTool)) { Die "display tool missing: $DisplayTool — phase output would be lost (yadm checkout it)" }
    New-Item -ItemType Directory -Force $LogDir | Out-Null
    $log = Join-Path $LogDir "$RunStamp-$Phase.log"
    # A resumed `up` stamps its first log with what it skipped (bash parity);
    # written before the child opens its append handle. Consumed on first use.
    # AppendAllText, not Add-Content: the scrubbed body lines are LF, and the
    # trailer is the one line tooling greps for — no stray \r on it.
    if ($script:ResumeHeader) {
        [System.IO.File]::AppendAllText($log, "$($script:ResumeHeader)`n")
        $script:ResumeHeader = ''
    }
    $psi = [System.Diagnostics.ProcessStartInfo]::new($Python)
    foreach ($a in @($DisplayTool, '--mode', $script:DisplayMode,
                     '--phase', $Phase, '--log', $log)) { $psi.ArgumentList.Add($a) }
    if ($script:PhasesStatus) {
        $psi.ArgumentList.Add('--phases'); $psi.ArgumentList.Add($script:PhasesStatus)
    }
    $psi.UseShellExecute = $false          # stdout/stderr stay on the console
    $psi.RedirectStandardInput = $true
    $psi.StandardInputEncoding = $Utf8NoBom
    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
    } catch {
        Die "could not start the display child ($Python $DisplayTool): $($_.Exception.Message)"
    }
    $script:PhaseWriter = $proc.StandardInput
    $script:PhaseWriter.AutoFlush = $true
    $script:SinkDied = $false
    $rc = 0
    try {
        & $Body 2>&1 | ForEach-Object { Write-PhaseLog "$_" }
        if ($LASTEXITCODE -is [int] -and $LASTEXITCODE -ne 0) { $rc = $LASTEXITCODE }
    } catch {
        Write-PhaseLog ($_ | Out-String)
        $rc = 1
    }
    if ($script:PhaseWriter) { $script:PhaseWriter.Close() }
    $script:PhaseWriter = $null
    $proc.WaitForExit()
    # A dead sink or a nonzero child exit (rc 3 = --log leg failure, by the
    # tool's contract) means the log is untrustworthy — fail the phase even
    # when the body itself succeeded, bash-pipefail style.
    if ($script:SinkDied -or $proc.ExitCode -ne 0) {
        [System.IO.File]::AppendAllText($log,
            "=== display sink FAILED (child rc=$($proc.ExitCode)) — output above may be incomplete`n")
        Write-Host "vm-harness-vmware: display sink failed mid-phase (child rc=$($proc.ExitCode)) — phase output was lost" -ForegroundColor Red
        if ($rc -eq 0) { $rc = 1 }
    }
    [System.IO.File]::AppendAllText($log, "=== $Phase done rc=$rc`n")
    "=== $Phase done rc=$rc"
    if ($rc -ne 0) {
        # Compact mode hid the stream — surface the failure before dying.
        if ($script:DisplayMode -eq 'compact') {
            "--- last 40 log lines ($log):"
            Get-Content $log -Tail 40 -ErrorAction SilentlyContinue
        }
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

# Serial chunks go through the phase sink like everything else: the display
# child mirrors them on the console (bar/plain) and scrubs them into the log —
# the raw ANSI/CR spray from the installer stays out of the file.
function Write-Serial([string]$Text) {
    if (-not $Text) { return }
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
# Set by Wait-Ssh: did the key actually authenticate, or did we only prove
# sshd is listening? Unattended phases must not proceed on the latter.
$script:SshKeyAuth = $false

function Wait-Ssh {
    $user = Get-GuestUser
    $script:SshKeyAuth = $false
    Say 'Waiting for ssh (up to ~2 min)'
    for ($i = 0; $i -lt 40; $i++) {
        $ip = Get-GuestIp
        if ($ip) {
            $out = & ssh -o BatchMode=yes -o ConnectTimeout=2 @SshOpts "$user@$ip" true 2>&1
            if ($LASTEXITCODE -eq 0) {
                $script:SshKeyAuth = $true
                Say "ssh ready: $user@$ip"
                return $ip
            }
            if ("$out" -match 'Permission denied') {
                Say "sshd up at $ip (key auth refused — expect password prompts)"
                return $ip
            }
        }
        Start-Sleep -Seconds 3
    }
    throw 'no ssh after ~2 minutes — check: status, tail install'
}

# Every automated ssh/scp adds BatchMode: without it a guest that refused the
# key parks the run on an interactive password prompt with no timeout, which
# is not what "unattended" means. Interactive `exec` deliberately omits it.
$BatchOpts = @('-o', 'BatchMode=yes') + $SshOpts

# Guard the phases that must run unattended. Wait-Ssh's key-refused downgrade
# is fine for `boot` (a human is watching); bootstrap/check would hang.
function Assert-KeyAuth {
    if (-not $script:SshKeyAuth) {
        throw ('ssh key auth was refused — an unattended phase cannot password-prompt. ' +
               'Re-seed with a host key present (destroy + up), or run the step by hand.')
    }
}

# POSIX single-quote a value going into a remote shell command string:
# close, escape, reopen. Guards the VM_HARNESS_CLASS/REPO/BRANCH overrides,
# which are operator-set but land verbatim in the guest's shell.
function ConvertTo-ShellQuoted([string]$Value) {
    "'" + ($Value -replace "'", "'\''") + "'"
}

# scp the host's AUR trust state (maintainers.tsv + exempt.txt) into the VM
# before bootstrap, same baseline a decrypt-restored machine would have
# (Story 2.10). Windows has no Arch state dir to read, so the source is
# overridable (VM_HARNESS_TRUST_DIR) and populated once by extracting just
# those two members from the yadm archive — recipe:
# knowledge/recipes/windows-trust-baseline.md. Without it the guest runs
# fresh TOFU, which trusts whatever it sees: fine for fast iteration, wrong
# for runs meant to predict a real rebuild (design note on #119).
function Get-TrustDir {
    if ($env:VM_HARNESS_TRUST_DIR) { $env:VM_HARNESS_TRUST_DIR }
    else { Join-Path $env:USERPROFILE '.local\state\aur-quarantine' }
}

function Send-TrustBaseline([string]$Ip) {
    $sdir = Get-TrustDir
    $have = @('maintainers.tsv', 'exempt.txt') |
        ForEach-Object { Join-Path $sdir $_ } | Where-Object { Test-Path $_ }
    if (-not $have) {
        Say "Trust baseline: none on host ($sdir) — VM runs fresh (TOFU)"
        return
    }
    Say "Trust baseline: injecting $(($have | Split-Path -Leaf) -join ' ') into the VM"
    & ssh @BatchOpts "$VmUser@$Ip" 'mkdir -p ~/.local/state/aur-quarantine'
    if ($LASTEXITCODE -ne 0) { throw "trust baseline mkdir failed (rc=$LASTEXITCODE)" }
    & scp @BatchOpts -q @have "$VmUser@${Ip}:.local/state/aur-quarantine/"
    if ($LASTEXITCODE -ne 0) { throw "trust baseline scp failed (rc=$LASTEXITCODE)" }
}

# Push the shared guest glue (fresh each run — the guest executes the host
# checkout's version) and run one of its subcommands, streaming output.
# Single `-t` (vm_ssh parity): a pty when the local console provides one, so
# the guest tools emit color; a warning + pty-less run when stdin is
# redirected. The scrub keeps either variant out of the logs (see header).
function Invoke-GuestGlue([string]$Ip, [string]$RemoteCmd) {
    & scp @BatchOpts -q $GuestTool "$VmUser@${Ip}:vm-harness-guest"
    if ($LASTEXITCODE -ne 0) { throw "scp vm-harness-guest failed (rc=$LASTEXITCODE)" }
    & ssh -t @BatchOpts "$VmUser@$Ip" $RemoteCmd 2>&1
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
        Assert-KeyAuth
        Send-TrustBaseline $ip
        Say "Running repo bootstrap inside the VM (class: $Class, unattended; AUR builds take a while)"
        $cmd = 'bash vm-harness-guest bootstrap' +
               " --class $(ConvertTo-ShellQuoted $Class)" +
               " --repo $(ConvertTo-ShellQuoted $Repo)"
        if ($Branch) { $cmd += " --branch $(ConvertTo-ShellQuoted $Branch)" }
        Invoke-GuestGlue $ip $cmd
    }
}

function Cmd-Check {
    Invoke-Phase 'check' {
        if (-not (Test-Path $Vmx)) { throw 'run: create first' }
        if ((Get-MediaState) -ne 'ejected') { throw 'not installed yet — run: install' }
        if (-not (Test-VmRunning)) { throw 'VM not running — run: boot' }
        $ip = Wait-Ssh
        Assert-KeyAuth
        Say "Asserting VM end state (class: $Class)"
        $cmd = 'bash vm-harness-guest check' +
               " --class $(ConvertTo-ShellQuoted $Class)"
        Invoke-GuestGlue $ip $cmd
    }
}

function Cmd-Exec([string[]]$Command) {
    if (-not (Test-Path $Vmx)) { Die 'no VM — run: create' }
    if (-not $Command) { Die 'usage: exec CMD [ARGS...]' }
    # A DHCP lease outlives the VM that held it, so an IP alone is not a
    # running guest — without this, exec against a stopped VM hangs on the
    # TCP connect instead of saying what is wrong.
    if (-not (Test-VmRunning)) { Die 'VM not running — run: boot' }
    $ip = Get-GuestIp
    if (-not $ip) { Die 'no IP known (no current lease yet — check: status)' }
    $user = Get-GuestUser
    # `--` ends ssh's own option parsing (it re-parses after the destination),
    # so a guest command starting with `-` reaches the guest intact.
    & ssh @SshOpts "$user@$ip" -- @Command
    exit $LASTEXITCODE
}

# Facts in, phase out — the decision table lives in vm-harness-vmx (pytest).
# Collapsed to a single string: a multi-line result would turn every `-eq`
# below into an array filter (silently falsy), so any surprise here has to
# reach the unknown-answer guard in Cmd-Up rather than slip past it.
function Get-ResumePoint {
    $media = if (Test-Path $Vmx) { Get-MediaState } else { 'absent' }
    $p = & $Python $VmxTool resume --media $media `
        --disk $(if (Test-Path $DiskVmdk) { 'yes' } else { 'no' }) `
        --seed $(if (Test-Path (Join-Path $SeedDir 'seed.iso')) { 'yes' } else { 'no' }) `
        --serial-log $(if (Test-Path $SerialLog) { 'yes' } else { 'no' }) `
        --running $(if (Test-VmRunning) { 'yes' } else { 'no' })
    if ($LASTEXITCODE -ne 0) { throw "vm-harness-vmx resume failed (rc=$LASTEXITCODE)" }
    (@($p) -join ' ').Trim()
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
    # IndexOf returns -1 for anything unrecognised, and PowerShell wraps a
    # negative index: $phases[-1..4] is check,create,install,... — i.e. an
    # unreadable answer would silently run the pipeline in the wrong order.
    if ($idx -lt 0) { Die "unreadable resume point '$from' from vm-harness-vmx — check: status" }
    # `create` refuses while a vmx exists (destroy is always explicit), so say
    # that here rather than after Cmd-Fetch has pulled a ~1 GB ISO to get there.
    if ($idx -eq 0 -and (Test-Path $Vmx)) {
        Die "resume wants a fresh create, but VM '$VmName' already exists — its disk or seed is missing.
Next:  vm-harness-vmware destroy   then:  up"
    }
    $skipped = @(); if ($idx -gt 0) { $skipped = @($phases[0..($idx - 1)]) }
    if ($skipped) {
        # Log association with the earlier run's set is this header plus
        # timestamp order (bash parity) — Invoke-Phase stamps the first log.
        $script:ResumeHeader = "resume: skipped $($skipped -join ' ') (probed complete) — starting at $from"
        Say $script:ResumeHeader
    }
    # create boots nothing, but install boots the ISO straight from the cache —
    # both need it present. An explicit `fetch` stays the force-refresh.
    if (-not (Test-Path $Iso) -and $idx -le 1) { Cmd-Fetch }
    # Breadcrumb for the display: every phase with its status — probed-complete
    # (resume) and already-run phases show done, the running one current.
    $todo = @($phases[$idx..($phases.Count - 1)])
    for ($i = 0; $i -lt $todo.Count; $i++) {
        $crumb = @($skipped | ForEach-Object { "${_}:done" })
        for ($j = 0; $j -lt $todo.Count; $j++) {
            $status = if ($j -lt $i) { 'done' } elseif ($j -eq $i) { 'current' } else { 'pending' }
            $crumb += "$($todo[$j]):$status"
        }
        $script:PhasesStatus = $crumb -join ','
        switch ($todo[$i]) {
            'create'    { Cmd-Create }
            'install'   { Cmd-Install }
            'boot'      { Cmd-Boot }
            'bootstrap' { Cmd-Bootstrap }
            'check'     { Cmd-Check }
        }
    }
    $script:PhasesStatus = ''
    Say 'up complete — all phases green'
}

# One-time host setup, not a phase: no VM involved, no logging contract.
function Cmd-TrustImport {
    if (-not (Test-Path $Archive)) { Die "no yadm archive at $Archive" }
    # --into the very directory Send-TrustBaseline reads, so setting
    # VM_HARNESS_TRUST_DIR can't leave import and injection pointing at
    # different places.
    $tdir = Get-TrustDir
    Say "Importing the AUR trust baseline into $tdir (gpg will prompt for the archive passphrase)"
    New-Item -ItemType Directory -Force $tdir | Out-Null
    & $Python $TrustTool --archive $Archive --into $tdir
    if ($LASTEXITCODE -ne 0) { Die "trust import failed (rc=$LASTEXITCODE)" }
    Say 'Done — bootstrap will inject this into every guest from now on'
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

# ---- dispatch: vm-harness-vmware [--progress|--plain] <subcommand> ---------
$Argv = @($args)
$ProgressFlag = $false
$PlainFlag = $false
while ($Argv.Count -gt 0 -and "$($Argv[0])" -like '-*') {
    switch ($Argv[0]) {
        '--progress' { $ProgressFlag = $true }
        '--plain'    { $PlainFlag = $true }
        { $_ -in '-h', '--help' } { Usage; exit 0 }
        default { Write-Host "vm-harness-vmware: unknown flag '$($Argv[0])'   (try: help)" -ForegroundColor Red; exit 2 }
    }
    $Argv = @($Argv | Select-Object -Skip 1)
}

# Resolve the attended display (bash-harness vocabulary). A display flag with
# nothing watching is a mistake — reject loudly. The bar default degrades to
# plain when the console is redirected; the tool renders unstyled if
# python-rich is absent (styling only), so rich is not probed here.
if ($ProgressFlag) {
    if ($PlainFlag) { Die '--progress and --plain contradict each other' }
    if ([Console]::IsOutputRedirected) { Die '--progress needs a console (stdout is redirected)' }
    $script:DisplayMode = 'compact'
} elseif (-not $PlainFlag -and -not [Console]::IsOutputRedirected -and (Test-Path $DisplayTool)) {
    $script:DisplayMode = 'bar'
}

switch ($Argv[0]) {
    'fetch'     { Cmd-Fetch }
    'seed'      { Cmd-Seed }
    'create'    { Cmd-Create }
    'install'   { Cmd-Install }
    'boot'      { Cmd-Boot }
    'up'        { Cmd-Up }
    'bootstrap' { Cmd-Bootstrap }
    'check'     { Cmd-Check }
    'exec'      { Cmd-Exec @($Argv | Select-Object -Skip 1) }
    'trust-import' { Cmd-TrustImport }
    'ip'        { Cmd-Ip }
    'status'    { Cmd-Status }
    'destroy'   { Cmd-Destroy }
    'tail'      { Cmd-Tail $Argv[1] }
    'help'    { Usage }
    $null     { Usage; exit 2 }
    default   { Write-Host "vm-harness-vmware: unknown subcommand '$($Argv[0])'" -ForegroundColor Red; Usage; exit 2 }
}
