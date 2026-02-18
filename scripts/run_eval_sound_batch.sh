#!/usr/bin/env bash
set -euo pipefail

SOUNDS_CSV="${1:-person_0,person_1,fan_1,plane,bell,birds1,birds2,engine_1,engine_2,fireplace,waves1}"
FRL_INDICES="${2:-0,1,2,3}"
RUNS_ROOT="${3:-/home/nino/ss-lite/runs}"

IFS=',' read -r -a SOUNDS <<< "${SOUNDS_CSV// /}"
IFS=',' read -r -a ROOMS <<< "${FRL_INDICES// /}"

if [[ "${#ROOMS[@]}" -eq 0 ]]; then
  echo "Empty room indices: ${FRL_INDICES}"
  exit 1
fi

for i in "${!SOUNDS[@]}"; do
  sound="${SOUNDS[$i]}"
  room="${ROOMS[$((i % ${#ROOMS[@]}))]}"
  room_csv="${room}"
  model_dir="${RUNS_ROOT}/exp_${sound}_frl${room}"
  echo "[eval-batch] sound=${sound} room=frl_apartment_${room} model_dir=${model_dir}"
  python /home/nino/ss-lite/scripts/prepare_sound_splits.py --sounds "${sound}" --frl-indices "${room_csv}"
  bash /home/nino/ss-lite/scripts/run_eval_sound_experiment.sh "${sound}" "${model_dir}" "" "${room_csv}"
done
