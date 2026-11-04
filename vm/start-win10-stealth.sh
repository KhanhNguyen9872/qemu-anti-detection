#!/usr/bin/env bash
# Launch Windows 10 with the stealth GEEKOM A8 profile.
#
# Required files in this directory:
#   win10.qcow2        - installed Windows disk
#   win10_VARS.fd      - writable copy of ../firmware/OVMF_VARS_stealth.fd
#
# Optional environment overrides:
#   QEMU_BIN, OVMF_CODE, DISK, VARS, ACCEL, TPM, CPU_MODE, CPU_MODEL, SMP, ISO
# The guest-visible platform is a GEEKOM A8 mini PC (AMD Ryzen 7 8845HS).
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QEMU_BIN="${QEMU_BIN:-/usr/local/bin/qemu-system-x86_64}"
OVMF_CODE="${OVMF_CODE:-$DIR/../firmware/OVMF_CODE_stealth.fd}"
DISK="${DISK:-$DIR/win10.qcow2}"
VARS="${VARS:-$DIR/win10_VARS.fd}"
SMB_DIR="${SMB_DIR:-$DIR/share}"
ISO="${ISO:-}"
REFRESH="${REFRESH:-144}"
ACCEL="${ACCEL:-kvm}"
case "$ACCEL" in
    kvm) : "${TPM:=1}" ;;
    tcg) : "${TPM:=0}" ;;
    *) echo "[!] Invalid ACCEL: $ACCEL (use kvm or tcg)" >&2; exit 1 ;;
esac
CPU_MODE="${CPU_MODE:-auto}"
HOST_VENDOR=$(awk -F: '/^vendor_id/{gsub(/[ \t]/,"",$2); print $2; exit}' /proc/cpuinfo 2>/dev/null)
if [ -z "${CPU_MODEL:-}" ]; then
    case "$CPU_MODE" in
        auto)
            if [ "$HOST_VENDOR" = "AuthenticAMD" ]; then
                CPU_MODEL="EPYC-Genoa,family=25,model=117,stepping=2,-pcid,-la57"
            else
                CPU_MODEL="EPYC-Rome,family=25,model=117,stepping=2,-pcid,-la57"
            fi
            ;;
        portable)
            CPU_MODEL="EPYC-Rome,family=25,model=117,stepping=2,-pcid,-la57"
            ;;
        compat)
            CPU_MODEL="qemu64,family=25,model=117,stepping=2"
            ;;
        native)
            CPU_MODEL="host"
            ;;
        *)
            echo "[!] Invalid CPU_MODE: $CPU_MODE (use auto, portable, compat, native)" >&2
            exit 1
            ;;
    esac
fi
SMP="${SMP:-16,sockets=1,cores=8,threads=2}"
mkdir -p "$SMB_DIR"

for f in "$QEMU_BIN" "$OVMF_CODE" "$DISK" "$VARS"; do
    [ -e "$f" ] || { echo "[!] Missing: $f" >&2; exit 1; }
done
if [ -n "$ISO" ] && [ ! -e "$ISO" ]; then
    echo "[!] Missing ISO: $ISO" >&2; exit 1
fi
BOOT_ARGS=(-boot order=c)
if [ -n "$ISO" ]; then
    BOOT_ARGS=(-cdrom "$ISO" -boot order=d)
fi

TPM="${TPM:-1}"
TPM_ARGS=()
if [ "$TPM" = "1" ]; then
    command -v swtpm >/dev/null 2>&1 || {
        echo "[!] swtpm is required for TPM 2.0 (or set TPM=0)" >&2
        exit 1
    }
    TPM_DIR="${TPM_DIR:-$DIR/tpm}"
    mkdir -p "$TPM_DIR"
    if [ -f "$TPM_DIR/swtpm.pid" ] && kill -0 "$(cat "$TPM_DIR/swtpm.pid")" 2>/dev/null; then
        :
    else
        rm -f "$TPM_DIR/swtpm.sock" "$TPM_DIR/swtpm.pid"
        swtpm socket --tpm2 --tpmstate dir="$TPM_DIR" \
            --ctrl type=unixio,path="$TPM_DIR/swtpm.sock" \
            --pid file="$TPM_DIR/swtpm.pid" --daemon \
            --log file="$TPM_DIR/swtpm.log"
    fi
    TPM_ARGS=(
        -chardev "socket,id=chrtpm,path=$TPM_DIR/swtpm.sock"
        -tpmdev emulator,id=tpm0,chardev=chrtpm
        -device tpm-crb,tpmdev=tpm0
    )
fi

if [ "$CPU_MODEL" = "host" ] && ! grep -qiE 'AMD Ryzen 7 8845H(S)?' /proc/cpuinfo; then
    echo "[!] Host CPU is not Ryzen 7 8845H/8845HS." >&2
    echo "    CPUID will not match the GEEKOM A8 profile." >&2
    echo "    For a portable AMD identity use:" >&2
    echo "    CPU_MODEL='EPYC-Genoa,family=25,model=117,stepping=2,-pcid,-la57' $0" >&2
fi

if [ "$ACCEL" = "tcg" ]; then
    ACCEL_ARGS=(-accel tcg,thread=multi)
    CPU_EXTRA=",hypervisor=off,-topoext,-amd-stibp,-stibp-always-on,-amd-ssbd,-amd-psfd,-lfence-always-serializing,-auto-ibrs,-nrip-save,-vnmi,-xsavec,-xsaves,-avx512-vpopcntdq,-avx512-bf16,-invpcid,-avx512f,-avx512dq,-avx512ifma,-avx512cd,-avx512bw,-avx512vl,-avx512vbmi,-avx512vbmi2,-avx512vnni,-avx512bitalg,-gfni,-vpclmulqdq,-fxsr-opt,-misalignsse,-osvw,-perfctr-core,-clzero,-ibpb,-ibrs"
else
    ACCEL_ARGS=(-enable-kvm)
    CPU_EXTRA=",topoext=on,hypervisor=off,kvm=off,\
-kvmclock,-kvm-nopiodelay,-kvm-mmu,-kvm-asyncpf,-kvm-steal-time,\
-kvm-pv-eoi,-kvm-pv-unhalt,-kvm-pv-tlb-flush,-kvm-asyncpf-vmexit,\
-kvm-pv-ipi,-kvm-poll-control,-kvm-pv-sched-yield,-kvm-asyncpf-int,\
-kvm-msi-ext-dest-id,-kvm-hint-dedicated"
fi

exec "$QEMU_BIN" \
  "${ACCEL_ARGS[@]}" \
  -machine q35,smm=on,smbios-entry-point-type=64,i8042=off,vmport=off \
  -cpu "$CPU_MODEL$CPU_EXTRA",model-id="AMD Ryzen 7 8845HS w/ Radeon 780M Graphics" \
  -smp "$SMP" \
  -m 8192 \
  -rtc base=localtime,clock=host \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file="$VARS" \
  -drive file="$DISK",if=none,id=disk0,format=qcow2,cache=writeback \
  -device "ide-hd,drive=disk0,bus=ide.0,rotation_rate=1,serial=S6PNNJ0T8123456,model=Samsung SSD 870 EVO 250GB" \
  "${BOOT_ARGS[@]}" \
  -netdev user,id=net0,smb="$SMB_DIR" \
  -device e1000e,netdev=net0,mac=00:1b:21:7c:4e:2a \
  -device qemu-xhci,id=xhci \
  -device qemu-xhci,id=xhci1 \
  -device usb-kbd,bus=xhci.0 \
  -device usb-tablet,bus=xhci1.0 \
  -audiodev pa,id=snd0 \
  -device ich9-intel-hda \
  -device hda-duplex,audiodev=snd0 \
  -device VGA,vgamem_mb=64,refresh_rate=$((REFRESH * 1000)) \
  -parallel none -serial none \
  -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off \
  -smbios "type=0,vendor=American Megatrends Inc.,version=SER8V1.0,date=03/15/2024,release=1.0,uefi=on" \
  -smbios "type=1,manufacturer=GEEKOM,product=A8,version=V1.0,serial=A8H4845S2601001,uuid=8539f13e-155d-4b62-941e-0f9be2e55107,sku=A8-8845HS,family=A8" \
  -smbios "type=2,manufacturer=GEEKOM,product=A8,version=V1.0,serial=A8H4845S2601001,asset=Default string" \
  -smbios "type=3,manufacturer=GEEKOM,version=V1.0,serial=A8H4845S2601001,asset=Default string,sku=A8-8845HS" \
  -smbios "type=4,sock_pfx=FP8,manufacturer=Advanced Micro Devices,version=AMD Ryzen 7 8845HS w/ Radeon 780M Graphics,max-speed=5100,current-speed=3800,part=100-000001278,processor-family=107" \
  -smbios "type=11,value=GEEKOM" \
  -smbios "type=11,value=SER8" \
  -smbios "type=11,value=Default string" \
  -smbios "type=17,loc_pfx=SODIMM,bank=BANK0,manufacturer=Samsung,serial=S0A1B2C3D4,asset=Default string,part=M425R1GB4BB0-CQKOL,speed=5600" \
  "${TPM_ARGS[@]}" \
  -display gtk,gl=on
