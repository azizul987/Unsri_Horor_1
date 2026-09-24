shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

// ============================================================================
// ✨ SHADER BARA API & PERCIKAN PIJAR (FOREST FIRE EMBERS / SPARKS)
// ============================================================================

uniform vec4 ember_color : source_color = vec4(1.0, 0.65, 0.15, 1.0); // Pijar bara oranye terang
uniform float pulse_speed : hint_range(1.0, 20.0) = 8.0;
uniform float glow_intensity : hint_range(1.0, 10.0) = 4.0;

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
	float dist = length(UV - vec2(0.5));
	// Titik bara berpijar tajam di tengah dan memudar lembut ke tepi
	float glow = smoothstep(0.48, 0.02, dist);
	
	// Kelap-kelip pendaran bara yang beterbangan
	float pulse = 0.8 + 0.3 * sin(TIME * pulse_speed + UV.x * 12.0);
	
	ALBEDO = ember_color.rgb * COLOR.rgb * glow_intensity * pulse;
	ALPHA = glow * COLOR.a;
}
