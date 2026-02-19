#!/usr/bin/env bash
set -euo pipefail

SOUNDS_CSV="${1:-person_0,person_1,fan_1,plane,bell,birds1,birds2,engine_1,engine_2,fireplace,waves1}"
FRL_INDICES="${2:-0,1,2,3}"
RUNS_ROOT="${3:-/home/nino/ss-lite/runs}"
MAX_JOBS="${MAX_JOBS:-2}"

IFS=',' read -r -a SOUNDS <<< "${SOUNDS_CSV// /}"
IFS=',' read -r -a ROOMS <<< "${FRL_INDICES// /}"

if [[ "${#ROOMS[@]}" -eq 0 ]]; then
  echo "Empty room indices: ${FRL_INDICES}"
  exit 1
fi

if [[ ! "${MAX_JOBS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "MAX_JOBS must be a positive integer, got: ${MAX_JOBS}"
  exit 1
fi

wait_for_slot() {
  while true; do
    running="$(jobs -pr | wc -l)"
    if [[ "${running}" -lt "${MAX_JOBS}" ]]; then
      break
    fi
    sleep 1
  done
}

declare -a PIDS=()
declare -a JOB_LABELS=()

for i in "${!SOUNDS[@]}"; do
  sound="${SOUNDS[$i]}"
  room="${ROOMS[$((i % ${#ROOMS[@]}))]}"
  room_csv="${room}"
  model_dir="${RUNS_ROOT}/exp_${sound}_frl${room}"
  echo "[train-batch] queue sound=${sound} room=frl_apartment_${room} model_dir=${model_dir}"
  python /home/nino/ss-lite/scripts/prepare_sound_splits.py --sounds "${sound}" --frl-indices "${room_csv}"
  wait_for_slot
  (
    echo "[train-batch] start sound=${sound} room=frl_apartment_${room}"
    set +e
    bash /home/nino/ss-lite/scripts/run_train_sound_experiment.sh "${sound}" "${model_dir}" "${room_csv}"
    rc=$?
    set -e
    if (( rc == 0 )); then
      echo "[train-batch] done sound=${sound} room=frl_apartment_${room} exit=${rc}"
    elif (( rc >= 128 )); then
      sig=$((rc - 128))
      echo "[train-batch] fail sound=${sound} room=frl_apartment_${room} exit=${rc} (signal=${sig})"
    else
      echo "[train-batch] fail sound=${sound} room=frl_apartment_${room} exit=${rc}"
    fi
    exit "${rc}"
  ) &
  pid=$!
  PIDS+=("${pid}")
  JOB_LABELS+=("sound=${sound} room=frl_apartment_${room} pid=${pid}")
  echo "[train-batch] spawned ${JOB_LABELS[-1]}"
done

failed=0
for i in "${!PIDS[@]}"; do
  pid="${PIDS[$i]}"
  label="${JOB_LABELS[$i]}"
  if wait "${pid}"; then
    echo "[train-batch] joined ${label} exit=0"
  else
    rc=$?
    ((failed += 1))
    if (( rc >= 128 )); then
      sig=$((rc - 128))
      echo "[train-batch] joined ${label} exit=${rc} (signal=${sig})"
    else
      echo "[train-batch] joined ${label} exit=${rc}"
    fi
  fi
done

if (( failed > 0 )); then
  echo "[train-batch] completed with failures: ${failed}/${#PIDS[@]}"
  exit 1
fi

echo "[train-batch] all jobs finished (${#PIDS[@]}/${#PIDS[@]} succeeded)"
