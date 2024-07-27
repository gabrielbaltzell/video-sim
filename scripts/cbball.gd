extends CharacterBody2D


# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 30.0
var bounce_damping = 0.00
var a = 1.0
var color_factor = 0.05
var color_change


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
		
		# change color by collision
		if a >= 1:
			color_change = color_factor
		if a <= 0:
			color_change = -color_factor
		a -= color_change
		var new = Color(a, 1, a, 1)
		circle.self_modulate = new
		

	move_and_slide()
