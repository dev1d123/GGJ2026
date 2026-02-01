shader_type canvas_item;

// --- CONFIGURACIÓN ---
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// COLORES Y BRILLO
uniform vec4 tint_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.1; // Qué tanto colorea
uniform float brightness : hint_range(0.0, 2.0) = 1.0;

// DISTORSIÓN (Curvatura del casco)
uniform float lens_distortion : hint_range(0.0, 0.5) = 0.05;

// ABERRACIÓN CROMÁTICA (Separación RGB)
uniform float aberration_amount : hint_range(0.0, 10.0) = 1.0;

// VIÑETA (Bordes oscuros)
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.4;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.5;

// SCANLINES (Líneas TV)
uniform float scanline_alpha : hint_range(0.0, 1.0) = 0.05;
uniform float scanline_count : hint_range(0.0, 1080.0) = 100.0;

// PULSACIÓN (Para la Ulti)
uniform bool is_pulsing = false;
uniform float pulse_speed = 5.0;

// --- FUNCIONES MATEMÁTICAS ---

vec2 distort_uv(vec2 uv) {
	// Fórmula de distorsión de barril
	vec2 cc = uv - 0.5;
	float dist = dot(cc, cc);
	return uv + cc * (dist * lens_distortion);
}

void fragment() {
	// 1. Aplicar Distorsión de Lente
	vec2 distorted_uv = distort_uv(SCREEN_UV);

	// Si la distorsión se sale de la pantalla, pintamos negro (bordes del casco)
	if (distorted_uv.x < 0.0 || distorted_uv.x > 1.0 || distorted_uv.y < 0.0 || distorted_uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {

		// 2. Aberración Cromática (Separar canales)
		// El rojo y el azul se separan más cuanto más lejos del centro
		float dist_from_center = length(distorted_uv - 0.5);

		// Calculamos offset dinámico (si pulsa, se mueve más)
		float final_aberration = aberration_amount * 0.005 * dist_from_center;
		if (is_pulsing) {
			final_aberration *= (1.0 + sin(TIME * pulse_speed) * 0.5);
		}

		float r = texture(screen_texture, distorted_uv - vec2(final_aberration, 0.0)).r;
		float g = texture(screen_texture, distorted_uv).g;
		float b = texture(screen_texture, distorted_uv + vec2(final_aberration, 0.0)).b;

		vec3 final_color = vec3(r, g, b);

		// 3. Aplicar Tinte de Máscara
		final_color = mix(final_color, tint_color.rgb * final_color, tint_amount);

		// 4. Scanlines (Efecto rejilla)
		float scanline = sin(distorted_uv.y * scanline_count * 3.14159 * 2.0);
		final_color -= scanline * scanline_alpha;

		// 5. Viñeta (Oscurecer esquinas)
		float vignette = 1.0 - smoothstep(1.0 - vignette_intensity, 1.0 - vignette_intensity + vignette_softness, length(UV - 0.5) * 1.5);
		final_color *= vignette;

		// 6. Brillo Final
		COLOR = vec4(final_color * brightness, 1.0);
	}
}