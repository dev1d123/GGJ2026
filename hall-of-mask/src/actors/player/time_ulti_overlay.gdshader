shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 1.0; // 1=full, 0=done
uniform float strength : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec2 uv = UV;

	// Distorsión de chromatic aberration suave en los bordes
	float dist_edge = length(uv - vec2(0.5)) * 2.0;
	float aberr = dist_edge * 0.012 * strength;
	float r = texture(TEXTURE, uv + vec2(aberr, 0.0)).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, uv - vec2(aberr, 0.0)).b;

	// Viñeta azul-cian en los bordes
	float vignette = smoothstep(0.45, 1.0, dist_edge);
	vec3 vign_color = vec3(0.0, 0.55, 1.0);

	vec3 base = vec3(r, g, b);
	base = mix(base, vign_color, vignette * strength * 0.5);

	// Tinte azul helado global muy sutil
	base = mix(base, vec3(0.05, 0.3, 0.8), 0.08 * strength);

	COLOR.rgb = base;
	COLOR.a = vignette * strength * 0.6 + 0.05 * strength;
}
