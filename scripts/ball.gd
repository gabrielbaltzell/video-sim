extends RigidBody2D

var velocity
var bounce_force = 1500

func _ready():
	contact_monitor = true
	max_contacts_reported = 1
	velocity = 750 * linear_velocity


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	var collision = move_and_collide(velocity * delta)
	print(linear_velocity)
	if collision:
		apply_central_impulse(collision.get_normal() * bounce_force)

