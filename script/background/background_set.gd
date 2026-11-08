extends Node2D

class_name BackgroundSet

@export var gradient: Sprite2D
@export var background_bottom: Node2D
@export var cloud_top: Node2D

var room_left: int = 0;
var room_top: int = 0;
var room_right: int = 640;
var room_bottom: int = 480;

var level_camera: LevelCamera
var _original_position: Vector2
# 渐变贴图的原始高度/偏移，用作纵向拉伸的基准（不再重建贴图，见 background_set）
var _gradient_base_ready: bool = false
var _gradient_base_height: float = 0.0
var _gradient_base_offset_y: float = 0.0
# 上次应用过的房间范围，范围没变化时直接跳过
var _applied_room: Rect2i = Rect2i(0, 0, 0, 0)
var _has_applied_room: bool = false

func _ready() -> void:
	_original_position = position
	# Get level size
	level_camera = get_tree().get_first_node_in_group("level_camera") as LevelCamera
	level_camera.limit_changed.connect(_on_level_camera_limit_changed)

	room_left = level_camera.limit_left
	room_top = level_camera.limit_top
	room_right = level_camera.limit_right
	room_bottom = level_camera.limit_bottom

	background_set()


func _physics_process(_delta: float) -> void:
	if level_camera and level_camera.offset != Vector2.ZERO:
		position = _original_position + level_camera.offset
	else:
		position = _original_position

func _on_level_camera_limit_changed(top: int, left: int, right: int, bottom: int) -> void:
	room_left = left
	room_top = top
	room_right = right
	room_bottom = bottom

	background_set()

func background_set() -> void:
	var room: Rect2i = Rect2i(room_left, room_top, room_right - room_left, room_bottom - room_top)
	if _has_applied_room and room == _applied_room:
		return
	_applied_room = room
	_has_applied_room = true

	# 渐变色背景
	# 注意：这里不能用 gradient_texture_2d.height 来设置高度。
	# GradientTexture2D.set_height() 没有相同值提前返回，每次赋值都会重新逐像素生成
	# 640 x 关卡高度 的整张图并重建 GPU 纹理；而长按关卡尺寸按钮时 limit_changed
	# 每个物理帧都会触发一次，贴图随之每帧重建，越按越卡。
	# 改为固定贴图 + 纵向拉伸，效果完全一致且开销是常数。
	if (gradient != null):
		_capture_gradient_base()
		var center_y: float = floorf((room_bottom + room_top) / 2.0)
		if _gradient_base_height > 0.0:
			var scale_y: float = float(room.size.y) / _gradient_base_height
			gradient.scale.y = scale_y
			# Sprite2D 的 offset 会跟着 scale 一起缩放，这里补回差值，
			# 保证绘制位置与"改贴图高度、offset 不变"的老做法完全一致。
			gradient.position.y = center_y + _gradient_base_offset_y * (1.0 - scale_y)
		else:
			gradient.position.y = center_y

	# 底部背景
	if (background_bottom != null):
		background_bottom.position.y = room_bottom

	# 顶部背景
	if (cloud_top != null):
		cloud_top.position.y = room_top

func _capture_gradient_base() -> void:
	if _gradient_base_ready:
		return
	_gradient_base_ready = true
	if gradient == null:
		return
	_gradient_base_offset_y = gradient.offset.y
	if gradient.texture != null:
		_gradient_base_height = float(gradient.texture.get_height())
