extends AudioStreamPlayer

## Song .txt files are expected at res://musictxts/<song_name>.txt,
## matching the naming used by single_track_note_extractor.py's output.
const SONG_DIR = "res://musictxts/"

## Instrument libraries are folders of wavs at res://libraries/<name>/,
## one file per note (e.g. libraries/guitar/ld.wav). Built into a
## Dictionary[String, AudioStream] at runtime via load_library() --
## swapping instruments is just pointing at a different folder, no
## code changes needed.
const LIBRARY_DIR = "res://libraries/"

var notes = []
var note_index = 0
var library: Dictionary = {}  # note name (e.g. "ld") -> AudioStream

@onready var ball = get_parent()

func _ready():
	# structural wiring only -- which song/instrument to load isn't known
	# yet at this point (the bootstrap in main.gd hasn't read the clip
	# config yet, since children ready before their parent does). Call
	# load_clip_audio() explicitly once that config is available.
	ball.ball_collided.connect(_on_ball_collision)

## Loads both the instrument library and the song for a clip in one
## call -- this is what main.gd's bootstrap should call once it has
## the clip config. Order matters: library first, so validation has
## something to check the song's notes against.
func load_clip_audio(song_name: String, instrument_name: String) -> void:
	load_library(instrument_name)
	load_song(song_name)
	_validate_notes_against_library()

## Scans res://libraries/<instrument_name>/ for .wav files and builds
## `library` as note_name -> AudioStream, keyed by filename (minus
## extension), e.g. "ld.wav" -> library["ld"]. Safe to call again to
## switch instruments; clears any previously loaded library first.
func load_library(instrument_name: String) -> void:
	library.clear()
	var dir_path = LIBRARY_DIR + instrument_name + "/"
	var dir = DirAccess.open(dir_path)
	if dir == null:
		push_error("audio_player.gd: could not open library directory: " + dir_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "wav":
			var note_name = file_name.get_basename()
			var stream = load(dir_path + file_name)
			if stream:
				library[note_name] = stream
			else:
				push_error("audio_player.gd: failed to load %s%s" % [dir_path, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()

	if library.is_empty():
		push_error("audio_player.gd: no .wav files found in " + dir_path)
	else:
		print("audio_player.gd: loaded %d notes from %s" % [library.size(), dir_path])

## Loads a song by name, e.g. load_song("mario") reads
## res://musictxts/mario.txt. Safe to call any time after _ready();
## resets note_index back to 0 so a re-called load always starts clean.
func load_song(song_name: String) -> void:
	var path = SONG_DIR + song_name + ".txt"
	var open_file = FileAccess.open(path, FileAccess.READ)
	if open_file == null:
		push_error("audio_player.gd: could not open song file: " + path)
		return

	var file_content = open_file.get_as_text()
	notes.clear()
	notes = load_array(file_content, file_content.length())
	note_index = 0

func load_array(file_content, length):
	var buffer = ""
	for i in length:
		# if file_content[i] is not ',' or ';' write file_content[i] to buffer
		if file_content[i] != ',' && file_content[i] != ';':
			buffer += file_content[i]
		# else if file_content[i] is ',' and buffer isn't null then append buffer to notes
		elif file_content[i] == ',' && buffer:
			notes.append(buffer)
			buffer = ""
		# else if file_content[i] is ';' and buffer isn't null then append buffer to notes and exit loop
		# found end of file
		elif file_content[i] == ';' && buffer:
			notes.append(buffer)
			buffer = ""
			break
		# else if file_content[i] is ';' and buffer is null then exit loop without writing buffer
		# found end of file
		elif file_content[i] == ';' && !buffer:
			print('bad .txt syntax - audio_player.gd load_array()')
			break
	return notes

## Checks that every note the loaded song needs actually exists in the
## loaded library, so a bad song/instrument pairing shows up as a
## clear warning at load time instead of a silent missing note (or a
## crash) mid-render. Non-fatal -- prints once per missing note name.
func _validate_notes_against_library() -> void:
	if notes.is_empty() or library.is_empty():
		return
	var missing = {}
	for note in notes:
		if not library.has(note) and not missing.has(note):
			missing[note] = true
	if not missing.is_empty():
		push_warning("audio_player.gd: song uses notes not present in the loaded library: " + str(missing.keys()))

func _on_ball_collision():
	if notes.is_empty():
		return

	var note = notes[note_index]
	if library.has(note):
		self.stream = library[note]
		self.play()
	else:
		push_error("audio_player.gd: note '%s' not found in loaded library -- skipping" % note)

	# increment note index
	if note_index < notes.size() - 1:
		note_index += 1
	else:
		note_index = 0
