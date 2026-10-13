extends Node2D

class_name DoorComponent

signal play_sound_locked
signal play_sound_unlock

@export var id: int = 0
@export var path_to_area: NodePath = ".."
@export var path_to_ani: NodePath = "../../AnimatedSprite2D"

@export var locked: bool = false
@export var unlocked: bool = false

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

func _create_id_label() -> void:
	id_label = Label.new()
	id_label.name = "DoorIdLabel"
	id_label.text = str(id)
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	id_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	id_label.position = Vector2(-8, -64)  # 显示在门上方
	id_label.add_to_group("door_id_label")
	add_child(id_label)

func set_door_id(new_id: int) -> void:
	id = new_id
	if id_label:
		id_label.text = str(new_id)

func _update_id_label_visibility() -> void:
	if id_label:
		# 只在编辑模式下显示ID
		var gm: GameMode = GameModeSingleton
		id_label.visible = (gm.game_mode == GameMode.GameModeType.EDIT)

func play_animation_enter() -> void:
	ani.play("enter")

func play_animation_exit() -> void:
	ani.play("exit")

func _on_animation_finished(animation: String) -> void:
	if animation == "exit":
		ani.play("default" if unlocked else "idle_unlocked")

func try_enter() -> bool:
	# 普通门
	if not locked:
		return true
	# 锁门
	if locked:
		# 锁门已解锁
		if unlocked:
			return true
		# 锁门未解锁
		if not unlocked:
			var keys: Array[Node] = get_tree().get_nodes_in_group("key_following")
			# 没有钥匙
			if keys.is_empty():
				emit_signal("play_sound_locked")
				return false
			# 有钥匙
			var max_key_id: int = 0
			for key: Node in keys:
				var key_movement: KeyMovement = key
				if max_key_id < key_movement.key_id:
					max_key_id = key_movement.key_id
			for key: Node in keys:
				var key_movement: KeyMovement = key
				if key_movement.key_id == max_key_id:
					key_movement.get_parent().queue_free()
					# 对面的门也解锁
					var doors: Array[Node] = get_tree().get_nodes_in_group("door")
					for d: Node in doors:
						var door: DoorComponent = d
						if door.id == id:
							door.unlocked = true
							door.remove_from_group("door_locked")
					remove_from_group("door_locked")
					emit_signal("play_sound_unlock")
					return true
	return false
