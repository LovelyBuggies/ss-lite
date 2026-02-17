# ss-lit: SoundSpaces 2.0 + Replica (minimal)

This repo is a minimal launcher for **SoundSpaces 2.0** realtime acoustic simulation with the **AV-Nav** baseline on **Replica**.

It reuses code from `/home/nino/sound-spaces` and keeps only the minimum local config/scripts here.

## What is included

- `configs/tasks/audiogoal_replica_ss2.yaml`
- `configs/exp/av_nav_replica_ss2_ddppo.yaml`
- `scripts/check_required_data.sh`
- `scripts/run_train_replica_ss2.sh`

## Minimum prerequisites

1. Habitat-Sim with audio support already works in your `ss` conda env.
2. `/home/nino/sound-spaces` exists (the main upstream repo).
3. You will place data under `/home/nino/ss-lit/data`.

## Data checklist (Replica only, no Matterport3D)

Required for training AV-Nav with realtime acoustic simulation:

1. Scene assets (Replica)
- Path needed:
  - `/home/nino/ss-lit/data/scene_datasets/replica`
  - `/home/nino/ss-lit/data/scene_datasets/replica/replica.scene_dataset_config.json`
- Meaning: 3D rooms and scene config used by the simulator.

2. AudioNav episode dataset (Replica)
- Path needed:
  - `/home/nino/ss-lit/data/datasets/audionav/replica/v1/train_telephone/train_telephone.json.gz`
- Meaning: training episodes (start, goal, sound id, scene, split).

3. Metadata (Replica)
- Path needed:
  - `/home/nino/ss-lit/data/metadata/replica`
- Meaning: graph/points used for navigation nodes and indexing.

4. Source sounds
- Path needed:
  - `/home/nino/ss-lit/data/sounds/1s_all`
- Meaning: dry source wav files that are convolved with realtime impulse responses.

5. Acoustic material mapping
- Path needed:
  - `/home/nino/ss-lit/data/mp3d_material_config.json`
- Meaning: absorption/reflection coefficients for realtime acoustic simulation.

Not required for this minimal SoundSpaces 2.0 run:

- `Matterport3D`
- pre-rendered `binaural_rirs`
- `scene_observations`

## Suggested commands to fetch minimum SoundSpaces side data

Run from `/home/nino/ss-lit`:

```bash
mkdir -p data
cd data

# Small files from SoundSpaces
wget http://dl.fbaipublicfiles.com/SoundSpaces/metadata.tar.xz
wget http://dl.fbaipublicfiles.com/SoundSpaces/datasets.tar.xz
wget http://dl.fbaipublicfiles.com/SoundSpaces/sounds.tar.xz

# Extract and keep Replica parts
tar xvf metadata.tar.xz
tar xvf datasets.tar.xz
tar xvf sounds.tar.xz

# Optional cleanup if mp3d folders were unpacked
rm -rf metadata/mp3d || true
rm -rf datasets/audionav/mp3d || true
rm -rf datasets/semantic_audionav/mp3d || true
```

Get material config:

```bash
cd /home/nino/ss-lit/data
wget https://raw.githubusercontent.com/facebookresearch/rlr-audio-propagation/main/RLRAudioPropagationPkg/data/mp3d_material_config.json
```

For Replica scene assets, follow Habitat-Sim dataset instructions and place outputs under:

- `/home/nino/ss-lit/data/scene_datasets/replica`

## Verify data

```bash
/home/nino/ss-lit/scripts/check_required_data.sh
```

## Train (AV-Nav, SoundSpaces 2.0 realtime, Replica)

```bash
conda activate ss
/home/nino/ss-lit/scripts/run_train_replica_ss2.sh
```

Optional: custom output directory

```bash
/home/nino/ss-lit/scripts/run_train_replica_ss2.sh /home/nino/ss-lit/runs/exp1
```

## Notes

- This setup uses `CONTINUOUS=True`, which switches to `ContinuousSoundSpacesSim` and realtime audio simulation.
- Launch script sets `PYTHONPATH=/home/nino/sound-spaces` so local upstream code is reused.
