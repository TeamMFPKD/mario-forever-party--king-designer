extends Node2D

class_name Spawner

@export var spawn_object_scene : PackedScene
@export var sprites: Array[Texture2D] = []

var is_in_level: bool
var offset: Vector2

func _ready() -> void:
	is_in_level = in_level_check()

	if !is_in_level:
		return

	var offset_marker = $"OffsetMarker" as Marker2D
	offset = offset_marker.position

	var create = func():
		if spawn_object_scene == null:
			push_error("%s: Spawn object scene is null!" % self.name)
		else:
			spawn()
	create.call_deferred()
	
func spawn() -> void:
	var spawn_object = spawn_object_scene.instantiate() as Node2D
	spawn_object.position = position + offset
	add_sibling(spawn_object)
	visible = false
	
	# 如果有door_id meta，设置到spawn出来的对象
	if has_meta("door_id"):
		var door_id = get_meta("door_id")
		var door_component = spawn_object.get_node_or_null("Area2D/DoorComponent")
		if door_component and door_component.has_method("set_door_id"):
			door_component.set_door_id(door_id)
		# 更新门的花色纹理
		_update_spawned_door_suit(spawn_object, door_id)

func _update_spawned_door_suit(spawn_object: Node2D, door_id: int):
	# 根据door_id计算花色索引（跳过第一个null元素）
	var suit_index = (door_id - 1) % 4 + 1
	
	# 检查sprites数组是否有有效的花色纹理
	if suit_index < 0 or suit_index >= len(sprites) or not sprites[suit_index]:
		return
	
	# 获取或创建花色Sprite节点
	var suit_sprite = spawn_object.get_node_or_null("Suit")
	if not suit_sprite:
		suit_sprite = Sprite2D.new()
		suit_sprite.name = "Suit"
		suit_sprite.position = Vector2(8, 8)
		suit_sprite.scale = Vector2(0.14, 0.14)
		spawn_object.add_child(suit_sprite)
	
	# 设置花色纹理
	suit_sprite.texture = sprites[suit_index]

func in_level_check() -> bool:
	return GameModeSingleton.game_mode == GameModeSingleton.GameModeType.TEST \
	or GameModeSingleton.game_mode == GameModeSingleton.GameModeType.PLAY \
	or GameModeSingleton.game_mode == GameModeSingleton.GameModeType.HISTORY_PLAY