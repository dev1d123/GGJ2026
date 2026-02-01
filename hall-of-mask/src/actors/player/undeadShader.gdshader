shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float desaturation = 0.6;
uniform float necro_glow = 0.25;
uniform float pulse_speed = 1.2;
uniform float dark_vignette = 0.4;

// Función de ruido para partículas necróticas
float noise(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 screen = texture(SCREEN_TEXTURE, uv);
    
    // Desaturación progresiva (mundo de muerte)
    float gray = dot(screen.rgb, vec3(0.299, 0.587, 0.114));
    screen.rgb = mix(screen.rgb, vec3(gray), desaturation);
    
    // Pulso necrótico
    float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
    
    // Distancia desde el centro
    float dist = distance(uv, vec2(0.5));
    
    // Vignette oscuro pesado
    float vignette = smoothstep(0.2, 1.0, dist);
    screen.rgb *= (1.0 - vignette * dark_vignette);
    
    // Partículas flotantes necróticas
    float particles = 0.0;
    for(float i = 0.0; i < 3.0; i++) {
        vec2 particle_uv = uv * (5.0 + i) + vec2(TIME * 0.1 * (i + 1.0), TIME * 0.15 * (i + 1.0));
        float particle = noise(particle_uv);
        particles += step(0.98, particle) * (1.0 - i / 3.0);
    }
    
    // Brillo morado necrótico en los bordes
    float edge_glow = smoothstep(0.4, 0.9, dist) * pulse;
    vec3 necro_color = vec3(0.5, 0.1, 0.7); // Morado oscuro
    
    // Efecto de energía necrótica
    float necro_energy = edge_glow * necro_glow;
    screen.rgb += necro_color * necro_energy;
    
    // Agregar partículas brillantes
    screen.rgb += necro_color * particles * 0.4;
    
    // Tinte morado general sutil
    screen.rgb += necro_color * 0.08 * pulse;
    
    // Oscurecer aún más el centro para efecto dramático
    screen.rgb *= 0.85 + 0.15 * (1.0 - smoothstep(0.0, 0.5, dist));
    
    COLOR = screen;
}
