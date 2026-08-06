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

# used when a clip config doesn't specify its own end_condition block
# (test.json doesn't yet -- these keep batch rendering functional until it does)
const DEFAULT_DURATION_CAP_SECONDS = 45.0
const DEFAULT_SETTLE_VELOCITY_THRESHOLD = 8.0
const DEFAULT_SETTLE_SUSTAIN_SECONDS = 2.0

@onready var circle = $"Wcircle-png"
@onready var ball = $CharacterBody2D
@onready var sub_balls = $SubBalls
@onready var particles = $Particles
# NOTE: verify this node path/name matches your actual scene tree --
# this assumes the AudioStreamPlayer with audio_player.gd attached is a
# direct child of the CharacterBody2D ball, named "AudioStreamPlayer".
@onready var audio_player: AudioStreamPlayer = ball.get_node("AudioStreamPlayer")
# The sprite carrying main.gdshader's material. Typed as Sprite2D (not
# just CanvasItem) because _world_to_uv() needs its texture size and
# centered/flip settings to convert collision points into UV space
# correctly.
@onready var background: Sprite2D = get_node_or_null("Icon")

var ball_sprite_tscn = preload("res://scenes/ball_sprite.tscn")
var explosive_particles_tscn = preload("res://scenes/explosive_particles.tscn")

var clip_config: Dictionary = {}
var rng := RandomNumberGenerator.new()
# derived once from the seed in _ready(); used to relate the shader's
# secondary color to the live primary (circle/particle) color via a hue
# rotation, so the seed visibly changes the background's look, not just
# the ball's launch.
var background_hue_shift: float = 0.0

# --- collision ripple pool ---
# Must match the array size (8) declared in main.gdshader's
# ripple_positions/ripple_start_times/ripple_colors uniforms.
const MAX_RIPPLES = 8
var ripple_positions: Array = []
var ripple_start_times: Array = []
var ripple_colors: Array = []
var ripple_index: int = 0
# Accumulated independently of delta-time quirks / built-in TIME so the
# shader's ripple ages stay exactly in sync with when main.gd actually
# recorded each collision -- pushed to the shader as "sim_time" every
# frame in _process().
var background_sim_time: float = 0.0

# Called when the node enters the scene tree for the first time.
# This is the bootstrap entry point: children (ball, audio_player) have
# already had their own _ready() calls run by the time this fires, so
# it's safe to reach into them here.
func _ready():
	clip_config = VideoConfig.load_clip()
	if clip_config.is_empty():
		push_error("main.gd: no clip config loaded -- aborting bootstrap")
		return

	print("Bootstrapping clip: ", clip_config.get("output", "unnamed"))

	if not background:
		push_error("main.gd: background node 'Icon' not found -- shader seed/color/ripple params will not be set")
	elif not background.material:
		push_error("main.gd: 'Icon' has no material assigned -- shader seed/color/ripple params will not be set")

	# --- audio: load this clip's song + instrument library ---
	audio_player.load_clip_audio(
		clip_config.get("song", "mario"),
		clip_config.get("instrument", "guitar")
	)

	# --- seed: drives starting color + ball launch velocity + background shader phase ---
	# same seed -> identical run, every time (re-renders are reproducible).
	# omit "seed" from the clip config for a fresh random run instead.
	if clip_config.has("seed"):
		rng.seed = int(clip_config["seed"])
	else:
		rng.randomize()

	# starting color: previously r/g/b always started at 1.0 (white),
	# so every clip opened on the same color regardless of seed. Now
	# picked from the seeded rng, and color_change_r/g/b are set
	# explicitly here too -- get_next_color() only ever *sets* a
	# direction when r/g/b hits 0 or 1, which the old code relied on
	# happening immediately since it started exactly at 1.0. A random
	# starting value won't hit either boundary right away, so without
	# this the first collision would try to use an uninitialized
	# (null) color_change_r/g/b and crash.
	r = rng.randf()
	g = rng.randf()
	b = rng.randf()
	color_change_r = color_factor_r if rng.randf() < 0.5 else -color_factor_r
	color_change_g = color_factor_g if rng.randf() < 0.5 else -color_factor_g
	color_change_b = color_factor_b if rng.randf() < 0.5 else -color_factor_b

	var start_color = Color(r, g, b, 1)
	color_circle_on_collision(start_color)

	ball.apply_seeded_start_velocity(rng)
	# spread across a visually useful range rather than raw seed int,
	# which could be any magnitude
	background_hue_shift = fmod(float(rng.seed) * 0.6180339887, 1.0)  # golden-ratio spread
	if background and background.material:
		background.material.set_shader_parameter("seed_offset", fmod(float(rng.seed), 1000.0))
		_push_background_colors(start_color)

		# ripple pool init: sentinel start times far in the past so no
		# ripple appears to fire at frame 0 (default-zeroed shader
		# arrays would otherwise read as "spawned at sim_time == 0",
		# which is indistinguishable from a real collision at t=0)
		background.material.set_shader_parameter("aspect_ratio", _current_aspect_ratio())
		for i in MAX_RIPPLES:
			ripple_positions.append(Vector2.ZERO)
			ripple_start_times.append(-1000.0)
			ripple_colors.append(Vector3(0.0, 0.0, 0.0))
		background.material.set_shader_parameter("ripple_positions", PackedVector2Array(ripple_positions))
		background.material.set_shader_parameter("ripple_start_times", PackedFloat32Array(ripple_start_times))
		background.material.set_shader_parameter("ripple_colors", PackedVector3Array(ripple_colors))

	# --- collision signal wiring (unchanged) ---
	ball.ball_collided.connect(_on_ball_collision)

	# --- end condition watcher: min(duration_cap, settle_time) ---
	var watcher = EndConditionWatcher.new()
	var duration_raw = clip_config.get("duration", DEFAULT_DURATION_CAP_SECONDS)
	var duration_seconds: float = DEFAULT_DURATION_CAP_SECONDS
	if duration_raw is String:
		duration_seconds = float(duration_raw)
	elif duration_raw is int or duration_raw is float:
		duration_seconds = float(duration_raw)
	watcher.duration_cap_seconds = duration_seconds
	watcher.settle_velocity_threshold = DEFAULT_SETTLE_VELOCITY_THRESHOLD
	watcher.settle_sustain_seconds = DEFAULT_SETTLE_SUSTAIN_SECONDS
	watcher.balls = [ball]
	print("Using duration cap %.2fs for %s" % [duration_seconds, clip_config.get("output", "unnamed")])
	add_child(watcher)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	background_sim_time += delta
	if background and background.material:
		background.material.set_shader_parameter("sim_time", background_sim_time)
		# cheap enough to recompute every frame, and necessary if the
		# camera/background scale changes over the course of the sim
		# (a static scale would only need this set once in _ready)
		background.material.set_shader_parameter("aspect_ratio", _current_aspect_ratio())

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
	_push_background_colors(next_color)
	_spawn_ripple(ball.global_position, next_color)

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

## Spawns a background ripple at the given world position, the same
## way emit_particles() spawns a particle burst there. Writes into the
## next slot of the ring buffer and re-sends the full arrays, since
## Godot shader uniforms don't support setting individual array
## elements -- only the whole array at once.
func _spawn_ripple(world_pos: Vector2, color: Color) -> void:
	if not background or not background.material:
		return

	var uv_pos = _world_to_uv(world_pos)

	ripple_positions[ripple_index] = uv_pos
	ripple_start_times[ripple_index] = background_sim_time
	ripple_colors[ripple_index] = Vector3(color.r, color.g, color.b)
	ripple_index = (ripple_index + 1) % MAX_RIPPLES

	background.material.set_shader_parameter("ripple_positions", PackedVector2Array(ripple_positions))
	background.material.set_shader_parameter("ripple_start_times", PackedFloat32Array(ripple_start_times))
	background.material.set_shader_parameter("ripple_colors", PackedVector3Array(ripple_colors))

## Converts a world-space position (e.g. ball.global_position) into the
## background sprite's UV space [0,1], going through the sprite's own
## global transform rather than the viewport size. This is what makes
## ripple placement correct even when the background is scaled/panned
## to track a moving or zooming camera -- the sprite-to-world
## relationship is what matters, not what the viewport happens to show.
func _world_to_uv(world_pos: Vector2) -> Vector2:
	if not background or not background.texture:
		return Vector2.ZERO

	# world position -> the sprite's own local (pre-scale, pre-pan) space
	var local_pos = background.get_global_transform().affine_inverse() * world_pos

	var tex_size = background.texture.get_size()
	if background.region_enabled and background.region_rect.size != Vector2.ZERO:
		tex_size = background.region_rect.size
	if tex_size.x == 0 or tex_size.y == 0:
		return Vector2.ZERO

	var uv: Vector2
	if background.centered:
		uv = (local_pos / tex_size) + Vector2(0.5, 0.5)
	else:
		uv = local_pos / tex_size

	if background.flip_h:
		uv.x = 1.0 - uv.x
	if background.flip_v:
		uv.y = 1.0 - uv.y

	return uv

## The sprite's actual displayed aspect ratio (world-space, accounting
## for its own scale) -- used by the shader to keep ripple rings
## circular rather than elliptical, regardless of pan/zoom.
func _current_aspect_ratio() -> float:
	if not background or not background.texture:
		return 1.0
	var tex_size = background.texture.get_size()
	if background.region_enabled and background.region_rect.size != Vector2.ZERO:
		tex_size = background.region_rect.size
	var global_scale = background.get_global_transform().get_scale()
	var displayed_size = tex_size * global_scale
	return displayed_size.x / max(displayed_size.y, 0.0001)

## Pushes the background shader's two colors: primary is the live
## circle/particle color, secondary is that same color hue-rotated by
## a seed-derived amount. Using the seed to set the *relationship*
## between the two colors (rather than picking a fixed offset) means
## different seeds visibly change the background's palette pairing,
## not just the flow pattern's phase.
func _push_background_colors(base_color: Color) -> void:
	if not background or not background.material:
		return
	var secondary = Color.from_hsv(
		fmod(base_color.h + 0.25 + background_hue_shift, 1.0),
		base_color.s,
		base_color.v
	)
	background.material.set_shader_parameter("color_primary", Vector3(base_color.r, base_color.g, base_color.b))
	background.material.set_shader_parameter("color_secondary", Vector3(secondary.r, secondary.g, secondary.b))
