extends CharacterBody2D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 30.0
var bounce_damping = 0.0

signal ball_collided

func _ready():
	pass

func _process(delta):
	pass

func _physics_process(delta):
	# add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# save collision information
	var collision = move_and_collide(velocity)
	if collision:
		velocity = velocity.bounce(collision.get_normal()) * (1 - bounce_damping)
		
		# collision signal to audio_player
		ball_collided.emit()
	
	move_and_slide()

	

