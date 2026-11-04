# VM files

1. Build/install the patched QEMU from the release asset, applying
   `qemu-10.2.2.patch` then `qemu-10.2.2-acpi-stealth.patch`.
2. Build/install the patched OVMF or use `../firmware/OVMF_CODE_stealth.fd`.
3. Create the writable NVRAM copy. For a new Windows install use the
   fresh store (keys, no stale boot entries):
   ```bash
   cp ../firmware/OVMF_VARS_fresh.fd win10_VARS.fd
   ```
   For an existing disk whose boot entry already matches, use
   `OVMF_VARS_stealth.fd`.
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

The guest profile is GEEKOM A8 / Ryzen 7 8845HS, 16 vCPU (8C/16T), 8 GiB RAM,
Samsung SSD 870 EVO 250 GB on AMD/ATI FCH AHCI (`1002:7901`, `MediaType = SSD`), Intel 82574L
NIC, Realtek ALC897 audio, dual AMD Phoenix xHCI controllers, 1920x1080 ASUS VA24EHE EDID.

EDID advertises a 50-240 Hz range; set the preferred timing with
`REFRESH=144 ./start-win10-stealth.sh`. Windows Basic Display Adapter does not
enumerate EDID modes, so it still runs at 64 Hz; a real 144 Hz mode needs VFIO
GPU passthrough (see `../STEALTH.md`).

The guest exposes 4 ACPI thermal zones (`TZ00`-`TZ03`), 2 fans, 5 voltage
probes, 4 temperature probes and 2 current probes through SMBIOS/ACPI.

## Fresh install and SEB profile

Fresh Windows install (the ISO is attached as a CD and booted first):

```bash
cp ../firmware/OVMF_VARS_fresh.fd win10_VARS.fd
DISK=win10.qcow2 VARS=win10_VARS.fd ISO=/path/Win10_22H2.iso \
  ./start-win10-stealth.sh
```

Normal use (KVM, TPM 2.0 on):

```bash
./start-win10-stealth.sh
```

Safe Exam Browser (TCG, no TPM to hide the OVMF measured-boot log):

```bash
ACCEL=tcg TPM=0 ./start-win10-stealth.sh
```

`ACCEL=tcg` defaults `TPM` to `0`; set `TPM=1` explicitly if you need TPM
under TCG. TCG is much slower. See `../STEALTH.md#seb--vmaware-profile`.

## Secure Boot and TPM 2.0

`firmware/OVMF_CODE_stealth.fd` is built with Secure Boot, SMM and TPM 2.0
support. `firmware/OVMF_VARS_stealth.fd` has Secure Boot enabled with a
GEEKOM PK/KEK and Microsoft KEK/db/dbx.

The launch script starts `swtpm` and adds `-device tpm-crb,tpmdev=tpm0` by
default. Install `swtpm` first; use `TPM=0` to boot without TPM for debugging.
The TPM state is kept in `./tpm`; deleting that directory clears the TPM.

## CPU identity and moving to another host

The default is **not** `-cpu host`. The launcher uses `CPU_MODE=auto`:

- On an **AMD** host: fixed `EPYC-Genoa,family=25,model=117,stepping=2,-pcid,-la57`
- On an **Intel** or unknown host: fixed `EPYC-Rome,family=25,model=117,stepping=2,-pcid,-la57`

Both use the `AMD Ryzen 7 8845HS w/ Radeon 780M Graphics` brand string, so
Windows shows the same CPU name and an AuthenticAMD identity regardless of
the host CPU.

Options:

- `CPU_MODE=auto` (default) — Genoa on AMD, Rome on Intel.
- `CPU_MODE=portable` — EPYC-Rome on both with `-pcid,-la57`; best cross-vendor KVM
  compatibility, tested on the AMD host.
- `CPU_MODE=compat` — `qemu64,family=25,model=117,stepping=2`; oldest
  baseline, last-resort for hosts where Rome still fails under KVM.
- `CPU_MODE=native` — `-cpu host`; only for a known 8845H/8845HS host.
- `CPU_MODEL='...'` — direct QEMU CPU model override.
- `SMP='4,sockets=1,cores=4,threads=2'` — 4C/8T; default is 8C/8T.
  `SMP='2,sockets=1,cores=2,threads=2'` gives 2C/4T.

The `-pcid,-la57` mask matches the 8845HS client feature set and suppresses
the per-vCPU `host doesn't support requested feature` warnings on hosts
without PCID/LA57.

Important limitation: KVM can only expose CPU features the host supports.
On Intel, QEMU filters AMD-only features such as SVM/AVX-512; the guest still
has the fixed 8845HS name/CPUID family/model, but its feature set and
`Virtualization: Enabled/Disabled` state can differ from an AMD host. For
identical CPU features on Intel and AMD you need TCG (slow) or bare-metal/
passthrough; a fixed CPU model does not make KVM emulate missing features.

To move the VM to another Linux host, copy:

```text
win10.qcow2
win10_VARS.fd
OVMF_CODE_stealth.fd
tpm/                  # keep the same TPM identity
secureboot/           # optional: local PK/KEK private keys
start-win10-stealth.sh
smbd
share/
```

Install the patched QEMU 10.2.2 from the release source and `swtpm` on the new
host. Keep the same disk GUID; the Secure Boot VARS boot entry is tied to the
disk. The locally built QEMU has `CONFIG_SMBD_COMMAND=/home/khanhnguyen9872/vms/smbd`;
if the new path differs, rebuild QEMU with `--smbd=/usr/sbin/smbd` or copy
`smbd` to the expected path. A different QEMU version/machine type can change
the ACPI/device profile, so use the same patched 10.2.2 build.

## Shared folder (SMB)

The launch scripts export `$DIR/share` to the guest through QEMU user-mode
SMB. QEMU must be built with `--smbd=/usr/sbin/smbd` (or another path to the
Samba `smbd` binary).

The host script only **exposes** the share; Windows does not auto-map a drive.
Map it once from a guest command prompt:

```powershell
net use Z: \\10.0.2.4\qemu /persistent:yes
```

Files are then available under `Z:\` and in `/home/<user>/vms/share` on the
host. If the drive does not reconnect after a reboot, run
`\\10.0.2.4\qemu\map-qemu-share.bat` (or copy it into the Windows Startup
folder). Override the exported directory with `SMB_DIR=/path/to/share`.

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

# if Windows Update installed a broken AMD display driver for 1002:1900
powershell -ExecutionPolicy Bypass -File \\10.0.2.4\qemu\fix-display.ps1
```

Reboot after cleanup. The display fix removes the failed OEM AMD binding,
keeps the inbox Microsoft Basic Display Adapter, and disables Windows Update
driver search so the broken AMD package is not reinstalled.

The Intel 82574L is a real Intel NIC; its `#2` suffix is a re-enumeration
artifact, not a QEMU device. QEMU does not emulate a
Realtek 2.5GbE/I225-V, so a matching NIC name requires PCI passthrough.
