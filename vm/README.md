# VM files

1. Build/install the patched QEMU from the release asset or `qemu-10.2.2.patch`.
2. Build/install the patched OVMF or use `../firmware/OVMF_CODE_stealth.fd`.
3. Create the writable NVRAM copy:
   ```bash
   cp ../firmware/OVMF_VARS_stealth.fd win10_VARS.fd
   ```
4. Put the installed Windows disk at `win10.qcow2`.
5. Run:
   ```bash
   ./start-win10-stealth.sh
   ```

If Windows reports `0xc0000225` after moving or resizing the disk, the OVMF
NVRAM entry is stale. Choose the raw `UEFI Samsung SSD 870 EVO ...` entry in
the firmware boot menu once, then repair the default entry from an elevated
Windows prompt:
```powershell
mountvol S: /S
bcdboot C:\Windows /s S: /f UEFI
```

The script uses `/usr/local/bin/qemu-system-x86_64` by default; override with
`QEMU_BIN=/path/to/qemu-system-x86_64`.

The guest profile is GEEKOM A8 / Ryzen 7 8845HS, 8 vCPU (8C/8T), 8 GiB RAM,
Samsung SSD 870 EVO 250 GB on AMD FCH AHCI (`MediaType = SSD`), Intel 82574L
NIC, Realtek ALC897 audio, dual AMD Phoenix xHCI controllers, 1920x1080 ASUS VA24EHE EDID.

EDID advertises a 50-240 Hz range; set the preferred timing with
`REFRESH=144 ./start-win10-stealth.sh`. Windows Basic Display Adapter does not
enumerate EDID modes, so it still runs at 64 Hz; a real 144 Hz mode needs VFIO
GPU passthrough (see `../STEALTH.md`).

The guest exposes 4 ACPI thermal zones (`TZ00`-`TZ03`), 2 fans, 5 voltage
probes, 4 temperature probes and 2 current probes through SMBIOS/ACPI.

## Shared folder (SMB)

The launch scripts export `$DIR/share` to the guest through QEMU user-mode
SMB. QEMU must be built with `--smbd=/usr/sbin/smbd` (or another path to the
Samba `smbd` binary).

In Windows, map it once:

```powershell
net use Z: \\10.0.2.4\qemu /persistent:yes
```

Files are then available under `Z:\` and in `/home/<user>/vms/share` on the
host. Override the exported directory with `SMB_DIR=/path/to/share`.

QEMU's user-mode SMB server is reachable at `10.0.2.4`; the share name is
`qemu`.


## Guest anti-detection cleanup

The Windows installation keeps PnP records from earlier QXL/VirtIO/Hyper-V
test profiles. Run these from an **elevated PowerShell** in the guest:

```powershell
# read-only audit
powershell -ExecutionPolicy Bypass -File \\10.0.2.4\qemu\audit-guest.ps1

# remove Kernel Debug NIC, non-present ghosts, and stale PS/2 devices
powershell -ExecutionPolicy Bypass -File \\10.0.2.4\qemu\clean-guest.ps1
```

Reboot after cleanup. The Intel 82574L is a real Intel NIC; its `#2` suffix is
a re-enumeration artifact, not a QEMU device. QEMU does not emulate a
Realtek 2.5GbE/I225-V, so a matching NIC name requires PCI passthrough.
