extends Node

## 检查 level_node.tscn 的实例化结果：number_label 是否解析、setup 是否生效、
## 场景里改的样式（字号）是否真的被运行时读到。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const RESULT_PATH: String = "res://tools/adventure_level_node_probe_result.txt"


func _ready() -> void:
	var lines: Array[String] = []
	var packed: PackedScene = load("res://object/adventure/level_node.tscn") as PackedScene
	lines.append("scene_loaded=%s" % str(packed != null))
	if packed == null:
		_write(lines)
		get_tree().quit()
		return

	var cell: AdventureLevelNode = packed.instantiate()
	lines.append("cell_type=%s" % cell.get_class())
	lines.append("cell_script=%s" % str(cell.get_script() != null))
	lines.append("export_label_null=%s" % str(cell.number_label == null))
	var raw: Variant = cell.get("number_label")
	lines.append("raw_type=%s" % type_string(typeof(raw)))

	cell.setup(7, false)
	var number: Label = cell.get_node_or_null("Number") as Label
	lines.append("number_found=%s" % str(number != null))
	if number != null:
		lines.append("text_after_setup=%s" % number.text)
		lines.append("font_size=%d" % number.get_theme_font_size("font_size"))
		lines.append("font_color=%s" % number.get_theme_color("font_color").to_html(false))
		lines.append("outline_size=%d" % number.get_theme_constant("outline_size"))

	cell.setup(3, true)
	if number != null:
		lines.append("text_endless=%s" % number.text)

	_write(lines)
	get_tree().quit()


func _write(lines: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
