# Prebuilt patched OVMF (4 MB, Secure Boot + TPM 2.0)

These files are built from `edk2` with `ovmf-stealth.patch` applied and:

- Secure Boot enabled (`SECURE_BOOT_ENABLE=TRUE`, `SMM_REQUIRE=TRUE`),
- TPM 2.0 support (`TPM2_ENABLE=TRUE`) with `Tcg2Acpi` included,
- host bridge `1022:14e8` accepted as Q35,
- QEMU video driver also matches `1002:1900`,
- TianoCore BGRT table and boot logo removed.

Files:

- `OVMF_CODE_stealth.fd` — 4 MB code image (3.5 MB used),
- `OVMF_VARS_stealth.fd` — 528 KB variable store with:
  - `GEEKOM Secure Boot PK` / `GEEKOM Secure Boot KEK`,
  - Microsoft KEK/db/dbx certificates,
  - `SecureBootEnable=1`, and a Windows Boot Manager entry.
- `OVMF_VARS_fresh.fd` — same keys/`SecureBootEnable=1`, but no
  `Boot####`/`BootOrder`; use this for a fresh Windows install so the
  installer creates the first boot entry.

Use with:

```bash
-drive if=pflash,format=raw,readonly=on,file=OVMF_CODE_stealth.fd
-drive if=pflash,format=raw,file=win10_VARS.fd
```

`win10_VARS.fd` should be a writable copy of `OVMF_VARS_stealth.fd`.
The QEMU machine must use `smm=on`.

TPM 2.0 uses `swtpm`:

```bash
swtpm socket --tpm2 --tpmstate dir=tpm \
  --ctrl type=unixio,path=tpm/swtpm.sock --daemon
```

then add:

```bash
-chardev socket,id=chrtpm,path=tpm/swtpm.sock
-tpmdev emulator,id=tpm0,chardev=chrtpm
-device tpm-crb,tpmdev=tpm0
```

The `swtpm` TPM reports manufacturer `IBM`; that is a property of the
emulator, not of QEMU.
