shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

void fragment() {
	// Center UV en -1..1
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);

	// Descartar fuera del circulo
	if (dist > 1.0) discard;

	float t = TIME;
	float angle = atan(uv.y, uv.x);

	// ── Anillos que se expanden hacia afuera ──────────────────────────
	float rings  = sin(dist * 18.0 - t * 6.0) * 0.5 + 0.5;
	rings = pow(rings, 3.0) * 0.7;

	// Segundo anillo mas lento y mas grueso (profundidad)
	float rings2 = sin(dist * 8.0 - t * 3.5 + 1.2) * 0.5 + 0.5;
	rings2 = pow(rings2, 2.0) * 0.35;

	// ── Rayos/Espadas rotatorias ──────────────────────────────────────
	float spokes = sin(angle * 6.0 - t * 2.5) * 0.5 + 0.5;
	spokes = pow(spokes, 6.0) * smoothstep(0.05, 0.35, dist) * 0.8;

	// Segundo set de rayos contra-rotatorio
	float spokes2 = sin(angle * 4.0 + t * 1.8) * 0.5 + 0.5;
	spokes2 = pow(spokes2, 8.0) * smoothstep(0.1, 0.5, dist) * 0.5;

	// ── Borde exterior brillante ──────────────────────────────────────
	float rim = pow(smoothstep(0.65, 1.0, dist), 0.6);

	// ── Nucleo central ────────────────────────────────────────────────
	float core = (1.0 - smoothstep(0.0, 0.18, dist)) * 0.9;

	// ── Pulso global ──────────────────────────────────────────────────
	float pulse = sin(t * 8.0) * 0.12 + 0.88;

	float brightness = (rings + rings2 + spokes + spokes2 + rim + core) * pulse;

	// Fade suave hacia el borde exterior
	float fade = smoothstep(1.0, 0.82, dist);
	brightness *= fade;

	// ── Color: dorado -> naranja segun distancia ──────────────────────
	vec3 gold   = vec3(1.0,  0.90, 0.05);
	vec3 orange = vec3(1.0,  0.30, 0.0);
	vec3 white  = vec3(1.0,  0.98, 0.85);
	vec3 col = mix(gold, orange, dist * dist);
	// Refuerzo blanco en el nucleo y en el borde
	col = mix(col, white, clamp(core * 1.2 + rim * 0.4, 0.0, 1.0));

	ALBEDO = col * brightness;
	// blend_add: ALPHA controla cuanta luz se suma (~ligeramente transparente)
	ALPHA  = clamp(brightness * 0.55, 0.0, 0.80);
}
