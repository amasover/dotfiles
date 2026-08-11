# VMware on Windows: "Module 'CPUID' initialization failed" at power-on — SOLVED

**Seen:** 2026-08-10/11, Story 2.36 (#119), Windows personal machine (Workstation
26H1 and a fresh 25H2U1, Windows 11 24H2, Ryzen 9 7950X3D). Every VM power-on —
vmrun, the GUI, direct `vmware-vmx`, a minimal 8-line vmx — died instantly.
`vmrun` reported only `Error: Unknown error` (rc=-1); no per-VM `vmware.log`.

## Root cause

A **stale loaded `vmx86` kernel driver instance**. Installs/upgrades replace
`C:\Windows\System32\drivers\vmx86.sys` on disk, but the loaded instance keeps
serving `\\.\Global\vmx86` — and its version handshake with the newer userland
fails. Release builds surface that as the misleading `Module 'CPUID'
initialization failed`; only the **debug binary** printed the truth:

```
Unable to open kernel device '\\.\Global\vmx86': The operation completed successfully.
Did you reboot after installing VMware Workstation?
```

The trap within the trap: `sc stop vmx86` **silently no-ops while vmware-authd
holds an open handle to the device** — so "restart the driver" attempts (and
possibly the installers' own) never actually reload it, and the stale instance
survives.

Unresolved nuance: 26H1 was the machine's FIRST VMware install (the 4/24 file
dates are the package's build timestamps, not an install date) and failed from
its first-ever power-on — so either its driver was wedged from the install-time
service dance onward, or **26H1's driver build is itself broken on this host**
(same 25.0.0 version label as 25H2U1's, older package build). The working state
was proven with 25H2U1's driver. A return to 26H1 is a cheap controlled
experiment: install, do the authd-first driver bounce below, run a 2-second
probe; if red, reinstall 25H2U1 and bounce again.

## Fix (no reboot needed)

```powershell
sudo pwsh -NoProfile -Command "
  Stop-Service VMAuthdService -Force
  Stop-Service VMUSBArbService -Force -ErrorAction SilentlyContinue
  sc.exe stop vmx86;  Start-Sleep 3;  sc.exe start vmx86
  Start-Service VMAuthdService; Start-Service VMUSBArbService"
```

Verify: `vmrun -T ws start <any vmx> nogui` → rc=0.

## Diagnosis tricks worth keeping

- Real errors live in `%LOCALAPPDATA%\Temp\vmware-<user>\vmware-vmx-*.log`
  (per-attempt) and `vmware-vix-*.log`, not in vmrun output.
- **Run the debug binary directly** for human-readable errors vmrun swallows:
  `x64\vmware-vmx-debug.exe -T querytoken -s vmx.stdio.keep=TRUE <vmx>`
- MSI event log (`MsiInstaller` provider) catches repairs that fail silently
  ("Stop vmware.exe…", status 1603) while msiexec returns 0.
- ProcMon cannot see raw device IOCTLs — a clean-looking trace does not clear
  the driver handshake path.

## Ruled out along the way (all tested red)

vmx config (minimal vmx failed identically) · WHP feature state · Hyper-V
on/off entirely · Memory Integrity · license/first-run state · MSI repair and
forced reinstall (`REINSTALLMODE=vamus`) · elevation · Process Lasso · core
parking (X3D CCD) · anticheat drivers · IFEO/exploit mitigations · leftover
VMware config files · Corsair iCUE · BIOS (never needed — F32h worked once the
driver reloaded).

## Related gotcha found right after (harness vmx authoring)

On modern virtualHW, NVMe + vmxnet3 are PCIe devices: a hand-authored vmx
without `pciBridge0` + `pciBridge4..7` (pcieRootPort, functions 8) dies with
`[msg.pci.noslotavail] No PCIe slot available for Ethernet0`. vm-harness-vmx
now emits the bridge set.

**Reboot rule:** silent installers must always get `/norestart` — a VMware
silent reinstall auto-rebooted the machine once (2026-08-10). Reboots are
Aaron's to trigger.
