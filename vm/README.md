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

The script uses `/usr/local/bin/qemu-system-x86_64` by default; override with
`QEMU_BIN=/path/to/qemu-system-x86_64`.

The guest profile is GEEKOM A8 / Ryzen 7 8845HS, 8 vCPU (8C/8T), 8 GiB RAM,
Samsung SSD 870 EVO 250 GB on AMD FCH AHCI, Intel 82574L NIC, Realtek ALC897
audio, AMD Phoenix xHCI, 1920x1080 ASUS VA24EHE EDID.
