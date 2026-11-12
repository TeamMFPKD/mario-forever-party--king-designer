extends CanvasLayer

## 百人团暂停菜单（3D 翻转版）。
##
## UI 节点全部在 object/ui/adventure_pause_menu.tscn，本脚本只负责翻转动画与菜单动作。
## 卡片放在 SubViewport 里，翻转时用细分网格 + adventure_pause_flip.gdshader 做
## 真实透视投影：正面采样关卡视口贴图（叠外边框），背面采样卡片贴图，
## 90° 侧对镜头时切换正反面（切换瞬间宽度为 0，看不见）。
## 动画结束后隐藏网格、显示 SubViewportContainer，按钮恢复正常交互。

@warning_ignore_start("unsafe_call_argument", "unsafe_cast")

const FLIP_OPEN_TIME: float = 0.55
const FLIP_CLOSE_TIME: float = 0.45
const MESH_SUBDIVISIONS: int = 32
const EDGE_SHADE: float = 0.30
# 翻转中段整体缩到 0.6，首尾回到 1.0（跟着 sin 峰值走，时间上正好在中点）。
const MID_SCALE: float = 0.6

# 每次暂停的翻转姿态在这个范围内随机（俯仰、滚转、上抛、透视距离、翻转方向）。
const PITCH_RANGE: Vector2 = Vector2(0.04, 0.15)
const ROLL_RANGE: Vector2 = Vector2(0.04, 0.15)
const LIFT_RANGE: Vector2 = Vector2(10.0, 26.0)
const PERSPECTIVE_RANGE: Vector2 = Vector2(1500.0, 2050.0)

@onready var _card_holder: Control = $Root/CardHolder
@onready var _card_container: SubViewportContainer = $Root/CardHolder/CardContainer
@onready var _card_viewport: SubViewport = $Root/CardHolder/CardContainer/CardViewport
@onready var _flip_mesh: MeshInstance2D = $Root/CardHolder/FlipMesh

var _is_open: bool = false
var _animating: bool = false

var _level_panel: Control
var _flip_tween: Tween
var _flip_material: ShaderMaterial

# 本次翻转的随机姿态；打开时抽一次，关闭时沿用，保证来回是同一张卡片。
var _flip_sign: float = 1.0
var _pitch_amount: float = 0.10
var _roll_amount: float = 0.085
var _lift_amount: float = 18.0


func _ready() -> void:
	visible = false
	_flip_material = _flip_mesh.material as ShaderMaterial
	if _flip_material != null:
		_flip_material.set_shader_parameter("card_tex", _card_viewport.get_texture())


func _unhandled_input(event: InputEvent) -> void:
	if not Adventure.is_running():
		return
	# 按键在标题页「设置 → 输入映射 → 暂停」里可改。
	if event.is_action_pressed("pause"):
		# 过关中 / 过关转场播放中按暂停键不算数，也不吃掉这次输入。
		if not _is_open and Adventure.is_pause_blocked():
			return
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if not Adventure.is_running() or _animating:
		return
	if _is_open:
		_close_flip()
		return
	# 玩家已过关 / 过关转场播放中：不允许打开暂停菜单（已经打开的仍可关闭）。
	if Adventure.is_pause_blocked():
		return
	_open_flip()


## 死亡/过关推进前强制关掉菜单，避免带着暂停状态重载场景。
## keep_paused：切场景期间继续保持冻结（中断回舞台用），由目标场景自己解冻。
func force_close(keep_paused: bool = false) -> void:
	_animating = false
	_is_open = false
	if _flip_tween != null and _flip_tween.is_valid():
		_flip_tween.kill()
		_flip_tween = null
	visible = false
	if _flip_mesh != null:
		_flip_mesh.visible = false
	if _card_holder != null:
		_card_holder.visible = false
	_set_card_interactive(true)
	if _level_panel != null and is_instance_valid(_level_panel):
		_level_panel.visible = true
	if not keep_paused:
		get_tree().paused = false


# ---------------------------------------------------------------------------
# 翻转
# ---------------------------------------------------------------------------

func _open_flip() -> void:
	if _animating:
		return
	_level_panel = _find_level_panel()
	if _level_panel == null:
		force_close()
		return

	_animating = true
	_is_open = true
	visible = true
	get_tree().paused = true

	var rect: Rect2 = _find_level_border_rect()
	if rect.size == Vector2.ZERO:
		rect = _level_panel.get_global_rect()
	_randomize_flip_style()
	_prepare_flip_stage(rect)
	_level_panel.visible = false

	_update_flip(0.0)
	_flip_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flip_tween.tween_method(_update_flip, 0.0, 1.0, FLIP_OPEN_TIME)
	await _flip_tween.finished
	_flip_tween = null

	_flip_mesh.visible = false
	_set_card_interactive(true)
	_animating = false


## keep_frozen：翻转结束后不解冻，交给调用方（跳过本关）继续冻结着切场景。
func _close_flip(keep_frozen: bool = false) -> void:
	if _animating:
		return
	if _level_panel == null:
		force_close(keep_frozen)
		return
	_animating = true
	_is_open = false

	_set_card_interactive(false)
	_flip_mesh.visible = true
	_update_flip(1.0)

	_flip_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flip_tween.tween_method(_update_flip, 1.0, 0.0, FLIP_CLOSE_TIME)
	await _flip_tween.finished
	_flip_tween = null

	_flip_mesh.visible = false
	_card_holder.visible = false
	if _level_panel != null and is_instance_valid(_level_panel):
		_level_panel.visible = true
	visible = false
	if not keep_frozen:
		get_tree().paused = false
	_animating = false


## 每次打开暂停时随机一次姿态，同一轮的关闭沿用，保证来回是同一张卡片。
## 总翻转角固定 180°（否则卡片落不平），随机的是方向与倾斜量。
func _randomize_flip_style() -> void:
	_flip_sign = -1.0 if randf() < 0.5 else 1.0
	_pitch_amount = randf_range(PITCH_RANGE.x, PITCH_RANGE.y) * (-1.0 if randf() < 0.35 else 1.0)
	_roll_amount = randf_range(ROLL_RANGE.x, ROLL_RANGE.y) * (-1.0 if randf() < 0.5 else 1.0)
	_lift_amount = randf_range(LIFT_RANGE.x, LIFT_RANGE.y)
	if _flip_material != null:
		_flip_material.set_shader_parameter(
			"perspective", randf_range(PERSPECTIVE_RANGE.x, PERSPECTIVE_RANGE.y)
		)


## 翻转期间卡片容器保持可见（否则子视口可能停更），只用透明度和输入开关控制。
func _set_card_interactive(active: bool) -> void:
	_card_container.modulate = Color(1, 1, 1, 1.0 if active else 0.0)
	_card_container.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE


func _prepare_flip_stage(rect: Rect2) -> void:
	_card_holder.visible = true
	_card_holder.global_position = rect.position
	_card_holder.size = rect.size
	# 必须保持容器 visible：SubViewportContainer 隐藏时子视口可能停止渲染，
	# 背面贴图会变成空白。翻转期间用全透明 + 忽略输入代替隐藏。
	# 注意 stretch=true 时视口尺寸由容器托管，不要再手动改 SubViewport.size。
	_set_card_interactive(false)
	_flip_mesh.visible = true
	_flip_mesh.mesh = _build_flip_mesh(rect.size)
	if _flip_material == null:
		return
	var level_viewport: SubViewport = _level_panel.get_node_or_null("SubViewport") as SubViewport
	if level_viewport != null:
		_flip_material.set_shader_parameter("level_tex", level_viewport.get_texture())
		# 关卡贴图贴在装饰边框的内框里（SubViewport 的实际渲染尺寸），不铺满整块边框。
		var level_size: Vector2 = Vector2(
			float(level_viewport.size.x), float(level_viewport.size.y)
		)
		var inner_min: Vector2 = (_level_panel.global_position - rect.position) / rect.size
		_flip_material.set_shader_parameter("inner_min", inner_min)
		_flip_material.set_shader_parameter("inner_size", level_size / rect.size)
	else:
		_flip_material.set_shader_parameter("inner_min", Vector2.ZERO)
		_flip_material.set_shader_parameter("inner_size", Vector2.ONE)


## p: 0 = 正面（关卡），1 = 背面（卡片）。
func _update_flip(p: float) -> void:
	var eased: float = p * p * (3.0 - 2.0 * p)
	var wave: float = sin(PI * eased)

	if _flip_material != null:
		_flip_material.set_shader_parameter("yaw", _flip_sign * PI * eased)
		_flip_material.set_shader_parameter("pitch", _pitch_amount * wave)
		_flip_material.set_shader_parameter("roll", _roll_amount * wave)
		_flip_material.set_shader_parameter("shade", 1.0 - EDGE_SHADE * wave)

	_flip_mesh.position = _card_holder.size * 0.5 + Vector2(0.0, -_lift_amount * wave)
	var mid_scale: float = lerpf(1.0, MID_SCALE, wave)
	_flip_mesh.scale = Vector2(mid_scale, mid_scale)


## 建一张细分四边形网格，供着色器逐顶点做透视投影（避免 4 顶点仿射变形）。
func _build_flip_mesh(size: Vector2) -> ArrayMesh:
	var cols: int = MESH_SUBDIVISIONS
	var rows: int = MESH_SUBDIVISIONS
	var vertices: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	for j: int in range(rows + 1):
		for i: int in range(cols + 1):
			var u: float = float(i) / float(cols)
			var v: float = float(j) / float(rows)
			vertices.append(Vector2((u - 0.5) * size.x, (v - 0.5) * size.y))
			uvs.append(Vector2(u, v))

	for j: int in range(rows):
		for i: int in range(cols):
			var a: int = j * (cols + 1) + i
			var b: int = a + 1
			var c: int = a + cols + 1
			var d: int = c + 1
			indices.append(a)
			indices.append(b)
			indices.append(d)
			indices.append(a)
			indices.append(d)
			indices.append(c)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _find_level_panel() -> Control:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("SubViewportContainer", true, false) as Control


## 关卡视口外框装饰的全局矩形；找不到时退回关卡视口矩形。
func _find_level_border_rect() -> Rect2:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return Rect2()
	var border: Control = scene.find_child("GameBorderTextureRect", true, false) as Control
	if border == null:
		return Rect2()
	return border.get_global_rect()


# ---------------------------------------------------------------------------
# 输入 / 菜单动作
# ---------------------------------------------------------------------------

func _on_root_gui_input(event: InputEvent) -> void:
	if not _is_open or _animating:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_close_flip()


func _skip_hard() -> void:
	_begin_skip(true)


func _skip_soft() -> void:
	_begin_skip(false)


## 跳过 / 永久排除：
## 点击瞬间推进团进度（下一关在此刻确定），随后冻结关卡、播已有的翻转动画，
## 动画结束后再切场景 —— 关卡不会在被卡片盖住的后台继续跑。
func _begin_skip(hard: bool) -> void:
	if _animating:
		return
	Adventure.skip_current_level(hard)
	var finished: bool = not Adventure.is_running()
	var next_key: String = Adventure.current_level_key()
	# 目标关卡已在点击瞬间确定；先放满 2 个物理帧再冻结，
	# 冻住的才是完整的一帧，切场景时不会残留上一关的半帧。
	await Adventure.settle_physics_frames(2)
	await _close_flip(true)
	# 兜底：翻转动画内部可能解冻。
	get_tree().paused = true
	Log.i("AdventurePauseMenu", ["跳过本关，下一关：", Adventure.RESULT_SCENE if finished else next_key])
	if finished:
		GlobalTransition.change_scene_to_file(Adventure.RESULT_SCENE)
	else:
		GlobalTransition.reload_current_scene()


func _interrupt() -> void:
	# 保存进度并直接回到百人团舞台（稍后可点「继续上次的团」）。
	# 卡片全程盖住关卡、不放隐藏：先跑满 2 个物理帧再冻结，然后直接切场景，
	# 这样从点击到舞台出现都不会露出任何关卡视口的画面
	# （GlobalTransition 淡出的是这张卡片，不是关卡）。
	Adventure.interrupt_run()
	await Adventure.settle_physics_frames(2)
	get_tree().paused = true
	GlobalTransition.change_scene_to_file(Adventure.STAGE_SCENE)
