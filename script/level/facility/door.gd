extends Node2D

class_name DoorComponent

@export var id: int = 0
@export var path_to_area: NodePath = ".."
@export var path_to_ani: NodePath = "../../AnimatedSprite2D"

var area: Area2D
var ani: AnimatedSprite2D
var id_label: Label

func _ready() -> void:
	area = get_node(path_to_area) as Area2D
	area.set_meta("door_component", self)
	add_to_group("door")
	ani = get_node(path_to_ani) as AnimatedSprite2D
	ani.animation_finished.connect(_on_animation_finished)
	
	# 创建ID显示Label
	_create_id_label()
	
	# 在编辑模式下显示ID
	_update_id_label_visibility()

func _create_id_label():
	id_label = Label.new()
	id_label.name = "DoorIdLabel"
	id_label.text = str(id)
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	id_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	id_label.position = Vector2(-8, -64)  # 显示在门上方
	id_label.add_to_group("door_id_label")
	add_child(id_label)

func set_door_id(new_id: int):
	id = new_id
	if id_label:
		id_label.text = str(new_id)

func _update_id_label_visibility():
	if id_label:
		# 只在编辑模式下显示ID
		id_label.visible = (GameModeSingleton.game_mode == GameModeSingleton.GameModeType.EDIT)

func play_animation_enter() -> void:
	ani.play("enter")

func play_animation_exit() -> void:
	ani.play("exit")

func _on_animation_finished(animation: String) -> void:
	if animation == "exit":
		ani.play("default")