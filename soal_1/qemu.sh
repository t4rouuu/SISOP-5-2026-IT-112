#!/bin/bash

case "$1" in

--single)
    qemu-system-x86_64 \
    -kernel osboot/bzImage \
    -initrd osboot/single.gz \
    -append "console=ttyS0" \
    -nographic
    ;;

--multi)
    qemu-system-x86_64 \
    -kernel osboot/bzImage \
    -initrd osboot/multi.gz \
    -append "console=ttyS0" \
    -nographic
    ;;

--all)
    qemu-system-x86_64 \
    -boot d \
    -cdrom osboot/farewell.iso
    ;;

*)
    echo "Usage:"
    echo "  ./qemu.sh --single"
    echo "  ./qemu.sh --multi"
    echo "  ./qemu.sh --all"
    ;;
esac
