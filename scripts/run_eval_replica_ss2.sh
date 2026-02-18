#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/nino/ss-lite"
MODEL_DIR="${1:-/home/nino/ss-lite/runs/av_nav_replica_ss2}"
CKPT_PATH="${2:-}"

cd "${REPO_ROOT}"
export WANDB_ENABLE="${WANDB_ENABLE:-1}"
export WANDB_ONLY="${WANDB_ONLY:-1}"
export WANDB_STRICT="${WANDB_STRICT:-1}"
export WANDB_ENTITY="${WANDB_ENTITY:-OpenMLRL}"
export WANDB_PROJECT="${WANDB_PROJECT:-ss-lite-ppo}"
RUN_SYNC_ID="${RUN_SYNC_ID:-$(date +%Y%m%d_%H%M%S)}"
export WANDB_RUN_GROUP="${WANDB_RUN_GROUP:-${RUN_SYNC_ID}}"

if [[ -z "${CKPT_PATH}" ]]; then
  CKPT_PATH="$(python - "${MODEL_DIR}" <<'PY'
import glob
import os
import sys

model_dir = sys.argv[1]
paths = glob.glob(os.path.join(model_dir, "data", "ckpt.*.pth"))
if len(paths) == 0:
    raise SystemExit(1)
paths = sorted(paths, key=lambda p: int(os.path.basename(p).split(".")[1]))
print(paths[-1])
PY
)"
fi

if [[ ! -f "${CKPT_PATH}" ]]; then
  echo "Checkpoint not found: ${CKPT_PATH}"
  exit 1
fi

CKPT_BASENAME="$(basename "${CKPT_PATH}")"
export WANDB_RUN_NAME="${WANDB_RUN_NAME_EVAL:-replica-ss2-eval-${RUN_SYNC_ID}-${CKPT_BASENAME}}"
export WANDB_JOB_TYPE="eval"
echo "[ss-lite] RUN_SYNC_ID=${RUN_SYNC_ID} WANDB_RUN_GROUP=${WANDB_RUN_GROUP} CKPT=${CKPT_PATH}"

COMMON_OPTS=(
  CONTINUOUS True
  USE_VECENV False
  USE_SYNC_VECENV True
  TASK_CONFIG.DATASET.SCENES_DIR /home/nino/ss-lite/data/scene_datasets/replica
  TASK_CONFIG.DATASET.DATA_PATH /home/nino/ss-lite/data/datasets/audionav/replica/{version}/{split}/{split}.json.gz
  TASK_CONFIG.SIMULATOR.AUDIO.METADATA_DIR /home/nino/ss-lite/data/metadata
  TASK_CONFIG.SIMULATOR.AUDIO.SOURCE_SOUND_DIR /home/nino/ss-lite/data/sounds/1s_all
  TASK_CONFIG.SIMULATOR.AUDIO.MATERIALS_CONFIG_PATH /home/nino/ss-lite/data/material_config.json
)

EVAL_ONLY_OPTS=(
  TASK_CONFIG.DATASET.CONTENT_SCENES "[\"*\"]"
  TASK_CONFIG.ENVIRONMENT.ITERATOR_OPTIONS.SHUFFLE False
  TASK_CONFIG.ENVIRONMENT.ITERATOR_OPTIONS.MAX_SCENE_REPEAT_EPISODES 1
)

PYTHONPATH=/home/nino/sound-spaces \
python /home/nino/sound-spaces/ss_baselines/av_nav/run.py \
  --run-type eval \
  --exp-config /home/nino/ss-lite/configs/exp/av_nav_replica_ss2_eval.yaml \
  --model-dir "${MODEL_DIR}" \
  EVAL_CKPT_PATH_DIR "${CKPT_PATH}" \
  "${COMMON_OPTS[@]}" \
  "${EVAL_ONLY_OPTS[@]}"
