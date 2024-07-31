extends Node2D

var r = 1.0
var color_factor_r = 0.04
var color_change_r
var g = 1.0
var color_factor_g = 0.02
var color_change_g
var b = 1.0
var color_factor_b = 0.05
var color_change_b

var ball_array = []
const BALL_ARRAY_MAX_SIZE = 21
var frame_counter = 0

@onready var circle = $"Wcircle-png"
@onready var ball = $CharacterBody2D
@onready var sub_balls = $SubBalls

var ball_sprite_tscn = preload("res://scenes/ball_sprite.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	# connect collision signal
	ball.ball_collided.connect(_on_ball_collision)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var last_pos = ball.global_position

	var j = frame_counter % BALL_ARRAY_MAX_SIZE
	var new_ball = ball_sprite_tscn.instantiate()

	if ball_array.size() < BALL_ARRAY_MAX_SIZE:
		ball_array.append(new_ball)
	else:
		ball_array[j].queue_free()
		ball_array[j] = new_ball

	sub_balls.add_child(ball_array[j])
	ball_array[j].position = last_pos

	frame_counter += 1

func _on_ball_collision():
	color_circle_on_collision()

func color_circle_on_collision():
	# change color by collision r
	if r >= 1:
		color_change_r = color_factor_r
	if r <= 0:
		color_change_r = -color_factor_r
	r -= color_change_r
	
	# change color by collision g
	if g >= 1:
		color_change_g = color_factor_g
	if g <= 0:
		color_change_g = -color_factor_g
	g -= color_change_g
	
	# change color by collision b
	if b >= 1:
		color_change_b = color_factor_b
	if b <= 0:
		color_change_b = -color_factor_b
	b -= color_change_b
	
	var new_color = Color(r, g, b, 1)
	circle.self_modulate = new_color
