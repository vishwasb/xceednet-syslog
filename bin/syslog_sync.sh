#!/usr/bin/env bash
for d in /remotelogs/*; do
  if [ -d "$d" ] && [[ $(basename "$d") =~ ^[A-Z]{8}$ ]]; then
    echo "Syncing folder: $d"
    aws s3 sync "$d" "s3://xceednetlogs1/$(basename "$d")/" \
      --storage-class STANDARD_IA \
      --exclude "*" \
      --include "*.gz"
  fi
done
