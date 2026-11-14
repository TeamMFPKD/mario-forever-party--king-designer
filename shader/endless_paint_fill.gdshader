shader_type canvas_item;

// 无尽团存档卡的卡面填充：流动的多色渐变（多颜色渐变油漆桶），并且一直在滚动。
//
// 分工：
//   * 本 shader 只画**卡面内部**，圆角在这里用 SDF 切（不依赖 clip_children，
//     Control 的 clip_children 只按矩形裁，切不出圆角）。
//   * 描边仍是 Button 自己的 StyleBoxFlat border；因此本节点要按描边宽度内缩，
//     见 adventure_slot_paint.gd 的 inset_px。
//   * 四种按钮状态（normal / hover / pressed / hover_pressed）照旧由样式表管。
//
// 颜色相位按**控件自身像素尺寸**换算（width_px / height_px 由脚本按实测矩形写入），
// 换分辨率时色块大小不会跟着缩水。

// 四色循环：色相拉开，相邻两色之间自然过渡
uniform vec4 color_a : source_color = vec4(1.000, 0.235, 0.188, 1.000);
uniform vec4 color_b : source_color = vec4(1.000, 0.831, 0.094, 1.000);
uniform vec4 color_c : source_color = vec4(0.180, 0.702, 1.000, 1.000);
uniform vec4 color_d : source_color = vec4(0.353, 0.902, 0.435, 1.000);

// 色块尺度（像素）：一组完整色带的波长，越小色块越碎
uniform float brush_width_px = 210.0;
uniform float brush_height_px = 210.0;
// 斜向角度（度）：0 = 竖直条纹，90 = 水平波纹
uniform float angle_deg = 34.0;
// 滚动速度（每秒推进多少像素，负值反向）
uniform vec2 scroll_speed = vec2(46.0, -22.0);
// 白色高光扫过的周期（秒）与强度：0 = 关闭
uniform float sheen_period = 4.5;
uniform float sheen_strength = 0.18;
// 明度与饱和度（脚本按选中态调）
uniform float value_mul = 1.0;
uniform float saturation = 1.0;

// 由脚本写入：当前绘制区域实际像素尺寸、内缩后的圆角半径
uniform vec2 width_px = vec2(208.0, 76.0);
uniform float corner_radius_px = 6.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// 平铺值噪声：让色块边界不是一条死板的直线
float tile_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 圆角矩形 SDF：返回负值表示在内部
float rounded_box_sdf(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - (half_size - vec2(radius));
	return length(max(q, vec2(0.0))) - radius;
}

void fragment() {
	float rad = radians(angle_deg);
	vec2 dir = vec2(cos(rad), sin(rad));

	// 像素坐标 → 归一化到"一个色带波长 = 1"的坐标系
	vec2 scale = vec2(max(brush_width_px, 1.0), max(brush_height_px, 1.0));
	vec2 px = UV * width_px;
	vec2 drift = scroll_speed * TIME / scale;
	float along = dot(px / scale, dir) - dot(drift, dir);

	// 主色带 + 细碎刷痕：主带负责分色，噪声只把边界揉毛，避免糊成一团
	float w1 = sin(along * TAU);
	float w3 = tile_noise(px * 0.08 + drift * 1.3) * 2.0 - 1.0;
	float sweep = w1 * 0.78 + w3 * 0.22;

	// 把 -1..1 映射到 0..4，在四色环上插值
	float ring_t = clamp(sweep * 0.5 + 0.5, 0.0, 1.0) * 4.0;
	float idx = floor(min(ring_t, 3.999));
	float t = smoothstep(0.0, 1.0, fract(ring_t));

	vec3 c0 = color_a.rgb;
	vec3 c1 = color_b.rgb;
	vec3 c2 = color_c.rgb;
	vec3 c3 = color_d.rgb;
	vec3 paint;
	if (idx < 1.0) {
		paint = mix(c0, c1, t);
	} else if (idx < 2.0) {
		paint = mix(c1, c2, t);
	} else if (idx < 3.0) {
		paint = mix(c2, c3, t);
	} else {
		paint = mix(c3, c0, t);
	}

	// 斜向高光：一抹白光周期性扫过，静态截图也能看出"在动"
	float sheen_pos = fract(TIME / max(sheen_period, 0.001));
	float sheen_x = UV.x + UV.y * 0.55;
	float sheen = 1.0 - smoothstep(0.0, 0.16, abs(sheen_x - (sheen_pos * 1.7 - 0.35)));
	paint = mix(paint, vec3(1.0), sheen * sheen_strength);

	// 明度 / 饱和度
	float luma = dot(paint, vec3(0.2126, 0.7152, 0.0722));
	paint = mix(vec3(luma), paint, saturation);
	paint *= value_mul;

	// 圆角裁切（1px 抗锯齿）
	vec2 p = UV * width_px - width_px * 0.5;
	float d = rounded_box_sdf(p, width_px * 0.5, max(corner_radius_px, 0.0));
	float mask = clamp(0.5 - d, 0.0, 1.0);

	COLOR = vec4(paint, mask);
}
