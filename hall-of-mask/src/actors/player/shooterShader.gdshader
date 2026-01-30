shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float focus_strength = 0.15;
uniform float scanline_strength = 0.04;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 screen = texture(SCREEN_TEXTURE, uv);

    float dist = distance(uv, vec2(0.5));
    float focus = smoothstep(0.6, 0.2, dist);

    float scanline = sin(uv.y * 1200.0) * scanline_strength;

    screen.rgb += vec3(0.0, focus * focus_strength, 0.0);
    screen.rgb += vec3(0.0, scanline, 0.0);

    COLOR = screen;
}
