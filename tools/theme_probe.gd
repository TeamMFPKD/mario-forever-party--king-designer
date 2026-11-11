extends Node

@warning_ignore_start("unsafe_cast")

## 打印全局主题 mfmp_theme.tres 里 Button / Label / Panel 的实际取值，确认改动生效。
## 运行：Godot --headless --path . res://tools/theme_probe.tscn

const OUTPUT: String = "res://tools/theme_probe_result.txt"


func _ready() -> void:
	var lines: Array[String] = []
	var theme: Theme = load("res://mfmp_theme.tres") as Theme
	if theme == null:
		lines.append("load=false")
	else:
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var box: StyleBox = theme.get_stylebox(state, "Button")
			lines.append("Button/%s=%s %s" % [state, box.get_class() if box else "<null>", _describe(box)])
		lines.append("Button/font_color=%s" % theme.get_color("font_color", "Button"))
		lines.append("Button/font_size=%d" % theme.get_font_size("font_size", "Button"))
		lines.append("Label/font_color=%s outline=%d outline_color=%s" % [
			theme.get_color("font_color", "Label"),
			theme.get_constant("outline_size", "Label"),
			theme.get_color("font_outline_color", "Label"),
		])
		var panel: StyleBox = theme.get_stylebox("panel", "Panel")
		lines.append("Panel/panel=%s" % (panel.get_class() if panel else "<builtin>"))
		var font: Font = theme.default_font
		lines.append("default_font=%s fallbacks=%d" % [
			font.get_font_name() if font else "<null>",
			(font as FontVariation).fallbacks.size() if font is FontVariation else -1,
		])
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	get_tree().quit()


func _describe(box: StyleBox) -> String:
	if box is StyleBoxFlat:
		var flat: StyleBoxFlat = box as StyleBoxFlat
		return "bg=%s border=%d color=%s radius=%d" % [
			flat.bg_color,
			flat.border_width_left,
			flat.border_color,
			flat.corner_radius_top_left,
		]
	return ""
