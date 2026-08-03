#!/bin/bash
SOURCE_DIR="/var/log/apache2"
BACKUP_DIR="/home/olabodedanielogooluwa/backups"

mkdir -p "$BACKUP_DIR"

if cp "$SOURCE_DIR/access.log" "$BACKUP_DIR/access_backup.log"; then
    echo "Backup complete."
else
    echo "ERROR: Backup failed. Check that $SOURCE_DIR/access.log exists and $BACKUP_DIR is writable."
    exit 1
fi

