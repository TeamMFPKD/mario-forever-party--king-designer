shader_type canvas_item;

// 困难档的景物入场：自下而上逐像素显示（越靠上的像素越晚出现）。
// 每个 Sprite2D 自己带 material，用 panel_y0/panel_y1 告诉它在这块面板里占的竖向区间，
// 这样面板上所有景物共享同一条「由下往上」的波纹，而不是各擦各的。
//   reveal = 0 → 全隐藏；reveal = 1 → 全显示。

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float softness : hint_range(0.001, 1.0) = 0.14;
uniform float panel_y0 : hint_range(0.0, 1.0) = 0.0;
uniform float panel_y1 : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// 该片元在整个面板里的竖向位置：0 = 面板顶，1 = 面板底
	float t = clamp(panel_y0 + UV.y * (panel_y1 - panel_y0), 0.0, 1.0);
	// 越靠上（t 越小）需要的 reveal 越大 → 越晚出现
	float need = 1.0 - t;
	float edge = reveal * (1.0 + softness);
	COLOR.a *= clamp((edge - need) / softness, 0.0, 1.0);
}
