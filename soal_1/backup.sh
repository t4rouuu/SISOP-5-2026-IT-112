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
