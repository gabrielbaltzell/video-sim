import argparse
import json
import subprocess
import os
import random
import re

GODOT_BIN = os.environ.get("GODOT_BIN", "godot")
FFMPEG_BIN = os.environ.get("FFMPEG_BIN", "ffmpeg")
FFPROBE_BIN = os.environ.get("FFPROBE_BIN", "ffprobe")
PROJECT_PATH = "."
OUTPUT_DIR = "output"

COVERS_COUNT = 10
COVERS_SUBDIR = "covers"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Batch-render clips from a video-sim config JSON via headless Godot."
    )
    parser.add_argument(
        "config",
        help="Path to the batch config JSON (e.g. JSONs/test.json)",
    )
    parser.add_argument(
        "--keep-avi",
        action="store_true",
        help="Keep the intermediate .avi after converting it to .mp4 (default: delete it)",
    )
    return parser.parse_args()


def convert_to_mp4(avi_path, mp4_path):
    """Converts a Godot .avi render to H.264/AAC .mp4 with ffmpeg.
    Returns True on success, False otherwise. Does not raise when
    ffmpeg itself is missing -- the caller handles that as a skipped
    conversion."""
    cmd = [
        FFMPEG_BIN, "-y", "-i", avi_path,
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "medium",
        "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart",
        mp4_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.returncode == 0


def sanitize_filename(name):
    """Replaces characters that are invalid in filenames with '_'."""
    return re.sub(r'[\\/:*?"<>|]', "_", name)


def get_clip_duration_seconds(clip, mp4_path):
    """Real clip duration from ffprobe, falling back to the config's
    'duration' field if ffprobe isn't available. Returns None if neither
    can be determined."""
    try:
        result = subprocess.run(
            [FFPROBE_BIN, "-v", "error", "-show_entries", "format=duration",
             "-of", "default=noprint_wrappers=1:nokey=1", mp4_path],
            capture_output=True, text=True,
        )
        if result.returncode == 0 and result.stdout.strip():
            return float(result.stdout.strip())
    except FileNotFoundError:
        pass
    raw_duration = clip.get("duration")
    if raw_duration is not None:
        try:
            return float(raw_duration)
        except (TypeError, ValueError):
            pass
    return None


def extract_covers(clip, mp4_path, covers_dir):
    """Captures COVERS_COUNT PNG frames from the clip at deterministic
    (seed-driven) random timestamps into covers_dir. Returns True if all
    covers were written."""
    duration = get_clip_duration_seconds(clip, mp4_path)
    if duration is None or duration <= 0:
        print(f"  WARNING: could not determine clip duration — covers skipped for {clip['output']}")
        return False

    rng = random.Random(clip.get("seed"))
    lo, hi = duration * 0.02, duration * 0.98
    times = sorted(round(rng.uniform(lo, hi), 3) for _ in range(COVERS_COUNT))

    os.makedirs(covers_dir, exist_ok=True)
    for i, t in enumerate(times, start=1):
        cover_path = os.path.join(covers_dir, f"cover_{i:02d}.png")
        cmd = [FFMPEG_BIN, "-y", "-ss", str(t), "-i", mp4_path,
               "-frames:v", "1", cover_path]
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
        except FileNotFoundError:
            print(f"  WARNING: ffmpeg not found (checked '{FFMPEG_BIN}') — covers skipped for {clip['output']}")
            return False
        if result.returncode != 0:
            print(f"  WARNING: cover {i} failed for {clip['output']} — covers skipped")
            return False
    return True


def main():
    args = parse_args()
    config_path = args.config

    with open(config_path) as f:
        clips = json.load(f)

    os.makedirs(OUTPUT_DIR, exist_ok=True)  # Godot won't create this for you

    # Clips without a seed get one generated and written back into the
    # config file, so Godot renders with the same seed that names the
    # project folder / drives the covers.
    seeds_added = False
    for clip in clips:
        if "seed" not in clip:
            clip["seed"] = random.randrange(0, 1_000_000)
            seeds_added = True
    if seeds_added:
        with open(config_path, "w") as f:
            json.dump(clips, f, indent=2)
            f.write("\n")

    for i, clip in enumerate(clips):
        song = clip.get("song", "song")
        seed = clip["seed"]
        project_dir = os.path.join(OUTPUT_DIR, sanitize_filename(f"{song}_seed_{seed}"))
        covers_dir = os.path.join(project_dir, COVERS_SUBDIR)
        os.makedirs(project_dir, exist_ok=True)
        os.makedirs(covers_dir, exist_ok=True)

        notes_path = os.path.join(project_dir, "notes.txt")
        with open(notes_path, "w") as f:
            json.dump(clip, f, indent=2)
            f.write("\n")

        clip_name = clip["output"]
        avi_path = os.path.join(project_dir, clip_name + ".avi")
        mp4_path = os.path.join(project_dir, clip_name + ".mp4")
        # duration is NOT passed as a cmdline flag -- VideoConfig.load_clip()
        # on the Godot side reads it straight out of the clip's JSON entry
        # (config_path + index is enough to find it there). Passing it here
        # too would be redundant, and clip.get("duration", "") produced a
        # bare `--duration ""` for any clip that omitted the key, which
        # VideoConfig would then try to float("") and crash on.
        cmd = [
            GODOT_BIN, "--path", PROJECT_PATH,
            "--write-movie", avi_path,
            "--", "--config", config_path, "--index", str(i),
        ]
        print(f"Rendering clip {i + 1}/{len(clips)}: {clip['output']} -> {project_dir}")
        result = subprocess.run(cmd)
        if result.returncode != 0:
            print(f"  clip {i} failed (exit {result.returncode}) — continuing")
            continue

        try:
            converted = convert_to_mp4(avi_path, mp4_path)
        except FileNotFoundError:
            converted = False
            print(f"  WARNING: ffmpeg not found (checked '{FFMPEG_BIN}') — "
                  f"kept {avi_path}. Install ffmpeg or set FFMPEG_BIN to convert.")
        if converted:
            if not args.keep_avi:
                os.remove(avi_path)
                print(f"  converted to {mp4_path}, removed {avi_path}")
            else:
                print(f"  converted to {mp4_path}, kept {avi_path}")
            extract_covers(clip, mp4_path, covers_dir)
        else:
            print(f"  WARNING: mp4 conversion failed for {clip['output']} — kept {avi_path}")


if __name__ == "__main__":
    main()
