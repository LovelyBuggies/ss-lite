# ss-lite: SoundSpaces 2.0 + Replica Minimal Setup

This repository provides a minimal training setup for running **AV-Nav** with **SoundSpaces 2.0 realtime acoustic simulation** on **Replica**.

It reuses code from `/home/nino/sound-spaces`; this repo only keeps minimal configs and scripts.

## Prerequisites

- System tools available: `wget`, `unzip`, `gzip` (or `pigz`).
- `habitat-sim` with audio support is already installed and working in your `ss` conda environment.
- Upstream repo exists at `/home/nino/sound-spaces`.

## Quick Start

### 1) Download all required data

```bash
set -euo pipefail

cd /home/nino/ss-lite
mkdir -p data

# SoundSpaces task data
cd /home/nino/ss-lite/data
wget -c http://dl.fbaipublicfiles.com/SoundSpaces/metadata.tar.xz
wget -c http://dl.fbaipublicfiles.com/SoundSpaces/datasets.tar.xz
wget -c http://dl.fbaipublicfiles.com/SoundSpaces/sounds.tar.xz

# Unzip
tar xvf metadata.tar.xz
tar xvf datasets.tar.xz
tar xvf sounds.tar.xz

wget -c https://raw.githubusercontent.com/facebookresearch/rlr-audio-propagation/main/RLRAudioPropagationPkg/data/mp3d_material_config.json -O material_config.json

# Replica scene assets
cd /home/nino/ss-lite/data/scene_datasets
wget -c https://raw.githubusercontent.com/facebookresearch/Replica-Dataset/main/download.sh -O download_replica.sh
chmod +x download_replica.sh
mkdir -p assets
./download_replica.sh /home/nino/ss-lite/data/scene_datasets/replica
```

### 2) Remove optional data

```bash
cd /home/nino/ss-lite/data
rm -rf metadata/mp3d || true
rm -rf datasets/audionav/mp3d || true
rm -rf datasets/semantic_audionav/mp3d || true
```

### 3) Validate and train (auto-eval enabled by default)

```bash
conda activate ss
python -m pip install wandb
wandb login
/home/nino/ss-lite/scripts/check_required_data.sh
/home/nino/ss-lite/scripts/run_train_replica_ss2.sh
```

By default, training logs are sent to Weights & Biases under:

- `entity`: `OpenMLRL`
- `project`: `ss-lite`
- `WANDB_ONLY`: `1`
- `WANDB_STRICT`: `1` (stop training immediately if W&B init fails)
- All scalar/image/video logs are routed to W&B.
- Runs are grouped by `WANDB_RUN_GROUP` (default: model dir name), with job types `train` and `eval`.

You can override them at runtime:

```bash
WANDB_ONLY=1 WANDB_ENTITY=OpenMLRL WANDB_PROJECT=ss-lite bash /home/nino/ss-lite/scripts/run_train_replica_ss2.sh
```

Eval control flags in the same entrypoint:

```bash
# disable eval watcher
ENABLE_EVAL=0 bash /home/nino/ss-lite/scripts/run_train_replica_ss2.sh

# run one initial eval before training if checkpoints already exist (default)
INITIAL_EVAL=1 bash /home/nino/ss-lite/scripts/run_train_replica_ss2.sh

# checkpoint cadence (unit: updates)
CHECKPOINT_INTERVAL=50 bash /home/nino/ss-lite/scripts/run_train_replica_ss2.sh

# eval cadence (unit: updates, default equals CHECKPOINT_INTERVAL)
EVAL_INTERVAL_UPDATES=50 bash /home/nino/ss-lite/scripts/run_train_replica_ss2.sh
```

`EVAL_INTERVAL_UPDATES` and `CHECKPOINT_INTERVAL` now use the same unit (`updates`).
`EVAL_INTERVAL_UPDATES` must be an integer multiple of `CHECKPOINT_INTERVAL`.
If previous checkpoints exist, `INITIAL_EVAL=1` evaluates the latest checkpoint once before new training starts.

### 4) Expected directory structure

```text
/home/nino/ss-lite/
├── configs/
│   ├── exp/av_nav_replica_ss2_ddppo.yaml
│   └── tasks/audiogoal_replica_ss2.yaml
├── scripts/
│   ├── check_required_data.sh
│   └── run_train_replica_ss2.sh
└── data/
    ├── material_config.json
    ├── metadata/
    │   └── replica/
    ├── datasets/
    │   └── audionav/replica/v1/train_telephone/train_telephone.json.gz
    ├── sounds/
    │   └── 1s_all/
    └── scene_datasets/
        └── replica/
            └── replica.scene_dataset_config.json
```

## Data

- `scene_datasets/replica/*`: Replica scene assets (geometry and semantics) used to load and render environments.
- `scene_datasets/replica/replica.scene_dataset_config.json`: Replica scene dataset config used by the simulator.
- `datasets/audionav/replica/v1/train_telephone/train_telephone.json.gz`: AudioNav training episodes (start, goal, scene, sound, etc.).
- `metadata/replica/*`: navigation metadata (`points` and graph) used for indexing and graph-based navigation.
- `sounds/1s_all/*.wav`: dry source sounds used to synthesize observations via convolution with impulse responses.
- `material_config.json`: acoustic material mapping (absorption/reflection coefficients) used by realtime acoustic simulation.

## Notes

- This setup uses `CONTINUOUS=True`, which switches to `ContinuousSoundSpacesSim` and enables realtime acoustic simulation.
- The launch script sets `PYTHONPATH=/home/nino/sound-spaces` to reuse upstream code.

## W&B Metrics

- `Environment/Reward`: average episode return over recently finished episodes in the training window.
- `Environment/SPL`: average Success weighted by Path Length during training (navigation efficiency with success).
- `Environment/Episode_length`: average episode length (steps) for recently finished training episodes.
- `Policy/Value_Loss`: critic/value loss from PPO update.
- `Policy/Action_Loss`: policy loss from PPO update.
- `Policy/Entropy`: policy entropy (higher means more exploration).
- `Policy/Learning_Rate`: current optimizer learning rate.
- `val/reward` (or `{split}/reward`): mean episode return on evaluation split.
- `val/{metric}` (or `{split}/{metric}`): mean evaluation metric for each task measure (for example `spl`, `soft_spl`, `success`, etc., depending on task config).

Logging cadence:

- Training scalars are emitted every 10 updates.
- With your current setup (`NUM_PROCESSES=1`, `num_steps=150`), one update is 150 env steps.
- Training scalar `step` on W&B corresponds to collected env frames (`count_steps`).
- Evaluation scalars use checkpoint index as `step`.

Media logging:

- Evaluation videos are uploaded by the built-in eval watcher in `run_train_replica_ss2.sh` via `configs/exp/av_nav_replica_ss2_eval.yaml` (`VIDEO_OPTION: ["wandb"]`).
- Video keys include checkpoint index (for example `ckpt_3/...`), so each video can be traced to a specific checkpoint evaluation.
