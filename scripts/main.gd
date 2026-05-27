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
@onready var particles = $Particles

var ball_sprite_tscn = preload("res://scenes/ball_sprite.tscn")
var explosive_particles_tscn = preload("res://scenes/explosive_particles.tscn")

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
	var next_color = Color()
	next_color = get_next_color()
	color_circle_on_collision(next_color)
	emit_particles(next_color)

func get_next_color():
	# change color by r
	if r >= 1:
		color_change_r = color_factor_r
	if r <= 0:
		color_change_r = -color_factor_r
	r -= color_change_r
	
	# change color by g
	if g >= 1:
		color_change_g = color_factor_g
	if g <= 0:
		color_change_g = -color_factor_g
	g -= color_change_g
	
	# change color by b
	if b >= 1:
		color_change_b = color_factor_b
	if b <= 0:
		color_change_b = -color_factor_b
	b -= color_change_b
	
	var new_color = Color(r, g, b, 1)
	return new_color

func color_circle_on_collision(next_color):
	
	circle.self_modulate = next_color

func emit_particles(next_color):
	var explosion = explosive_particles_tscn.instantiate()
	particles.add_child(explosion)
	explosion.position = ball.global_position
	explosion.color = next_color
	explosion.emitting = true
	
