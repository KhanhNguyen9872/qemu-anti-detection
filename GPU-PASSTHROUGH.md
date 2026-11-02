# GPU trong máy ảo: virtio-gpu, fake ID, hay passthrough?

## TL;DR

- **Không thể** dùng `virtio-gpu` rồi giả PCI ID/name để cài driver AMD thật.
  Driver AMD sẽ không chạy trên phần cứng virtio; nó đọc thanh ghi/BAR của GPU
  AMD thật và sẽ lỗi hoặc BSOD.
- Cách duy nhất để Windows thấy **GPU thật + driver AMD thật + D3D thật** là
  **PCI passthrough (VFIO)** một GPU vật lý.
- Máy hiện tại (ThinkBook 14 G6+ AHP, Ryzen 7 8845H) chỉ có **Radeon 780M iGPU**
  đang dùng cho màn hình host. Passthrough iGPU sẽ làm host mất màn hình; muốn
  làm phải chấp nhận host headless (USB DisplayLink/SSH) hoặc dùng eGPU.
- Nếu không có GPU thứ hai, giữ VGA đã spoof `1002:1900` như hiện tại: PCI ID
  trông thật nhưng Windows chỉ có **Microsoft Basic Display Adapter**, không có
  driver AMD, không chơi game/anti-cheat cần GPU được.

## Vì sao virtio-gpu không "giả AMD" được?

1. `virtio-gpu` là thiết bị paravirtual. Windows dùng driver `viogpudo` của
   virtio-win; đây là driver **WDDM display-only**, không expose D3D12/D3D11
   đầy đủ. QEMU `virtio-gpu-gl` dùng VirGL (OpenGL) và không map sang D3D của
   Windows.
2. Đổi `vendor_id`/`device_id` của virtio-gpu thành `1002:1900` chỉ đổi cấu
   hình PCI. Driver AMD (`amdkmdag.sys`) sẽ thử đọc/ghi các register AMD, BAR
   layout, firmware/PSP, VRAM... không tồn tại trên virtio-gpu → cài driver có
   thể "thành công" nhưng khởi động GPU sẽ fail, Device Manager báo lỗi 43,
   hoặc BSOD.
3. Anti-cheat kiểm tra **driver đã ký + hành vi IOCTL + khả năng render**, không
   chỉ chuỗi tên. Đổi tên thiết bị/BIOS không qua được bước render/IOCTL.
4. `qxl`, `vmware-svga` có thể có 3D một phần nhưng lộ chữ ký VMware/Red Hat;
   cũng không phải AMD thật.

## Cách đúng: VFIO passthrough

Điều kiện:

- Một GPU rời **không bị host dùng** (dGPU laptop, eGPU USB4/Thunderbolt, hoặc
  GPU cắm qua adapter M.2 → PCIe x4).
- CPU/BIOS bật AMD-V/IOMMU; kernel host có `amd_iommu=on iommu=pt`.
- GPU và audio function của nó nằm trong IOMMU group có thể tách (hoặc pass cả
  group).
- Guest dùng đúng driver AMD cho GPU đó.

Quy trình mẫu (Ubuntu host):

```bash
# 1. Bật IOMMU
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="amd_iommu=on iommu=pt /' /etc/default/grub
sudo update-grub && reboot

# 2. Xem IOMMU group
for g in /sys/kernel/iommu_groups/*; do
  echo "IOMMU group ${g##*/}:"
  for d in "$g"/devices/*; do lspci -nns "${d##*/}"; done
done

# 3. Bind GPU + audio sang vfio-pci (ví dụ 1002:73ff + 1002:ab28)
echo "options vfio-pci ids=1002:73ff,1002:ab28" | sudo tee /etc/modprobe.d/vfio.conf
sudo update-initramfs -u && reboot

# 4. QEMU: bỏ VGA ảo, gắn GPU thật
#    -vga none \
#    -device vfio-pci,host=0000:03:00.0,multifunction=on \
#    -device vfio-pci,host=0000:03:00.1
```

Sau đó cài driver AMD trong Windows như máy thật. Để xem màn hình guest, dùng
monitor vật lý cắm vào GPU hoặc **Looking Glass** (shared memory).

### Với laptop 8845H hiện tại

- Chỉ có 780M iGPU, host đang dùng cho màn hình laptop. Unbind iGPU = mất màn
  hình host; có thể dùng USB DisplayLink/SSH để điều khiển host, nhưng firmware
  laptop thường khóa/chia IOMMU group và iGPU chia sẻ với USB/audio, rất dễ
  không tách được. Không khuyến nghị.
- eGPU qua USB4 (nếu máy có) hoặc M.2 → PCIe adapter + nguồn ngoài là hướng
  thực tế nhất. Cần kiểm tra IOMMU group và độ ổn định của cổng.
- Máy desktop có dGPU rời là môi trường lý tưởng.

## Nếu không có GPU thứ hai

Giữ cấu hình hiện tại:

- PCI ID VGA `1002:1900` + subsystem `1002:1900` (đã patch QEMU/OVMF).
- EDID ASUS VA24EHE 1920x1080.
- Windows: "Microsoft Basic Display Adapter"; không cài được AMD driver thật.
- Có thể đổi tên/hiển thị trong registry để trông giống AMD, nhưng **không có
  D3D/không chơi game/không qua anti-cheat kiểm tra render**. Đây chỉ là lớp
  trang trí, không phải GPU thật.

## Tóm lại

| Cách | Driver AMD thật | D3D/Game | Anti-cheat | Ghi chú |
|---|---|---|---|---|
| VGA ảo + fake ID | Không | Không | Không | Hiện tại, PCI ID đẹp |
| virtio-gpu + fake ID | Không | Không (chỉ display) | Không | Tệ hơn, lộ VirtIO |
| QXL/VMware SVGA | Không (driver riêng) | Một phần | Không | Lộ chữ ký VM |
| VFIO passthrough | Có | Có | Có (như máy thật) | Cần GPU rời |
