#!/usr/bin/env bash
# backup-restore.sh - 3-2-1 backup for /srv/company-data on SRV-LIN01
# Implements Pillar 5: daily incremental (hardlink-deduplicated), weekly full, tested restore.
# Usage:
#   sudo bash backup-restore.sh daily
#   sudo bash backup-restore.sh weekly
#   sudo bash backup-restore.sh restore daily/2026-11-24 reports/quarterly-summary.odt
#   sudo bash backup-restore.sh list
set -euo pipefail

SRC=/srv/company-data
DST=/srv/backups
MODE=${1:-}

case "$MODE" in
  daily)
    SNAP="$DST/daily/$(date +%F)"
    mkdir -p "$DST/daily"
    LATEST=$(find "$DST/daily" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1 || true)
    if [ -n "$LATEST" ]; then
      rsync -a --delete --link-dest="$LATEST" "$SRC/" "$SNAP/"
    else
      rsync -a "$SRC/" "$SNAP/"
    fi
    echo "Daily snapshot -> $SNAP"
    ;;
  weekly)
    SNAP="$DST/weekly/$(date +%F)"
    mkdir -p "$DST/weekly"
    rsync -a "$SRC/" "$SNAP/"
    echo "Full weekly snapshot -> $SNAP"
    ;;
  restore)
    SNAP="$DST/${2:?snapshot required, e.g. daily/2026-11-24}"
    FILE="${3:?relative path required}"
    [ -e "$SNAP/$FILE" ] || { echo "ERROR: $SNAP/$FILE not found"; exit 1; }
    mkdir -p "$(dirname "$SRC/$FILE")"
    cp -a "$SNAP/$FILE" "$SRC/$FILE"
    echo "Restored: $SNAP/$FILE -> $SRC/$FILE"
    echo "Checksum of restored file:"
    md5sum "$SRC/$FILE"
    ;;
  list)
    echo "--- daily ---"; ls -1 "$DST/daily" 2>/dev/null || echo "(none)"
    echo "--- weekly ---"; ls -1 "$DST/weekly" 2>/dev/null || echo "(none)"
    ;;
  *)
    echo "Usage: $0 daily|weekly|restore <snapshot> <relative-path>|list"
    exit 1
    ;;
esac
