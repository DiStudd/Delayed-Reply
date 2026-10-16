
shader_type sky;

// ============================================================
// PALETTE
// ============================================================

uniform vec3 background_color : source_color = vec3(0.003, 0.004, 0.018);
uniform vec3 nebula_blue : source_color = vec3(0.035, 0.12, 0.85);
uniform vec3 nebula_purple : source_color = vec3(0.48, 0.035, 0.85);
uniform vec3 nebula_pink : source_color = vec3(0.95, 0.055, 0.40);
uniform vec3 nebula_cyan : source_color = vec3(0.015, 0.65, 0.95);

// ============================================================
// NEBULA
// ============================================================

uniform float nebula_coverage : hint_range(0.0, 1.0) = 0.52;
uniform float nebula_strength : hint_range(0.0, 2.0) = 1.15;
uniform float nebula_scale : hint_range(1.0, 10.0) = 3.2;
uniform float nebula_detail : hint_range(0.5, 3.0) = 1.35;
uniform float nebula_speed : hint_range(0.0, 0.02) = 0.0012;

// ============================================================
// STARS
// ============================================================

uniform float star_density : hint_range(15.0, 100.0) = 43.0;
uniform float star_amount : hint_range(0.1, 1.0) = 1;
uniform float star_brightness : hint_range(0.1, 3.0) = 1.35;
uniform float star_color_variety : hint_range(0.0, 1.0) = 0.9;
uniform float bright_star_amount : hint_range(0.0, 1.0) = 0.8;
uniform float twinkle_amount : hint_range(0.0, 1.0) = 0.08;
uniform float twinkle_speed : hint_range(0.1, 2.0) = 0.45;
uniform float star_drift_speed : hint_range(0.0, 0.01) = 0.01;
uniform float object_drift_speed : hint_range(0.0, 0.01) = 0.0;

// ============================================================
// LARGE OBJECTS
// ============================================================

uniform float objects_brightness : hint_range(0.0, 2.0) = .5;
uniform float galaxy_scale : hint_range(0.5, 2.0) = 2;
uniform float show_galaxy = 1;
uniform float show_planets = .5;


// ============================================================
// HASH / NOISE
// ============================================================

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash31(i);
	float b = hash31(i + vec3(1.0, 0.0, 0.0));
	float c = hash31(i + vec3(0.0, 1.0, 0.0));
	float d = hash31(i + vec3(1.0, 1.0, 0.0));
	float e = hash31(i + vec3(0.0, 0.0, 1.0));
	float f1 = hash31(i + vec3(1.0, 0.0, 1.0));
	float g = hash31(i + vec3(0.0, 1.0, 1.0));
	float h = hash31(i + vec3(1.0, 1.0, 1.0));

	return mix(
		mix(mix(a, b, f.x), mix(c, d, f.x), f.y),
		mix(mix(e, f1, f.x), mix(g, h, f.x), f.y),
		f.z
	);
}

float fbm(vec3 p) {
	float n = 0.0;
	n += noise3(p) * 0.57;
	n += noise3(p * 2.03 + vec3(3.1, 8.2, 1.7)) * 0.28;
	n += noise3(p * 4.07 + vec3(6.2, 2.4, 9.1)) * 0.15;
	return n;
}


// ============================================================
// COLORFUL NEBULA
// ============================================================

vec3 generate_nebula(vec3 dir) {
	if (nebula_coverage <= 0.001 || nebula_strength <= 0.001) {
		return vec3(0.0);
	}

	vec3 p = dir * nebula_scale;
	p += vec3(
		TIME * nebula_speed,
		TIME * nebula_speed * 0.31,
		-TIME * nebula_speed * 0.43
	);

	float broad = noise3(p);
	float detail = fbm(p * nebula_detail + vec3(2.3, 5.7, 1.9));

	float threshold = 0.77 - nebula_coverage * 0.40;
	float cloud = smoothstep(threshold, threshold + 0.13, broad * 0.65 + detail * 0.55);

	float wisps = smoothstep(0.28, 0.78, detail);
	cloud *= mix(0.55, 1.0, wisps);

	float purple = smoothstep(0.32, 0.72, detail);
	float pink = smoothstep(0.57, 0.84, broad * detail * 1.55);
	float cyan = smoothstep(0.48, 0.78, broad + detail * 0.35);

	vec3 col = mix(nebula_blue, nebula_purple, purple);
	col = mix(col, nebula_pink, pink * 0.72);
	col = mix(col, nebula_cyan, cyan * 0.68);

	// Bright cloud cores make the nebula readable at low resolution.
	float core = smoothstep(0.58, 0.91, broad) * cloud;
	col += vec3(0.18, 0.19, 0.65) * core;

	return col * cloud * nebula_strength;
}


// ============================================================
// STARS: BIGGER, COLORED, MOSTLY STABLE
// ============================================================

vec3 generate_stars(vec3 dir) {
	vec3 col = vec3(0.0);

	vec3 grid = dir * star_density;
	vec3 cell = floor(grid);
	vec3 local = fract(grid) - 0.5;

	float seed = hash31(cell);

	if (seed > 1.0 - star_amount * 0.43) {
		vec3 offset = vec3(
			hash31(cell + vec3(11.2, 3.4, 7.1)),
			hash31(cell + vec3(2.8, 17.1, 5.3)),
			hash31(cell + vec3(6.7, 9.2, 21.4))
		) * 0.66 - 0.33;

		float d = length(local - offset);
		float size_seed = hash31(cell + vec3(4.1, 8.3, 2.7));

		// Deliberately larger for pixel-art rendering.
		float size = mix(0.026, 0.085, size_seed);
		float star = 1.0 - smoothstep(size * 0.35, size, d);

		float phase = hash31(cell + vec3(5.4, 3.7, 9.1)) * 6.28318;
		float pulse = 1.0 - twinkle_amount * 0.5
			+ twinkle_amount * 0.5
			* sin(TIME * twinkle_speed + phase);

		float temp = hash31(cell + vec3(2.1, 4.8, 7.3));

		vec3 star_col = mix(
			vec3(0.60, 0.77, 1.0),
			vec3(1.0, 0.68, 0.40),
			smoothstep(0.65, 0.96, temp) * star_color_variety
		);

		star_col = mix(
			star_col,
			vec3(0.35, 0.92, 1.0),
			hash31(cell + vec3(7.3, 2.2, 4.9))
				* star_color_variety * 0.28
		);

		col += star_col * star * pulse
			* mix(0.45, 1.0, size_seed) * star_brightness;
	}

	// Rare, very visible stars with a soft halo.
	vec3 big_grid = dir * 22.0;
	vec3 big_cell = floor(big_grid);
	vec3 big_local = fract(big_grid) - 0.5;

	float big_seed = hash31(big_cell + vec3(13.0, 5.0, 2.0));

	if (big_seed > 1.0 - bright_star_amount * 0.075) {
		vec3 offset = vec3(
			hash31(big_cell + vec3(3.0, 7.0, 1.0)),
			hash31(big_cell + vec3(8.0, 2.0, 6.0)),
			hash31(big_cell + vec3(5.0, 9.0, 4.0))
		) * 0.28 - 0.14;

		float d = length(big_local - offset);
		float core = 1.0 - smoothstep(0.014, 0.045, d);
		float halo = exp(-d * 15.0);

		vec3 big_col = mix(
			vec3(0.45, 0.78, 1.0),
			vec3(1.0, 0.55, 0.32),
			hash31(big_cell + vec3(4.0, 6.0, 9.0))
		);

		col += big_col * (core * 2.1 + halo * 0.30)
			* star_brightness;
	}

	return col;
}


// ============================================================
// SPIRAL GALAXY
// ============================================================

vec3 generate_galaxy(vec3 dir) {
	if (show_galaxy < 0.5) {
		return vec3(0.0);
	}

	vec3 center = normalize(vec3(-0.62, 0.25, -0.74));
	vec3 right = normalize(cross(center, vec3(0.0, 1.0, 0.0)));
	vec3 up = normalize(cross(right, center));

	float facing = dot(dir, center);
	if (facing <= 0.0) {
		return vec3(0.0);
	}

	vec2 uv = vec2(dot(dir, right), dot(dir, up)) / facing;
	uv /= galaxy_scale;

	float radius = length(uv);
	float angle = atan(uv.y, uv.x);

	float disc = exp(-radius * 3.6);
	float core = exp(-radius * 20.0);

	float arms = 0.5 + 0.5 * cos(angle * 2.0 - radius * 18.0);
	arms = pow(arms, 3.0);

	float edge = 1.0 - smoothstep(0.75, 1.15, radius);
	float dust = noise3(vec3(uv * 7.0, 2.1));

	float spiral = disc * (0.22 + arms * 0.78) * edge;
	spiral *= mix(0.55, 1.0, dust);

	vec3 galaxy_col = mix(
		vec3(0.18, 0.22, 1.0),
		vec3(0.95, 0.16, 0.65),
		smoothstep(0.1, 0.8, radius)
	);

	galaxy_col += vec3(0.95, 0.55, 0.25) * core * 2.0;

	return galaxy_col * (spiral * 1.25 + core * 0.9)
		* objects_brightness;
}


// ============================================================
// PLANETS
// ============================================================

// Angular disc with simple day/night lighting.
vec3 planet(
	vec3 dir,
	vec3 center,
	float radius,
	vec3 base_color,
	vec3 light_dir
) {
	center = normalize(center);

	float facing = dot(dir, center);
	float angle = acos(clamp(facing, -1.0, 1.0));

	if (angle > radius * 1.3) {
		return vec3(0.0);
	}

	float disc = 1.0 - smoothstep(radius * 0.94, radius, angle);

	vec3 tangent = normalize(dir - center * facing);
	float shade = clamp(dot(normalize(center + tangent * (angle / radius)),
		normalize(light_dir)) * 0.5 + 0.5, 0.08, 1.0);

	float rim = exp(-abs(angle - radius * 0.93) * 85.0);

	vec3 result = base_color * shade * disc;
	result += vec3(0.08, 0.65, 1.0) * rim * disc * 0.65;

	return result;
}

vec3 generate_planets(vec3 dir) {
	if (show_planets < 0.5) {
		return vec3(0.0);
	}

	vec3 col = vec3(0.0);

	// Large blue planet on the right.
	col += planet(
		dir,
		vec3(0.82, -0.32, -0.47),
		0.17,
		vec3(0.025, 0.14, 0.48),
		vec3(-0.5, 0.4, 0.8)
	);

	// Smaller warm moon on the left.
	col += planet(
		dir,
		vec3(-0.78, -0.48, -0.42),
		0.065,
		vec3(0.48, 0.12, 0.24),
		vec3(-0.4, 0.6, 0.8)
	);

	// Small distant turquoise world near the top.
	col += planet(
		dir,
		vec3(0.12, 0.78, -0.61),
		0.038,
		vec3(0.04, 0.34, 0.42),
		vec3(-0.3, 0.7, 0.6)
	);

	// Ringed planet: projected elliptical ring around its center.
	vec3 center = normalize(vec3(0.55, 0.36, -0.75));
	vec3 right = normalize(cross(center, vec3(0.0, 1.0, 0.0)));
	vec3 up = normalize(cross(right, center));

	float facing = dot(dir, center);
	if (facing > 0.0) {
		vec2 p = vec2(dot(dir, right), dot(dir, up)) / facing;
		p.y *= 0.38;

		float r = length(p);
		float ring = smoothstep(0.105, 0.115, r)
			* (1.0 - smoothstep(0.22, 0.235, r));

		vec3 ring_col = mix(
			vec3(0.22, 0.38, 0.95),
			vec3(0.9, 0.30, 0.72),
			smoothstep(0.11, 0.23, r)
		);

		col += ring_col * ring * objects_brightness;

		col += planet(
			dir,
			center,
			0.095,
			vec3(0.12, 0.055, 0.34),
			vec3(-0.5, 0.5, 0.6)
		);
	}

	return col * objects_brightness;
}


// ============================================================
// FINAL COMPOSITION
// ============================================================

void sky() {
	vec3 dir = normalize(EYEDIR);

	// Звёзды медленно вращаются вокруг оси Y.
	float star_angle = TIME * star_drift_speed;
	float cs = cos(star_angle);
	float sn = sin(star_angle);

	vec3 star_dir = normalize(vec3(
		dir.x * cs - dir.z * sn,
		dir.y,
		dir.x * sn + dir.z * cs
	));

	// Весь слой крупных объектов получает отдельный дрейф.
	float object_angle = TIME * object_drift_speed;
	float oc = cos(object_angle);
	float os = sin(object_angle);

	vec3 object_dir = normalize(vec3(
		dir.x * oc - dir.z * os,
		dir.y,
		dir.x * os + dir.z * oc
	));

	vec3 color = background_color;

	// Туманность продолжает двигаться через TIME внутри функции.
	color += generate_nebula(dir);

	// Галактика и планеты используют движущееся направление.
	color += generate_galaxy(object_dir);
	color += generate_planets(object_dir);

	// Звёзды двигаются немного быстрее крупных объектов.
	color += generate_stars(star_dir);

	COLOR = color;
}
