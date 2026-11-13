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

## 回放页卡片只盖住中间的关卡视口，两侧的「查看」「返回」仍归本场景管。
## 它们被按下时要同步解冻，否则切到下一场景时树还是 paused。
const HISTORY_UNDERLYING_BUTTONS: Array[String] = [
	"GameRoomSize/MarginContainer/Button",
	"GameRoomSize/BackToHistory/BackToHistoryButton",
]

@onready var _root: Control = $Root
@onready var _card_holder: Control = $Root/CardHolder
@onready var _backdrop: ColorRect = $Root/CardHolder/Backdrop
@onready var _card_container: SubViewportContainer = $Root/CardHolder/CardContainer
@onready var _card_viewport: SubViewport = $Root/CardHolder/CardContainer/CardViewport
@onready var _flip_mesh: MeshInstance2D = $Root/CardHolder/FlipMesh
@onready var _title: Label = $Root/CardHolder/CardContainer/CardViewport/BackPanel/Content/VBox/Title
@onready var _center: Control = $Root/CardHolder/CardContainer/CardViewport/BackPanel/Content/VBox/Center
@onready var _buttons: Control = $Root/CardHolder/CardContainer/CardViewport/BackPanel/Content/VBox/Center/Buttons

## 卡片上的选项按钮是否显示。只要翻卡动画、不要按钮时置 false。
@export var actions_visible: bool = true
## 是否允许在百人团之外使用（例如回放页）。为 true 时不再要求 Adventure.is_running()。
@export var usable_outside_adventure: bool = false
## 回放页变体：只留「继续」「排除」；「排除」只写排除名单，不推进团、不切场景。
@export var history_mode: bool = false

var _is_open: bool = false
var _animating: bool = false

var _exclude_button: Button
var _skip_button: Button
var _abort_button: Button

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
	_buttons.visible = actions_visible
	_exclude_button = _buttons.get_node("ExcludeButton") as Button
	_skip_button = _buttons.get_node("SkipButton") as Button
	_abort_button = _buttons.get_node("AbortButton") as Button
	if history_mode:
		_skip_button.visible = false
		_abort_button.visible = false
		# 回放页的卡片不独占焦点：方向键要能跳到两侧的「查看」「返回」。
		_root.set_meta(&"ui_focus_modal_inclusive", true)
		# Root 全屏 STOP 会吃掉 UiNavigator 合成的点击，改成穿透让下层按钮能被点中；
		# 卡片区域仍有 CardContainer（STOP）挡着，继续 / 排除照常可点。
		# 代价：卡片外空白处不再触发「点空白继续」，改用「继续」按钮或暂停键收起菜单。
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_connect_underlying_buttons.call_deferred()
	if not actions_visible:
		# 没有选项时按钮容器会塌陷，标题就贴在卡片顶部。
		# 这里让标题吃掉整张卡片并垂直居中，视觉上"暂停"落在正中间。
		_center.size_flags_vertical = Control.SIZE_FILL
		_title.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_flip_material = _flip_mesh.material as ShaderMaterial
	if _flip_material != null and _card_viewport != null:
		_flip_material.set_shader_parameter("card_tex", _card_viewport.get_texture())
	# 过关 / 转场状态可能在菜单打开期间变化，三个动作按钮要跟着实时置灰。
	Adventure.pause_actions_blocked_changed.connect(_refresh_action_buttons)
	_refresh_action_buttons()


## 本菜单什么时候可用：百人团跑团中，或显式允许的非百人团场景（回放页）。
func _is_active_context() -> bool:
	return Adventure.is_running() or usable_outside_adventure


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active_context():
		return
	# 按键在标题页「设置 → 输入映射 → 暂停」里可改。
	if event.is_action_pressed("pause"):
		# 过关 / 转场期间也允许暂停，只是卡片上会切场景的动作被置灰。
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if not _is_active_context() or _animating:
		return
	if _is_open:
		_close_flip()
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
	if _backdrop != null:
		_backdrop.visible = false
	Adventure.set_transition_menu_paused(false)
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
	# 每次打开都重读状态：恢复过的关卡要能重新排除，
	# 过关 / 转场期间则把排除 / 跳过 / 中断一起置灰。
	_refresh_action_buttons()

	var rect: Rect2 = _find_level_border_rect()
	if rect.size == Vector2.ZERO:
		rect = _level_panel.get_global_rect()
	_randomize_flip_style()
	_prepare_flip_stage(rect)
	_level_panel.visible = false
	# 过场动画播到一半会搬到主视口，不再受关卡视口的显隐约束；翻卡缩小/上抛时
	# 卡片下方会露出还在播的黄色过场。转场期间用垫底色盖住，并定格它的时间线。
	_backdrop.visible = Adventure.is_pass_transition_running()
	Adventure.set_transition_menu_paused(true)

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
	if _backdrop != null:
		_backdrop.visible = false
	Adventure.set_transition_menu_paused(false)
	if _level_panel != null and is_instance_valid(_level_panel):
		_level_panel.visible = true
	visible = false
	# 过关 / 转场期间世界本来就冻结着，交给转场流程统一解冻；
	# 这里提前解冻会让旧关卡在换关前多跑一帧。
	if not keep_frozen and not Adventure.is_pause_action_blocked():
		get_tree().paused = false
	_animating = false


## 跳过 / 永久排除的离场翻转。
##
## 卡片原地翻 180°，正反面都用卡片本身的贴图：翻过去看到的还是这张卡片，
## 不会像翻回关卡那样露出关卡画面。翻完卡片留在原地继续盖住关卡，
## 由 GlobalTransition 把这张卡片淡出到下一关。
func _flip_away_for_skip() -> void:
	_level_panel = _find_level_panel()
	if _level_panel == null:
		return
	var rect: Rect2 = _find_level_border_rect()
	if rect.size == Vector2.ZERO:
		rect = _level_panel.get_global_rect()
	_randomize_flip_style()
	_prepare_flip_stage(rect)
	# 正面也换成卡片贴图，并铺满整块网格（不叠游戏边框）。
	if _flip_material != null:
		_flip_material.set_shader_parameter("level_tex", _card_viewport.get_texture())
		_flip_material.set_shader_parameter("inner_min", Vector2.ZERO)
		_flip_material.set_shader_parameter("inner_size", Vector2.ONE)
	if _backdrop != null:
		_backdrop.visible = true
	# 跳过不走过关转场，别把打开菜单时设的定格标志带到下一关。
	Adventure.set_transition_menu_paused(false)
	# 关卡视口先藏起来：卡片侧对镜头的瞬间是透明的，
	# 露出的是垫底色，而不是关卡画面。
	_level_panel.visible = false

	_animating = true
	_is_open = false
	_update_flip(1.0)
	_flip_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flip_tween.tween_method(_update_flip, 1.0, 0.0, FLIP_CLOSE_TIME)
	await _flip_tween.finished
	_flip_tween = null
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
## 同时标记 ui_focus_skip：卡片全透明时按钮仍是 visible，不排除的话手柄光标会浮在空处。
func _set_card_interactive(active: bool) -> void:
	_card_container.modulate = Color(1, 1, 1, 1.0 if active else 0.0)
	_card_container.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	_card_container.set_meta("ui_focus_skip", not active)


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
	# 每次翻转都重新绑定本实例的卡片贴图：材质是场景资源，可能被同时存在的
	# 另一个暂停菜单实例改写成它自己的（不可见）视口，导致卡片背面全透明。
	_flip_material.set_shader_parameter("card_tex", _card_viewport.get_texture())
	var level_viewport: SubViewport = _level_panel.get_node_or_null("SubViewport") as SubViewport
	if level_viewport != null:
		_flip_material.set_shader_parameter("level_tex", level_viewport.get_texture())
		# 关卡贴图贴在装饰边框的内框里（SubViewportContainer 的显示尺寸），不铺满整块边框。
		# 注意不能用 SubViewport.size：它是渲染分辨率（1280×960），而容器在屏幕上是
		# 1280×928（size_2d_override 640×480 按 928 高拉伸），用渲染尺寸会让正面贴图
		# 纵向多出约 32px，翻转落平时底部露出一条对不齐的「残留」。
		var level_size: Vector2 = _level_panel.size
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
			# 排除按钮点完会变灰但仍留在卡片上；点它（以及卡片本身）不能被当成
			# "点空白处继续"。回放页 Root 本身是 IGNORE，正常鼠标不会走到这里，
			# 但保留这层判断，兼容直接 emit gui_input 的场景。
			if history_mode and _card_holder.get_global_rect().has_point(mouse_event.global_position):
				return
			_close_flip()


## 回放页：下层「查看 / 返回」被按下时同步解冻并收起卡片。
## 不能走 _close_flip() 的异步翻回 —— 切场景会把旧菜单连同 tween 一起销毁，
## await 永远不返回，树会一直停在 paused。
func _connect_underlying_buttons() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	for path: String in HISTORY_UNDERLYING_BUTTONS:
		var button: Button = scene.get_node_or_null(path) as Button
		if button != null and not button.pressed.is_connected(_on_underlying_pressed):
			button.pressed.connect(_on_underlying_pressed)


func _on_underlying_pressed() -> void:
	force_close()


## 「排除」：百人团里是硬跳过并翻到下一关；回放页里只写名单、保持暂停。
func _on_exclude_pressed() -> void:
	if Adventure.is_pause_action_blocked():
		return
	if not history_mode:
		_begin_skip(true)
		return
	var key: String = _history_level_key()
	if key.is_empty():
		Log.w("AdventurePauseMenu", "找不到当前回放关卡，无法排除")
		return
	Adventure.exclude_level(key)
	# 不翻卡、不切场景、不解冻：菜单与树暂停都维持原样。
	_exclude_button.disabled = true


## 回放页里当前关卡的 key（关卡文件名，与百人团关卡池一致）。
func _history_level_key() -> String:
	var setter: Node = get_tree().get_first_node_in_group("level_path_set")
	if setter == null:
		return ""
	var path: String = str(setter.get_meta("level_path_name", ""))
	if path.is_empty() or path == "invalid":
		return ""
	return AdventureLevelIdentity.key_from_path(path)


## 过关 / 过关转场播放中：暂停照常开，但会切场景的三个动作一律 Disabled。
## 回放页的排除按钮额外叠加「已排除 / 拿不到关卡 key」的置灰规则。
func _refresh_action_buttons() -> void:
	if _exclude_button == null or _skip_button == null or _abort_button == null:
		return
	var blocked: bool = Adventure.is_pause_action_blocked()
	_skip_button.disabled = blocked
	_abort_button.disabled = blocked
	if history_mode:
		var key: String = _history_level_key()
		_exclude_button.disabled = blocked or key.is_empty() or Adventure.is_excluded(key)
	else:
		_exclude_button.disabled = blocked


func _skip_soft() -> void:
	if Adventure.is_pause_action_blocked():
		return
	_begin_skip(false)


## 跳过 / 永久排除：
## 点击瞬间推进团进度（下一关在此刻确定），冻结关卡后把卡片翻走。
##
## 常规情况不是「原地翻完再硬切」，而是先把下一关预加载到卡片后面，
## 再翻卡把它露出来 —— 翻转期间背后一直是活的新关卡，既不会露出上一关，
## 也不会出现一块空白的垫底。
func _begin_skip(hard: bool) -> void:
	if _animating:
		return
	# 预加载下一关期间也锁住输入：卡片一直盖着，不允许再触发一次暂停/跳过。
	_animating = true
	Adventure.skip_current_level(hard)
	var finished: bool = not Adventure.is_running()
	var next_key: String = Adventure.current_level_key()
	# 目标关卡已在点击瞬间确定；先放满 2 个物理帧再冻结，
	# 冻住的才是完整的一帧，切场景时不会残留上一关的半帧。
	await Adventure.settle_physics_frames(2)
	Log.i("AdventurePauseMenu", ["跳过本关，下一关：", Adventure.result_scene() if finished else next_key])
	if finished:
		# 没有下一关可露：卡片原地翻完直接切结算页（不播淡出 shader）。
		await _flip_away_for_skip()
		get_tree().paused = true
		GlobalTransition.change_scene_to_file(Adventure.result_scene(), true)
		return
	await _flip_reveal_next_level()


## 跳过 / 排除的主流程：预加载下一关 → 在卡片后面就位 → 翻卡露出新关卡。
func _flip_reveal_next_level() -> void:
	# 旧场景马上会被销毁，先把暂停菜单挂到 root 上，免得跟着一起没。
	if get_parent() != get_tree().root:
		reparent(get_tree().root)

	var next_scene: Node = await Adventure.preload_next_level_scene()
	if next_scene == null:
		# 预加载失败：退化成「原地翻 + 即时切场景」。
		await _flip_away_for_skip()
		get_tree().paused = true
		GlobalTransition.reload_current_scene(true)
		return

	# 换场后 current_scene 已经是新关卡，重新取面板与边框。
	_level_panel = _find_level_panel()
	if _level_panel == null:
		visible = false
		get_tree().paused = false
		queue_free()
		return
	var rect: Rect2 = _find_level_border_rect()
	if rect.size == Vector2.ZERO:
		rect = _level_panel.get_global_rect()
	_randomize_flip_style()
	_prepare_flip_stage(rect)
	# 翻转期间不显示实时关卡视口：把整块关卡（含边框）隐掉，
	# 只让卡片自己翻；翻完再把关卡放出来。
	var level_modulate: Color = _level_panel.modulate
	_level_panel.modulate.a = 0.0

	_animating = true
	_is_open = false
	_update_flip(1.0)
	_flip_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flip_tween.tween_method(_update_flip, 1.0, 0.0, FLIP_CLOSE_TIME)
	await _flip_tween.finished
	_flip_tween = null

	# 翻完：先恢复关卡视口，再撤掉卡片并解冻。
	if is_instance_valid(_level_panel):
		_level_panel.modulate = level_modulate
	visible = false
	_card_holder.visible = false
	_animating = false
	get_tree().paused = false
	queue_free()


func _interrupt() -> void:
	if Adventure.is_pause_action_blocked():
		return
	# 保存进度并直接回到百人团舞台（稍后可点「继续上次的团」）。
	# 卡片全程盖住关卡、不放隐藏：先跑满 2 个物理帧再冻结，然后直接切场景，
	# 这样从点击到舞台出现都不会露出任何关卡视口的画面
	# （GlobalTransition 淡出的是这张卡片，不是关卡）。
	Adventure.interrupt_run()
	await Adventure.settle_physics_frames(2)
	get_tree().paused = true
	GlobalTransition.change_scene_to_file(Adventure.STAGE_SCENE)
