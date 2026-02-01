shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float distortion = 0.015;
uniform float time_glow = 0.2;
uniform float time_speed = 3.0;
uniform float chromatic_aberration = 0.003;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = vec2(0.5);
    
    // Distorsión radial temporal (como si el tiempo se doblara)
    float dist = distance(uv, center);
    float time_warp = sin(TIME * time_speed + dist * 8.0) * distortion;
    
    // Ondas circulares temporales
    float ring = sin(dist * 20.0 - TIME * 4.0) * 0.5 + 0.5;
    ring *= smoothstep(0.8, 0.3, dist);
    
    // Aplicar distorsión temporal
    vec2 distorted_uv = center + (uv - center) * (1.0 + time_warp);
    
    // Aberración cromática para efecto de distorsión temporal
    float aberration = chromatic_aberration * (1.0 + sin(TIME * 2.0) * 0.5);
    float r = texture(SCREEN_TEXTURE, distorted_uv + vec2(aberration, 0.0)).r;
    float g = texture(SCREEN_TEXTURE, distorted_uv).g;
    float b = texture(SCREEN_TEXTURE, distorted_uv - vec2(aberration, 0.0)).b;
    
    vec4 screen = vec4(r, g, b, 1.0);
    
    // Pulsos de energía temporal
    float pulse = 0.6 + 0.4 * sin(TIME * time_speed);
    
    // Anillos de tiempo azules/cian
    float edge = smoothstep(0.3, 0.8, dist);
    vec3 time_color = vec3(0.2, 0.6, 1.0); // Azul cian brillante
    
    // Efecto de reloj (líneas radiales)
    float angle = atan(uv.y - 0.5, uv.x - 0.5);
    float clock_lines = smoothstep(0.98, 1.0, cos(angle * 12.0 + TIME * 2.0)) * edge;
    
    // Aplicar efectos temporales
    screen.rgb += time_color * edge * time_glow * pulse;
    screen.rgb += time_color * ring * 0.3;
    screen.rgb += time_color * clock_lines * 0.4;
    
    // Brillo en el centro (epicentro temporal)
    float center_glow = smoothstep(0.3, 0.0, dist) * 0.15;
    screen.rgb += time_color * center_glow * pulse;
    
    // Efecto de distorsión temporal en los bordes
    float time_vignette = smoothstep(0.6, 1.0, dist);
    screen.rgb = mix(screen.rgb, screen.rgb * time_color, time_vignette * 0.2);
    
    COLOR = screen;
}
