shader_type canvas_item;

uniform float i_time = 0.0;
uniform float i_time_total = 1.0;

void fragment() {
	float rate = i_time / i_time_total;
	COLOR = vec4(texture(TEXTURE, UV).rgb, 1.0 * (1.0 - rate));
}