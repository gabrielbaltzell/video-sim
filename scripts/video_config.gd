class_name VideoConfig
extends RefCounted

## Utility for parsing engine cmdline args and loading a single clip's
## config out of a batch config file (e.g. test.json).
##
## Run from the command line like:
##   godot --headless --write-movie output/clip_001.avi -- --config test.json --index 0
##
## Falls back to sensible defaults with no args at all, so pressing Play
## in the editor still works (loads res://test.json, index 0) without
## needing a full cmdline invocation every time.

const DEFAULT_CONFIG_PATH = "res://JSONs/test.json"
const DEFAULT_INDEX = 0

## Parses everything after the "--" separator on the command line into
## a Dictionary. "--key value" -> {"key": "value"}. A flag with no
## following value (or one immediately followed by another --flag)
## is stored as boolean true.
static func parse_cmdline_args() -> Dictionary:
	var args = OS.get_cmdline_user_args()
	var parsed = {}
	var i = 0
	while i < args.size():
		if args[i].begins_with("--"):
			var key = args[i].trim_prefix("--")
			if i + 1 < args.size() and not args[i + 1].begins_with("--"):
				parsed[key] = args[i + 1]
				i += 1
			else:
				parsed[key] = true
		i += 1
	return parsed

## Reads the batch config file (an Array of clip Dictionaries) and
## returns the single clip at the requested index. Returns an empty
## Dictionary and logs an error on any failure -- callers should check
## for that rather than assuming a valid clip always comes back.
static func load_clip() -> Dictionary:
	var args = parse_cmdline_args()
	var config_path: String = args.get("config", DEFAULT_CONFIG_PATH)
	var index: int = int(args.get("index", DEFAULT_INDEX))

	# a bare filename (e.g. "test.json" from --config test.json) is
	# ambiguous -- normalize it to Godot's res:// virtual path so it
	# doesn't depend on whatever the OS working directory happens to be
	# at the moment the engine was launched.
	if not (config_path.begins_with("res://") or config_path.begins_with("user://") or config_path.is_absolute_path()):
		config_path = "res://" + config_path

	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_error("VideoConfig: could not open config file: " + config_path)
		return {}

	var text = file.get_as_text()
	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_error("VideoConfig: JSON parse error in %s at line %d: %s" % [
			config_path, json.get_error_line(), json.get_error_message()
		])
		return {}

	var clips = json.data
	if not clips is Array:
		push_error("VideoConfig: expected a top-level array in " + config_path)
		return {}

	if index < 0 or index >= clips.size():
		push_error("VideoConfig: index %d out of range for %s (%d clips)" % [
			index, config_path, clips.size()
		])
		return {}

	var clip = clips[index]
	if clip is Dictionary and clip.has("duration"):
		var raw_duration = clip.get("duration")
		if raw_duration is String:
			clip["duration"] = float(raw_duration)
		elif raw_duration is int:
			clip["duration"] = float(raw_duration)
		elif raw_duration is float:
			clip["duration"] = float(raw_duration)

	if clip is Dictionary and clip.has("seed"):
		var raw_seed = clip.get("seed")
		if raw_seed is String:
			clip["seed"] = int(raw_seed)
		elif raw_seed is float:
			clip["seed"] = int(raw_seed)

	return clip
