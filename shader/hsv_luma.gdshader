// HSV 调整 —— 亮度补偿去色版（与 hsv_te.gdshader 参数名一致，可整块替换使用）
//
// 与既有 hsv_te.gdshader（CTF Effects\HSV.hlsl 逐行同源移植）的差异：
//  1) 去色灰阶：旧版 fS 走负向分支时把 S 收敛到 0，但 V 仍保留原像素的 max 通道，
//     于是灰阶 = max(r,g,b) —— 天空/高光/亮色素材去色后落在 0.9~1.0，视觉上就是"整屏发白"，
//     再叠一个正 value 更是直接全部顶到纯白（实测：蓝天 0.900→白、砖红 0.800→白）。
//     本版把负向饱和度写成"色度线性衰减 + 明度向感知亮度补偿"：
//         k = 1 + fS            (fS ∈ [-1,0] ⇒ k ∈ [0,1])
//         S' = S * k
//         V' = mix(V, 灰, )  灰 = Rec.709 亮度 = dot(rgb, vec3(0.2126, 0.7152, 0.0722))
//     fS = -1 ⇒ S' = 0 且 V' = 灰 ⇒ 输出真正的单色灰（去色），且亮度权重符合人眼观感。
//     灰锚点取**原像素**亮度、与色相参数无关 ⇒ 调 hue 不会让去色后的灰阶漂移。
//  2) 正向饱和度：旧版 fS>0 会把通道推成负值（实测红砖 → (0.800,-0.698,-0.800)），靠 LDR 裁剪
//     硬扛、导致偏色；本版改为把 S 推向 1（保色相、不溢出）。
//  3) hsv_to_rgb 不再对色相斜坡做 smoothstep 染色 ⇒ hue/saturation/value 全为 0 时
//     是**逐像素恒等变换**（旧版同参数下会把蓝天绿通道 0.550 拉到 0.515）。
//  4) rgb→hsv 用六段分支 + d>0 守卫，不靠 1e-10 硬撑，纯黑/纯灰像素无 NaN 风险。
//
// value 语义与旧版保持一致（HSV 的 V += fV 后 clamp），负向去色时作用在补偿后的灰阶上
// （fS=-1 ⇒ 灰阶 = 亮度 + fV）。
shader_type canvas_item;

uniform float hue: hint_range(-1.0, 1.0) = 0.0;
uniform float saturation: hint_range(-1.0, 1.0) = 0.0;
uniform float value: hint_range(-1.0, 1.0) = 0.0;

varying vec4 v_vertex_color;

void vertex() {
	v_vertex_color = COLOR;
}

// Rec.709 亮度权重
float luma709(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 rgb_to_hsv(vec3 c) {
	float mx = max(max(c.r, c.g), c.b);
	float mn = min(min(c.r, c.g), c.b);
	float d = mx - mn;
	float h = 0.0;
	// d = 0（纯灰/纯黑）时色相无意义，保持 0；先守卫再除，避免 NaN 与色相垃圾值
	if (d > 0.0) {
		float h6 = 0.0;
		if (mx == c.r) {
			h6 = (c.g - c.b) / d;
		} else if (mx == c.g) {
			h6 = (c.b - c.r) / d + 2.0;
		} else {
			h6 = (c.r - c.g) / d + 4.0;
		}
		// fract 等于 fposmod(x, 1.0)：把负色相也收进 [0,1)
		h = fract(h6 / 6.0);
	}
	return vec3(h, mx > 0.0 ? d / mx : 0.0, mx);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), clamp(c.y, 0.0, 1.0));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 hsv = rgb_to_hsv(tex.rgb);
	// 灰度锚点：原像素的感知亮度（与 hue 无关，保证去色后仍是"原来那张图"的明暗关系）
	float gray = luma709(tex.rgb);

	// 色相：±1.0 = 一整圈
	hsv.x = fract(hsv.x + hue);

	// 饱和度：fS<0 线性去色（k 递减到 0），fS>0 把 S 推向 1
	float k = clamp(1.0 + saturation, 0.0, 1.0);
	hsv.y = mix(hsv.y, 1.0, max(saturation, 0.0)) * k;
	// 明度：去色时收到灰阶（fS=-1 ⇒ V = gray），随后统一加 fV 并 clamp
	hsv.z = mix(hsv.z, gray, 1.0 - k) + value;
	hsv.z = clamp(hsv.z, 0.0, 1.0);
	hsv.y = clamp(hsv.y, 0.0, 1.0);

	COLOR = v_vertex_color * vec4(hsv_to_rgb(hsv), tex.a);
}
