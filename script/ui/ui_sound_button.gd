class_name UiSoundButton
extends Button

## 带音效的通用按钮基类，挂在 ui/ui_button.tscn 上，所有用该场景的按钮自动继承。
##
## 两个音效各自独立配置：
## - `focus_sound`：四角红框切到这个按钮时播（留空则退回 UiNavigator 的全局默认音效）
## - `pressed_sound`：按下时播（留空则不出声）
##
## 注意焦点不是靠 `grab_focus()` 触发的——项目里 `NoButtonFocus` 把所有按钮的
## focus_mode 压成 NONE，红框是 UiNavigator 自己画的，所以由它主动调
## `play_focus_sound()`。
##
## 播放器是**全局静态池**，节点挂在 `get_tree().root` 下而不是按钮自己身上：
## 按钮随场景销毁时如果播放器也跟着没了，切场景那一下的音效就会被硬截断。

## 被四角焦点切到时播放的音效；留空表示用全局默认的移动音效。
@export var focus_sound: AudioStream
## 按下时播放的音效；留空表示不出声。
@export var pressed_sound: AudioStream

## 池大小：同时最多叠这么多个音效，超出就抢占最旧的一个
const POOL_SIZE: int = 4
const POOL_HOLDER_NAME: StringName = &"UiSoundPool"

static var _pool: Array[AudioStreamPlayer] = []
static var _pool_index: int = 0


func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	_play(pressed_sound)


## 由 UiNavigator 调用。返回 true 表示已播放，调用方不必再播默认音效。
func play_focus_sound() -> bool:
	return _play(focus_sound)


func _play(stream: AudioStream) -> bool:
	if stream == null:
		return false
	var player: AudioStreamPlayer = _next_player()
	if player == null:
		return false
	player.stream = stream
	player.play()
	return true


## 轮转取一个播放器；池还没建（或场景切换把 root 下的持有节点清掉了）时重建。
static func _next_player() -> AudioStreamPlayer:
	if _pool.is_empty() or not is_instance_valid(_pool[0]):
		_build_pool()
	if _pool.is_empty():
		return null
	var player: AudioStreamPlayer = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	return player


static func _build_pool() -> void:
	_pool.clear()
	_pool_index = 0
	var main_loop: MainLoop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return
	var tree: SceneTree = main_loop as SceneTree
	var holder: Node = tree.root.get_node_or_null(String(POOL_HOLDER_NAME))
	if holder == null:
		holder = Node.new()
		holder.name = POOL_HOLDER_NAME
		tree.root.add_child(holder)
	for i: int in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "UiSoundPlayer%d" % i
		# UI 音效走独立总线，音量由设置里的「UI 音量」控制
		player.bus = &"UI"
		# 菜单通常停在暂停状态，播放器必须无视 tree.paused
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		holder.add_child(player)
		_pool.append(player)
