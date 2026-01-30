shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float desaturation = 0.35;
uniform float glow_strength = 0.15;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 screen = texture(SCREEN_TEXTURE, uv);

    float gray = dot(screen.rgb, vec3(0.299, 0.587, 0.114));
    screen.rgb = mix(screen.rgb, vec3(gray), desaturation);

    float dist = distance(uv, vec2(0.5));
    float edge = smoothstep(0.5, 0.85, dist);

    screen.rgb += vec3(edge * glow_strength);

    COLOR = screen;
}
