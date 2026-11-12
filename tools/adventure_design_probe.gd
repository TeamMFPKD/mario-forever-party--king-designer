extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 无头自检：把四套方案各建一遍，确认没有脚本/布局报错。

const PATHS: Array[String] = [
	"res://tools/adventure_design/scheme_a_paper.gd",
	"res://tools/adventure_design/scheme_b_stage.gd",
	"res://tools/adventure_design/scheme_c_neon.gd",
	"res://tools/adventure_design/scheme_d_poster.gd",
]
const OUTPUT: String = "res://tools/design_probe.txt"


func _ready() -> void:
	var lines: PackedStringArray = PackedStringArray()
	for index: int in range(PATHS.size()):
		var script: GDScript = load(PATHS[index]) as GDScript
		if script == null:
			lines.append("SCHEME_%d LOAD_FAIL" % index)
			continue
		var scheme: Control = script.new() as Control
		if scheme == null:
			lines.append("SCHEME_%d INSTANCE_FAIL" % index)
			continue
		scheme.size = Vector2(1920, 1080)
		add_child(scheme)
		scheme.call("build")
		lines.append("SCHEME_%d OK children=%d" % [index, scheme.get_child_count()])
		scheme.queue_free()
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	get_tree().quit()
