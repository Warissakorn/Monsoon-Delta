shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform vec4 water_color : source_color = vec4(0.21, 0.58, 0.62, 0.76);
uniform float motion_scale : hint_range(0.0, 1.0) = 1.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// World space keeps the quiet ripples continuous across neighboring hexes.
	// The surface never moves, so rendered water and picking share one height.
	vec2 p = world_position.xz;
	float time = TIME * motion_scale;
	float ripple = sin(p.x * 18.0 + p.y * 10.0 + time * 0.9);
	float cross_wave = sin(p.y * 15.0 - p.x * 5.0 - time * 0.6);
	float glint = smoothstep(0.87, 0.99, ripple) * smoothstep(0.1, 0.85, cross_wave);
	float slow_wave = sin(p.x * 2.3 + p.y * 3.1 + time * 0.35) * 0.025;
	ALBEDO = water_color.rgb * (0.96 + slow_wave) + vec3(0.28, 0.38, 0.32) * glint * 0.34;
	ROUGHNESS = 0.27 - glint * 0.08;
	METALLIC = 0.08;
	SPECULAR = 0.52;
	EMISSION = water_color.rgb * 0.025;
	ALPHA = water_color.a;
}
