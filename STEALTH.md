# Stealth QEMU 10.2.2 build — GEEKOM A8 / Ryzen 7 8845HS profile

Apply the two patches to a vanilla QEMU 10.2.2 tarball from the
[v10.2.2-stealth release](https://github.com/KhanhNguyen9872/qemu-anti-detection/releases/tag/v10.2.2-stealth):
the base patch is `qemu-10.2.2.patch`; the ACPI/VMAware hardening delta is
`qemu-10.2.2-acpi-stealth.patch` and must be applied after it.

The patch applies to a **vanilla QEMU 10.2.2 tarball** and includes both the
original `qemu-anti-detection` string changes and the additional stealth work
described below.

## Guest-visible platform

| Item | Value |
|---|---|
| System | GEEKOM A8 mini PC |
| CPU | fixed AMD CPUID + 8845HS brand; Genoa on AMD, Rome on Intel; 8C/16T |
| BIOS | American Megatrends Inc. SER8V1.0, 03/15/2024 |
| Board / chassis | GEEKOM A8, mini-PC chassis (SMBIOS type 3 = 0x23) |
| Memory | 1x 8 GiB Samsung DDR5-5600 SODIMM |
| Storage | Samsung SSD 870 EVO 250 GB on AMD FCH SATA (1002:7901) |
| Network | Intel 82574L (8086:10d3), Intel OUI MAC |
| USB | 2x AMD Phoenix xHCI (1022:15b9), Logitech keyboard/mouse |
| Audio | AMD HD Audio (1022:15e3) + Realtek ALC897 codec (10ec:0897) |
| GPU | Radeon 780M PCI ID (1002:1900) — see the GPU limitation below |
| Monitor | ASUS VA24EHE EDID, 1920x1080 |
| Firmware | Secure Boot ON, TPM 2.0 (`swtpm`), GEEKOM PK/KEK |

## Main changes

- SMBIOS: full type 0/1/2/3/4/7/16/17/19/26/27/28/29/32 tables with realistic
  serials, cache tables, thermal/voltage/current/cooling probes, DDR5 SODIMM
  details, mini-PC chassis and 16 MB AMI BIOS.
- ACPI: OEM ID `ALASKA`, OEM table ID `A M I`, creator `INTL` (2023),
  WAET/BGRT/QEMU fw_cfg node removed, static processor objects (no
  `ACPI0010` container or CPU-hotplug `PRES` device), DSDT revision 2,
  parallel/serial ports disabled by the launch profile.
- ACPI/AML fingerprints used by VMAware 2.8.2 are removed or renamed:
  QEMU `DBUG` debug port, `DRAC` DRAM controller, `SMI0`/`GPE0` PNP0A06
  devices, `ACPI0006` GPE identity, `PRTP`/`PRTA` routing tables,
  `LNKE`-`LNKH`/`GSIE`-`GSIH` link names, the QEMU HPET period check,
  TPM PPI `TPP2`/`TPP3`/`TPFN` names, zeroed `_S5`, the QEMU `_OSC`
  mask byte pattern, `EDSM`, the fixed PIRQ `_PRS` set, QEMU-specific
  APIC interrupt overrides, and FADT C2/C3 latency `0x0FFF`. A PNP0100
  system-timer device is added so `ACPI\PNP0100` exists like on real
  hardware. The FCH LPC/SATA/SMBus vendor is `1002` (AMD/ATI) instead of
  `1022`, which avoids VMAware's "AMD vendor at Intel Q35 slot" check;
  the host bridge, xHCI and HD Audio stay `1022`.
- CPUID: fixed AMD CPU model with brand string
  "AMD Ryzen 7 8845HS w/ Radeon 780M Graphics"; `CPU_MODE=auto` chooses
  `EPYC-Genoa,family=25,model=117,stepping=2,-pcid,-la57` on AMD and
  `EPYC-Rome,family=25,model=117,stepping=2,-pcid,-la57` on Intel. The default is
  **not** `-cpu host`, so the host CPUID vendor/model is not leaked. KVM
  paravirt leaves hidden (`kvm=off`), hypervisor bit cleared, all `kvm-*`
  paravirt features disabled, Hyper-V enlightenments disabled. On Intel,
  KVM filters AMD-only features; the name/identity stay fixed but the
  feature set and SVM state can differ.
- Machine: `vmport=off` disables the VMware backdoor I/O port emulation;
  `i8042=off` removes the PS/2 controller from the machine.
- Secure Boot/TPM: OVMF is built with `SECURE_BOOT_ENABLE`, `SMM_REQUIRE`
  and `TPM2_ENABLE`; `Tcg2Acpi` supplies the TPM2 ACPI table. The variable
  store uses a GEEKOM PK/KEK plus Microsoft KEK/db/dbx. TPM 2.0 is provided
  by `swtpm` on a `tpm-crb` device.
- PCI: Q35 host bridge 1022:14e8, FCH LPC 1002:790e, FCH SATA 1002:7901,
  FCH SMBus 1002:790b, HD Audio 1022:15e3, xHCI 1022:15b9,
  VGA 1002:1900; AMD/Intel subsystem IDs.
- VGA/EDID: ASPEED-style default replaced with an ASUS VA24EHE 1920x1080
  EDID and real manufacturer/product/serial/week/year. The EDID range is
  50-240 Hz and the preferred timing follows the `REFRESH` environment
  variable (default 144 Hz).
- Sensors: SMBIOS type 26 (5 voltage probes), type 27 (2 fans), type 28
  (4 temperature probes) and type 29 (2 current probes), all with status OK.
  The ACPI DSDT also exposes four thermal zones, `TZ00`-`TZ03`
  (CPU/GPU/SSD/system), through `MSAcpi_ThermalZoneTemperature`.
- Storage: IDE identify word 217 is set to 1 (non-rotating), so Windows
  `Get-PhysicalDisk` reports `MediaType = SSD`, `BusType = SATA`, model
  `Samsung SSD 870 EVO 250GB` and serial `S6PNNJ0T8123456`.
- USB: two AMD Phoenix xHCI controllers (1022:15b9), each with its own root
  hub, so Device Manager shows a CPU xHCI and a chipset xHCI instead of a
  single controller. HID: Logitech K120 keyboard (046d:c31c) and Logitech M105
  mouse (046d:c077); Wacom Intuos S tablet IDs for `usb-tablet`.
- IDE: Samsung SSD model/serial and firmware revision `SVT02B6Q` instead of
  `QEMU HARDDISK` / `2.5+`; ASUS DVD-ROM model.
- NVMe: Samsung 990 PRO model/firmware/PCI ID (not used by the installed
  Windows disk because the guest must stay on AHCI).
- Audio codec: Realtek ALC897 instead of the QEMU codec ID.

## Build QEMU

```bash
wget https://download.qemu.org/qemu-10.2.2.tar.xz
tar xf qemu-10.2.2.tar.xz
cd qemu-10.2.2
git apply /path/to/qemu-10.2.2.patch
git apply /path/to/qemu-10.2.2-acpi-stealth.patch
./configure --enable-kvm --enable-gtk --enable-spice --enable-slirp
make -j"$(nproc)"
sudo make install
```

Or build directly from the extracted release tarball.

## Patched OVMF

The stock OVMF identifies the Q35 host bridge as `8086:29c0` and the VGA as
`1234:1111`. The stealth build changes those IDs, so OVMF must be patched too:

```bash
git clone --recursive https://github.com/tianocore/edk2.git
cd edk2
git apply /path/to/ovmf-stealth.patch
source edksetup.sh
make -C BaseTools -j"$(nproc)"
build -a X64 -t GCC -p OvmfPkg/OvmfPkgX64.dsc -b RELEASE \
  -D FD_SIZE_4MB=TRUE -D SECURE_BOOT_ENABLE=TRUE \
  -D SMM_REQUIRE=TRUE -D TPM2_ENABLE=TRUE -n"$(nproc)"
```

The resulting `OVMF_CODE.fd` / `OVMF_VARS.fd` are in
`Build/OvmfX64/RELEASE_GCC/FV/`. Prebuilt files are under `firmware/`.

`ovmf-stealth.patch`:
- teaches OVMF that `1022:14e8` is the Q35 host bridge,
- adds `1002:1900` to the QEMU video driver ID table,
- removes the TianoCore BGRT table and boot logo,
- adds `Tcg2Acpi` to the OVMF TPM component list so Windows sees
  `ACPI\MSFT0101` and the TPM2 ACPI table.

The prebuilt `firmware/OVMF_VARS_stealth.fd` has Secure Boot enabled with
`GEEKOM Secure Boot PK` / `GEEKOM Secure Boot KEK`, Microsoft KEK/db/dbx,
and a Windows Boot Manager entry. `firmware/OVMF_VARS_fresh.fd` has the
same keys but no `Boot####`/`BootOrder`; use it for a fresh Windows install
so Windows Setup creates the first boot entry. Both were generated offline
with `virt-fw-vars`; the private keys are not distributed.

## Launch

See the companion script [`vm/start-win10-stealth.sh`](vm/start-win10-stealth.sh).
The profile uses `-machine q35,smm=on,smbios-entry-point-type=64,vmport=off`,
`-cpu host,...,hypervisor=off,kvm=off`, the patched OVMF, and the SMBIOS
overrides listed in `STEALTH.md`/the script.

Set the preferred EDID refresh with `REFRESH=144 ./start-win10-stealth.sh`
(the value is milliseconds in QEMU's EDID property: `refresh_rate=Hz * 1000`).

TPM 2.0 is enabled by default. The script starts `swtpm` and passes
`-device tpm-crb,tpmdev=tpm0`; use `TPM=0` only for debugging. Secure Boot is
controlled by the `firmware/OVMF_VARS_stealth.fd` variable store.

### If Windows stops at 0xc0000225

This error is usually a stale OVMF NVRAM boot entry, not a broken disk. At the
firmware boot menu select the raw `UEFI Samsung SSD 870 EVO ...` entry once;
Windows then boots. To repair the default entry permanently, mount the ESP in
an elevated prompt and rebuild it:

```powershell
mountvol S: /S
bcdboot C:\Windows /s S: /f UEFI
```

Alternatively recreate `win10_VARS.fd` from
`firmware/OVMF_VARS_stealth.fd` and add the entry with `bcfg`/`bcdboot`.

## SEB / VMAware profile

Safe Exam Browser 3.10.3 uses VMAware 2.8.2 in `seb_x64.dll`. After the
QEMU/ACPI fixes above, a KVM guest is reduced to five VMAware techniques:

| Technique | Score | Why it remains |
|---|---:|---|
| `GPU_CAPABILITIES` | 20 | Microsoft Basic Display Adapter has no gamma-ramp capability |
| `KVM_INTERCEPTION` | 150 | KVM intercepts `VMCALL`/`VMMCALL`; not a QEMU setting |
| `SVM_EXCEPTIONS` | 35 | KVM hides/exposes SVM inconsistently |
| `MEASURED_BOOT` | 150 | OVMF's TCG log contains its SEC/PEI blob bounds |
| `TIMER` | 45 | KVM exit latency |

KVM is still reported as the brand because the QEMU-specific firmware,
ACPI, DMI and PCI strings are gone; the remaining detections are
hypervisor/Timing/TPM artifacts. VMAware's default threshold is 150, so
`KVM_INTERCEPTION` alone keeps SEB in "VM detected" state.

For SEB, use the TCG profile:

```bash
ACCEL=tcg TPM=0 ./start-win10-stealth.sh
```

`ACCEL=tcg` replaces KVM with multi-threaded TCG, so `VMCALL`/`VMMCALL`
raise `#UD` instead of being intercepted, and the KVM exit-timer check
disappears. `TPM=0` removes the OVMF measured-boot log. Secure Boot stays
on because it is controlled by the OVMF VARS, not the TPM. TCG is much
slower; use the default KVM mode for normal work and the TCG mode only
for SEB.

The expected remaining score under TCG+TPM=0 is below 150 (GPU 20 plus,
at worst, TIMER 45 and SVM 35), so SEB's native check should pass. A fresh
Windows install is strongly recommended: old PnP ghosts, DeviceCache and
the previous TPM/EFI state can still trigger SEB's managed checks.

## Verification

- `info pci` shows 1022:14e8 / 1002:790e / 1002:7901 / 1002:790b /
  1022:15e3 / 1022:15b9 / 1002:1900 / 8086:10d3.
- Guest `Win32_BIOS` should read "American Megatrends Inc." and
  "SER8V1.0"; `Win32_ComputerSystem` should read "GEEKOM A8".
- CPUID leaves 0x40000000..0x40000010 are zero.
- Task Manager on the installed guest: 8 cores / 16 logical processors,
  8.0 GB RAM, `Virtualization: Enabled`, and **no "Virtual machine" row**.
  `Win32_ComputerSystem.HypervisorPresent` is `False`.
- `Get-PhysicalDisk` reports `MediaType = SSD`, `BusType = SATA`,
  `FriendlyName = Samsung SSD 870 EVO 250GB`.
- `Win32_Fan` returns 2 instances, `Win32_TemperatureProbe` 4,
  `Win32_VoltageProbe` 5 and `Win32_CurrentProbe` 2, all `Status = OK`.
- Elevated `Get-CimInstance -Namespace root/wmi -ClassName
  MSAcpi_ThermalZoneTemperature` returns four zones:
  `TZ00` 3182, `TZ01` 3232, `TZ02` 3132, `TZ03` 3082 (tenths of Kelvin).
- `Win32_CacheMemory` and the SMBIOS type 7/26-29 tables are present.
- Secure Boot: `Confirm-SecureBootUEFI` is `True` (elevated) and
  `HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot\State\UEFISecureBootEnabled`
  is `1`.
- TPM: Device Manager has `Trusted Platform Module 2.0` (`ACPI\MSFT0101\1`);
  `Get-Tpm` reports present/ready/enabled/activated, and `Win32_Tpm`
  reports `SpecVersion = 2.0`. The `swtpm` emulator reports manufacturer
  `IBM` (emulator property, not QEMU).
- Old hardware ghost devices must be removed after switching an existing
  Windows installation (see `STEALTH.md`).

## GPU limitation

`virtio-gpu` is not a real GPU and cannot run the AMD driver. See
[GPU-PASSTHROUGH.md](GPU-PASSTHROUGH.md) for the only real solution
(VFIO passthrough) and the trade-offs.

The QEMU `VGA` device is spoofed as `1002:1900`, and its EDID advertises
1920x1080 at up to 240 Hz. Windows 10 installs the inbox **Microsoft Basic
Display Adapter**, which does not enumerate the EDID modes; `dxdiag` therefore
shows 64 Hz and `Win32_VideoController.CurrentRefreshRate` reports 1. The
EDID/`REFRESH` setting is ready for a real GPU driver, but getting an actual
144 Hz mode requires VFIO passthrough of a real AMD GPU (or a VM-specific
driver, which weakens the anti-detection profile).
