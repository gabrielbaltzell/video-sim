extends AudioStreamPlayer

var file = "res://musictxts/test.txt"
var notes = []

func _ready():
	var open_file = FileAccess.open(file, FileAccess.READ)
	var file_content = open_file.get_as_text()
	print(file_content)
	notes = load_array(file_content, file_content.length())
	print(notes)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func load_array(file_content, length):
	var buffer = ""
	for i in length:
		if file_content[i] != ',' && file_content[i] != ';':
			buffer += file_content[i]
		elif file_content[i] == ',' && buffer:
			notes.append(buffer)
			buffer = ""
		elif file_content[i] == ';' && buffer:
			notes.append(buffer)
			buffer = ""
			break
		elif file_content[i] == ';' && !buffer:
			break
	return notes
