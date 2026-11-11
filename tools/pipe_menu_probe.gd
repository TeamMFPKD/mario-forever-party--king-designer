extends Node

@warning_ignore_start("unsafe_cast", "unsafe_property_access")

## 检查 pipe_menu.tscn 里每根水管在「未运行」状态下预设的贴图，确认编辑器里也能看到对应颜色。
## 运行：Godot --headless --path . res://tools/pipe_menu_probe.tscn

const OUTPUT: String = "res://tools/pipe_menu_probe_result.txt"


func _ready() -> void:
	var lines: Array[String] = []
	var packed: PackedScene = load("res://ui/title/pipe_menu.tscn") as PackedScene
	if packed == null:
		lines.append("load=false")
	else:
		var root: Node = packed.instantiate()
		for index: int in range(5):
			var pipe: Node = root.get_node_or_null("Pipe%d" % index)
			if pipe == null:
				lines.append("Pipe%d=missing" % index)
				continue
			var cap: TextureRect = pipe.get_node_or_null("Cap") as TextureRect
			var body: TextureRect = pipe.get_node_or_null("Body") as TextureRect
			lines.append("Pipe%d cap=%s body=%s export=%s" % [
				index,
				_atlas_path(cap),
				_atlas_path(body),
				_export_path(pipe),
			])
		root.free()
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	get_tree().quit()


func _atlas_path(node: TextureRect) -> String:
	if node == null or node.texture == null:
		return "<null>"
	var texture: Texture2D = node.texture
	if texture is AtlasTexture:
		var atlas: Texture2D = (texture as AtlasTexture).atlas
		if atlas != null:
			return atlas.resource_path.get_file()
	return texture.resource_path.get_file()


func _export_path(pipe: Node) -> String:
	var texture: Texture2D = pipe.get("pipe_texture") as Texture2D
	if texture == null:
		return "<null>"
	return texture.resource_path.get_file()
