extends Node

const SEMI_SOLID_DATA_NAME: String = "semi-solid"

@export var path_to_tile_map_layer: NodePath = ".."
@export var semi_solid_scene: PackedScene = preload("uid://b46odv7so3u8a")

var tile_map: TileMapLayer

## 本节点创建出来的半实心平台，关卡重新加载时统一清理，避免重复叠加。
var _created: Array[Node2D] = []

func _ready() -> void:
	tile_map = get_node(path_to_tile_map_layer) as TileMapLayer
	_connect_level_manager()
	# 场景自带瓦片（如测试房间）时先建一次；关卡文件稍后灌入时由信号重建。
	_rebuild.call_deferred()

## 关卡瓦片是在场景 ready 之后才写进 TileMapLayer 的，
## 只在 _ready 里扫一遍会读到空地图，因此要监听关卡数据加载完成。
func _connect_level_manager() -> void:
	var manager: LevelManager = get_tree().get_first_node_in_group("level_manager") as LevelManager
	if manager == null:
		return
	if not manager.has_signal("level_data_loaded"):
		return
	if not manager.is_connected("level_data_loaded", _on_level_data_loaded):
		manager.connect("level_data_loaded", _on_level_data_loaded)

func _on_level_data_loaded() -> void:
	_rebuild()

func _rebuild() -> void:
	_clear_created()
	if tile_map == null:
		return
	var tile_set: TileSet = tile_map.tile_set
	if tile_set == null:
		return
	if not _has_semi_solid_layer(tile_set):
		return

	for cell_coords: Vector2i in tile_map.get_used_cells():
		var tile_data: TileData = tile_map.get_cell_tile_data(cell_coords)
		if tile_data == null:
			continue
		var is_semi_solid: Variant = tile_data.get_custom_data(SEMI_SOLID_DATA_NAME)
		if not is_semi_solid:
			continue
		var semi_solid: Node2D = semi_solid_scene.instantiate() as Node2D
		if semi_solid == null:
			continue
		semi_solid.position = tile_map.map_to_local(cell_coords)
		tile_map.add_child(semi_solid)
		_created.append(semi_solid)

func _clear_created() -> void:
	for node: Node2D in _created:
		if is_instance_valid(node):
			node.queue_free()
	_created.clear()

func _has_semi_solid_layer(tile_set: TileSet) -> bool:
	for i: int in range(tile_set.get_custom_data_layers_count()):
		if tile_set.get_custom_data_layer_name(i) == SEMI_SOLID_DATA_NAME:
			return true
	return false
