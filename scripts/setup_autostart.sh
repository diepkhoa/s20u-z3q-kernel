#!/system/bin/sh
set -e

echo "=== Dang thiet lap che do Server Tu Dong cho S20 Ultra ==="

# 1. Tao thu muc service.d neu chua co
mkdir -p /data/adb/service.d

# 2. Tao file s20u_server_boot.sh voi co che ghi log
cat << 'BOOT_EOF' > /data/adb/service.d/s20u_server_boot.sh
#!/system/bin/sh
# File tu dong chay sau khi S20 Ultra khoi dong
exec > /data/adb/s20u_boot.log 2>&1
echo "=== [$(date)] S20 Ultra Server Boot Triggered ==="

# Doi 15 giay de nhan dien USB-LAN va phan cung on dinh
sleep 15

# 1. Ep CPU luon thuc (Chong Doze Mode / Deep Sleep)
echo "Dang khoa WakeLock va tat Doze Mode..."
dumpsys deviceidle disable
settings put global stay_on_while_plugged_in 3

# 2. Khoi dong Ubuntu Container trong Droidspaces
echo "Dang khoi dong Container Ubuntu..."
droidspaces start ubuntu || echo "Droidspaces chua duoc cau hinh"

# 3. Tat toan bo giao dien Android UI de giai phong 11.5GB RAM
echo "Dang giai phong RAM (Khai tu Android UI)..."
stop

echo "=== [$(date)] Server da san sang hoat dong! ==="
BOOT_EOF

# 3. Cap quyen thuc thi cho script
chmod 755 /data/adb/service.d/s20u_server_boot.sh

echo "=================================================="
echo " CAI DAT THANH CONG! "
echo " Tu gio, moi khi reboot may se tu chay Ubuntu va tat Android UI."
echo " File log luu tai: /data/adb/s20u_boot.log"
echo "=================================================="
