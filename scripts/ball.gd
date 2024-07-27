extends RigidBody2D

var velocity
var bounce_force = 1500

# Damping factor for slowing down the ball's movement over time
@export var linear_damping: float = 0.05
@export var angular_damping: float = 0.05

# Minimum velocity threshold to stop the ball
@export var stop_velocity_threshold: float = 5.0


func _ready():
	contact_monitor = true
	max_contacts_reported = 1
	velocity = 750 * linear_velocity
	
	# Initialize properties
	self.linear_damp = linear_damping
	self.angular_damp = angular_damping


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	var collision = move_and_collide(velocity * delta)
	velocity = linear_velocity
	print(velocity)
	if collision:
		apply_central_impulse(velocity.bounce(collision.get_normal()))

func _integrate_forces(state):
	var velocity = state.linear_velocity
	
	if velocity.length() < stop_velocity_threshold:
		velocity = Vector2.ZERO
		state.linear_velocity = velocity
		
