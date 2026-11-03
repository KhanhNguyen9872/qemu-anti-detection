# Stealth QEMU 10.2.2 build — GEEKOM A8 / Ryzen 7 8845HS profile

The complete, buildable patched QEMU 10.2.2 source tree is distributed as
the `qemu-10.2.2-stealth-source.tar.xz` asset of the
[v10.2.2-stealth release](https://github.com/KhanhNguyen9872/qemu-anti-detection/releases/tag/v10.2.2-stealth).
The full patch is in `qemu-10.2.2.patch`.

The patch applies to a **vanilla QEMU 10.2.2 tarball** and includes both the
original `qemu-anti-detection` string changes and the additional stealth work
described below.

## Guest-visible platform

| Item | Value |
|---|---|
| System | GEEKOM A8 mini PC |
| CPU | AMD Ryzen 7 8845HS w/ Radeon 780M Graphics, 8C/8T (SMT disabled) |
| BIOS | American Megatrends Inc. SER8V1.0, 03/15/2024 |
| Board / chassis | GEEKOM A8, mini-PC chassis (SMBIOS type 3 = 0x23) |
| Memory | 1x 8 GiB Samsung DDR5-5600 SODIMM |
| Storage | Samsung SSD 870 EVO 250 GB on AMD FCH SATA (1022:7901) |
| Network | Intel 82574L (8086:10d3), Intel OUI MAC |
| USB | 2x AMD Phoenix xHCI (1022:15b9), Logitech keyboard/mouse |
| Audio | AMD HD Audio (1022:15e3) + Realtek ALC897 codec (10ec:0897) |
| GPU | Radeon 780M PCI ID (1002:1900) — see the GPU limitation below |
| Monitor | ASUS VA24EHE EDID, 1920x1080 |

## Main changes

- SMBIOS: full type 0/1/2/3/4/7/16/17/19/26/27/28/29/32 tables with realistic
  serials, cache tables, thermal/voltage/current/cooling probes, DDR5 SODIMM
  details, mini-PC chassis and 16 MB AMI BIOS.
- ACPI: OEM ID `ALASKA`, OEM table ID `A M I`, creator `INTL` (2023),
  WAET/BGRT/QEMU fw_cfg node removed, static processor objects (no
  `ACPI0010` container or CPU-hotplug `PRES` device), DSDT revision 2,
  parallel/serial ports disabled by the launch profile.
- CPUID: KVM paravirt leaves hidden (`kvm=off`), hypervisor bit cleared,
  all `kvm-*` paravirt features disabled, Hyper-V enlightenments disabled,
  brand string "AMD Ryzen 7 8845HS w/ Radeon 780M Graphics".
- Machine: `vmport=off` disables the VMware backdoor I/O port emulation;
  `i8042=off` removes the PS/2 controller from the machine.
- PCI: Q35 host bridge 1022:14e8, FCH LPC 1022:790e, FCH SATA 1022:7901,
  FCH SMBus 1022:790b, HD Audio 1022:15e3, xHCI 1022:15b9,
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
git apply /path/to/qemu-10.2.2.patch     # or: patch -p1 < ...
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
build -a X64 -t GCC -p OvmfPkg/OvmfPkgX64.dsc -b RELEASE -D FD_SIZE_4MB -n"$(nproc)"
```

The resulting `OVMF_CODE.fd` / `OVMF_VARS.fd` are in
`Build/OvmfX64/RELEASE_GCC/FV/`. Prebuilt files are under `firmware/`.

`ovmf-stealth.patch`:
- teaches OVMF that `1022:14e8` is the Q35 host bridge,
- adds `1002:1900` to the QEMU video driver ID table,
- removes the TianoCore BGRT table and boot logo.

## Launch

See the companion script [`vm/start-win10-stealth.sh`](vm/start-win10-stealth.sh).
The profile uses `-machine q35,smm=on,smbios-entry-point-type=64,vmport=off`,
`-cpu host,...,hypervisor=off,kvm=off`, the patched OVMF, and the SMBIOS
overrides listed in `STEALTH.md`/the script.

Set the preferred EDID refresh with `REFRESH=144 ./start-win10-stealth.sh`
(the value is milliseconds in QEMU's EDID property: `refresh_rate=Hz * 1000`).

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

## Verification

- `info pci` shows 1022:14e8 / 1022:790e / 1022:7901 / 1022:790b /
  1022:15e3 / 1022:15b9 / 1002:1900 / 8086:10d3.
- Guest `Win32_BIOS` should read "American Megatrends Inc." and
  "SER8V1.0"; `Win32_ComputerSystem` should read "GEEKOM A8".
- CPUID leaves 0x40000000..0x40000010 are zero.
- Task Manager on the installed guest: 8 cores / 8 logical processors,
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
