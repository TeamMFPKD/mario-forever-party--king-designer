shader_type canvas_item;

// 颜色筛选 + 改色
//
// 用途：按「筛选色」把贴图里的某种颜色挑出来，统一换成「目标色」，
// 其余像素一律丢弃成透明——相当于一次性感的阈值抠色，但只认一种颜色。
//
// 参数：
//   filter_color   要筛选的颜色，默认黑。贴图里接近这个颜色的像素会被保留。
//   target_color   保留下来的像素统一渲染成这个颜色，默认白。
//   tolerance      判定阈值（0~1），越大吃进的近似色越多。默认 0.02 对像素图足够。
//   keep_alpha     关闭后连原图本身的透明通道一起忽略，全部按不透明处理。
//
// 典型用法：把纯黑描边的贴图换成任意描边色，或从精灵表里抠出某一种主色做剪影。

uniform vec4 filter_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 target_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tolerance : hint_range(0.0, 0.5) = 0.02;
uniform bool keep_alpha = true;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// 原图透明的地方直接丢弃，避免把整块矩形都染上目标色。
	if (keep_alpha && tex.a <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		// 按 RGB 三通道最大差值判定「同色」。
		// 用 max 而不是欧氏距离：颜色只要有一路对不上就判定为不同，
		// 对调色板贴图（纯色块）来说更严格，也不会被抗锯齿边缘骗过去。
		vec3 diff = abs(tex.rgb - filter_color.rgb);
		float dist = max(diff.r, max(diff.g, diff.b));

		if (dist <= tolerance) {
			COLOR = vec4(target_color.rgb, target_color.a * tex.a);
		} else {
			COLOR = vec4(0.0);
		}
	}
}

// 极像素风格：关掉纹理过滤插值，放大时不糊边
//（在节点上把 texture_filter 设为 Nearest 效果相同，这里留着说明用途）
