shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec4 outer_color : source_color = vec4(0.055, 0.11, 0.13, 1.0);
uniform vec4 inner_color : source_color = vec4(0.12, 0.24, 0.25, 1.0);
uniform float rain_blend = 0.0;
varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float distance_from_delta = length(world_position * vec2(0.9, 1.0));
	vec3 lagoon = mix(inner_color.rgb, outer_color.rgb, smoothstep(4.0, 23.0, distance_from_delta));
	float island_shadow = 1.0 - smoothstep(5.5, 8.5, length((world_position - vec2(0.7, 0.8)) * vec2(1.0, 1.06)));
	lagoon *= 1.0 - island_shadow * 0.36;
	ALBEDO = mix(lagoon, lagoon * vec3(0.82, 0.91, 1.05), rain_blend);
}
