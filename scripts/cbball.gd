extends CharacterBody2D


# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 30.0
var bounce_damping = 0.0
var r = 1.0
var color_factor_r = 0.04
var color_change_r
var g = 1.0
var color_factor_g = 0.02
var color_change_g
var b = 1.0
var color_factor_b = 0.05
var color_change_b

signal ball_collided


@onready var circle = get_node("../Wcircle-png")

func _ready():
	pass

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# save collision information
	var collision = move_and_collide(velocity)
	if collision:
		velocity = velocity.bounce(collision.get_normal()) * (1 - bounce_damping)
		
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
		
		var new = Color(r, g, b, 1)
		circle.self_modulate = new

		ball_collided.emit()
		

	move_and_slide()
