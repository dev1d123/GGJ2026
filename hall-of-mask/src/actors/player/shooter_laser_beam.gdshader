shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

// Fade controlado desde GDScript al morir el rayo
uniform float alpha_mult : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// UV.x = alrededor del cilindro (0..1)
	// UV.y = a lo largo del eje del cilindro (0 = base, 1 = punta)
	float along = UV.y;
	float t     = TIME;

	// ── Cuerpo base del rayo ─────────────────────────────────────────
	// El cilindro es delgado, siempre se ve brillante
	float base_glow = 0.65;

	// ── Streaks de energía moviéndose hacia el objetivo ──────────────
	float s1 = fract(along * 2.0 - t * 8.0);
	float streak1 = exp(-abs(s1 - 0.5) * 20.0) * 0.9;

	float s2 = fract(along * 3.5 - t * 12.0 + 0.4);
	float streak2 = exp(-abs(s2 - 0.5) * 28.0) * 0.65;

	float s3 = fract(along * 1.5 - t * 5.5 + 0.75);
	float streak3 = exp(-abs(s3 - 0.5) * 16.0) * 0.5;

	// Streak contra-dirección para efecto de tensión eléctrica
	float s4 = fract(along * 2.8 + t * 6.0 + 0.2);
	float streak4 = exp(-abs(s4 - 0.5) * 35.0) * 0.35;

	// ── Destello en punta (impacto) ──────────────────────────────────
	float impact_glow = smoothstep(0.78, 1.0, along) * 1.2;

	// ── Destello en la base (origen) ────────────────────────────────
	float origin_glow = smoothstep(0.22, 0.0, along) * 0.6;

	// ── Fade en los extremos para evitar bordes duros ────────────────
	float tip_fade = smoothstep(0.0, 0.06, along) * smoothstep(1.0, 0.94, along);

	// ── Pulso de alta frecuencia (parpadeo eléctrico) ────────────────
	float flicker = sin(t * 22.0 + along * 18.0) * 0.07 + 0.93;

	float brightness = (base_glow + streak1 + streak2 + streak3 + streak4
		+ impact_glow + origin_glow) * tip_fade * flicker;

	// ── Color: blanco → cian → azul eléctrico ────────────────────────
	vec3 white      = vec3(1.0,  1.0,  1.0);
	vec3 cyan_bright= vec3(0.4,  1.0,  1.0);
	vec3 cyan_deep  = vec3(0.0,  0.85, 1.0);
	vec3 blue_elec  = vec3(0.1,  0.45, 1.0);

	float streak_total = clamp(streak1 + streak2 + streak3 + streak4, 0.0, 1.0);
	vec3 col = mix(cyan_deep, cyan_bright, streak_total);
	col = mix(col, white,      clamp(streak_total * 1.4 - 0.6, 0.0, 1.0));
	col = mix(col, blue_elec,  clamp(1.0 - streak_total - base_glow * 0.5, 0.0, 0.4));
	// Punta de impacto más blanca/brillante
	col = mix(col, white, clamp(impact_glow * 0.7, 0.0, 1.0));

	ALBEDO = col * brightness;
	ALPHA  = clamp(brightness * alpha_mult, 0.0, 1.0);
}
