shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, unshaded;

// ============================================================================
// 🔥 SHADER LIDAH API KEBAKARAN HUTAN (FOREST FIRE FLAME)
// ============================================================================

uniform sampler2D flame_texture : source_color, filter_linear_mipmap;
uniform bool use_texture = false;

// Parameter Warna Api
uniform vec4 color_core : source_color = vec4(1.0, 0.95, 0.5, 1.0);  // Inti panas (kuning keputihan)
uniform vec4 color_flame : source_color = vec4(1.0, 0.45, 0.05, 1.0); // Lidah api (oranye membara)
uniform vec4 color_tip : source_color = vec4(0.8, 0.1, 0.0, 0.0);    // Ujung api (merah tua)

// Gerakan & Bentuk Lidah Api
uniform float flame_speed : hint_range(0.5, 15.0) = 4.0;
uniform float flame_waviness : hint_range(0.0, 2.0) = 0.35;
uniform float emission_boost : hint_range(1.0, 10.0) = 2.5;

void vertex() {
	// Menjaga partikel selalu menghadap kamera (Billboard) dengan skala tetap
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	vec2 uv = UV;
	
	// Efek kibasan lidah api ke atas
	float wave = sin(uv.y * 7.0 - TIME * flame_speed) * flame_waviness * (1.0 - uv.y);
	uv.x += wave * 0.15;
	
	float alpha_shape = 0.0;
	if (use_texture) {
		vec4 tex = texture(flame_texture, uv);
		alpha_shape = tex.a * tex.r;
	} else {
		// Bentuk tetesan lidah api prosedural (tidak perlu file gambar eksternal)
		vec2 center = vec2(0.5, 0.7);
		vec2 d = uv - center;
		float taper = mix(1.8, 0.6, clamp(uv.y, 0.0, 1.0));
		float dist = length(vec2(d.x * taper, d.y * 1.1));
		alpha_shape = smoothstep(0.48, 0.05, dist);
		
		// Noise bergerigi sederhana di tepi lidah api
		float noise = sin(uv.y * 18.0 + TIME * flame_speed * 1.5) * cos(uv.x * 14.0 - TIME * flame_speed);
		alpha_shape *= clamp(1.0 + noise * 0.25, 0.0, 1.0);
	}
	
	// Gradasi warna vertikal api dari inti hingga ujung
	float vert_factor = clamp(uv.y, 0.0, 1.0);
	vec3 final_color = mix(color_tip.rgb, mix(color_flame.rgb, color_core.rgb, vert_factor), vert_factor);
	
	// Padukan dengan vertex color partikel
	final_color *= COLOR.rgb * emission_boost;
	float final_alpha = alpha_shape * COLOR.a;
	
	ALBEDO = final_color;
	ALPHA = final_alpha;
}
