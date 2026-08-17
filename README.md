# Samsung Galaxy S20 Ultra (SM-G988N) - Docker Native & AI Edge Server Kernel

## 1. Tổng quan mục đích dự án
Dự án này được tạo ra nhằm mục đích tái sử dụng chiếc điện thoại Samsung Galaxy S20 Ultra 5G (phiên bản Hàn Quốc SM-G988N, mã bo mạch z3q, sử dụng vi xử lý Qualcomm Snapdragon 865 và 12GB RAM LPDDR5) bị hỏng màn hình để chuyển đổi thành một máy chủ tính toán AI cục bộ (Local AI Edge Node) và máy chủ Docker Native hoạt động liên tục 24/7.

Node tính toán này phục vụ các mục đích chính trong hệ thống máy chủ gia đình (Homelab):
- Tách riêng và gánh toàn bộ tác vụ Machine Learning của hệ thống lưu trữ ảnh Immich (nhận diện khuôn mặt, tìm kiếm ngữ cảnh CLIP) từ máy chủ lưu trữ NAS chính.
- Vận hành các mô hình ngôn ngữ lớn (Local LLM) phục vụ nhu cầu cá nhân như viết nội dung Fanpage, trả lời tin nhắn khách hàng tự động, xử lý dữ liệu qua Ollama và n8n.
- Chạy hệ sinh thái trợ lý ảo tự hành (OpenClaw) độc lập với chi phí điện năng siêu thấp và không tốn chi phí thuê API đám mây.

---

## 2. Kiến trúc và Quy trình đóng gói (CI/CD Pipeline)

Toàn bộ quá trình biên dịch và đóng gói được tự động hóa hoàn toàn qua GitHub Actions trên nền tảng Ubuntu 22.04:

- Mã nguồn nhân (Kernel Source): Sử dụng cây mã nguồn Linux Kernel 4.19 hợp nhất cho dòng Samsung Snapdragon 865 từ tác giả GoRhanHee.
- Nền tảng cấu hình (.config): Trích xuất trực tiếp 100% cấu hình nhị phân từ bản phát hành chính thức z3q_SuSFS của GoRhanHee bằng công cụ extract-ikconfig, đảm bảo tính tương thích phần cứng tuyệt đối và không gây xung đột khóa bảo mật.
- Trình biên dịch: Sử dụng bộ công cụ Proton-Clang (LLVM 13) kết hợp trình liên kết LLD (ld.lld) để xử lý các liên kết địa chỉ bộ nhớ lớn trên kiến trúc ARM64 (aarch64).
- Các bản vá tích hợp:
  + Sửa lỗi bộ dịch bảng ký hiệu Qualcomm GSI (xóa __packed khỏi union gsi_channel_scratch) nhằm phục hồi việc tính toán mã băm CRC cho tính năng kiểm soát phiên bản module (CONFIG_MODVERSIONS).
  + Khóa tính năng tự động tối ưu hóa stpcpy của Clang bằng cờ -fno-builtin-stpcpy.
  + Sửa lỗi biến trùng lặp yylloc trong bộ phân tích cú pháp cây thiết bị (DTC) bằng cờ -fcommon.
  + Sửa lỗi đường dẫn tương đối trong cơ chế Ftrace của driver HID và Display PLL.
  + Bổ sung chỉ thị bỏ qua cảnh báo frame-address trong driver Wi-Fi Broadcom.
- Đóng gói đầu ra tự động: Sử dụng công cụ magiskboot để tự động rã nén file boot.img gốc của bản ROM Samsung One UI 5.1 (Android 13 Bit 8), thay thế file nhị phân Image mới vào và đóng gói thành file boot_docker.tar chuẩn nạp trực tiếp qua phần mềm Samsung Odin (slot AP).

---

## 3. Các tính năng cốt lõi và Tối ưu hóa hệ thống

### 3.1. Hỗ trợ Container và Mạng máy chủ (Docker / LXC / Droidspaces)
- Bật đầy đủ 6/6 không gian tên Linux (Namespaces): UTS, IPC, USER, PID, NET, MOUNT.
- Bật toàn diện các hệ thống quản lý tài nguyên (Cgroups v1 & v2): CPU, CPU Accounting, Devices, Freezer, Scheduler, CPUSets, Memory, Swap Accounting.
- Bật hệ thống tệp tin OverlayFS (CONFIG_OVERLAY_FS=y) làm nền tảng lưu trữ chuẩn overlay2 cho Docker.
- Bật mạng cầu nối ảo (Bridge), giao diện mạng ảo (VETH) và bảng định tuyến Netfilter / IP Tables phục vụ việc NAT port và cấp phát IP cho Container.
- Nhúng sẵn driver điều khiển card mạng dây qua cổng Type-C: Realtek RTL8152 / RTL8153 / RTL8153B (Gigabit Ethernet) và ASIX AX88179.

### 3.2. Quyền Root và Tương thích phần cứng
- Nhúng trực tiếp quyền Root cấp độ nhân bằng KernelSU-Next (nhánh legacy cho Kernel 4.19) kết hợp công nghệ ẩn Root VFS SuSFS qua cơ chế Manual Hook.
- Giữ nguyên CONFIG_MODVERSIONS=y để cho phép nhân Linux tải 100% các file driver độc quyền (.ko) trong phân vùng /vendor của Samsung (driver cảm ứng, quản lý nguồn PMIC, âm thanh).
- Vô hiệu hóa toàn bộ 7 cơ chế tự hủy và bảo vệ của Samsung Knox: UH (User Hypervisor), RKP (Realtime Kernel Protection), KDP (Kernel Data Protection), CFP (Control Flow Protection), DEFEX (Data Execution Prevention), PROCA (Process Authenticator), FIVE (File Integrity Verification Engine).

### 3.3. Tối ưu hóa vận hành 24/7 (Headless Server Script)
Kịch bản tự động hóa khởi động được kích hoạt qua thư mục /data/adb/service.d/ đảm nhiệm các tác vụ:
- Giả lập pin cố định ở mức 100% và trạng thái sạc AC (dumpsys battery set level 100, status 2, ac 1) nhằm triệt tiêu hoàn toàn hiện tượng sụt pin ảo và tự động tắt nguồn (Shutdown) khi mod nguồn trực tiếp không dùng pin.
- Tắt hoàn toàn cơ chế ngủ sâu (Doze Mode / Deep Sleep) và ép giữ WakeLock liên tục khi cắm nguồn.
- Bật cờ chuyển tiếp gói tin (IP Forwarding: ip_forward=1) cho mạng nội bộ.
- Tắt các chip không sử dụng (Bluetooth, NFC) để giảm nhiệt độ bo mạch.
- Tắt toàn bộ máy ảo Java (Zygote/ART) và giao diện Android (lệnh stop) sau khi khởi động container Ubuntu thành công, giải phóng toàn bộ 11.5GB RAM trống cho tác vụ AI.
### 3.4. Kiến trúc vận hành Native Container (Không qua máy ảo Virtual Machine)

Hệ thống vận hành theo mô hình Native Containerization (sử dụng Linux Namespaces, Cgroups và Chroot/Pivot_root), hoàn toàn không sử dụng bất kỳ tầng ảo hóa phần cứng (Hypervisor/VM như QEMU, KVM hay VirtualBox).

#### So sánh bản chất kiến trúc:

- Mô hình máy ảo truyền thống (Virtual Machine):
  Phải khởi chạy một tầng ảo hóa trung gian để giả lập CPU ảo, RAM ảo và chạy đè một nhân Linux thứ hai (Guest Kernel) lên trên nhân của máy (Host Kernel). Mô hình này gây suy giảm từ 20% đến 30% hiệu năng xử lý tính toán và tiêu tốn thêm 2GB đến 3GB RAM cho hệ thống ảo hóa.

- Mô hình Native Container trên S20 Ultra:
  Chỉ tồn tại duy nhất một nhân Linux Kernel 4.19 duy nhất chạy trực tiếp trên phần cứng thô (Bare-Metal). Khi kịch bản khởi động thực thi lệnh `stop`, toàn bộ tầng giao diện đồ họa (SurfaceFlinger), máy ảo Java (Zygote/ART) và các dịch vụ người dùng của Android bị đóng băng và giải phóng hoàn toàn. Toàn bộ tiến trình của Ubuntu, Docker Daemon, Immich ML và Ollama AI đều gửi tập lệnh tính toán ma trận trực tiếp xuống các thanh ghi phần cứng của vi xử lý Snapdragon 865 và tập lệnh ARM NEON với độ trễ bằng 0 và hao phí hiệu năng bằng 0%.

#### Sơ đồ kiến trúc phân tầng hệ thống:
```test
+-----------------------------------------------------------------------------+
|              PHAN CUNG BARE-METAL: QUALCOMM SNAPDRAGON 865 + 12GB LPDDR5    |
+--------------------------------------+--------------------------------------+
                                       |
+--------------------------------------v--------------------------------------+
|            NHAN LINUX KERNEL 4.19 (DUY NHAT, CHAY TRUC TIEP TREN PHAN CUNG) |
|  - Dieu phoi 8 nhan CPU Kryo 585, 12GB RAM LPDDR5 (Bang thong 44 GB/s)      |
|  - Tich hop Cgroups, Linux Namespaces, OverlayFS, Driver RTL8153B, SuSFS    |
+--------------------+------------------------------------+-------------------+
                     |                                    |
  (Duy tri ~150MB RAM quan ly phan cung)                  | (Available ~11.5GB RAM Native)
                     |                                    |
+--------------------v----------------+  +----------------v-------------------+
|  TIEN TRINH NATIVE ANDROID CAP THAP |  |   MOI TRUONG LINUX UBUNTU 24.04   |
|  - thermal-engine (kiem soat nhiet) |  |   (DROIDSPACES / NATIVE CONTAINER) |
|  - healthd / charger (on dinh nguon)|  |  - Khong su dung Hypervisor / VM   |
|  ---------------------------------- |  |  - Zero Virtualization Overhead    |
|  * He dieu hanh Java One UI         |  |  - Thuc thi truc tiep tren Kernel  |
|  * May ao Java Zygote / Dalvik ART  |  |  - Quan ly service bang systemd    |
|  * Bo dung hinh SurfaceFlinger      |  +----------------+-------------------+
|  ==> DA BI KSU KILL HOAN TOAN       |                   |
+-------------------------------------+  +----------------v-------------------+
                                         |    DOCKER RUNTIME & AI WORKLOAD    |
                                         |  - Immich Machine Learning Node    |
                                         |  - Ollama AI (Qwen 2.5 / DeepSeek) |
                                         |  - n8n Automation Engine           |
                                         +------------------------------------+
```
---

## 4. Hướng dẫn nạp và Cài đặt

### Bước 1: Nạp Kernel qua Odin
1. Đưa điện thoại về chế độ Download Mode.
2. Mở phần mềm Odin3 trên máy tính:
   - Slot AP: Chọn file boot_docker.tar tải từ mục Releases.
   - Slot USERDATA: chọn file [vbmeta_disabled.tar](https://github.com/GoRhanHee/kernel_samsung_sm8250/releases/download/Version_12830/vbmeta_disabled.tar)
3. Bấm Start để nạp (thời gian nạp khoảng 3-5 giây).

### Bước 2: Kích hoạt quyền Root và Tự động hóa
1. Sau khi máy khởi động vào One UI, cài đặt ứng dụng KernelSU_Next.apk.
2. Cài đặt ứng dụng Termux và Droidspaces.apk.
3. Mở KernelSU Manager, cấp quyền Root cho Termux và Droidspaces.
4. Mở Termux và chạy dòng lệnh sau để áp dụng kịch bản tự động hóa máy chủ:
   ```bash
   su -c "curl -fsSL https://raw.githubusercontent.com/diepkhoa/s20u-z3q-kernel/main/scripts/setup_autostart.sh | sh"
   ```
5. Mở Droidspaces, khởi tạo môi trường Ubuntu 24.04 LTS và cài đặt các dịch vụ cần thiết (Ollama, Immich ML, n8n, OpenClaw).

---

## 5. Đánh giá hiệu suất và So sánh với phần cứng x86

Nhờ chạy ở chế độ Native Container (chia sẻ trực tiếp nhân Linux Kernel với phần cứng, không qua lớp ảo hóa Hypervisor/VM, hao phí hiệu năng bằng 0%), hệ thống tận dụng tối đa sức mạnh của vi xử lý Snapdragon 865 (1 nhân Cortex-A77 2.84 GHz + 3 nhân Cortex-A77 2.42 GHz + 4 nhân Cortex-A55 1.80 GHz) và 12GB RAM LPDDR5 tốc độ cao (băng thông 44 GB/s).

### 5.1. Bảng so sánh hiệu năng thực tế với các vi xử lý x86:

| Tiêu chí | Snapdragon 865 (S20 Ultra Server) | Intel Core i5-10210U (Laptop/Mini PC) | Intel Processor N100 (Mini PC Alder Lake) | Intel Celeron N5105 / J4125 (NAS Mini PC) | Laptop Nvidia GTX 1660 Ti (dGPU 6GB) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Kiến trúc | ARM64 (8 nhân, 7nm) | x86_64 (4 nhân 8 luồng, 14nm) | x86_64 (4 nhân 4 luồng, 10nm) | x86_64 (4 nhân 4 luồng, 10nm/14nm) | Turing GPU (1536 CUDA, 12nm) |
| Bộ nhớ khả dụng | 12GB LPDDR5 (44 GB/s) | 8GB - 16GB DDR4 (21 - 38 GB/s) | 8GB - 16GB DDR4/DDR5 | 8GB DDR4 | 6GB VRAM GDDR6 (288 GB/s) |
| Hiệu năng đa nhân | Ngang ngửa 1:1 (~3.400 điểm Geekbench) | Ngang ngửa 1:1 (~3.500 điểm Geekbench) | Tương đương (~3.100 điểm Geekbench) | Mạnh hơn gấp đôi (~1.500 điểm Geekbench) | Không so sánh trực tiếp CPU |
| Công suất tiêu thụ | 3W - 5W (Toàn tải ~7W) | 15W - 35W | 10W - 20W | 10W - 15W | 80W - 120W |
| Tốc độ AI (Model 3B) | 14 - 18 từ/giây | 12 - 16 từ/giây | 12 - 15 từ/giây | 5 - 8 từ/giây | 40 - 50 từ/giây |
| Tốc độ AI (Model 7B) | 5 - 7 từ/giây | 4 - 6 từ/giây | 4 - 6 từ/giây | 1 - 2 từ/giây (Tràn RAM) | 25 - 35 từ/giây (Giới hạn 6GB VRAM) |
| Khả năng chạy 24/7 | Hoàn hảo, không ồn, tản nhiệt nhôm mát dưới 42°C | Tốt, quạt nhỏ | Rất tốt | Rất tốt | Kém, quạt ồn, nhiệt độ cao, tốn điện |

### 5.2. Đánh giá ứng dụng thực tế:
- Đối với Immich Machine Learning: 12GB RAM LPDDR5 cho phép tải toàn bộ model CLIP và nhận diện khuôn mặt mà không làm ảnh hưởng đến tài nguyên máy chủ lưu trữ chính.
- Đối với tự động hóa n8n và tạo nội dung: Tốc độ xử lý của mô hình Qwen 2.5 7B (5-7 từ/giây) và Qwen 2.5 3B (14-18 từ/giây) là hoàn toàn đáp ứng tốt cho các kịch bản chạy ngầm, tổng hợp tin tức, soạn bài viết Fanpage và trực tin nhắn chăm sóc khách hàng với độ trễ phản hồi chỉ từ 3 đến 5 giây.
- Tiêu thụ điện năng: Toàn bộ node tính toán này chỉ tiêu thụ khoảng 3W đến 5W điện năng, chi phí vận hành hàng tháng dưới 10.000 VNĐ.
