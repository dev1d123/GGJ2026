shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float distortion = 0.003;
uniform float glow = 0.12;

void fragment() {
    vec2 uv = SCREEN_UV;

    float wave = sin(TIME * 2.0 + uv.y * 10.0) * distortion;
    uv.x += wave;

    vec4 screen = texture(SCREEN_TEXTURE, uv);

    float dist = distance(uv, vec2(0.5));
    float edge = smoothstep(0.4, 0.8, dist);

    screen.rgb += vec3(edge * glow, edge * glow, 0.0);

    COLOR = screen;
}
