extends AudioStreamPlayer

var test_file = "res://musictxts/test.txt"
var mario_file = "res://musictxts/mario.txt"
var notes = []
var note_index = 0

# preload audio files
var ld = preload("res://wavs/LD.wav")
var ld_sharp = preload("res://wavs/LD#.wav")
var le = preload("res://wavs/LE.wav")
var lf = preload("res://wavs/LF.wav")
var lf_sharp = preload("res://wavs/LF#.wav")
var lg = preload("res://wavs/LG.wav")
var lg_sharp = preload("res://wavs/LG#.wav")
var a = preload("res://wavs/A.wav")
var a_sharp = preload("res://wavs/A#.wav")
var b = preload("res://wavs/B.wav")
var c = preload("res://wavs/C.wav")
var c_sharp = preload("res://wavs/C#.wav")
var d = preload("res://wavs/D.wav")
var d_sharp = preload("res://wavs/D#.wav")
var e = preload("res://wavs/E.wav")
var f = preload("res://wavs/F.wav")
var f_sharp = preload("res://wavs/F#.wav")
var g = preload("res://wavs/G.wav")
var g_sharp = preload("res://wavs/G#.wav")
var ha = preload("res://wavs/HA.wav")
var ha_sharp = preload("res://wavs/HA#.wav")
var hb = preload("res://wavs/HB.wav")
var hc = preload("res://wavs/HC.wav")
var hc_sharp = preload("res://wavs/HC#.wav")
var hd = preload("res://wavs/HD.wav")
var hd_sharp = preload("res://wavs/HD#.wav")
var he = preload("res://wavs/HE.wav")
var hf = preload("res://wavs/HF.wav")
var hf_sharp = preload("res://wavs/HF#.wav")
var hg = preload("res://wavs/HG.wav")
var hg_sharp = preload("res://wavs/HG#.wav")
var hha = preload("res://wavs/HHA.wav")
var hha_sharp = preload("res://wavs/HHA#.wav")
var hhb = preload("res://wavs/HHB.wav")
var hhc = preload("res://wavs/HHC.wav")
var hhc_sharp = preload("res://wavs/HHC#.wav")
var hhd = preload("res://wavs/HHD.wav")
var hhd_sharp = preload("res://wavs/HHD#.wav")
var hhe = preload("res://wavs/HHE.wav")


@onready var ball = get_parent()

func _ready():
	# prepare .txt file on ready
	var open_file = FileAccess.open(mario_file, FileAccess.READ)
	var file_content = open_file.get_as_text()
	
	# call load with contents of .txt file and save array into notes[]
	notes = load_array(file_content, file_content.length())
	print(notes)

	# connect signal
	ball.ball_collided.connect(_on_ball_collision)
	
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
			print('bad .txt syntax - audi_player.gd load_array()')
			break
	return notes

func _on_ball_collision():
	var note = notes[note_index]
	
	# play note
	match note:
		'LD':
			self.stream = ld
			self.play()
		'LD#':
			self.stream = ld_sharp
			self.play()
		'LE':
			self.stream = le
			self.play()
		'LF':
			self.stream = lf
			self.play()
		'LF#':
			self.stream = lf_sharp
			self.play()
		'LG':
			self.stream = lg
			self.play()
		'LG#':
			self.stream = lg_sharp
			self.play()
		'A':
			self.stream = a
			self.play()
		'A#':
			self.stream = a_sharp
			self.play()
		'B':
			self.stream = b
			self.play()
		'C':
			self.stream = c
			self.play()
		'C#':
			self.stream = c_sharp
			self.play()
		'D':
			self.stream = d
			self.play()
		'D#':
			self.stream = d_sharp
			self.play()
		'E':
			self.stream = e
			self.play()
		'F':
			self.stream = f
			self.play()
		'F#':
			self.stream = f_sharp
			self.play()
		'G':
			self.stream = g
			self.play()
		'G#':
			self.stream = g_sharp
			self.play()
		'HA':
			self.stream = ha
			self.play()
		'HA#':
			self.stream = ha_sharp
			self.play()
		'HB':
			self.stream = hb
			self.play()
		'HC':
			self.stream = hc
			self.play()
		'HC#':
			self.stream = hc_sharp
			self.play()
		'HD':
			self.stream = hd
			self.play()
		'HD#':
			self.stream = hd_sharp
			self.play()
		'HE':
			self.stream = he
			self.play()
		'HF':
			self.stream = hf
			self.play()
		'HF#':
			self.stream = hf_sharp
			self.play()
		'HG':
			self.stream = hg
			self.play()
		'HG#':
			self.stream = hg_sharp
			self.play()
		'HHA':
			self.stream = hha
			self.play()
		'HHA#':
			self.stream = hha_sharp
			self.play()
		'HHB':
			self.stream = hhb
			self.play()
		'HHC':
			self.stream = hhc
			self.play()
		'HHC#':
			self.stream = hhc_sharp
			self.play()
		'HHD':
			self.stream = hhd
			self.play()
		'HHD#':
			self.stream = hhd_sharp
			self.play()
		'HHE':
			self.stream = hhe
			self.play()

	# increment note index
	if note_index < notes.size() - 1:
		note_index += 1
	else:
		note_index = 0
