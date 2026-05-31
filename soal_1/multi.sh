#!/bin/bash

set -e

ROOTFS="rootfs_multi"

rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"

cd "$ROOTFS"

mkdir -p bin dev proc sys etc tmp root home/henn home/hann home/viii home/kids

cp /bin/busybox bin/busybox

for cmd in sh ls cat mount echo mkdir rm pwd uname dmesg whoami id chmod chown clear
do
ln -sf busybox bin/$cmd
done

cat > etc/passwd << EOF
root:x:0:0:root:/root:/bin/sh
henn:x:1000:1000:henn:/home/henn:/bin/sh
hann:x:1001:1001:hann:/home/hann:/bin/sh
viii:x:1002:1002:viii:/home/viii:/bin/sh
kids:x:1003:1003:kids:/home/kids:/bin/sh
EOF

cat > etc/group << EOF
root:x:0:
henn:x:1000:
hann:x:1001:
viii:x:1002:
kids:x:1003:
EOF

chmod 1777 tmp
chmod 700 root

cat > init << 'EOF'
#!/bin/sh

mount -t proc proc /proc
mount -t sysfs sysfs /sys

clear

echo
echo "=================================="
echo "         FAREWELL PARTY"
echo "=================================="
echo
echo "Welcome, root"
echo

exec /bin/sh
EOF

chmod +x init

find . | cpio -o -H newc | gzip > ../osboot/multi.gz

cd ..

rm -rf "$ROOTFS"

echo "multi.gz berhasil dibuat"
