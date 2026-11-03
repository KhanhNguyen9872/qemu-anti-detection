#!/usr/bin/env bash
# Launch Windows 10 with the stealth GEEKOM A8 profile.
#
# Required files in this directory:
#   win10.qcow2        - installed Windows disk
#   win10_VARS.fd      - writable copy of ../firmware/OVMF_VARS_stealth.fd
#
# Optional environment overrides:
#   QEMU_BIN, OVMF_CODE, DISK, VARS
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QEMU_BIN="${QEMU_BIN:-/usr/local/bin/qemu-system-x86_64}"
OVMF_CODE="${OVMF_CODE:-$DIR/../firmware/OVMF_CODE_stealth.fd}"
DISK="${DISK:-$DIR/win10.qcow2}"
VARS="${VARS:-$DIR/win10_VARS.fd}"
SMB_DIR="${SMB_DIR:-$DIR/share}"
REFRESH="${REFRESH:-144}"
mkdir -p "$SMB_DIR"

for f in "$QEMU_BIN" "$OVMF_CODE" "$DISK" "$VARS"; do
    [ -e "$f" ] || { echo "[!] Missing: $f" >&2; exit 1; }
done

exec "$QEMU_BIN" \
  -enable-kvm \
  -machine q35,smm=on,smbios-entry-point-type=64,i8042=off \
  -cpu host,topoext=on,hypervisor=off,kvm=off,\
-kvmclock,-kvm-nopiodelay,-kvm-mmu,-kvm-asyncpf,-kvm-steal-time,\
-kvm-pv-eoi,-kvm-pv-unhalt,-kvm-pv-tlb-flush,-kvm-asyncpf-vmexit,\
-kvm-pv-ipi,-kvm-poll-control,-kvm-pv-sched-yield,-kvm-asyncpf-int,\
-kvm-msi-ext-dest-id,-kvm-hint-dedicated,\
model-id="AMD Ryzen 7 8845HS w/ Radeon 780M Graphics" \
  -smp 8,sockets=1,cores=8,threads=1 \
  -m 8192 \
  -rtc base=localtime,clock=host \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file="$VARS" \
  -drive file="$DISK",if=none,id=disk0,format=qcow2,cache=writeback \
  -device "ide-hd,drive=disk0,bus=ide.0,rotation_rate=1,serial=S6PNNJ0T8123456,model=Samsung SSD 870 EVO 250GB" \
  -boot order=c \
  -netdev user,id=net0,smb="$SMB_DIR" \
  -device e1000e,netdev=net0,mac=00:1b:21:7c:4e:2a \
  -device qemu-xhci,id=xhci \
  -device usb-tablet,bus=xhci.0 \
  -device usb-kbd,bus=xhci.0 \
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
  -name "Windows 10 Pro" \
  -display gtk,gl=on
