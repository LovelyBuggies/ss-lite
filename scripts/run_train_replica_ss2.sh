#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/nino/ss-lite"
MODEL_DIR="${1:-/home/nino/ss-lite/runs/av_nav_replica_ss2}"
ENABLE_EVAL="${ENABLE_EVAL:-1}"
INITIAL_EVAL="${INITIAL_EVAL:-1}"
CHECKPOINT_INTERVAL="${CHECKPOINT_INTERVAL:-50}"
EVAL_INTERVAL_UPDATES="${EVAL_INTERVAL_UPDATES:-${CHECKPOINT_INTERVAL}}"

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
EVAL_INTERVAL_CKPTS=$(( EVAL_INTERVAL_UPDATES / CHECKPOINT_INTERVAL ))

kill_proc_tree() {
  local pid="$1"
  local child
  for child in $(pgrep -P "${pid}" 2>/dev/null || true); do
    kill_proc_tree "${child}"
  done
  kill -TERM "${pid}" 2>/dev/null || true
}

cleanup() {
  local code=$?
  if [[ -n "${EVAL_PID:-}" ]]; then
    kill_proc_tree "${EVAL_PID}"
    sleep 0.5
    kill -KILL "${EVAL_PID}" 2>/dev/null || true
  fi
  wait 2>/dev/null || true
  exit $code
}

trap cleanup INT TERM EXIT

cd "${REPO_ROOT}"
export WANDB_ENABLE="${WANDB_ENABLE:-1}"
export WANDB_ONLY="${WANDB_ONLY:-1}"
export WANDB_STRICT="${WANDB_STRICT:-1}"
export WANDB_ENTITY="${WANDB_ENTITY:-OpenMLRL}"
export WANDB_PROJECT="${WANDB_PROJECT:-ss-lite}"
RUN_SYNC_ID="${RUN_SYNC_ID:-$(date +%Y%m%d_%H%M%S)}"
export WANDB_RUN_GROUP="${WANDB_RUN_GROUP:-${RUN_SYNC_ID}}"
echo "[ss-lite] RUN_SYNC_ID=${RUN_SYNC_ID} WANDB_RUN_GROUP=${WANDB_RUN_GROUP}"

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

if [[ "${ENABLE_EVAL}" == "1" ]]; then
  PREV_CKPT_IND=-1
  CKPT_DIR="${MODEL_DIR}/data"
  mkdir -p "${CKPT_DIR}"

  mapfile -t EXISTING_CKPTS < <(find "${CKPT_DIR}" -maxdepth 1 -type f -name 'ckpt.*.pth' | sort -V)
  if (( ${#EXISTING_CKPTS[@]} > 0 )); then
    PREV_CKPT_IND=$(( ${#EXISTING_CKPTS[@]} - 1 ))
    if [[ "${INITIAL_EVAL}" == "1" ]]; then
      # Let the watcher evaluate the latest existing checkpoint first,
      # instead of launching a separate one-off eval process/run.
      PREV_CKPT_IND=$(( PREV_CKPT_IND - 1 ))
    fi
  fi

  export WANDB_RUN_NAME="${WANDB_RUN_NAME_EVAL:-replica-ss2-eval-${RUN_SYNC_ID}}"
  export WANDB_JOB_TYPE="eval"
  PYTHONPATH=/home/nino/sound-spaces \
  python /home/nino/sound-spaces/ss_baselines/av_nav/run.py \
    --run-type eval \
    --eval-interval "${EVAL_INTERVAL_CKPTS}" \
    --prev-ckpt-ind "${PREV_CKPT_IND}" \
    --exp-config /home/nino/ss-lite/configs/exp/av_nav_replica_ss2_eval.yaml \
    --model-dir "${MODEL_DIR}" \
    "${COMMON_OPTS[@]}" &
  EVAL_PID=$!
fi

export WANDB_RUN_NAME="${WANDB_RUN_NAME_TRAIN:-replica-ss2-train-${RUN_SYNC_ID}}"
export WANDB_JOB_TYPE="train"
PYTHONPATH=/home/nino/sound-spaces \
python /home/nino/sound-spaces/ss_baselines/av_nav/run.py \
  --exp-config /home/nino/ss-lite/configs/exp/av_nav_replica_ss2_ddppo.yaml \
  --model-dir "${MODEL_DIR}" \
  CHECKPOINT_INTERVAL "${CHECKPOINT_INTERVAL}" \
  "${COMMON_OPTS[@]}"
