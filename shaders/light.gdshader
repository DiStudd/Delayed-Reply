
shader_type canvas_item;

uniform sampler2D screen_tex :
	hint_screen_texture, repeat_disable, filter_nearest;

// Общая цветокоррекция
uniform float contrast : hint_range(0.7, 1.6) = 1.2;
uniform float saturation : hint_range(0.0, 1.5) = 1.2;
uniform float color_levels : hint_range(3.0, 16.0) = 12.0;

// Цвет теней и светлых участков
uniform vec4 shadow_tint : source_color =
	vec4(0.12, 0.20, 0.23, 1.0);

uniform vec4 light_tint : source_color =
	vec4(1.0, 0.91, 0.76, 1.0);

uniform float shadow_strength :
	hint_range(0.0, 0.8) = 0.38;

uniform float light_strength :
	hint_range(0.0, 0.4) = 0.48;

// Атмосфера
uniform float vignette_strength :
	hint_range(0.0, 0.6) = 0.36;

uniform float grain_strength :
	hint_range(0.0, 0.1) = 0.04;

uniform float scanline_strength :
	hint_range(0.0, 0.15) = 0.056;

// Дополнительная пикселизация.
// 1 = не увеличиваем пиксели повторно.
uniform int pixel_block_size :
	hint_range(1, 4) = 1;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	float block_size = float(max(pixel_block_size, 1));

	// Привязка выборки к сетке пикселей
	vec2 block = SCREEN_PIXEL_SIZE * block_size;
	vec2 uv = (floor(SCREEN_UV / block) + 0.5) * block;
	uv = clamp(uv, block * 0.5, vec2(1.0) - block * 0.5);

	vec3 col = textureLod(screen_tex, uv, 0.0).rgb;

	// Контраст и насыщенность
	col = (col - 0.5) * contrast + 0.5;

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	col = clamp(col, 0.0, 1.0);

	// Затемняем преимущественно тёмные участки.
	// Реальные тени должны быть включены в 3D-сцене.
	float shadows = 1.0 - smoothstep(0.12, 0.58, lum);
shadows = pow(shadows, 1.25);
	col = mix(col, col * shadow_tint.rgb,
		shadows * shadow_strength);

	// Слегка согреваем яркие участки
	float highlights = smoothstep(0.48, 0.88, lum);
	col = mix(col, col * light_tint.rgb,
		highlights * light_strength);

	// Уменьшаем количество оттенков
	col = floor(clamp(col, 0.0, 1.0) * color_levels + 0.5)
		/ color_levels;

	// Мягкая виньетка
	vec2 centered = SCREEN_UV - vec2(0.5);
	centered.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	float edge = smoothstep(0.25, 0.72, length(centered));
	col *= 1.0 - edge * vignette_strength;

	// Незаметное зерно, привязанное к пиксельной сетке
	vec2 noise_cell = floor(FRAGCOORD.xy / block_size);
	float grain = hash21(noise_cell) - 0.5;
	col += grain * grain_strength;

	// Необязательные горизонтальные полосы
	float scanline = mod(floor(FRAGCOORD.y), 2.0);
	col *= 1.0 - scanline * scanline_strength;

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
