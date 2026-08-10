# VMware on Windows: "Module 'CPUID' initialization failed" at power-on — UNRESOLVED

**Seen:** 2026-08-10, Story 2.36 (#119), Windows personal machine (Workstation 26H1
26.0.0-25388281, Windows 11 24H2, Ryzen 9 7950X3D). Every VM power-on — vmrun, the
Workstation GUI, `vmware-vmx -T querytoken` run directly, and a minimal 8-line vmx —
dies instantly. `vmrun` reports only `Error: Unknown error` (rc=-1); no `vmware.log`
appears in the VM directory.

## Diagnosis path (what actually yields information)

1. `vmrun`'s log: `%LOCALAPPDATA%\Temp\vmware-<user>\vmware-vix-*.log` — shows the
   `vmware-vmx.exe` child dying instantly ("The pipe has been ended").
2. The child's log: `%LOCALAPPDATA%\Temp\vmware-<user>\vmware-vmx-*.log` — the real
   error: `Module 'CPUID' initialization failed`, preceded by `IOPL_Init: Hyper-V
   detected by CPUID` (Hyper-V on) or `IOPL_VBSRunning: VBS is set to 0` (off).
3. Running the failing step directly with a console prints human-readable errors
   vmrun swallows:
   `& "...\x64\vmware-vmx.exe" -T querytoken -s vmx.stdio.keep=TRUE <vmx>`
4. MSI event log (`Get-WinEvent`, provider `MsiInstaller`) — caught a repair that
   silently failed (1603, "Stop vmware.exe") while msiexec returned 0.

## Ruled OUT on this machine (each tested, still red)

- **vmx config** — an 8-line minimal vmx fails identically; the harness vmx is fine.
- **WHP feature disabled** — enabling `HypervisorPlatform` + reboot: no change.
  (Original version of this note called that the fix — falsified.)
- **Hyper-V coexistence itself** — with Hyper-V fully off (no hypervisor present,
  VBS=0) the native path fails the same way.
- **Memory Integrity** — already off.
- **License/first-run state** — no license UI; GUI power-on fails the same way.
- **MSI repair & forced reinstall** (`REINSTALLMODE=vamus REINSTALL=ALL`) — no change.
- **Driver/userland version mismatch** — vmx86.sys is 25.0.0 while userland is 26.0.0,
  but the 26H1 installer's own DRVSTORE payload ships that exact 25.0.0 driver
  (DriverVer 07/23/2025) — red herring, VMware reuses unchanged components.
- **Firmware SVM** — `VirtualizationFirmwareEnabled: True`, SLAT true, and WSL2 runs
  fine, so the hardware virtualization path works for Microsoft's hypervisor.

## Current state / next candidates

Never-worked-here matters: no VM has ever booted under VMware on this machine (25H1
installed 2026-04, unproven; 26H1 upgraded over it). Untried, in order:

1. **Clean uninstall → reboot → fresh 26H1 install → reboot** (Broadcom's standard
   escalation; repair-over-top is proven insufficient). Aaron holding off for now.
2. Broadcom support/community post with the vmware-vmx log bundle.
3. Downgrade test to 25H1 (no evidence it ever worked either).

**Reboot rule:** silent installers must always get `/norestart` — a VMware silent
reinstall auto-rebooted the machine once (2026-08-10). Reboots are Aaron's to trigger.
