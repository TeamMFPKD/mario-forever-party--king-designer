extends Node

@warning_ignore_start("unsafe_cast", "unsafe_property_access")

## 截 HostPage / JoinPage 的「参与模式」一行，检查角色徽章样式。
## 运行（窗口）：Godot --path . res://tools/hall_role_shot.tscn

const OUTPUT_HOST: String = "res://tools/hall_role_host.png"
const OUTPUT_JOIN: String = "res://tools/hall_role_join.png"


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await get_tree().process_frame
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var packed: PackedScene = load("res://room/title.tscn") as PackedScene
	if packed == null:
		get_tree().quit()
		return
	var title: Node = packed.instantiate()
	get_tree().root.add_child(title)
	for frame: int in range(12):
		await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout

	var host: CanvasItem = title.get_node_or_null("GameRoomSize/HostPage") as CanvasItem
	var join: CanvasItem = title.get_node_or_null("GameRoomSize/JoinPage") as CanvasItem
	if host != null:
		if join != null:
			join.visible = false
		host.visible = true
		await get_tree().create_timer(0.6).timeout
		Input.warp_mouse(Vector2(4, 4))
		await get_tree().process_frame
		await get_tree().process_frame
		_save(OUTPUT_HOST)
	if join != null:
		if host != null:
			host.visible = false
		join.visible = true
		await get_tree().create_timer(0.6).timeout
		Input.warp_mouse(Vector2(4, 4))
		await get_tree().process_frame
		await get_tree().process_frame
		_save(OUTPUT_JOIN)
	get_tree().quit()


func _save(path: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(path)
