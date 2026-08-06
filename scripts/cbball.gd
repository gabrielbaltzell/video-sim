extends CharacterBody2D

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 15.0
var bounce_damping = 0.0

# Range for the seeded starting launch speed (see apply_seeded_start_velocity).
@export var min_launch_speed: float = 1.0
@export var max_launch_speed: float = 7.0

signal ball_collided

func _ready():
	pass

## Gives the ball a deterministic starting velocity: a random angle and
## speed drawn from `rng`, which the caller (main.gd) has already
## seeded from the clip config's "seed" field. Same seed -> same
## launch, every time -- that's the whole point of passing an rng in
## rather than calling randf() directly here.
func apply_seeded_start_velocity(rng: RandomNumberGenerator) -> void:
	var angle = rng.randf_range(0.0, TAU)
	var speed = rng.randf_range(min_launch_speed, max_launch_speed)
	velocity = Vector2(cos(angle), sin(angle)) * speed

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
