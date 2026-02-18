#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/nino/ss-lite"
MODEL_DIR="${1:-/home/nino/ss-lite/runs/av_nav_replica_ss2}"
ENABLE_EVAL="${ENABLE_EVAL:-1}"
INITIAL_EVAL="${INITIAL_EVAL:-1}"
CHECKPOINT_INTERVAL="${CHECKPOINT_INTERVAL:-100}"
EVAL_INTERVAL_UPDATES="${EVAL_INTERVAL_UPDATES:-${CHECKPOINT_INTERVAL}}"
TRAIN_CHUNK_UPDATES="${TRAIN_CHUNK_UPDATES:-${EVAL_INTERVAL_UPDATES}}"
TOTAL_UPDATES="${TOTAL_UPDATES:-40000}"

if (( EVAL_INTERVAL_UPDATES <= 0 )); then
  echo "EVAL_INTERVAL_UPDATES must be > 0"
  exit 1
fi
if (( CHECKPOINT_INTERVAL <= 0 )); then
  echo "CHECKPOINT_INTERVAL must be > 0"
  exit 1
fi
if (( EVAL_INTERVAL_UPDATES % CHECKPOINT_INTERVAL != 0 )); then
  echo "EVAL_INTERVAL_UPDATES (${EVAL_INTERVAL_UPDATES}) must be a multiple of CHECKPOINT_INTERVAL (${CHECKPOINT_INTERVAL})"
  exit 1
fi
if (( TRAIN_CHUNK_UPDATES <= 0 )); then
  echo "TRAIN_CHUNK_UPDATES must be > 0"
  exit 1
fi
if (( TRAIN_CHUNK_UPDATES % CHECKPOINT_INTERVAL != 0 )); then
  echo "TRAIN_CHUNK_UPDATES (${TRAIN_CHUNK_UPDATES}) must be a multiple of CHECKPOINT_INTERVAL (${CHECKPOINT_INTERVAL})"
  exit 1
fi
if (( TOTAL_UPDATES <= 0 )); then
  echo "TOTAL_UPDATES must be > 0"
  exit 1
fi

cd "${REPO_ROOT}"
export WANDB_ENABLE="${WANDB_ENABLE:-1}"
export WANDB_ONLY="${WANDB_ONLY:-1}"
export WANDB_STRICT="${WANDB_STRICT:-1}"
export WANDB_ENTITY="${WANDB_ENTITY:-OpenMLRL}"
export WANDB_PROJECT="${WANDB_PROJECT:-ss-lite}"
RUN_SYNC_ID="${RUN_SYNC_ID:-$(date +%Y%m%d_%H%M%S)}"
export WANDB_RUN_GROUP="${WANDB_RUN_GROUP:-${RUN_SYNC_ID}}"
echo "[ss-lite] RUN_SYNC_ID=${RUN_SYNC_ID} WANDB_RUN_GROUP=${WANDB_RUN_GROUP}"
echo "[ss-lite] CHECKPOINT_INTERVAL=${CHECKPOINT_INTERVAL} EVAL_INTERVAL_UPDATES=${EVAL_INTERVAL_UPDATES} TRAIN_CHUNK_UPDATES=${TRAIN_CHUNK_UPDATES} TOTAL_UPDATES=${TOTAL_UPDATES}"

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
  TASK_CONFIG.ENVIRONMENT.ITERATOR_OPTIONS.SHUFFLE False
  TASK_CONFIG.ENVIRONMENT.ITERATOR_OPTIONS.MAX_SCENE_REPEAT_EPISODES 1
)

CKPT_DIR="${MODEL_DIR}/data"
mkdir -p "${CKPT_DIR}"

get_latest_ckpt_meta() {
  python - "${MODEL_DIR}" <<'PY'
import glob
import os
import sys
import torch

model_dir = sys.argv[1]
ckpt_dir = os.path.join(model_dir, "data")
paths = glob.glob(os.path.join(ckpt_dir, "ckpt.*.pth"))

if len(paths) == 0:
    print("|||")
    raise SystemExit(0)

def ckpt_idx(path):
    return int(os.path.basename(path).split(".")[1])

latest = sorted(paths, key=ckpt_idx)[-1]
idx = ckpt_idx(latest)
update = idx

try:
    ckpt = torch.load(latest, map_location="cpu", weights_only=False)
    extra_state = ckpt.get("extra_state", {})
    if "update" in extra_state:
        update = int(extra_state["update"])
    else:
        cfg = ckpt.get("config", None)
        interval = int(getattr(cfg, "CHECKPOINT_INTERVAL", 1))
        update = interval * idx
except Exception:
    pass

print(f"{latest}|{idx}|{update}")
PY
}

run_eval_for_ckpt() {
  local ckpt_path="$1"
  local ckpt_idx="$2"
  if [[ "${ENABLE_EVAL}" != "1" ]]; then
    return
  fi
  export WANDB_RUN_NAME="${WANDB_RUN_NAME_EVAL:-replica-ss2-eval-${RUN_SYNC_ID}-ckpt${ckpt_idx}}"
  export WANDB_JOB_TYPE="eval"
  PYTHONPATH=/home/nino/sound-spaces \
  python /home/nino/sound-spaces/ss_baselines/av_nav/run.py \
    --run-type eval \
    --exp-config /home/nino/ss-lite/configs/exp/av_nav_replica_ss2_eval.yaml \
    --model-dir "${MODEL_DIR}" \
    EVAL_CKPT_PATH_DIR "${ckpt_path}" \
    "${COMMON_OPTS[@]}" \
    "${EVAL_ONLY_OPTS[@]}"
}

run_train_chunk() {
  local chunk_updates="$1"
  export WANDB_RUN_NAME="${WANDB_RUN_NAME_TRAIN:-replica-ss2-train-${RUN_SYNC_ID}}"
  export WANDB_JOB_TYPE="train"
  SS_TRAIN_CHUNK_UPDATES="${chunk_updates}" \
  PYTHONPATH=/home/nino/sound-spaces \
  python /home/nino/sound-spaces/ss_baselines/av_nav/run.py \
    --exp-config /home/nino/ss-lite/configs/exp/av_nav_replica_ss2_ddppo.yaml \
    --model-dir "${MODEL_DIR}" \
    CHECKPOINT_INTERVAL "${CHECKPOINT_INTERVAL}" \
    NUM_UPDATES "${TOTAL_UPDATES}" \
    "${COMMON_OPTS[@]}"
}

last_eval_idx=-1
meta="$(get_latest_ckpt_meta)"
IFS='|' read -r latest_ckpt_path latest_ckpt_idx latest_update <<< "${meta}"

if [[ "${INITIAL_EVAL}" == "1" && "${ENABLE_EVAL}" == "1" && -n "${latest_ckpt_path}" ]]; then
  echo "[ss-lite] Initial eval on existing checkpoint idx=${latest_ckpt_idx}"
  run_eval_for_ckpt "${latest_ckpt_path}" "${latest_ckpt_idx}"
  last_eval_idx="${latest_ckpt_idx}"
fi

while true; do
  meta="$(get_latest_ckpt_meta)"
  IFS='|' read -r latest_ckpt_path latest_ckpt_idx latest_update <<< "${meta}"
  if [[ -n "${latest_update}" ]] && (( latest_update >= TOTAL_UPDATES - 1 )); then
    echo "[ss-lite] Training target reached at update=${latest_update}. Exiting."
    break
  fi

  echo "[ss-lite] Train chunk start: chunk_updates=${TRAIN_CHUNK_UPDATES}"
  run_train_chunk "${TRAIN_CHUNK_UPDATES}"

  new_meta="$(get_latest_ckpt_meta)"
  IFS='|' read -r new_ckpt_path new_ckpt_idx new_update <<< "${new_meta}"
  if [[ -z "${new_ckpt_path}" ]]; then
    echo "[ss-lite] ERROR: no checkpoint produced."
    exit 1
  fi
  echo "[ss-lite] Train chunk done: latest_ckpt_idx=${new_ckpt_idx} update=${new_update}"

  if [[ "${ENABLE_EVAL}" == "1" ]]; then
    if [[ "${new_ckpt_idx}" != "${last_eval_idx}" ]]; then
      run_eval_for_ckpt "${new_ckpt_path}" "${new_ckpt_idx}"
      last_eval_idx="${new_ckpt_idx}"
    else
      echo "[ss-lite] Skip eval: latest checkpoint unchanged (idx=${new_ckpt_idx})"
    fi
  fi
done
