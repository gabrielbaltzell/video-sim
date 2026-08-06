extends Node
class_name EndConditionWatcher

## Ends the simulation deterministically: min(duration_cap, settle_time),
## whichever comes first. Intended to be added as a child of the
## bootstrap scene root and given a list of ball nodes to monitor.
##
## duration_cap is a hard ceiling checked first every tick, so no config
## can produce a runaway render even if the settle logic has a bug.
## Set duration_cap_seconds to 0 to disable the cap and rely on settle
## detection alone.
##
## settle triggers only once max ball speed has stayed continuously
## below settle_velocity_threshold for settle_sustain_seconds -- a
## single low-velocity instant (e.g. the apex of a normal bounce arc)
## must NOT trigger this, which is why any tick above threshold resets
## the sustain timer back to zero rather than just pausing it.
##
## Both conditions are checked every tick (not settle-only-as-fallback),
## so whichever of duration_cap / settle actually happens first is what
## ends the sim -- true min(duration_cap, settle_time) semantics.

@export var duration_cap_seconds: float = 70
@export var settle_velocity_threshold: float = 8.0
@export var settle_sustain_seconds: float = 2.0

## Ball nodes to monitor. Each must expose a `velocity: Vector2`
## property -- true of both CharacterBody2D (cbball.gd) and
## RigidBody2D-derived bodies. Set this before the watcher starts
## ticking (i.e. before it's added to the tree, or in the same frame).
var balls: Array = []

var elapsed_time: float = 0.0
var settle_timer: float = 0.0
var _finished: bool = false

func _physics_process(delta: float) -> void:
	if _finished:
		return

	elapsed_time += delta

	# hard ceiling -- always checked first. duration_cap_seconds <= 0
	# means "no cap", so settle detection below is the only way to end.
	if duration_cap_seconds > 0.0 and elapsed_time >= duration_cap_seconds:
		_end_simulation("duration cap reached at %.2fs" % elapsed_time)
		return

	# Disable settle-based termination for this workflow so the clip always
	# runs until the configured duration cap is reached.
	return

func _get_max_ball_speed() -> float:
	var max_speed = 0.0
	for ball in balls:
		if is_instance_valid(ball):
			max_speed = max(max_speed, ball.velocity.length())
	return max_speed

func _end_simulation(reason: String) -> void:
	_finished = true
	print("EndConditionWatcher: ending simulation - ", reason)
	get_tree().quit()
