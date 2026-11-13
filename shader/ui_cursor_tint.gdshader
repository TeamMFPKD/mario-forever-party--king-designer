shader_type canvas_item;

// 四角光标着色：只把"原始红色填充"的像素替换成高亮色。
// 描边（近黑 #1A1A1A）与抗锯齿边缘因为颜色距离超出 tolerance，不会被误伤。
//
// 不用 modulate 做这件事的原因：红色 (0.91, 0.20, 0.16) 想变黄 (1.0, 0.77, 0.19)
// 需要把绿色通道乘以 ~3.8，而 modulate 作用在整张贴图上，黑色描边会被一起提亮成灰色。

uniform vec4 base_color = vec4(0.909804, 0.203922, 0.164706, 1.0);
uniform vec4 highlight_color = vec4(1.0, 0.772549, 0.192157, 1.0);
uniform float highlight_amount : hint_range(0.0, 1.0) = 0.0;
uniform float tolerance : hint_range(0.01, 0.5) = 0.12;

void fragment() {
	float d = distance(COLOR.rgb, base_color.rgb);
	float mask = 1.0 - smoothstep(tolerance * 0.5, tolerance, d);
	COLOR.rgb = mix(COLOR.rgb, highlight_color.rgb, mask * highlight_amount);
}
