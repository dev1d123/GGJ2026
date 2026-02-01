shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float focus_strength = 0.25;
uniform float scanline_strength = 0.06;
uniform float crosshair_intensity = 0.15;
uniform float zoom_pulse_speed = 1.5;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center = vec2(0.5);
    
    // Efecto de enfoque tipo francotirador
    float dist = distance(uv, center);
    float focus_ring = smoothstep(0.25, 0.3, dist) * smoothstep(0.6, 0.4, dist);
    float center_clarity = smoothstep(0.5, 0.15, dist);
    
    // Zoom pulse (respira)
    float zoom_pulse = 0.95 + 0.05 * sin(TIME * zoom_pulse_speed);
    vec2 zoomed_uv = center + (uv - center) * zoom_pulse;
    
    vec4 screen = texture(SCREEN_TEXTURE, zoomed_uv);
    
    // Scanlines horizontales tipo mira táctica
    float scanline = sin(uv.y * 800.0 + TIME * 50.0) * scanline_strength;
    
    // Líneas de retícula (crosshair grid)
    float grid_x = smoothstep(0.498, 0.5, abs(uv.x - 0.5));
    float grid_y = smoothstep(0.498, 0.5, abs(uv.y - 0.5));
    float crosshair = (grid_x + grid_y) * crosshair_intensity;
    
    // Círculo de enfoque en el centro
    float focus_circle = smoothstep(0.22, 0.23, dist) * smoothstep(0.24, 0.23, dist);
    
    // Aplicar efectos verdes (visión nocturna/tecnológica)
    screen.rgb += vec3(0.0, focus_ring * focus_strength, 0.0);
    screen.rgb += vec3(0.0, center_clarity * 0.1, 0.0);
    screen.rgb += vec3(0.0, scanline * 0.8, 0.0);
    screen.rgb += vec3(0.0, crosshair, 0.0);
    screen.rgb += vec3(0.0, focus_circle * 0.3, 0.0);
    
    // Vignette oscuro en los bordes
    float vignette = smoothstep(0.7, 0.3, dist);
    screen.rgb *= 0.7 + 0.3 * vignette;
    
    COLOR = screen;
}
