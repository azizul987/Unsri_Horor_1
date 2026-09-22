shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform sampler2D butterfly_texture : source_color, filter_nearest;
uniform float flap_speed : hint_range(0.0, 60.0) = 35.0;
uniform float flap_amount : hint_range(0.0, 1.5) = 0.6;

// Settingan Emission (Cahaya Pendaran Glow di Kegelapan)
uniform bool enable_emission = true;
uniform vec4 emission_color : source_color = vec4(0.5, 0.9, 0.6, 1.0); // Warna pendaran (contoh: hijau mistis)
uniform float emission_energy : hint_range(0.0, 10.0) = 2.5;            // Kekuatan terang cahaya

void vertex() {
	// Menjaga partikel tetap menghadap kamera (Billboard) dan mempertahankan ukuran partikel
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]
	);

	// Tekukan kepakan sayap: kiri & kanan mengepak bolak-balik
	float flap = sin(TIME * flap_speed);
	VERTEX.z += abs(VERTEX.x) * flap * flap_amount;
}

void fragment() {
	vec4 tex = texture(butterfly_texture, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	// Aktifkan pendaran cahaya (Glow / Emission)
	if (enable_emission) {
		EMISSION = tex.rgb * emission_color.rgb * emission_energy;
	}
}
