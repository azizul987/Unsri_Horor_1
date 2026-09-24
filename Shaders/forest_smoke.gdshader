shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// ============================================================================
// 💨 SHADER ASAP PEKAT KEBAKARAN HUTAN (FOREST FIRE SMOKE)
// ============================================================================

uniform vec4 smoke_color_base : source_color = vec4(0.22, 0.15, 0.1, 0.85); // Abu pekat dekat api
uniform vec4 smoke_color_top : source_color = vec4(0.06, 0.06, 0.06, 0.0);   // Abu-abu hitam pekat di udara
uniform float smoke_density : hint_range(0.1, 2.0) = 1.0;

void vertex() {
	// Billboard: selalu menghadap kamera dan menjaga ukuran partikel
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	vec2 d = UV - vec2(0.5);
	float dist = length(d);
	
	// Bentuk gumpalan asap melingkar dengan tepi lembut (soft cloud puff)
	float puff = smoothstep(0.48, 0.05, dist);
	
	// Turbulensi organik gumpalan asap
	float turbulence = sin(UV.x * 10.0 + TIME * 0.5) * cos(UV.y * 10.0 - TIME * 0.7);
	puff *= clamp(1.0 + turbulence * 0.22, 0.0, 1.0);
	
	// Transisi warna asap
	vec3 col = mix(smoke_color_base.rgb, smoke_color_top.rgb, clamp(1.0 - COLOR.a, 0.0, 1.0));
	
	ALBEDO = col * COLOR.rgb;
	ALPHA = puff * COLOR.a * smoke_density;
}
