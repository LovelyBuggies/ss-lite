#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/nino/ss-lit"
MODEL_DIR="${1:-/home/nino/ss-lit/runs/av_nav_replica_ss2}"

cd "${REPO_ROOT}"
PYTHONPATH=/home/nino/sound-spaces \
python /home/nino/sound-spaces/ss_baselines/av_nav/run.py \
  --exp-config /home/nino/ss-lit/configs/exp/av_nav_replica_ss2_ddppo.yaml \
  --model-dir "${MODEL_DIR}" \
  CONTINUOUS True
