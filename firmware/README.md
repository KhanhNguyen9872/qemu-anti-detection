# Prebuilt patched OVMF (4 MB)

These files are built from `edk2` with `ovmf-stealth.patch` applied:

- host bridge `1022:14e8` accepted as Q35,
- QEMU video driver also matches `1002:1900`,
- TianoCore BGRT table and boot logo removed.

Files:

- `OVMF_CODE_stealth.fd` — 4 MB code image (3.5 MB used),
- `OVMF_VARS_stealth.fd` — 528 KB variable-store template.

Use with:

```bash
-drive if=pflash,format=raw,readonly=on,file=OVMF_CODE_stealth.fd
-drive if=pflash,format=raw,file=win10_VARS.fd
```

`win10_VARS.fd` should be a writable copy of `OVMF_VARS_stealth.fd`.
