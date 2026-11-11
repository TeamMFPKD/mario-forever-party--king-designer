extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 无头探针：确认五套标题画面按钮方案都能无报错构建。
## 运行：Godot --headless --path . res://tools/title_design_probe.tscn
## 判据：结果文件里 5 行都是 SCHEME_n OK。

const OUTPUT: String = "res://tools/title_design_probe_result.txt"

const SCHEME_PATHS: Array[String] = [
	"res://tools/title_design/scheme_a_arcade.gd",
	"res://tools/title_design/scheme_b_rail.gd",
	"res://tools/title_design/scheme_c_hero.gd",
	"res://tools/title_design/scheme_d_ring.gd",
	"res://tools/title_design/scheme_e_grid.gd",
	"res://tools/title_design/scheme_f_pipe.gd",
]


func _ready() -> void:
	var lines: Array[String] = []
	for index: int in range(SCHEME_PATHS.size()):
		var script: GDScript = load(SCHEME_PATHS[index]) as GDScript
		if script == null:
			lines.append("SCHEME_%d LOAD_FAIL" % index)
			continue
		var instance: Object = script.new()
		var scheme: Control = instance as Control
		if scheme == null:
			lines.append("SCHEME_%d INSTANCE_FAIL" % index)
			continue
		add_child(scheme)
		scheme.size = TitleKit.CANVAS
		scheme.call("build")
		lines.append("SCHEME_%d OK children=%d" % [index, scheme.get_child_count()])
		remove_child(scheme)
		scheme.queue_free()
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	get_tree().quit()
