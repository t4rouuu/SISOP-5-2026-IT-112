#!/bin/bash

set -e

ROOTFS=rootfs_single

rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"

cd "$ROOTFS"

mkdir -p \
bin \
dev \
proc \
sys \
etc \
tmp \
root

# BusyBox
cp /bin/busybox bin/

for cmd in sh ls cat mount echo mkdir rm pwd uname dmesg whoami id; do
    ln -sf busybox bin/$cmd
done

# User database
cat > etc/passwd << EOF
root:x:0:0:root:/root:/bin/sh
EOF

cat > etc/group << EOF
root:x:0:
EOF

# Init
cat > init << 'EOF'
#!/bin/sh

mount -t proc proc /proc
mount -t sysfs sysfs /sys

cd /root

echo
echo "================================="
echo "      Farewell Party OS"
echo "================================="
echo

exec /bin/sh
EOF

chmod +x init

find . | cpio -o -H newc | gzip > ../osboot/single.gz

cd ..

rm -rf "$ROOTFS"

echo "single.gz berhasil dibuat"
