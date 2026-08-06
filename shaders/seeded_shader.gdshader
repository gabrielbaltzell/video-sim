shader_type canvas_item;

// --- animated background flow field ---
// color_primary/color_secondary are pushed from main.gd whenever the
// circle/particle color-cycle advances, so the background tracks the
// same evolving palette instead of sitting flat black.
uniform vec3 color_primary : source_color = vec3(0.85, 0.2, 0.3);
uniform vec3 color_secondary : source_color = vec3(0.2, 0.3, 0.85);

// set once at bootstrap from the clip config's "seed" field -- offsets
// the flow field's phase so different seeds produce visibly different
// (but each internally deterministic and repeatable) background motion.
uniform float seed_offset = 0.0;

uniform float flow_speed : hint_range(0.0, 1.0) = 0.12;
uniform float flow_scale : hint_range(1.0, 10.0) = 3.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.72; // overall pull toward black


// --- collision ripples ---
// A small ring buffer of ripples, spawned from main.gd the same way it
// spawns particles: on ball_collided, at the ball's position, with the
// current cycling color. Godot shader arrays need a literal size here
// (8), which must match MAX_RIPPLES in main.gd -- keep them in sync if
// you change either.
uniform vec2 ripple_positions[8];      // UV-space origin of each ripple
uniform float ripple_start_times[8];   // sim_time value when each ripple was spawned
uniform vec3 ripple_colors[8];         // circle/particle color at spawn time

uniform float ripple_speed : hint_range(0.0, 2.0) = 0.35;        // ring expansion speed, UV/sec
uniform float ripple_lifetime : hint_range(0.1, 10.0) = 2.5;     // seconds until a ripple fully fades
uniform float ripple_width : hint_range(0.001, 0.5) = 0.05;      // ring thickness, UV units
uniform float ripple_trail_frequency : hint_range(0.0, 200.0) = 55.0; // trailing-ring spacing behind the leading edge
uniform float ripple_turbulence : hint_range(0.0, 0.1) = 0.012;  // organic wobble from the noise texture
uniform float ripple_amplitude : hint_range(0.0, 3.0) = 1.6;     // overall ripple brightness

// screen aspect ratio, set once from the viewport so rings read as
// circles rather than ellipses (UV space itself usually isn't square)
uniform float aspect_ratio = 1.777;

// sim_time is pushed from main.gd's _process() every frame, rather than
// relying on the built-in TIME, so ripple ages stay exactly in sync
// with the moment main.gd recorded each collision.
uniform float sim_time = 0.0;

// other
uniform sampler2D noise;
uniform float waveAmplitude = 0.1;
uniform float waveFrequency = 1.0;


vec2 wave(vec2 uv, float time) {
	return vec2(
		uv.x + sin(uv.y * waveFrequency * 5.0 + time) * waveAmplitude,
		uv.y + sin(uv.x * waveFrequency + time) * waveAmplitude
	);
}

// layered sine flow field, phase-shifted by seed_offset so every seed
// gets a visually distinct (but deterministic) moving gradient
vec3 background_color(vec2 uv_in, float time) {
	vec2 uv = uv_in * flow_scale;
	float t = time * flow_speed;

	float n1 = sin(uv.x * 1.3 + t + seed_offset);
	float n2 = sin(uv.y * 1.7 - t * 1.3 + seed_offset * 1.7);
	float n3 = sin((uv.x + uv.y) * 0.9 + t * 0.7 - seed_offset * 0.6);
	float n4 = cos((uv.x - uv.y) * 1.1 + t * 0.5 + seed_offset * 2.3);

	float pattern = (n1 + n2 + n3 + n4) * 0.25; // roughly [-1, 1]
	pattern = pattern * 0.5 + 0.5;              // remap to [0, 1]

	vec3 col = mix(color_primary, color_secondary, pattern);

	// soft vignette so the center -- where the circle/ball live --
	// reads a bit cleaner, with color motion showing more toward the edges
	float dist = distance(uv_in, vec2(0.5));
	float vignette = smoothstep(0.15, 0.75, dist);
	col = mix(col, col * 0.4, vignette * 0.6);

	return col * (1.0 - darkness);
}

// One expanding-and-fading ring, water-style: a leading edge with a
// few trailing ripples behind it, both faded by how old the ripple is.
// Returns the ring's intensity at this fragment (0 = no contribution).
float ripple_ring(vec2 uv, vec2 origin, float age, float turbulence_sample) {
	if (age < 0.0 || age > ripple_lifetime) {
		return 0.0;
	}

	vec2 p = uv - origin;
	p.x *= aspect_ratio; // keep the ring circular regardless of aspect ratio
	float dist = length(p) + turbulence_sample;

	float radius = age * ripple_speed;
	float ring = 1.0 - abs(dist - radius) / ripple_width;
	ring = clamp(ring, 0.0, 1.0);
	// trailing ripples behind the leading edge, like real water
	ring *= 0.6 + 0.4 * sin((radius - dist) * ripple_trail_frequency);
	ring = max(ring, 0.0);

	float fade = 1.0 - (age / ripple_lifetime);
	return ring * fade * fade; // fade^2 for a snappier falloff near the end of life
}

void fragment() {
	vec3 bg = background_color(UV, TIME);

	// reused across all ripples for a subtle water-like wobble instead
	// of perfectly circular rings
	vec2 wave_uv = wave(UV, TIME);
	vec4 ns = texture(noise, wave_uv);
	float turbulence_sample = (ns.x - 0.5) * ripple_turbulence;

	float ripple_total = 0.0;
	vec3 ripple_color_sum = vec3(0.0);

	for (int i = 0; i < 8; i++) {
		float age = sim_time - ripple_start_times[i];
		float intensity = ripple_ring(UV, ripple_positions[i], age, turbulence_sample);
		ripple_total += intensity;
		ripple_color_sum += ripple_colors[i] * intensity;
	}

	vec3 ripple_color = bg;
	if (ripple_total > 0.001) {
		ripple_color = ripple_color_sum / ripple_total; // weighted average of contributing ripples' colors
	}

	float blend = clamp(ripple_total * ripple_amplitude, 0.0, 1.0);
	vec3 final_color = mix(bg, clamp(ripple_color + bg * 0.3, 0.0, 1.0), blend);

	COLOR = vec4(final_color, 1.0);
}
