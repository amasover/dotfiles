# VMware on Windows: "Module 'CPUID' initialization failed" at power-on

**Seen:** 2026-08-10, Story 2.36 (#119), first `vm-harness-vmware.ps1 install` on the
Windows personal machine (Workstation 26.0.0). `vmrun start` reports only
`Error: Unknown error` (rc=-1) and no `vmware.log` appears in the VM directory.

## Diagnosis path

1. `vmrun`'s own log: `%LOCALAPPDATA%\Temp\vmware-<user>\vmware-vix-*.log` — shows the
   `vmware-vmx.exe` child starting, then "The pipe has been ended" (it died instantly).
2. The child's log: `%LOCALAPPDATA%\Temp\vmware-<user>\vmware-vmx-*.log` — the real error:
   `IOPL_Init: Hyper-V detected by CPUID` … `Module 'CPUID' initialization failed.`

## Cause

The host runs Microsoft's hypervisor (Hyper-V / WSL2 / VBS "Memory Integrity" all cause
this), so Workstation cannot use VT-x directly and must go through the **Windows
Hypervisor Platform** optional feature (ULM mode). If `HypervisorPlatform` is *disabled*,
guest power-on dies with exactly this generic error — headless (`nogui`) runs surface no
dialog explaining it.

## Fix

```powershell
sudo pwsh -NoProfile -Command "Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -NoRestart"
# then reboot
```

Check state first: `Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform`
(elevated). The alternative — removing the Hyper-V stack for native VMware performance —
costs WSL2; revisit only if daily-driver 3D performance under WHP disappoints
([decision-daily-driver-vm.md](../../docs/decision-daily-driver-vm.md) picked VMware for 3D).
