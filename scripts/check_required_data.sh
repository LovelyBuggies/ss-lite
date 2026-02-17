#!/usr/bin/env bash
set -euo pipefail

missing=0

check_path() {
  local p="$1"
  if [[ -e "$p" ]]; then
    echo "[OK] $p"
  else
    echo "[MISSING] $p"
    missing=1
  fi
}

echo "Checking Replica + SoundSpaces 2.0 minimum data under /home/nino/ss-lite/data"

check_path /home/nino/ss-lite/data/material_config.json

check_path /home/nino/ss-lite/data/scene_datasets/replica
check_path /home/nino/ss-lite/data/scene_datasets/replica/replica.scene_dataset_config.json

check_path /home/nino/ss-lite/data/datasets/audionav/replica/v1/train_telephone/train_telephone.json.gz
check_path /home/nino/ss-lite/data/metadata/replica
check_path /home/nino/ss-lite/data/sounds/1s_all

if [[ "$missing" -eq 1 ]]; then
  echo "\nResult: missing required files."
  exit 1
fi

echo "\nResult: minimum required files look present."
