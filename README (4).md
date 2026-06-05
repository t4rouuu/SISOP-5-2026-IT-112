# Soal 1 - Farewell Party

**Nama**: A.Algifari Rantiga Isdar  
**NRP**: 5027251112

---

## Daftar Isi
- [Soal 2 - kernel.sh](#2-kernelsh)
- [Soal 3 - single.sh](#3-singlesh)
- [Soal 4 - multi.sh](#4-multish)
- [Soal 5 - iso.sh](#5-isosh)
- [Soal 6 - qemu.sh](#6-qemush)
- [Soal 7 - backup.sh](#7-backupsh)
- [Soal 8 - Internet Access](#8-internet-access)
- [Soal 9 - Package Manager](#9-package-manager-party)
- [Soal 10 - FUSE](#10-fuse)

---

## 2. kernel.sh

Script ini mendownload kernel Linux 6.1.1, mengkompilasi menggunakan `.config` yang sudah disiapkan, dan menyimpan hasilnya ke `osboot/bzImage`.

Selama proses kompilasi, kernel dikonfigurasi dengan beberapa fitur tambahan yang dibutuhkan:
- `CONFIG_FUSE_FS=y` untuk mendukung FUSE
- `CONFIG_E1000=y` untuk driver jaringan
- `CONFIG_VIRTIO=y`, `CONFIG_VIRTIO_NET=y`, `CONFIG_VIRTIO_PCI=y` untuk virtio support

```bash
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
```

---

## 3. single.sh

Script ini membuat single-user filesystem dengan hanya user `root`, menggunakan BusyBox untuk shell environment. Output disimpan ke `osboot/single.gz`.

```bash
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
```

---

## 4. multi.sh

Script ini membuat multi-user filesystem dengan user `root`, `henn`, `hann`, `viii`, dan `kids`. Setiap user memiliki password dan hak akses masing-masing sesuai spesifikasi. Output disimpan ke `osboot/multi.gz`.

Terdapat beberapa revisi dari kode awal:
- Menambahkan `login`, `getty` ke busybox symlink
- Menambahkan password hash menggunakan `openssl passwd`
- Menambahkan `/etc/shadow` untuk autentikasi
- Menambahkan group `grp_hann`, `grp_viii`, `grp_kids` untuk mengatur akses antar user
- Menambahkan `etc/inittab` dan `etc/init.d/rcS` untuk init system
- Menambahkan ASCII art banner **Farewell Party** di `/etc/profile`
- Menambahkan `mknod -m 666 dev/fuse c 10 229` untuk support FUSE
- Menambahkan `hello_fuse` dan `nano` static binary
- Menambahkan konfigurasi network di `rcS`

```bash
#!/bin/bash
set -e

# install dependencies di host jika belum ada
if ! dpkg -l musl 2>/dev/null | grep -q "^ii"; then
    echo "Installing musl on host..."
    sudo apt-get install -y musl
fi

if ! dpkg -l libfuse-dev 2>/dev/null | grep -q "^ii"; then
    echo "Installing libfuse-dev on host..."
    sudo apt-get install -y libfuse-dev
fi

# compile nano static jika belum ada
if [ ! -f "nano-static" ]; then
    echo "Compiling nano static..."
    sudo apt-get install -y libncurses-dev 2>/dev/null
    wget -q https://www.nano-editor.org/dist/v7/nano-7.2.tar.gz
    tar -xzf nano-7.2.tar.gz
    cd nano-7.2
    ./configure --enable-utf8 LDFLAGS="-static" CFLAGS="-static" 2>/dev/null
    make 2>/dev/null
    cp src/nano ../nano-static
    cd ..
    rm -rf nano-7.2 nano-7.2.tar.gz
    echo "nano static compiled."
fi

# compile hello_fuse static jika belum ada
if [ ! -f "hello_fuse" ]; then
    echo "Compiling hello_fuse..."
    cat > /tmp/hello_fuse.c << 'FUSEOF'
#define FUSE_USE_VERSION 26
#include <fuse.h>
#include <string.h>
#include <errno.h>

static const char *hello_str = "Hello from FUSE!\n";
static const char *hello_path = "/hello";

static int hello_getattr(const char *path, struct stat *stbuf) {
    memset(stbuf, 0, sizeof(struct stat));
    if (strcmp(path, "/") == 0) {
        stbuf->st_mode = S_IFDIR | 0755;
        stbuf->st_nlink = 2;
    } else if (strcmp(path, hello_path) == 0) {
        stbuf->st_mode = S_IFREG | 0444;
        stbuf->st_nlink = 1;
        stbuf->st_size = strlen(hello_str);
    } else {
        return -ENOENT;
    }
    return 0;
}

static int hello_readdir(const char *path, void *buf, fuse_fill_dir_t filler,
                         off_t offset, struct fuse_file_info *fi) {
    if (strcmp(path, "/") != 0) return -ENOENT;
    filler(buf, ".", NULL, 0);
    filler(buf, "..", NULL, 0);
    filler(buf, hello_path + 1, NULL, 0);
    return 0;
}

static int hello_open(const char *path, struct fuse_file_info *fi) {
    if (strcmp(path, hello_path) != 0) return -ENOENT;
    return 0;
}

static int hello_read(const char *path, char *buf, size_t size, off_t offset,
                      struct fuse_file_info *fi) {
    if (strcmp(path, hello_path) != 0) return -ENOENT;
    size_t len = strlen(hello_str);
    if (offset >= len) return 0;
    if (offset + size > len) size = len - offset;
    memcpy(buf, hello_str + offset, size);
    return size;
}

static struct fuse_operations hello_oper = {
    .getattr = hello_getattr,
    .readdir = hello_readdir,
    .open    = hello_open,
    .read    = hello_read,
};

int main(int argc, char *argv[]) {
    return fuse_main(argc, argv, &hello_oper, NULL);
}
FUSEOF
    gcc -static /tmp/hello_fuse.c -o hello_fuse $(pkg-config fuse --cflags) -lfuse -lpthread -ldl
    echo "hello_fuse compiled."
fi

ROOTFS="rootfs_multi"
rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"
cd "$ROOTFS"

mkdir -p bin dev proc sys etc tmp root home/henn home/hann home/viii home/kids usr/bin

# buat /dev/fuse di dalam rootfs
mknod -m 666 dev/fuse c 10 229

cp /bin/busybox bin/busybox
for cmd in sh ls cat mount echo mkdir rm pwd uname dmesg whoami id chmod chown clear login getty ping wget tar udhcpc ifconfig route
do
    ln -sf busybox bin/$cmd
done

# copy nano static
cp ../nano-static usr/bin/nano
chmod +x usr/bin/nano

# copy hello_fuse static
cp ../hello_fuse usr/bin/hello_fuse
chmod +x usr/bin/hello_fuse

cat > bin/party << 'EOF'
#!/bin/sh
MIRROR="http://dl-cdn.alpinelinux.org/alpine/v3.18/main/x86_64"

usage() {
    echo "Usage: party install <package>"
    echo "       party remove <package>"
    echo "       party update"
}

case "$1" in
install)
    shift
    if [ -z "$1" ]; then
        echo "Error: package name required"
        exit 1
    fi
    for pkg in "$@"; do
        echo "Fetching index for $pkg..."
        INDEX=$(wget --no-check-certificate -q -O - "${MIRROR}/APKINDEX.tar.gz" 2>/dev/null | tar -xzO APKINDEX 2>/dev/null | grep "^P:${pkg}$" -A 10 | grep "^V:" | head -1 | cut -d: -f2)
        if [ -z "$INDEX" ]; then
            echo "Error: package $pkg not found"
            exit 1
        fi
        echo "Downloading ${pkg}-${INDEX}..."
        wget --no-check-certificate -q "${MIRROR}/${pkg}-${INDEX}.apk" -O /tmp/${pkg}.apk
        if [ $? -ne 0 ]; then
            echo "Error: failed to download $pkg"
            exit 1
        fi
        echo "Installing $pkg..."
        mkdir -p /tmp/pkg_extract
        tar -xzf /tmp/${pkg}.apk -C /tmp/pkg_extract 2>/dev/null || true
        for dir in usr bin lib sbin; do
            if [ -d "/tmp/pkg_extract/$dir" ]; then
                cp -r /tmp/pkg_extract/$dir / 2>/dev/null || true
            fi
        done
        rm -rf /tmp/${pkg}.apk /tmp/pkg_extract
        echo "$pkg installed successfully."
    done
    ;;
remove)
    echo "remove not supported in minimal mode"
    ;;
update)
    echo "Checking mirror: ${MIRROR}"
    wget --no-check-certificate -q -O /dev/null "${MIRROR}/APKINDEX.tar.gz" && echo "Mirror reachable." || echo "Mirror unreachable."
    ;;
*)
    usage
    ;;
esac
EOF
chmod +x bin/party

HASH_ROOT=$(openssl passwd -1 "root123")
HASH_HENN=$(openssl passwd -1 "henn123")
HASH_HANN=$(openssl passwd -1 "hann123")
HASH_VIII=$(openssl passwd -1 "viii123")
HASH_KIDS=$(openssl passwd -1 "kids123")

cat > etc/passwd << EOF
root:x:0:0:root:/root:/bin/sh
henn:x:1000:1000:henn:/home/henn:/bin/sh
hann:x:1001:1001:hann:/home/hann:/bin/sh
viii:x:1002:1002:viii:/home/viii:/bin/sh
kids:x:1003:1003:kids:/home/kids:/bin/sh
EOF

cat > etc/shadow << EOF
root:${HASH_ROOT}:19000:0:99999:7:::
henn:${HASH_HENN}:19000:0:99999:7:::
hann:${HASH_HANN}:19000:0:99999:7:::
viii:${HASH_VIII}:19000:0:99999:7:::
kids:${HASH_KIDS}:19000:0:99999:7:::
EOF
chmod 640 etc/shadow

cat > etc/group << EOF
root:x:0:
henn:x:1000:henn
hann:x:1001:hann
viii:x:1002:viii
kids:x:1003:kids
grp_hann:x:1004:henn,hann
grp_viii:x:1005:henn,hann,viii
grp_kids:x:1006:henn,hann,viii,kids
EOF

chmod 1777 tmp

chown 0:0 root
chmod 700 root

chown 1000:1000 home/henn
chmod 700 home/henn

chown 1001:1004 home/hann
chmod 750 home/hann

chown 1002:1005 home/viii
chmod 750 home/viii

chown 1003:1006 home/kids
chmod 750 home/kids

cat > etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

cat > etc/profile << 'EOF'
clear
cat << 'BANNER'
 ______                          _ _   ____            _
|  ____|                        | | | |  _ \          | |
| |__ __ _ _ __ _____      _____| | | | |_) | __ _ _ __| |_ _   _
|  __/ _` | '__/ _ \ \ /\ / / _ \ | | |  __/ / _` | '__| __| | | |
| | | (_| | | |  __/\ V  V /  __/ | | | |   | (_| | |  | |_| |_| |
|_|  \__,_|_|  \___| \_/\_/ \___|_|_| |_|    \__,_|_|   \__|\__, |
                                                               __/ |
                                                              |___/
BANNER
echo ""
echo "Welcome, $(whoami)"
echo ""
EOF

cat > etc/inittab << 'EOF'
::sysinit:/etc/init.d/rcS
ttyS0::respawn:/bin/login
::restart:/sbin/init
::ctrlaltdel:/sbin/reboot
EOF

mkdir -p etc/init.d
cat > etc/init.d/rcS << 'EOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true

ifconfig eth0 10.0.2.15 netmask 255.255.255.0 2>/dev/null || true
route add default gw 10.0.2.2 2>/dev/null || true
echo "nameserver 8.8.8.8" > /etc/resolv.conf
EOF
chmod +x etc/init.d/rcS

mkdir -p sbin
ln -sf ../bin/busybox sbin/init

cat > init << 'EOF'
#!/bin/sh
exec /sbin/init
EOF
chmod +x init

find . | cpio -o -H newc | gzip > ../osboot/multi.gz
cd ..
rm -rf "$ROOTFS"
echo "multi.gz berhasil dibuat"
```
<img width="955" height="556" alt="sisop5 4 6" src="https://github.com/user-attachments/assets/4fc5580f-0756-404d-bba6-8d452e9b00fb" />
<img width="967" height="668" alt="sisop5 4 5" src="https://github.com/user-attachments/assets/4a18b2f0-8ab1-45f7-b3d1-92f504f3003f" />
<img width="947" height="696" alt="sisop5 4 4" src="https://github.com/user-attachments/assets/e724c660-9470-43cc-a170-4dfe656c898c" />
<img width="1368" height="503" alt="sisop5 4 3" src="https://github.com/user-attachments/assets/097240ef-6a5e-428a-a225-66176af0b36b" />
<img width="1371" height="452" alt="sisop5 4 2" src="https://github.com/user-attachments/assets/8440713b-3abd-4e57-a757-29c300d6c78e" />
<img width="950" height="188" alt="sisop5 4 1" src="https://github.com/user-attachments/assets/abee3ba7-818e-45c0-b08c-ecc0a81d1ca8" />

---

## 5. iso.sh

Script ini membuat bootable ISO menggunakan GRUB yang memuat kedua filesystem (single dan multi). Output disimpan ke `osboot/farewell.iso`.

```bash
#!/bin/bash
set -e
ISO_DIR=iso_root
rm -rf "$ISO_DIR"
mkdir -p "$ISO_DIR/boot/grub"
cp osboot/bzImage "$ISO_DIR/boot/"
cp osboot/single.gz "$ISO_DIR/boot/"
cp osboot/multi.gz "$ISO_DIR/boot/"
cat > "$ISO_DIR/boot/grub/grub.cfg" << 'EOF'
set timeout=10
set default=0
menuentry "Farewell OS - Single User" {
linux /boot/bzImage console=tty0
initrd /boot/single.gz
}
menuentry "Farewell OS - Multi User" {
linux /boot/bzImage console=tty0
initrd /boot/multi.gz
}
EOF
grub-mkrescue -o osboot/farewell.iso "$ISO_DIR"
rm -rf "$ISO_DIR"
echo "farewell.iso berhasil dibuat"
```

---

## 6. qemu.sh

Script untuk menjalankan QEMU dengan tiga mode: single-user, multi-user, dan boot dari ISO.

Revisi yang dilakukan: menambahkan `-nic user,model=e1000` pada mode `--multi` agar network interface eth0 tersedia di dalam OS.

```bash
#!/bin/bash
case "$1" in
--single)
    qemu-system-x86_64 \
    -kernel osboot/bzImage \
    -initrd osboot/single.gz \
    -append "console=tty0 console=ttyS0 init=/init" \
    -nic user \
    -nographic
    ;;
--multi)
    qemu-system-x86_64 \
    -kernel osboot/bzImage \
    -initrd osboot/multi.gz \
    -append "console=tty0 console=ttyS0 init=/init" \
    -nic user,model=e1000 \
    -nographic
    ;;
--all)
    qemu-system-x86_64 \
    -boot d \
    -cdrom osboot/farewell.iso \
    -nic user
    ;;
*)
    echo "Usage:"
    echo "  ./qemu.sh --single"
    echo "  ./qemu.sh --multi"
    echo "  ./qemu.sh --all"
    ;;
esac
```

---

## 7. backup.sh

Script untuk mengarsipkan semua file build ke dalam satu zip dengan nama berdasarkan timestamp, lalu menghapus file aslinya.

```bash
#!/bin/bash
set -e
TIMESTAMP=$(date +"%d%m%Y-%H%M%S")
BACKUP_NAME="osboot/farewell_backup_${TIMESTAMP}.zip"
zip -j "$BACKUP_NAME" \
osboot/bzImage \
osboot/single.gz \
osboot/multi.gz \
osboot/farewell.iso
echo "Backup dibuat: $BACKUP_NAME"
rm -f osboot/bzImage
rm -f osboot/single.gz
rm -f osboot/multi.gz
rm -f osboot/farewell.iso
echo "File build telah dihapus"
```

---

## 8. Internet Access

Di host, kernel dikompilasi ulang dengan menambahkan `CONFIG_E1000=y` agar QEMU dapat mengenali network interface eth0, dan pada `qemu.sh` ditambahkan flag `-nic user,model=e1000` pada mode `--multi`.

Di dalam QEMU, `etc/init.d/rcS` pada `multi.sh` secara otomatis mengkonfigurasi network saat boot:

```sh
ifconfig eth0 10.0.2.15 netmask 255.255.255.0
route add default gw 10.0.2.2
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```
**Bukti:**

> <img width="1363" height="750" alt="sisop5 8 1" src="https://github.com/user-attachments/assets/aa36e466-eab5-4de1-9309-636a448d096f" />


---

## 9. Package Manager (party)

Package manager bernama `party` dibuat sebagai shell script yang mengambil package dari mirror Alpine Linux. Mendukung perintah `install`, `remove`, dan `update`. TLS verification di-bypass menggunakan flag `--no-check-certificate` pada wget.

Cara penggunaan:
```sh
party install <package>
party update
```

**Bukti:**

> <img width="952" height="750" alt="sisop5 9 1" src="https://github.com/user-attachments/assets/70695565-1139-42cd-91db-494cd72fd02f" />
<img width="436" height="107" alt="sisop5 9 3" src="https://github.com/user-attachments/assets/cbb345e3-1b7f-49ec-aa6e-a878dc413836" />



---

## 10. FUSE

Untuk menjalankan FUSE di dalam OS, dibutuhkan:

**Kernel**: dikompilasi dengan `CONFIG_FUSE_FS=y`.

**Device node**: `mknod -m 666 dev/fuse c 10 229` ditambahkan ke `multi.sh` agar `/dev/fuse` tersedia saat boot.

**Program**: `hello_fuse` dikompilasi secara static di host dan di-copy ke `usr/bin/hello_fuse` di dalam rootfs.

Cara menjalankan:
```sh
mkdir -p /tmp/mnt
hello_fuse /tmp/mnt -f &
sleep 1
cat /tmp/mnt/hello
```

Output yang diharapkan:
```
Hello from FUSE!
```

**Bukti:**

> <img width="1363" height="750" alt="sisop5 10" src="https://github.com/user-attachments/assets/a41815b6-70e1-43b6-9d53-84bf0c2c109b" />

