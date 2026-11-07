shader_type canvas_item;

uniform float i_time = 0.0;
uniform float i_time_total = 0.25;

void fragment() {
	float rate = clamp(i_time / max(i_time_total, 0.0001), 0.0, 1.0);
	// 两端平缓、中间偏快，淡出收尾更柔和
	float alpha = 1.0 - smoothstep(0.0, 1.0, rate);
	COLOR = vec4(texture(TEXTURE, UV).rgb, alpha);
}
