shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

void fragment() {
	vec2 uv  = UV * 2.0 - 1.0; // -1..1
	float dist = length(uv);
	if (dist > 1.0) discard;

	float t     = TIME;
	float angle = atan(uv.y, uv.x); // -PI..PI

	// ── Grilla de coordenadas táctica ────────────────────────────────
	vec2 grid_uv = uv * 9.0;
	float gx   = abs(fract(grid_uv.x) - 0.5);
	float gy   = abs(fract(grid_uv.y) - 0.5);
	float grid = smoothstep(0.48, 0.44, min(gx, gy)) * 0.18 * (1.0 - smoothstep(0.6, 0.95, dist));
	grid *= (1.0 - dist * 0.7);

	// ── Barrido tipo radar ───────────────────────────────────────────
	// age = 0 → recién barrido (brillante), approaching 1 → a punto de ser barrido (oscuro)
	float point_norm = fract((angle / (TAU)) + 0.5);  // 0..1
	float sweep_norm = fract(t * 0.38);              // 0..1, ~2.6 seg por vuelta
	float age        = fract(point_norm - sweep_norm + 1.0);

	float trail_len  = 0.38;
	float sweep_trail = max(0.0, 1.0 - age / trail_len);
	sweep_trail = pow(sweep_trail, 1.6) * smoothstep(0.04, 0.14, dist);

	// Línea frontal brillante del barrido
	float sweep_edge = smoothstep(0.028, 0.0, age) * smoothstep(0.04, 0.1, dist) * 2.2
					 + smoothstep(0.972, 1.0, age) * smoothstep(0.04, 0.1, dist) * 2.2;

	// ── Anillos de alcance ───────────────────────────────────────────
	float rim_outer = pow(smoothstep(0.97, 1.0, dist) + smoothstep(1.0, 0.97, dist), 2.0) * 1.2;
	float r_mid     = abs(dist - 0.66);
	float rim_mid   = smoothstep(0.012, 0.0, r_mid) * 0.55;
	float r_inner   = abs(dist - 0.33);
	float rim_inner = smoothstep(0.012, 0.0, r_inner) * 0.35;

	// ── Cruz cardinal (N/S/E/W) ──────────────────────────────────────
	float cross_h = smoothstep(0.007, 0.0, abs(uv.y)) * (1.0 - smoothstep(0.0, 0.98, abs(uv.x))) * 0.22;
	float cross_v = smoothstep(0.007, 0.0, abs(uv.x)) * (1.0 - smoothstep(0.0, 0.98, abs(uv.y))) * 0.22;

	// ── "Ping" en el borde del barrido: pequeños destellos ──────────
	float ping_dist = abs(dist - 0.33) + abs(dist - 0.66) + abs(dist - 0.99);
	float ping = smoothstep(0.018, 0.0, ping_dist) * smoothstep(0.015, 0.0, age) * 3.0;

	// ── Núcleo central ───────────────────────────────────────────────
	float core = (1.0 - smoothstep(0.0, 0.07, dist)) * 1.4;

	// ── Pulso global ─────────────────────────────────────────────────
	float pulse = sin(t * 5.5) * 0.08 + 0.92;

	float brightness = (grid
		+ sweep_trail * 0.75 + sweep_edge
		+ rim_outer + rim_mid + rim_inner
		+ cross_h + cross_v
		+ ping + core) * pulse;

	// Fade suave hacia el borde exterior
	brightness *= smoothstep(1.0, 0.88, dist);

	// ── Color: verde-cian tecnológico ────────────────────────────────
	vec3 cyan    = vec3(0.0,  1.0,  0.9);
	vec3 teal    = vec3(0.0,  0.75, 0.4);
	vec3 white   = vec3(0.7,  1.0,  1.0);
	vec3 col = mix(teal, cyan, dist * 0.7 + sweep_trail * 0.5);
	col = mix(col, white, clamp(core + sweep_edge * 0.3 + ping * 0.6, 0.0, 1.0));

	ALBEDO = col * brightness;
	ALPHA  = clamp(brightness * 0.22, 0.0, 0.38);
}
