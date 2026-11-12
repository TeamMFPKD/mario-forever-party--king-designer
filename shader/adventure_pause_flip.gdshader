shader_type canvas_item;

// 暂停菜单 3D 翻转：把细分网格按 Y 轴旋转并做透视投影。
// 正面 = 关卡视口贴图 + 外边框贴图合成；背面 = 暂停卡片视口贴图。
// 两者在 90° 侧对镜头时切换，切换瞬间不可见。

uniform float yaw = 0.0;
uniform float pitch = 0.0;
uniform float roll = 0.0;
uniform float perspective = 1700.0;
uniform float shade = 1.0;
uniform vec2 inner_min = vec2(0.0);
uniform vec2 inner_size = vec2(1.0);
uniform sampler2D level_tex : hint_default_black;
uniform sampler2D border_tex : hint_default_transparent;
uniform sampler2D card_tex : hint_default_transparent;

void vertex() {
	vec3 v = vec3(VERTEX.x, VERTEX.y, 0.0);

	float cy = cos(yaw);
	float sy = sin(yaw);
	v = vec3(v.x * cy, v.y, v.x * sy);

	float cp = cos(pitch);
	float sp = sin(pitch);
	v = vec3(v.x, v.y * cp - v.z * sp, v.y * sp + v.z * cp);

	float w = perspective / max(perspective + v.z, 1.0);
	vec2 s = vec2(v.x * w, v.y * w);

	float cr = cos(roll);
	float sr = sin(roll);
	VERTEX = vec2(s.x * cr - s.y * sr, s.x * sr + s.y * cr);
}

void fragment() {
	vec4 out_color;
	// 用同一个 yaw 决定正反面，几何与贴图永远同帧一致（不会出现换面的滞后跳变）。
	if (abs(yaw) < 1.5707963) {
		// 关卡贴图只贴内框，装饰边框单独保留，避免翻转时视口被放大盖住边框。
		vec2 luv = (UV - inner_min) / inner_size;
		float inside = step(0.0, luv.x) * step(luv.x, 1.0) * step(0.0, luv.y) * step(luv.y, 1.0);
		vec4 bg = texture(level_tex, clamp(luv, vec2(0.0), vec2(1.0)));
		vec4 bd = texture(border_tex, UV);
		out_color = mix(bd, vec4(bg.rgb, 1.0), inside);
	} else {
		vec2 uv = UV;
		// 转过 90° 后网格几何是镜像的，UV 再翻一次，卡片文字才是正的。
		uv.x = 1.0 - uv.x;
		out_color = texture(card_tex, uv);
	}
	COLOR = vec4(out_color.rgb * shade, out_color.a);
}
