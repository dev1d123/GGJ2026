shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// strength: 0 = normal, 1 = teletransporte completo
uniform float strength : hint_range(0.0, 1.0) = 0.0;

// Pseudo-random
float rand(vec2 co) {
	return fract(sin(dot(co, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv     = SCREEN_UV;
	vec2 center = vec2(0.5);
	vec2 to_c   = center - uv;
	float dc    = length(to_c);
	float s     = strength;
	float s2    = s * s;

	// ── 1. IMPLOSIÓN ESPACIAL ─────────────────────────────────────────
	// Las UV se aprietan hacia el centro como si el espacio se plegara
	float fold = s2 * 4.5 * smoothstep(0.85, 0.0, dc);
	vec2  warp_uv = uv + to_c * fold;

	// ── 2. GLITCH — BANDAS HORIZONTALES DESPLAZADAS ───────────────────
	float gt     = floor(TIME * 24.0);
	float band_h = 0.03 + rand(vec2(gt, 1.3)) * 0.07;
	float band   = floor(warp_uv.y / band_h);
	float chance = rand(vec2(band, gt));
	float goff   = 0.0;
	if (chance > (1.0 - s * 0.75)) {
		goff = (rand(vec2(band + 0.5, gt)) - 0.5) * 0.14 * s;
	}
	warp_uv.x += goff;

	// ── 3. SCANLINES DE ENERGÍA ────────────────────────────────────────
	float scan = pow(sin(warp_uv.y * 200.0 + TIME * 30.0) * 0.5 + 0.5, 7.0) * s * 0.35;

	// ── 4. ABERRACIÓN CROMÁTICA RADIAL ─────────────────────────────────
	// Crece drásticamente con strength²
	float aberr    = s2 * 0.055 + 0.001;
	vec2  dir_aberr = normalize(warp_uv - center + vec2(0.0001));

	float cr = texture(SCREEN_TEXTURE, clamp(warp_uv + dir_aberr * aberr * 3.0, vec2(0.0), vec2(1.0))).r;
	float cg = texture(SCREEN_TEXTURE, clamp(warp_uv,                            vec2(0.0), vec2(1.0))).g;
	float cb = texture(SCREEN_TEXTURE, clamp(warp_uv - dir_aberr * aberr * 3.0, vec2(0.0), vec2(1.0))).b;
	vec3 col = vec3(cr, cg, cb);

	// ── 5. VIGNETTE DE ENERGÍA (oscurece los bordes) ──────────────────
	float vig = smoothstep(0.1, 0.65, dc) * s * 0.9;
	col *= (1.0 - vig);

	// ── 6. GRIETAS / RAYOS DE ENERGÍA (cian brillante) ────────────────
	// Líneas radiales tenues que surgen del centro
	float angle  = atan(uv.y - 0.5, uv.x - 0.5);
	float cracks = pow(abs(sin(angle * 8.0 + TIME * 6.0)), 12.0) * s * 0.6
				 * smoothstep(0.08, 0.5, dc);
	vec3 cyan = vec3(0.25, 0.88, 1.0);
	col = mix(col, cyan, clamp(cracks + scan, 0.0, 0.7) * s);

	// ── 7. PULSO DE NEBULOSA — color violeta/añil ────────────────────
	float nebula = s2 * smoothstep(0.45, 0.05, dc) * 0.55;
	col = mix(col, vec3(0.45, 0.15, 1.0), nebula);

	// ── 8. FLASH BLANCO al pico (s > 0.82)─────────────────────────────
	float flash = smoothstep(0.82, 1.0, s);
	col = mix(col, vec3(1.0), flash);

	COLOR = vec4(col, 1.0);
}
