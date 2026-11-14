extends Node

## 验证隐藏问号砖的碰撞形状：藏起来时是 32×32 矩形，顶出来后换回可见砖的凸多边形。
## 无头运行，结果写 tools/question_block_hidden_shape_probe_result.txt。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const RESULT_PATH: String = "res://tools/question_block_hidden_shape_probe_result.txt"
const VISIBLE_SCENE: String = "res://object/level/block/question_block.tscn"
const HIDDEN_SCENE: String = "res://object/level/block/question_block_hidden.tscn"


func _ready() -> void:
	var lines: Array[String] = []
	await _check(lines, VISIBLE_SCENE, "visible", false)
	await _check(lines, HIDDEN_SCENE, "hidden", true)
	_write(lines)
	get_tree().quit()


func _check(lines: Array[String], path: String, tag: String, expect_hidden: bool) -> void:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		lines.append(tag + "_load=false")
		return
	lines.append(tag + "_load=true")
	var block: Node = packed.instantiate()
	add_child(block)
	await get_tree().process_frame
	await get_tree().process_frame

	var shape_node: CollisionShape2D = block.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		lines.append(tag + "_shape_node=false")
		return
	var shape: Shape2D = shape_node.shape
	lines.append(tag + "_shape_node=true")
	lines.append(tag + "_shape_class=%s" % _class_of(shape))
	lines.append(tag + "_one_way=%s" % str(shape_node.one_way_collision))
	var body: StaticBody2D = block as StaticBody2D
	lines.append(tag + "_collision_layer=%d" % body.collision_layer)

	var is_rect: bool = shape is RectangleShape2D
	lines.append(tag + "_is_rect=%s" % str(is_rect))
	if is_rect:
		var rect: RectangleShape2D = shape as RectangleShape2D
		lines.append(tag + "_rect_size=%dx%d" % [int(rect.size.x), int(rect.size.y)])
	# 隐藏态应换成矩形；可见态应保持多边形
	lines.append(tag + "_matches_expect=%s" % str(is_rect == expect_hidden))

	# 顶出来：隐藏砖要能还原成可见形状
	if expect_hidden:
		var hit: BlockHit = block.get_node_or_null("BlockHit") as BlockHit
		if hit != null:
			hit.set_visible()
			await get_tree().process_frame
			await get_tree().process_frame
			var after: Shape2D = shape_node.shape
			lines.append("restored_shape_class=%s" % _class_of(after))
			lines.append("restored_is_polygon=%s" % str(after is ConvexPolygonShape2D))
			lines.append("restored_one_way=%s" % str(shape_node.one_way_collision))
			lines.append("restored_layer=%d" % body.collision_layer)
	block.queue_free()


func _class_of(shape: Shape2D) -> String:
	if shape == null:
		return "none"
	return shape.get_class()


func _write(lines: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
