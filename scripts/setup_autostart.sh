#!/system/bin/sh
set -e

echo "=== Dang thiet lap che do Server Tu Dong Tối Ưu cho S20 Ultra ==="

# 1. Tao thu muc service.d neu chua co
mkdir -p /data/adb/service.d

# 2. Tao file s20u_server_boot.sh hoàn chỉnh
cat << 'BOOT_EOF' > /data/adb/service.d/s20u_server_boot.sh
#!/system/bin/sh
# File tu dong chay sau khi S20 Ultra khoi dong
exec > /data/adb/s20u_boot.log 2>&1
echo "=================================================="
echo "=== [$(date)] S20 Ultra Server Boot Triggered ==="
echo "=================================================="

# Doi 10 giay de nhan dien USB-LAN va phan cung on dinh
sleep 10

# ----------------------------------------------------
# 1. ĐÁNH LỪA HỆ THỐNG VỀ PIN & NGUỒN (CHỐNG SẬP NGUỒN)
# ----------------------------------------------------
echo "[1/6] Dang khoa trang thai Pin 100% va nguon AC..."
dumpsys battery set level 100
dumpsys battery set status 2      # Trạng thái: Đang sạc (Charging)
dumpsys battery set ac 1          # Nguồn cấp: Cắm sạc AC
dumpsys battery set usb 0
dumpsys battery set wireless 0

# ----------------------------------------------------
# 2. TẮT CHẾ ĐỘ TIẾT KIỆM PIN & ÉP CPU LUÔN THỨC
# ----------------------------------------------------
echo "[2/6] Dang vo hieu hoa che do tiet kiem pin va Doze Mode..."
dumpsys deviceidle disable
settings put global low_power 0
settings put global low_power_trigger_level 0
settings put global stay_on_while_plugged_in 7  # Luôn sáng/thức khi cắm nguồn
settings put global sleep_timeout 0

# ----------------------------------------------------
# 3. BẬT CHUYỂN TIẾP MẠNG (BẮT BUỘC CHO DOCKER/CONTAINER)
# ----------------------------------------------------
echo "[3/6] Dang bat IP Forwarding cho Docker & Droidspaces..."
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 1 > /proc/sys/net/ipv4/conf/all/forwarding

# ----------------------------------------------------
# 4. TẮT CÁC PHẦN CỨNG THỪA ĐỂ GIẢM NHIỆT & TIẾT KIỆM ĐIỆN
# ----------------------------------------------------
echo "[4/6] Dang tat Bluetooth va NFC..."
service call bluetooth_manager 8 >/dev/null 2>&1 || true
svc nfc disable >/dev/null 2>&1 || true

# (Tùy chọn: Nếu cắm dây LAN thì có thể tắt Wi-Fi để mát máy hơn)
# svc wifi disable

# ----------------------------------------------------
# 5. KHỞI ĐỘNG UBUNTU CONTAINER TRONG DROIDSPACES
# ----------------------------------------------------
echo "[5/6] Dang khoi dong Container Ubuntu 24.04..."
if command -v droidspaces >/dev/null 2>&1; then
    droidspaces start ubuntu || echo "Droidspaces start failed"
else
    echo "Droidspaces CLI chua duoc cai dat vao PATH"
fi

# ----------------------------------------------------
# 6. KHAI TỬ GIAO DIỆN ANDROID (GIẢI PHÓNG 11.5GB RAM)
# ----------------------------------------------------
echo "[6/6] Dang tat Android UI de giai phong 11.5GB RAM cho AI..."
sleep 5
stop

echo "=================================================="
echo "=== [$(date)] S20 Ultra Server da san sang 100%! ==="
echo "=================================================="
BOOT_EOF

# 3. Cap quyen thuc thi
chmod 755 /data/adb/service.d/s20u_server_boot.sh

echo "=================================================="
echo " CAI DAT THANH CONG! "
echo " Script da duoc toi uu toan dien (Pin, Doze, Mang, RAM)."
echo " File log luu tai: /data/adb/s20u_boot.log"
echo "=================================================="
