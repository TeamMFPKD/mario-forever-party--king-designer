extends Node

const OUTPUT_PATH: String = "res://tools/title.png"


func _ready() -> void:
	var packed: PackedScene = load("res://room/title.tscn") as PackedScene
	if packed == null:
		get_tree().quit()
		return
	var title: Node = packed.instantiate()
	add_child(title)
	await get_tree().create_timer(1.0).timeout
	var choose: Button = title.get_node_or_null(
		"GameRoomSize/ChooseModePanel/ChooseMode/HBoxContainer/VBoxContainer/ChooseHostButton"
	) as Button
	if choose != null:
		choose.emit_signal("pressed")
	await get_tree().create_timer(1.0).timeout
	var role_button: Button = title.get_node_or_null(
		"GameRoomSize/HostPage/MfpkdPanel/UiMarginContainer/VBoxContainer/RoleRow/RoleToggleButton"
	) as Button
	if role_button != null:
		role_button.emit_signal("pressed")
	await get_tree().create_timer(0.5).timeout
	var host_button: Button = title.get_node_or_null(
		"GameRoomSize/HostPage/MfpkdPanel/UiMarginContainer/VBoxContainer/HBoxContainer/HostButton"
	) as Button
	if host_button != null:
		host_button.emit_signal("pressed")
	await get_tree().create_timer(2.0).timeout
	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(OUTPUT_PATH)
	get_tree().quit()
