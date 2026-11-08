shader_type canvas_item;
render_mode blend_mix;

// 标题画面 Ad 按钮的 hover 光晕：以图片 alpha 为轮廓，向外扩散并羽化成白色描边。
// 光晕由一个比按钮更大的 Sprite2D 承载（show_behind_parent），
// 因此 UV 0..1 覆盖的是“按钮 + 四周留白”，需要按像素坐标反推原图 UV。

// 显式传入原图，避免依赖 Sprite2D 的内置 TEXTURE（自定义函数内不可见）
uniform sampler2D source_texture : hint_default_transparent, filter_linear, repeat_disable;
// 贴边描边色 / 外围羽化色（亮背景上外围略偏冷更容易看清，改回纯白即可）
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 glow_color_outer : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
// 0 = 完全隐藏，1 = 扩散到 max_radius
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// 光晕最大外扩距离（像素）
uniform float max_radius : hint_range(0.0, 96.0) = 36.0;
// 贴边实心描边宽度（像素）
uniform float edge_width : hint_range(0.0, 12.0) = 3.0;
// hover 时的呼吸脉动幅度（0 = 关闭）
uniform float pulse_strength : hint_range(0.0, 0.5) = 0.15;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.6;
// 白光外侧的淡冷暗晕：把亮背景稍微压暗，白光才有轮廓（0 = 关闭）
uniform vec4 shadow_color : source_color = vec4(0.24, 0.34, 0.5, 1.0);
uniform float shadow_strength : hint_range(0.0, 0.6) = 0.22;
// 当前绘制区域（按钮 + 留白）与图片区域的实际像素尺寸
uniform vec2 node_size_px = vec2(1.0);
uniform vec2 image_size_px = vec2(1.0);

const int RING_COUNT = 3;
const int DIRECTION_COUNT = 12;

float image_alpha(vec2 px) {
	vec2 uv = (px - (node_size_px - image_size_px) * 0.5) / image_size_px;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(source_texture, uv).a;
}

// 圆环采样求加权平均 alpha：越外圈权重越低，形成羽化
float blur_halo(vec2 px, float radius) {
	float sum = image_alpha(px);
	float weight_sum = 1.0;

	for (int ring = 1; ring <= RING_COUNT; ring++) {
		float ring_t = float(ring) / float(RING_COUNT);
		float ring_radius = radius * ring_t;
		float weight = 1.0 - ring_t * 0.72;
		for (int i = 0; i < DIRECTION_COUNT; i++) {
			float angle = (float(i) + 0.5 * float(ring)) / float(DIRECTION_COUNT) * TAU;
			vec2 offset = vec2(cos(angle), sin(angle)) * ring_radius;
			sum += image_alpha(px + offset) * weight;
			weight_sum += weight;
		}
	}

	return sum / weight_sum;
}

// 形态学膨胀：取邻域 alpha 最大值，得到一圈边缘锐利的实心描边
float dilate_alpha(vec2 px, float radius) {
	float result = image_alpha(px);

	for (int i = 0; i < DIRECTION_COUNT; i++) {
		float angle = (float(i) + 0.5) / float(DIRECTION_COUNT) * TAU;
		vec2 dir = vec2(cos(angle), sin(angle));
		result = max(result, image_alpha(px + dir * radius));
		result = max(result, image_alpha(px + dir * radius * 0.5));
	}

	return result;
}

void fragment() {
	if (amount <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 px = UV * node_size_px;
		// 呼吸：亮度与半径一起轻微起伏，让亮背景上的光晕更容易被察觉
		float breath = 0.5 + 0.5 * sin(TIME * pulse_speed);
		float radius = max_radius * amount * (1.0 - pulse_strength * (0.5 - 0.5 * breath));
		float brightness = 1.0 - pulse_strength * (0.5 - 0.5 * breath);

		// 三层：贴边实心白描边 → 中层亮雾 → 外围羽化
		float edge = smoothstep(0.3, 0.65, dilate_alpha(px, edge_width));
		float inner = smoothstep(0.08, 0.55, blur_halo(px, radius * 0.45));
		float outer = smoothstep(0.02, 0.6, blur_halo(px, radius));

		float halo = max(edge, max(inner * 0.95, outer * 0.65));
		vec3 color = mix(glow_color_outer.rgb, glow_color.rgb, max(edge, inner));

		float glow_alpha = clamp(halo * amount * intensity * brightness, 0.0, 1.0);
		// 白光外侧压一层很淡的冷暗色，让白光在明亮场景里有轮廓
		float shadow_alpha = shadow_strength * smoothstep(0.0, 0.55, outer) * (1.0 - glow_alpha) * amount;
		float out_alpha = glow_alpha + shadow_alpha * (1.0 - glow_alpha);
		vec3 out_color = (color * glow_alpha + shadow_color.rgb * shadow_alpha * (1.0 - glow_alpha)) / max(out_alpha, 0.0001);

		COLOR = vec4(out_color, out_alpha);
	}
}
