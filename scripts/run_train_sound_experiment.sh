#!/usr/bin/env bash
set -euo pipefail

SOUND_RAW="${1:-}"
MODEL_DIR="${2:-}"
FRL_INDICES_RAW="${3:-${FRL_INDICES:-0,1,2,3}}"
CHECKPOINT_INTERVAL="${CHECKPOINT_INTERVAL:-50}"
TOTAL_UPDATES="${TOTAL_UPDATES:-40000}"

if [[ -z "${SOUND_RAW}" ]]; then
  echo "Usage: bash $0 <sound> [model_dir] [frl_indices_csv]"
  echo "sound in: telephone fireplace bowl birds1 birds2 engine_1 engine_2 impulse waves1 person_0 person_1 fan_1 plane bell (or birds -> birds1)"
  echo "example: bash $0 person_0 /home/nino/ss-lite/runs/exp_person_0_frl0123 0,1,2,3"
  exit 1
fi

if [[ "${SOUND_RAW}" == "birds" ]]; then
  SOUND="birds1"
else
  SOUND="${SOUND_RAW}"
fi

case "${SOUND}" in
  telephone|fireplace|bowl|birds1|birds2|engine_1|engine_2|impulse|waves1|person_0|person_1|fan_1|plane|bell) ;;
  *)
    echo "Unsupported sound: ${SOUND}"
    exit 1
    ;;
esac

IFS=',' read -r -a FRL_IDX_ARR <<< "${FRL_INDICES_RAW// /}"
if [[ "${#FRL_IDX_ARR[@]}" -eq 0 ]]; then
  echo "Empty frl indices: ${FRL_INDICES_RAW}"
  exit 1
fi

SCENE_TAG=""
SCENE_LIST=()
for idx in "${FRL_IDX_ARR[@]}"; do
  if [[ ! "${idx}" =~ ^[0-9]+$ ]]; then
    echo "Invalid frl index: ${idx}"
    exit 1
  fi
  SCENE_TAG+="${idx}"
  SCENE_LIST+=("\"frl_apartment_${idx}\"")
done
SCENES="[$(IFS=,; echo "${SCENE_LIST[*]}")]"
SCENE_LABEL="$(printf 'frl_apartment_%s-' "${FRL_IDX_ARR[@]}")"
SCENE_LABEL="${SCENE_LABEL%-}"

if [[ -z "${MODEL_DIR}" ]]; then
  MODEL_DIR="/home/nino/ss-lite/runs/exp_${SOUND}_frl${SCENE_TAG}"
fi

REPO_ROOT="/home/nino/ss-lite"
TRAIN_SPLIT="train_exp_${SOUND}_frl${SCENE_TAG}"
SPLIT_ROOT="/home/nino/ss-lite/data/datasets/audionav/replica/v1/${TRAIN_SPLIT}/${TRAIN_SPLIT}.json.gz"
if [[ ! -f "${SPLIT_ROOT}" ]]; then
  echo "Split not found: ${SPLIT_ROOT}"
  echo "Run: python /home/nino/ss-lite/scripts/prepare_sound_splits.py --sounds ${SOUND} --frl-indices ${FRL_INDICES_RAW}"
  exit 1
fi

cd "${REPO_ROOT}"
export WANDB_ENABLE="${WANDB_ENABLE:-1}"
export WANDB_ONLY="${WANDB_ONLY:-1}"
export WANDB_STRICT="${WANDB_STRICT:-1}"
export WANDB_ENTITY="${WANDB_ENTITY:-OpenMLRL}"
export WANDB_PROJECT="${WANDB_PROJECT:-ss-lite-ppo}"
RUN_SYNC_ID="${RUN_SYNC_ID:-$(date +%Y%m%d_%H%M%S)}"
export WANDB_RUN_GROUP="${WANDB_RUN_GROUP:-${RUN_SYNC_ID}}"
export WANDB_RUN_NAME="${WANDB_RUN_NAME_TRAIN:-train-${SOUND}-${SCENE_LABEL}-${RUN_SYNC_ID}}"
export WANDB_JOB_TYPE="train"

COMMON_OPTS=(
  CONTINUOUS True
  USE_VECENV False
  USE_SYNC_VECENV True
  TASK_CONFIG.DATASET.SCENES_DIR /home/nino/ss-lite/data/scene_datasets/replica
  TASK_CONFIG.DATASET.DATA_PATH /home/nino/ss-lite/data/datasets/audionav/replica/{version}/{split}/{split}.json.gz
  TASK_CONFIG.SIMULATOR.AUDIO.METADATA_DIR /home/nino/ss-lite/data/metadata
  TASK_CONFIG.SIMULATOR.AUDIO.SOURCE_SOUND_DIR /home/nino/ss-lite/data/sounds/1s_all
  TASK_CONFIG.SIMULATOR.AUDIO.MATERIALS_CONFIG_PATH /home/nino/ss-lite/data/material_config.json
  TASK_CONFIG.DATASET.SPLIT "${TRAIN_SPLIT}"
  TASK_CONFIG.DATASET.CONTENT_SCENES "${SCENES}"
)

PYTHONPATH=/home/nino/sound-spaces \
python /home/nino/sound-spaces/ss_baselines/av_nav/run.py \
  --exp-config /home/nino/ss-lite/configs/exp/av_nav_replica_ss2_ddppo.yaml \
  --model-dir "${MODEL_DIR}" \
  CHECKPOINT_INTERVAL "${CHECKPOINT_INTERVAL}" \
  NUM_UPDATES "${TOTAL_UPDATES}" \
  "${COMMON_OPTS[@]}"
