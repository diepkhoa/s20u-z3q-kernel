#!/bin/bash
set -e

cd /workspace

echo "=== 1. Thiet lap moi truong thu vien ==="
ln -sf /lib/x86_64-linux-gnu/libtinfo.so.6 /lib/x86_64-linux-gnu/libtinfo.so.5 2>/dev/null || true
ln -sf /lib/x86_64-linux-gnu/libncurses.so.6 /lib/x86_64-linux-gnu/libncurses.so.5 2>/dev/null || true

echo "=== 2. Chuan bi cong cu Magiskboot ==="
if [ ! -f "/usr/local/bin/magiskboot" ]; then
    apt update && apt install -y wget unzip dos2unix patch libncurses5 libtinfo5 || true
    wget -q https://github.com/topjohnwu/Magisk/releases/download/v27.0/Magisk-v27.0.apk -O /tmp/magisk.apk
    unzip -j -q /tmp/magisk.apk "lib/x86_64/libmagiskboot.so" -d /tmp/
    mv /tmp/libmagiskboot.so /usr/local/bin/magiskboot
    chmod +x /usr/local/bin/magiskboot
fi

echo "=== 3. Chuan bi Toolchain Proton-Clang ==="
if [ ! -d "toolchain/bin" ]; then
    git clone --depth=1 https://github.com/kdrag0n/proton-clang.git toolchain
    rm -f toolchain/bin/as toolchain/bin/ld
fi

echo "=== 4. Chuan bi Ma nguon Kernel ==="
if [ ! -d "src/.git" ]; then
    git clone --depth=1 https://github.com/xwenx90/GalaxyS20_Series_KernelSU_Next_Susfs.git -b x1q src
fi

echo "=== 5. Chuan bi KernelSU-Next ==="
if [ ! -d "/tmp/ksu" ]; then
    git clone --depth=1 https://github.com/KernelSU-Next/KernelSU-Next.git -b legacy /tmp/ksu
fi
rm -rf src/drivers/kernelsu && mkdir -p src/drivers/kernelsu
cp -r /tmp/ksu/kernel/* src/drivers/kernelsu/
cp -r /tmp/ksu/include src/drivers/kernelsu/ 2>/dev/null || true
cp -r /tmp/ksu/uapi src/drivers/kernelsu/ 2>/dev/null || true
if [ -d "/tmp/ksu/include/uapi" ]; then
    cp -r /tmp/ksu/include/uapi src/drivers/kernelsu/
fi

echo "=== 6. Ap dung tat ca cac ban va da duoc kiem chung ==="
find src/ -name "Kconfig*" -type f -exec sed -i 's/\xc2\xa0/ /g; s/\r$//; s/^\xef\xbb\xbf//' {} +
sed -i '/No hooks were defined/d' src/drivers/kernelsu/Kbuild 2>/dev/null || true
sed -i '1i ccflags-y += -DCONFIG_KSU_MANUAL_HOOK -DCONFIG_KSU_SUSFS -I$(srctree)/drivers/kernelsu -I$(srctree)/drivers/kernelsu/include -I$(srctree)/drivers/kernelsu/uapi' src/drivers/kernelsu/Kbuild 2>/dev/null || true
find src/drivers/kernelsu/ -type f -exec sed -i 's/return strscpy_pad(dest, src, count);/strncpy(dest, src, count); return strlen(dest);/g' {} + 2>/dev/null || true
find src/drivers/kernelsu/ -type f -exec sed -i 's/\bstrscpy_pad\b/strncpy/g' {} + 2>/dev/null || true
sed -i 's/^YYLTYPE yylloc;/extern YYLTYPE yylloc;/' src/scripts/dtc/dtc-lexer.l 2>/dev/null || true
sed -i 's/^YYLTYPE yylloc;/extern YYLTYPE yylloc;/' src/scripts/dtc/dtc-lexer.lex.c_shipped 2>/dev/null || true
sed -i 's/mask, mark->ignored_mask/mark->mask, mark->ignored_mask/g' src/fs/notify/fdinfo.c 2>/dev/null || true
sed -i 's|#define TRACE_INCLUDE_PATH \.|#define TRACE_INCLUDE_PATH ../../drivers/hid|' src/drivers/hid/hid-trace.h 2>/dev/null || true
sed -i 's|#define TRACE_INCLUDE_PATH \.|#define TRACE_INCLUDE_PATH ../../techpack/display/pll|' src/techpack/display/pll/pll_trace.h 2>/dev/null || true
sed -i 's|#include "cam_cci_dev.h"|#include "../cam_cci/cam_cci_dev.h"|g' src/techpack/camera/drivers/cam_sensor_module/cam_sensor_io/cam_sensor_i2c.h 2>/dev/null || true
sed -i 's/int is_ib_init_succeed()/int is_ib_init_succeed(void)/g' src/drivers/input/input_booster.c 2>/dev/null || true
sed -i '1i #pragma clang diagnostic ignored "-Wframe-address"' src/drivers/net/wireless/broadcom/bcmdhd_101_16/dhd_linux.c 2>/dev/null || true
find src/drivers/net/wireless/broadcom/ -name "Makefile*" -type f -exec sed -i 's/-Werror\b//g' {} + 2>/dev/null || true
sed -i 's/KBUILD_CFLAGS   :=/KBUILD_CFLAGS   := -fno-builtin-stpcpy -fno-builtin /g' src/Makefile 2>/dev/null || true
find src/drivers/platform/msm/gsi/ -type f -exec sed -i 's/union __packed gsi_channel_scratch/union gsi_channel_scratch/g; s/struct __packed gsi_mhi_channel_scratch/struct gsi_mhi_channel_scratch/g; s/union __packed gsi_evt_scratch/union gsi_evt_scratch/g' {} + 2>/dev/null || true
find src/include/ -type f -exec sed -i 's/union __packed gsi_channel_scratch/union gsi_channel_scratch/g; s/struct __packed gsi_mhi_channel_scratch/struct gsi_mhi_channel_scratch/g; s/union __packed gsi_evt_scratch/union gsi_evt_scratch/g' {} + 2>/dev/null || true

echo "=== 7. Nap .config goc va gop co Docker ==="
cd /workspace/src
export PATH=/workspace/toolchain/bin:$PATH
MAKE_ARGS="ARCH=arm64 SUBARCH=arm64 CC=clang LD=ld.lld CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- HOSTCFLAGS=-fcommon HOSTCXXFLAGS=-fcommon"

cp /workspace/config/z3q_base.config .config
scripts/kconfig/merge_config.sh -m .config /workspace/config/docker.config
make $MAKE_ARGS olddefconfig

echo "=== 8. Bat dau bien dich Kernel ==="
export KSU_GIT_VERSION="12450"
export KSU_VERSION_TAG="v1.0.5"
make $MAKE_ARGS -j$(nproc)

echo "=== 9. Dong goi file boot_docker.tar cho Odin ==="
mkdir -p /workspace/output
cp arch/arm64/boot/Image /workspace/output/Image

if [ -f "/workspace/stock/boot.img" ]; then
    echo "Dang dong goi bang magiskboot..."
    mkdir -p /tmp/repack && cd /tmp/repack
    cp /workspace/stock/boot.img ./boot.img
    magiskboot unpack boot.img
    cp /workspace/output/Image ./kernel
    magiskboot repack boot.img new-boot.img
    mv new-boot.img boot.img
    tar -cvf /workspace/output/boot_docker.tar boot.img
    echo "=================================================="
    echo " BIEN DICH VA DONG GOI THANH CONG! "
    echo " File Odin luu tai: ~/s20u-kernel-ci/output/boot_docker.tar"
    echo "=================================================="
fi
