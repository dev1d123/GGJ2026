shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float intensity : hint_range(0.0, 1.0) = 0.4;
uniform float pulse_speed = 2.5;
uniform float heat_distortion = 0.003;
uniform float flame_intensity = 0.3;

// Función de ruido para efecto de fuego
float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Distorsión de calor (heat waves)
    float heat_wave = sin(uv.y * 20.0 + TIME * 3.0) * cos(uv.x * 15.0 + TIME * 2.5);
    vec2 distorted_uv = uv + vec2(heat_wave * heat_distortion, heat_wave * heat_distortion * 0.5);
    
    vec4 screen = texture(SCREEN_TEXTURE, distorted_uv);
    
    // Vignette rojo intenso
    float dist = distance(uv, vec2(0.5));
    float vignette = smoothstep(0.3, 0.9, dist);
    
    // Pulso de fuego
    float pulse = 0.6 + 0.4 * sin(TIME * pulse_speed);
    
    // Efecto de llamas en los bordes
    float flame_noise = random(vec2(uv.x * 10.0, uv.y * 5.0 + TIME * 2.0));
    float flame = flame_noise * vignette * flame_intensity * pulse;
    
    // Overlay rojo-naranja con efecto de fuego
    vec3 fire_color = vec3(1.0, 0.3, 0.0); // Naranja-rojo
    screen.rgb += fire_color * (vignette * intensity * pulse + flame);
    
    // Aumentar contraste en el centro
    screen.rgb = mix(screen.rgb, screen.rgb * 1.2, 1.0 - vignette);
    
    COLOR = screen;
}

