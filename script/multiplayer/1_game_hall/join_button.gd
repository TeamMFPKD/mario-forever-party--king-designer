extends Button

@export var line_edit_frp_domain: LineEdit
@export var line_edit_remote_port: LineEdit
@export var line_edit_player_name: LineEdit

@export var player_page: Control

@export var player_name_limit: int = 12

const GameConfigType: GDScript = preload("res://script/utils/game_config.gd")
const ROLE_TOGGLE_SCRIPT: GDScript = preload("res://script/multiplayer/1_game_hall/role_toggle_button.gd")

var game_config: GameConfigType
var frp_domain: String = ""
var remote_port: int = 0
var player_name: String = ""


func _ready() -> void:
	pressed.connect(_on_button_pressed)
	game_config = GameConfig

	# 从配置加载默认值
	if game_config:
		line_edit_frp_domain.text = game_config.get_frp_domain()
		line_edit_remote_port.text = str(game_config.get_remote_port())
		line_edit_player_name.text = game_config.get_player_name()
	_add_role_row()


func _add_role_row() -> void:
	var hbox: Node = get_parent()
	if hbox == null:
		return
	var box: Node = hbox.get_parent()
	if box == null:
		return
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "RoleRow"
	row.theme = preload("res://mfmp_theme.tres")
	# 与下方 Quit/Host 那行保持同样的间距，左右两格才能宽度对齐。
	row.add_theme_constant_override("separation", 32)
	# 文案与字号对齐 UiLabel（45 / outline 7），并撑满左半格。
	var label: Label = Label.new()
	label.text = tr("参与模式")
	label.add_theme_font_size_override("font_size", 45)
	label.add_theme_constant_override("outline_size", 7)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	# 按钮字号、内边距、尺寸全部交给 mfmp_theme（与 Quit/Host 同源），撑满右半格。
	var button: Button = Button.new()
	button.name = "RoleToggleButton"
	button.set_script(ROLE_TOGGLE_SCRIPT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_FILL
	# ui_button.tscn 里字号是 50 的 override，动态 new 出来的按钮不会继承，
	# 这里补上同值，否则文字会比 Quit/Host 小一圈。
	button.add_theme_font_size_override("font_size", 50)
	row.add_child(button)
	box.add_child.call_deferred(row)
	# 放在头像选择器之后、底部按钮行之前。
	box.move_child.call_deferred(row, hbox.get_index())
	# 行高对齐下方 Quit/Host 那一行：等布局稳定后取同列按钮的实际高度。
	_sync_role_row_height.call_deferred(button, hbox)


## 把「参与模式」行的高度对齐到下方按钮行，避免两行一高一矮。
func _sync_role_row_height(button: Button, hbox: Node) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if button == null or not is_instance_valid(button):
		return
	for child: Node in hbox.get_children():
		var ref: Control = child as Control
		if ref != null and ref != button:
			# 用最小尺寸而不是 size：按钮行此刻可能还没完成布局，size 会取到 tscn 里的旧 offset。
			var h: float = ref.get_combined_minimum_size().y
			if h > 0.0:
				button.custom_minimum_size.y = h
				return


func _on_button_pressed() -> void:
	frp_domain = line_edit_frp_domain.text.strip_edges()
	remote_port = line_edit_remote_port.text.to_int()
	player_name = line_edit_player_name.text.substr(0, player_name_limit)

	var manager: MultiplayerManager = MPManager
	manager.frp_domain = frp_domain
	manager.remote_port = remote_port
	manager.player_name = player_name
	manager.player.name = player_name
	# 测试启动的观战身份由 role_toggle_button 在 _ready 里预选；
	# 正常界面由“参与模式”按钮决定，这里不覆盖。
	if MpTest.has("--mp-spectate"):
		manager.player.is_spectator = true

	# 测试启动不写全局配置，避免同机多实例并发覆盖 user://game_settings.cfg。
	if game_config and not MpTest.is_test_launch():
		game_config.set_frp_domain(frp_domain)
		game_config.set_remote_port(remote_port)
		game_config.set_player_name(player_name)

	manager.join_game(frp_domain, remote_port)
