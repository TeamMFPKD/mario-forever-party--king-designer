shader_type canvas_item;

// 无尽团存档卡的卡面填充：多色渐变 + 滚动。
//
// 只画卡面内部：圆角用圆角矩形 SDF 切（不依赖 clip_children，它只按矩形裁），
// 描边仍是 Button 自己的 StyleBoxFlat border，所以本节点要按描边宽度内缩。
//
// style 选风格，band_soft 控制色带交界是硬边还是柔和过渡：
//   0 = 干净斜向色带（默认）
//   1 = 波浪色带（沿垂直方向起伏）
//   2 = 旋转色环（绕中心转）
//   3 = 液态流动（域扭曲噪声，像颜料在流动）
//   4 = 双色扫光（只有两个颜色，一抹高光扫过）

uniform int style = 0;
// 0.5 = 两色各占一半、交界柔和；越小色带越窄、交界越硬
uniform float band_soft = 0.5;

// 默认配色是「低饱和彩虹」压亮度、提明度后的奶白变种（变种表里的 D5）：
// 粉红 / 浅黄 / 薄荷 / 天蓝，四色都被推到高明度低饱和，放在浅灰白底上不抢眼，
// 又能与定量团的白卡区分开。原始 D 组色值 #E89AA0 / #E8D69A / #9ADFA8 / #9AC2E8
// 统一做了 sat x0.85、val x1.08。
uniform vec4 color_a : source_color = vec4(0.983, 0.702, 0.723, 1.000);
uniform vec4 color_b : source_color = vec4(0.983, 0.918, 0.702, 1.000);
uniform vec4 color_c : source_color = vec4(0.696, 0.944, 0.746, 1.000);
uniform vec4 color_d : source_color = vec4(0.702, 0.846, 0.983, 1.000);

// 一组完整四色周期的波长（像素）：越大色块越宽
uniform float brush_px = 210.0;
// 斜向角度（度）：0 = 竖直条纹，90 = 水平波纹
uniform float angle_deg = 34.0;
// 滚动速度（每秒推进多少像素）
uniform vec2 scroll_speed = vec2(30.0, -12.0);
// 顶部玻璃高光强度：0 = 关闭
uniform float gloss = 0.12;
// 白光扫过的周期（秒）与强度：0 = 关闭
uniform float sheen_period = 5.0;
uniform float sheen_strength = 0.0;
uniform float value_mul = 1.0;
uniform float saturation = 1.0;

// 由脚本写入：当前绘制区域实际像素尺寸、内缩后的圆角半径
uniform vec2 width_px = vec2(339.0, 76.0);
uniform float corner_radius_px = 4.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		sum += vnoise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return sum;
}

// 四色环：t 为周期数（1.0 = 绕一圈）。band_soft 越小交界越硬。
vec3 ramp(float t, float soft) {
	float x = fract(t) * 4.0;
	float i = floor(min(x, 3.999));
	float f = x - i;
	f = smoothstep(0.5 - soft, 0.5 + soft, f);
	vec3 c0 = color_a.rgb;
	vec3 c1 = color_b.rgb;
	vec3 c2 = color_c.rgb;
	vec3 c3 = color_d.rgb;
	if (i < 1.0) {
		return mix(c0, c1, f);
	} else if (i < 2.0) {
		return mix(c1, c2, f);
	} else if (i < 3.0) {
		return mix(c2, c3, f);
	}
	return mix(c3, c0, f);
}

float rounded_box_sdf(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - (half_size - vec2(radius));
	return length(max(q, vec2(0.0))) - radius;
}

void fragment() {
	float rad = radians(angle_deg);
	vec2 dir = vec2(cos(rad), sin(rad));
	vec2 perp = vec2(-dir.y, dir.x);
	vec2 px = UV * width_px;
	vec2 drift = scroll_speed * TIME;

	float along = dot(px + drift, dir) / brush_px;
	float across = dot(px, perp) / brush_px;

	vec3 paint;
	float t = 0.0;

	if (style == 0) {
		t = along;
		paint = ramp(t, band_soft);
	} else if (style == 1) {
		t = along + 0.16 * sin(across * 3.4 + TIME * 0.5);
		paint = ramp(t, band_soft);
	} else if (style == 2) {
		vec2 p = px - width_px * 0.5;
		float ang = atan(p.y, p.x) / TAU + TIME * 0.03;
		t = ang * 1.0 + length(p) / brush_px * 0.35;
		paint = ramp(t, band_soft);
	} else if (style == 3) {
		vec2 q = px / brush_px + drift / brush_px * 0.5;
		float warp = fbm(q * 1.6) - 0.5;
		t = (q.x + q.y) * 0.9 + warp * 0.55;
		paint = ramp(t, band_soft);
	} else {
		// 双色：低频波把两色揉在一起，再叠一抹扫光
		float w = 0.5 + 0.5 * sin(along * TAU * 0.5);
		paint = mix(color_a.rgb, color_c.rgb, w);
		float sweep = 1.0 - smoothstep(0.0, 0.35, abs(fract(TIME / max(sheen_period, 0.001)) * 1.6 - UV.x + UV.y * 0.4));
		paint = mix(paint, vec3(1.0), sweep * max(sheen_strength, 0.25));
	}

	// 白扫光（style 4 已自带，跳过）
	if (style != 4 && sheen_strength > 0.0) {
		float sp = fract(TIME / max(sheen_period, 0.001));
		float sx = UV.x + UV.y * 0.5;
		float s = 1.0 - smoothstep(0.0, 0.20, abs(sx - (sp * 1.7 - 0.35)));
		paint = mix(paint, vec3(1.0), s * sheen_strength);
	}

	// 顶部玻璃高光：让卡面有"油漆未干"的湿润感
	if (gloss > 0.0) {
		float g = smoothstep(0.55, 0.0, UV.y) * gloss;
		paint = mix(paint, vec3(1.0), g);
	}

	float luma = dot(paint, vec3(0.2126, 0.7152, 0.0722));
	paint = mix(vec3(luma), paint, saturation);
	paint *= value_mul;

	vec2 p = UV * width_px - width_px * 0.5;
	float d = rounded_box_sdf(p, width_px * 0.5, max(corner_radius_px, 0.0));
	COLOR = vec4(paint, clamp(0.5 - d, 0.0, 1.0));
}
