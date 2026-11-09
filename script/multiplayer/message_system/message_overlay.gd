extends CanvasLayer

## 《超级马力欧创作家 2》风格快捷消息：
## - 右侧按钮打开全屏面板，顶部 3×7 网格展示 21 条预置用语；
## - 灰色底板贴住屏幕上边缘（左右上满宽），高度自动包住整个按钮网格并留白；
## - 面板打开期间拦截玩家输入，点击空白区域淡出；
## - 选中用语后关闭面板，左下角弹出「头像 + 玩家名 + 消息」气泡，约 2 秒后淡出；
## - 发送后进入约 2 秒冷却，冷却期间按钮不可按，面板上盖一层「正在发送消息中……」。

## 气泡弹出时发出，用于播放音效（音效素材待补充）。
signal message_popped(player_name: String, quick_id: int)

const MAX_BUBBLES: int = 8
const BUBBLE_GAP: float = 8.0
const BUBBLE_MARGIN_LEFT: float = 24.0
const BUBBLE_MARGIN_BOTTOM: float = 24.0
const SEND_COOLDOWN: float = 2.3
const PANEL_FADE_TIME: float = 0.15
## 灰色底板相对按钮网格的上下外扩留白（左右留白写在场景偏移里）
const PANEL_PADDING_TOP: float = 32.0
const PANEL_PADDING_BOTTOM: float = 40.0
## 选中的用语按钮：从点击到该消息展示结束一直保持黄色
const HIGHLIGHT_MODULATE: Color = Color(1, 1, 0, 1)

@export var open_button: Button
@export var panel_root: Control
@export var backdrop: Panel
@export var blocker: Control
@export var quick_grid: GridContainer
@export var sending_layer: Control
@export var quick_button_scene: PackedScene
@export var bubble_layer: Control
@export var bubble_scene: PackedScene
@export var input_blocker: PlayerInputBlocker
@export var message_sound: AudioStreamPlayer
@export var panel_open_sound: AudioStreamPlayer
@export var panel_close_sound: AudioStreamPlayer
@export var send_confirm_sound: AudioStreamPlayer
@export var cursor_sound: AudioStreamPlayer

## 调试用：单人房间也显示消息按钮
@export var debug: bool = false

var _quick_buttons: Array[Button] = []
var _highlighted_button: Button
var _bubbles: Array[MessageBubble] = []
var _cooldown_left: float = 0.0
var _is_open: bool = false
var _panel_tween: Tween


func _ready() -> void:
	MPManager.players_updated.connect(_on_players_updated)
	MPManager.messages_updated.connect(_on_messages_updated)
	open_button.pressed.connect(toggle_panel)
	blocker.gui_input.connect(_on_blocker_gui_input)
	bubble_layer.resized.connect(_layout_bubbles)
	_build_quick_buttons()
	_fit_panel_to_grid()
	if quick_grid:
		quick_grid.minimum_size_changed.connect(_fit_panel_to_grid)
	panel_root.visible = false
	panel_root.modulate.a = 0.0
	_set_sending_overlay(false)
	_on_players_updated()


func _process(delta: float) -> void:
	if _cooldown_left <= 0.0:
		return
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _cooldown_left <= 0.0:
		_set_quick_buttons_disabled(false)
		_set_sending_overlay(false)


func _on_players_updated() -> void:
	var required: int = 1 if debug else 2
	open_button.visible = MPManager.players.size() >= required
	if not open_button.visible:
		close_panel()


func _build_quick_buttons() -> void:
	for quick_id: int in range(1, QuickMessageTable.COUNT + 1):
		var button: Button = quick_button_scene.instantiate() as Button
		if not button:
			push_error("MessageOverlay: quick_button_scene is not a Button")
			return
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
		button.text = QuickMessageTable.key_of(quick_id)
		button.pressed.connect(_on_quick_button_pressed.bind(quick_id, button))
		button.mouse_entered.connect(_on_quick_button_hover)
		quick_grid.add_child(button)
		_quick_buttons.append(button)


func toggle_panel() -> void:
	if _is_open:
		close_panel()
	else:
		open_panel()


func open_panel() -> void:
	if _is_open or not open_button.visible:
		return
	_is_open = true
	panel_root.visible = true
	panel_root.modulate.a = 0.0
	# 冷却期间重新打开面板：按钮是禁用状态，同时保留「正在发送消息中……」提示
	_set_sending_overlay(_cooldown_left > 0.0)
	if input_blocker:
		input_blocker.block()
	if panel_open_sound:
		panel_open_sound.play()
	_kill_panel_tween()
	_panel_tween = create_tween()
	_panel_tween.tween_property(panel_root, "modulate:a", 1.0, PANEL_FADE_TIME)


func close_panel(play_sound: bool = true) -> void:
	if not _is_open and not panel_root.visible:
		return
	var was_open: bool = _is_open
	_is_open = false
	if input_blocker:
		input_blocker.unblock()
	if was_open and play_sound and panel_close_sound:
		panel_close_sound.play()
	_kill_panel_tween()
	if not panel_root.visible:
		return
	_panel_tween = create_tween()
	_panel_tween.tween_property(panel_root, "modulate:a", 0.0, PANEL_FADE_TIME)
	_panel_tween.tween_callback(_hide_panel_root)


func _hide_panel_root() -> void:
	panel_root.visible = false


func _kill_panel_tween() -> void:
	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()


func _on_blocker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			close_panel()
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			close_panel()


func _on_quick_button_pressed(quick_id: int, button: Button) -> void:
	if _cooldown_left > 0.0:
		return
	MPManager.chat.send_quick(quick_id)
	if send_confirm_sound:
		send_confirm_sound.play()
	_highlighted_button = button
	_cooldown_left = SEND_COOLDOWN
	_set_quick_buttons_disabled(true)
	_set_sending_overlay(true)
	close_panel(false)


## 冷却期间在按钮上盖一层「正在发送消息中……」；冷却结束或面板重开时同步刷新。
func _set_sending_overlay(sending: bool) -> void:
	if sending_layer:
		sending_layer.visible = sending


## 灰色底板高度跟随按钮网格：网格多一行，底板就跟着长高，始终包住全部按钮并留出边距。
func _fit_panel_to_grid() -> void:
	if not backdrop or not quick_grid:
		return
	var content_height: float = quick_grid.get_combined_minimum_size().y
	backdrop.offset_bottom = PANEL_PADDING_TOP + content_height + PANEL_PADDING_BOTTOM


func _on_quick_button_hover() -> void:
	if _cooldown_left > 0.0:
		return
	if cursor_sound:
		cursor_sound.play()


func _set_quick_buttons_disabled(disabled: bool) -> void:
	for button: Button in _quick_buttons:
		button.disabled = disabled
		if disabled and button == _highlighted_button:
			button.modulate = HIGHLIGHT_MODULATE
		elif disabled:
			button.modulate = Color(1, 1, 1, 0.5)
		else:
			button.modulate = Color(1, 1, 1, 1)
	if not disabled:
		_highlighted_button = null


func _on_messages_updated() -> void:
	for message: Dictionary in MPManager.messages:
		if message.get("displayed", false):
			continue
		message["displayed"] = true
		_spawn_bubble(message)


func _spawn_bubble(message: Dictionary) -> void:
	var quick_id_variant: Variant = message.get("quick_id", 0)
	var quick_id: int = 0
	if quick_id_variant is int:
		quick_id = quick_id_variant
	if not QuickMessageTable.is_valid_id(quick_id):
		return
	var player_name: String = str(message.get("player_name", ""))
	var avatar_id: String = str(message.get("avatar_id", ""))
	# 身份色按发送者在房间名单里的位置算，各端一致，不需要同步
	var player_id: int = 0
	var player_id_variant: Variant = message.get("player_id", 0)
	if player_id_variant is int:
		player_id = player_id_variant
	var bubble: MessageBubble = bubble_scene.instantiate() as MessageBubble
	if not bubble:
		push_error("MessageOverlay: bubble_scene is not a MessageBubble")
		return
	bubble_layer.add_child(bubble)
	bubble.setup(player_name, QuickMessageTable.text_of(quick_id), avatar_id, MPManager.player_color(player_id))
	bubble.finished.connect(_on_bubble_finished)
	_bubbles.append(bubble)
	_trim_bubbles()
	_layout_bubbles()
	bubble.play_intro(BUBBLE_MARGIN_LEFT)
	message_popped.emit(player_name, quick_id)
	_on_message_popped(player_name, quick_id)


## 音效接入口：素材补好后给 MessageSound 赋值即可，外部也可连接 message_popped 信号。
func _on_message_popped(_player_name: String, _quick_id: int) -> void:
	if message_sound and message_sound.stream:
		message_sound.play()


## 系统消息（玩家离开、与主机断开）复用同一套气泡堆叠，外观保持纯文字。
func show_system_message(text: String) -> void:
	var bubble: MessageBubble = bubble_scene.instantiate() as MessageBubble
	if not bubble:
		push_error("MessageOverlay: bubble_scene is not a MessageBubble")
		return
	bubble_layer.add_child(bubble)
	bubble.setup_system(text)
	bubble.finished.connect(_on_bubble_finished)
	_bubbles.append(bubble)
	_trim_bubbles()
	_layout_bubbles()
	bubble.play_intro(BUBBLE_MARGIN_LEFT)


func _trim_bubbles() -> void:
	while _bubbles.size() > MAX_BUBBLES:
		var oldest: MessageBubble = _bubbles[0]
		_bubbles.remove_at(0)
		if is_instance_valid(oldest):
			oldest.dismiss()
	_layout_bubbles()


func _on_bubble_finished(bubble: MessageBubble) -> void:
	_bubbles.erase(bubble)
	if is_instance_valid(bubble):
		bubble.queue_free()
	_layout_bubbles()


func _layout_bubbles() -> void:
	if not bubble_layer:
		return
	var y: float = bubble_layer.size.y - BUBBLE_MARGIN_BOTTOM
	for index: int in range(_bubbles.size() - 1, -1, -1):
		var bubble: MessageBubble = _bubbles[index]
		if not is_instance_valid(bubble):
			continue
		y -= bubble.size.y
		bubble.position = Vector2(bubble.position.x, y)
		y -= BUBBLE_GAP
