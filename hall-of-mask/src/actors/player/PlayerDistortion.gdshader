shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;

	float wave = sin((uv.y + TIME * 2.0) * 40.0) * 0.03 * strength;
	uv.x += wave;

	COLOR = texture(SCREEN_TEXTURE, uv);
}
