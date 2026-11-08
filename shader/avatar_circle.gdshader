shader_type canvas_item;

// 头像圆形裁切：把正方形区域的贴图裁成圆形，圆外完全透明，边缘做 1 像素抗锯齿。
// 用法：挂在头像 TextureRect 的 material 上，节点保持正方形、
// stretch_mode = Keep Aspect Covered（非正方形素材会居中裁切而不是留黑边）。

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 2.0;
	float edge = max(fwidth(dist), 0.0001);
	COLOR.a *= 1.0 - smoothstep(1.0 - edge, 1.0, dist);
}
