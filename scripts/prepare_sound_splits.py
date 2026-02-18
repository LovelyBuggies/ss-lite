#!/usr/bin/env python3
import argparse
import gzip
import json
import random
from pathlib import Path


DEFAULT_SOUNDS = [
    "telephone",
    "fireplace",
    "bowl",
    "birds1",
    "birds2",
    "engine_1",
    "engine_2",
    "impulse",
    "waves1",
    "person_0",
    "person_1",
    "fan_1",
    "plane",
    "bell",
]
VERSION = "v1"


def load_json_gz(path: Path):
    with gzip.open(path, "rt") as f:
        return json.load(f)


def dump_json_gz(path: Path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(path, "wt") as f:
        json.dump(obj, f)


def split_episodes(episodes, val_ratio: float, seed: int):
    episodes = list(episodes)
    rng = random.Random(seed)
    rng.shuffle(episodes)
    if len(episodes) <= 1:
        return episodes, []
    val_n = max(1, int(len(episodes) * val_ratio))
    val_n = min(val_n, len(episodes) - 1)
    val_eps = episodes[:val_n]
    train_eps = episodes[val_n:]
    return train_eps, val_eps


def source_split_for_sound(sound: str) -> str:
    return "train_telephone" if sound == "telephone" else "train_multiple"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-dir", default="/home/nino/ss-lite/data/datasets/audionav/replica/v1")
    parser.add_argument("--val-ratio", type=float, default=0.1)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument(
        "--sounds",
        default=",".join(DEFAULT_SOUNDS),
        help="comma-separated sounds (e.g. telephone,fireplace,birds1)",
    )
    parser.add_argument(
        "--frl-indices",
        default="0,1,2,3",
        help="comma-separated frl apartment indices (e.g. 0,1,2,3)",
    )
    args = parser.parse_args()

    base_dir = Path(args.base_dir)
    sounds = [s.strip() for s in args.sounds.split(",") if s.strip()]
    scene_indices = [int(x.strip()) for x in args.frl_indices.split(",") if x.strip()]
    scenes = [f"frl_apartment_{i}" for i in scene_indices]
    summary = []

    for sound in sounds:
        src_split = source_split_for_sound(sound)
        src_content_dir = base_dir / src_split / "content"
        scene_tag = "".join(str(i) for i in scene_indices)
        train_split = f"train_exp_{sound}_frl{scene_tag}"
        val_split = f"val_exp_{sound}_frl{scene_tag}"
        train_content_dir = base_dir / train_split / "content"
        val_content_dir = base_dir / val_split / "content"

        train_total = 0
        val_total = 0

        for idx, scene in enumerate(scenes):
            src_path = src_content_dir / f"{scene}.json.gz"
            if not src_path.exists():
                raise FileNotFoundError(f"Missing source scene file: {src_path}")

            scene_data = load_json_gz(src_path)
            episodes = scene_data.get("episodes", [])
            matched = [
                ep
                for ep in episodes
                if isinstance(ep, dict)
                and isinstance(ep.get("info"), dict)
                and ep["info"].get("sound") == sound
            ]
            tr_eps, va_eps = split_episodes(matched, args.val_ratio, args.seed + idx)
            train_total += len(tr_eps)
            val_total += len(va_eps)

            dump_json_gz(train_content_dir / f"{scene}.json.gz", {"episodes": tr_eps})
            dump_json_gz(val_content_dir / f"{scene}.json.gz", {"episodes": va_eps})

        root_template = {"episodes": [], "content_scenes_path": "{data_path}/content/{scene}.json.gz"}
        dump_json_gz(base_dir / train_split / f"{train_split}.json.gz", root_template)
        dump_json_gz(base_dir / val_split / f"{val_split}.json.gz", root_template)

        summary.append((sound, train_split, train_total, val_split, val_total))

    print("Prepared splits:")
    for sound, tr, tr_n, va, va_n in summary:
        print(f"- {sound}: {tr} ({tr_n} eps), {va} ({va_n} eps)")


if __name__ == "__main__":
    main()
