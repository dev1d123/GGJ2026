shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float intensity : hint_range(0.0, 1.0) = 0.25;
uniform float pulse_speed = 1.5;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 screen = texture(SCREEN_TEXTURE, uv);

    float dist = distance(uv, vec2(0.5));
    float vignette = smoothstep(0.45, 0.75, dist);

    float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
    float red_overlay = vignette * intensity * pulse;

    screen.rgb += vec3(red_overlay * 0.6, 0.0, 0.0);
    COLOR = screen;
}

