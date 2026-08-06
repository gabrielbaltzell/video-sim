# AGENTS.md

Godot 4.7 (GL Compatibility) music-visualizer: a ball bounces inside a circle; each collision plays the next note of a song, advances a color cycle, spawns particles, and emits a background shader ripple. Clips are rendered headlessly to `.avi` via the movie writer.

## Rendering (the main workflow)

Single clip:
```
godot --headless --write-movie output/clip_001.avi -- --config JSONs/test.json --index 0
```
Batch (all clips in a config file):
```
python python_scripts/video_sim_subprocessor.py JSONs/test.json
```

- Arguments after `--` are user args parsed by `VideoConfig.parse_cmdline_args()` (`scripts/video_config.gd`); the movie-writer/engine flags go before it. Don't drop the `--`.
- `output/` must already exist — Godot won't create it (the batch script does `os.makedirs`).
- Movie writer runs at 28 fps (`movie_writer/fps` in `project.godot`).
- Pressing Play in the editor works without args and falls back to `res://JSONs/test.json` index 0.

## Clip config (`JSONs/*.json`)

Top-level array of clip objects. Used fields: `song`, `instrument`, `output` (clip name, becomes `output/<output>.avi`), `duration`, `seed`. `balls`/`shape` are currently ignored.
- `duration` is read from the JSON by Godot — do NOT pass it as a cmdline flag (a bare `--duration ""` crashes `float("")`).
- `seed` (int) makes the run deterministic; omit it for a random run.
- `song` maps to `res://musictxts/<song>.txt`; `instrument` maps to `res://libraries/<instrument>/` wav folder.

## Song / instrument pipeline

- Songs are generated from MIDI: drop a `.mid` in `python_scripts/Mids/`, run `python python_scripts/single_track_note_extractor.py` (requires `pretty_midi`). It octave-folds the melody onto the library's note range and writes `musictxts/<name>.txt`.
- Song file format: comma-separated note names, single trailing `;` (terminator — parser `load_array()` in `scripts/audio_player.gd` breaks on it).
- Note names use flat spelling (`a_sharp`, not `A#`) with `l`/`h`/`hh` prefixes forming one contiguous chromatic run. `NOTE_NAMES` in the extractor must match the wav filenames in `libraries/<instrument>/` exactly (guitar = 39 notes).

## Determinism

`seed` drives `RandomNumberGenerator` for launch velocity, starting color, and the background shader's `seed_offset` + hue shift. Same seed ⇒ identical render. If you add new RNG draws, keep the draw order deterministic.

## Tight coupling (edit these together)

- `scripts/main.gd` walks `scenes/main.tscn` by literal node names: `Icon`, `Wcircle-png`, `CharacterBody2D` (plus `ball.get_node("AudioStreamPlayer")`), `SubBalls`, `Particles`.
- `MAX_RIPPLES = 8` in `main.gd` must stay in sync with the literal `[8]` uniform arrays in `shaders/seeded_shader.gdshader` and the `ShaderMaterial` defaults in `main.tscn`. Godot can't set individual shader array elements — the whole array is re-sent on each collision.
- `seeded_shader.gdshader` is the active background shader (wired in `main.tscn`); `shaders/main.gdshader` is the older, unused circle shader.

## End condition

`EndConditionWatcher` (`scripts/end_condition_watcher.gd`) ends each clip via its `duration` cap. Settle-based termination is currently disabled (early `return` in `_physics_process`) — re-enable only if you also restore the intended behavior.

## Environment

- Project lives in OneDrive on Windows; WSL mount is `/mnt/c/...`. Godot binary is 4.7.1, path in `.vscode/settings.json`. Godot typically runs on the Windows side even when editing from WSL.
- `.godot/` is gitignored. Godot 4.4+ `.uid` sidecar files are tracked — commit new ones when adding scripts/shaders.
- `.gitattributes` forces LF; `output/*.avi` renders are currently untracked but not ignored.
