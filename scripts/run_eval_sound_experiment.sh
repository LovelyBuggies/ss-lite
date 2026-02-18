#!/usr/bin/env bash
set -euo pipefail

SOUND_RAW="${1:-}"
MODEL_DIR="${2:-}"
CKPT_PATH="${3:-}"
FRL_INDICES_RAW="${4:-${FRL_INDICES:-0,1,2,3}}"

if [[ -z "${SOUND_RAW}" ]]; then
  echo "Usage: bash $0 <sound> [model_dir] [ckpt_path] [frl_indices_csv]"
  echo "sound in: telephone fireplace bowl birds1 birds2 engine_1 engine_2 impulse waves1 person_0 person_1 fan_1 plane bell (or birds -> birds1)"
  echo "example: bash $0 person_0 /home/nino/ss-lite/runs/exp_person_0_frl0123 '' 0,1,2,3"
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

VAL_SPLIT="val_exp_${SOUND}_frl${SCENE_TAG}"
SPLIT_ROOT="/home/nino/ss-lite/data/datasets/audionav/replica/v1/${VAL_SPLIT}/${VAL_SPLIT}.json.gz"
if [[ ! -f "${SPLIT_ROOT}" ]]; then
  echo "Split not found: ${SPLIT_ROOT}"
  echo "Run: python /home/nino/ss-lite/scripts/prepare_sound_splits.py --sounds ${SOUND} --frl-indices ${FRL_INDICES_RAW}"
  exit 1
fi

export WANDB_RUN_NAME_EVAL="${WANDB_RUN_NAME_EVAL:-eval-${SOUND}-${SCENE_LABEL}}"

EVAL_SPLIT="${VAL_SPLIT}" \
EVAL_CONTENT_SCENES="${SCENES}" \
bash /home/nino/ss-lite/scripts/run_eval_replica_ss2.sh "${MODEL_DIR}" "${CKPT_PATH}"
