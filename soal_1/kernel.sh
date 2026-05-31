#!/bin/bash

set -e

KERNEL_VER=6.1.1

mkdir -p osboot

if [ ! -d linux-$KERNEL_VER ]; then
    wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL_VER.tar.xz
    tar -xf linux-$KERNEL_VER.tar.xz
fi

cd linux-$KERNEL_VER

cp ../.config .config

make olddefconfig

make KCFLAGS="-Wno-error" -j$(nproc)

cp arch/x86/boot/bzImage ../osboot/bzImage

echo "Kernel selesai."
