#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="/home/nino/ss-lite"
MODEL_DIR="${1:-/home/nino/ss-lite/runs/av_nav_replica_ss2}"

cd "${REPO_ROOT}"
export WANDB_ENABLE="${WANDB_ENABLE:-1}"
export WANDB_ONLY="${WANDB_ONLY:-1}"
export WANDB_STRICT="${WANDB_STRICT:-1}"
export WANDB_ENTITY="${WANDB_ENTITY:-OpenMLRL}"
export WANDB_PROJECT="${WANDB_PROJECT:-ss-lite}"

PYTHONPATH=/home/nino/sound-spaces \
python /home/nino/sound-spaces/ss_baselines/av_nav/run.py \
  --exp-config /home/nino/ss-lite/configs/exp/av_nav_replica_ss2_ddppo.yaml \
  --model-dir "${MODEL_DIR}" \
  CONTINUOUS True \
  USE_VECENV False \
  USE_SYNC_VECENV True \
  TASK_CONFIG.DATASET.SCENES_DIR /home/nino/ss-lite/data/scene_datasets/replica \
  TASK_CONFIG.DATASET.DATA_PATH /home/nino/ss-lite/data/datasets/audionav/replica/{version}/{split}/{split}.json.gz \
  TASK_CONFIG.SIMULATOR.AUDIO.METADATA_DIR /home/nino/ss-lite/data/metadata \
  TASK_CONFIG.SIMULATOR.AUDIO.SOURCE_SOUND_DIR /home/nino/ss-lite/data/sounds/1s_all \
  TASK_CONFIG.SIMULATOR.AUDIO.MATERIALS_CONFIG_PATH /home/nino/ss-lite/data/material_config.json
