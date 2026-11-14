extends AudioStreamPlayer

class_name ContinuousAudioStream

## 同一音效资源被重复触发时的处理策略。
## 移植自 MFGTE 的 ContinuousAudioPlayer.SameStreamPolicy。
enum RepeatPolicy {
	## 叠加（默认）：同资源并发超过 max_same_stream_voices 后，新实例音量压到 overflow_volume_db。
	## 适合"群体事件"——一片砖同时碎、一群敌人同时被踩，防止叠成噪音。
	## 不会整段静音，只是把超出上限的那几次压到听不见。
	OVERLAP = 0,
	## 重播截断：新实例起播时停掉同资源的其它实例，只留最新这一击。
	## 适合"连击"音效——高频但每次只想听最新一次（金币、顶砖、时间滴答）：
	## 既不象 OVERLAP 那样把超限的几次整段静音（表现是"音效少了/断续"），
	## 也不会叠成噪音。
	RESTART = 1,
}

## 同一音效资源被重复触发时的处理策略。
@export var repeat_policy: RepeatPolicy = RepeatPolicy.OVERLAP

## 同资源允许同时发声的实例上限。已达上限后，新发声的实例音量压到 overflow_volume_db。
## 仅在 repeat_policy = OVERLAP 时生效。
@export var max_same_stream_voices: int = 8

## 并发超限时新生效实例的音量（dB，默认 -60 基本听不见）。仅 OVERLAP 生效。
@export var overflow_volume_db: float = -60.0

## 父节点退场时所属的主场景：延迟回调里据此判断"整个场景是不是被卸载了"。
## 不能在此刻判断——Godot 卸载场景时子节点先退出树，此刻场景根还没退出。
var parent: Node
var viewport: Viewport
var tree: SceneTree
var owner_scene: Node
var playing_detect: bool
var free_on_finished_hooked: bool

## 当前在世界里发声中的同类实例（静态登记表，用于统计"同一音效资源"的并发数）。
static var _voices: Array[ContinuousAudioStream] = []

## 所有在场音效节点（静态登记表）：供统一轮询器每帧集中检查 Playing 状态。
static var _registry: Array[ContinuousAudioStream] = []

## 统一轮询器实例（常驻 SceneTree.Root，首次入场时按需创建）。
static var _poller: Node = null

## 轮询器脚本路径。
## 这里必须用运行时 load 而不能 preload：audio_voice_poller.gd 里要调用本类的
## 静态方法，preload 会造成「A 依赖 B、B 依赖 A」的循环引用，两个脚本都解析失败。
const POLLER_SCRIPT_PATH: String = "res://script/level/sound/audio_voice_poller.gd"

## 上一帧的播放状态，用于捕捉"开始发声"这一上升沿。
var _was_playing: bool = false
## 调用方原本设定的音量（dB）；被并发压制时先存起来，停播时还原。
var _base_volume_db: float = 0.0
## 本实例当前是否正处于"并发超限被压制"状态。
var _suppressed: bool = false
## 本次发声的音频资源标识（同一资源视为"同一个音效"）。
var _stream_key: String = ""


func _enter_tree() -> void:
	if not _registry.has(self):
		_registry.append(self)
	_ensure_poller()


func _exit_tree() -> void:
	_registry.erase(self)
	_voices.erase(self)


func _ready() -> void:
	parent = get_parent()
	viewport = parent.get_viewport()
	tree = get_tree()
	if not parent.tree_exiting.is_connected(_on_parent_exiting):
		parent.tree_exiting.connect(_on_parent_exiting)
	_base_volume_db = volume_db


## AudioStreamPlayer 没有"开始播放"信号，只能比对 playing 状态捕捉上升沿。
## 由统一轮询器每帧集中调用一次（不再逐节点占一个 _physics_process 回调）；
## 代价是压制会晚一帧生效（60Hz 下 ≤16ms，刚好落在音效起振段，听感无碍）。
func poll_playback() -> void:
	var playing_now: bool = playing

	# 换关保护：搬到 Viewport 下的一次性音效播完后自行释放。
	if playing_detect and not playing_now:
		queue_free()
		return

	if playing_now:
		if not _was_playing:
			_on_started_playing()
		elif not _voices.has(self):
			_voices.append(self)
	elif _was_playing:
		_on_stopped_playing()

	_was_playing = playing_now


## 统一轮询入口（由轮询器每帧调用一次）：遍历在场音效节点，顺带清理已释放实例。
static func poll_all_playback() -> void:
	for i: int in range(_registry.size() - 1, -1, -1):
		var player: ContinuousAudioStream = _registry[i]
		if player == null or not is_instance_valid(player):
			_registry.remove_at(i)
			continue
		player.poll_playback()


## 开始发声：按 repeat_policy 决定与同资源既有实例的关系。
func _on_started_playing() -> void:
	_prune_voices()

	_stream_key = get_stream_key()
	if not _voices.has(self):
		_voices.append(self)

	if repeat_policy == RepeatPolicy.RESTART:
		_stop_same_stream_voices()
		if _suppressed:
			_suppressed = false
			volume_db = _base_volume_db
		return

	# 只在"未被自己压过"时采样，避免把压制值当成原音量累积。
	if not _suppressed:
		_base_volume_db = volume_db
	var same_stream: int = _count_same_stream()
	_suppressed = same_stream >= max_same_stream_voices
	volume_db = overflow_volume_db if _suppressed else _base_volume_db


## RESTART 策略：停掉同资源的其它发声实例。
## 一次性实例（已挂"播完自释放"）顺手 queue_free，避免只停不播完导致节点残留；
## 常驻实例（场景里的音效节点）只停播，绝不能销毁。
func _stop_same_stream_voices() -> void:
	for i: int in range(_voices.size() - 1, -1, -1):
		var other: ContinuousAudioStream = _voices[i]
		if other == null or not is_instance_valid(other):
			_voices.remove_at(i)
			continue
		if other == self:
			continue
		if other.get_stream_key() != _stream_key:
			continue

		# 先停再释放：stop() 让 playing 立刻为 false，
		# 统一轮询器下一帧就不会把它当"正在发声"重新登记回 _voices。
		other.stop()
		if other.free_on_finished_hooked:
			other.queue_free()
		_voices.remove_at(i)


## 停止发声：还原被压制的音量（实例若复用，下次发声才能取到正确的原音量）。
func _on_stopped_playing() -> void:
	_voices.erase(self)
	if _suppressed:
		_suppressed = false
		volume_db = _base_volume_db


## 同一音效资源（同一个 AudioStream）当前正在发声的实例数，不含自己。
func _count_same_stream() -> int:
	var count: int = 0
	for other: ContinuousAudioStream in _voices:
		if other == self:
			continue
		if other == null or not is_instance_valid(other):
			continue
		if not other.playing:
			continue
		if other.get_stream_key() != _stream_key:
			continue
		count += 1
	return count


## 登记表清灰：剔除已释放 / 已离树 / 已停播的实例。
static func _prune_voices() -> void:
	for i: int in range(_voices.size() - 1, -1, -1):
		var voice: ContinuousAudioStream = _voices[i]
		if voice == null or not is_instance_valid(voice) \
				or voice.is_queued_for_deletion() \
				or not voice.is_inside_tree() \
				or not voice.playing:
			_voices.remove_at(i)


## 音效资源标识：优先用资源路径（同一文件加载出的 AudioStream 视为同一个音效），
## 内联/无路径资源（如程序内 new 出来的）退化为实例 ID。
func get_stream_key() -> String:
	if stream == null:
		return ""
	if not stream.resource_path.is_empty():
		return stream.resource_path
	return "@instance:%d" % stream.get_instance_id()


## 确保统一轮询器存在：挂在 SceneTree.Root 下常驻（等同 autoload，但不改 project.godot）。
static func _ensure_poller() -> void:
	if _poller != null and is_instance_valid(_poller):
		return
	var main_loop: MainLoop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		return
	var scene_tree: SceneTree = main_loop
	var poller_script: GDScript = load(POLLER_SCRIPT_PATH) as GDScript
	if poller_script == null:
		return
	var poller_variant: Variant = poller_script.new()
	if not poller_variant is Node:
		return
	var poller: Node = poller_variant
	poller.name = "AudioVoicePoller"
	_poller = poller
	# 在别的节点 _enter_tree 期间直接改树会报 "Parent node is busy"，延迟到空闲帧加入。
	var add_child_callable: Callable = Callable(scene_tree.root, &"add_child").bind(poller)
	add_child_callable.call_deferred()


## 父节点退场：把本实例搬到 Viewport，让正在播的一次性音效播完再释放。
## 但整个主场景被卸载（切关 / 死亡重开 / 退出）时，旧关卡的音效一律不续播，
## 否则上一关正在响的音效会串到新场景、和新场景的开局音叠在一起。
func _on_parent_exiting() -> void:
	owner_scene = tree.current_scene if tree != null else null
	# AudioStreamPlayer 每次进入场景树都会检查 autoplay：临时摘掉，
	# 防止重新入树时又从头播一遍（旧音效在新场景"诈尸"）。
	var was_autoplay: bool = autoplay
	autoplay = false
	if parent != null:
		parent.remove_child(self)
	var fn: Callable = func() -> void:
		_reparent_to_viewport(was_autoplay)
	fn.call_deferred()
	free_on_finished()


func _reparent_to_viewport(was_autoplay: bool) -> void:
	# 主场景已随卸载销毁（reload_current_scene / change_scene_to_file / 手动换关）：
	# 旧关卡的声音一律不续播。current_scene 为空只发生在退出或主场景尚未就绪时，
	# 同样不该续播（顺带避开向已销毁的 Viewport 挂节点）。
	if owner_scene == null \
			or not is_instance_valid(owner_scene) \
			or not owner_scene.is_inside_tree():
		queue_free()
		return
	if not is_instance_valid(viewport):
		queue_free()
		return
	viewport.add_child(self)
	autoplay = was_autoplay
	# 退场前没在播 / 已经播完：不留滞在 Viewport 下。
	# 换关常在暂停状态下发生，轮询兜底未必跑得到，这里必须当场判。
	if not playing:
		queue_free()
		return
	playing_detect = true


## 幂等挂"播完自释放"，避免重复连接 finished 报 ERR_INVALID_PARAMETER。
func free_on_finished() -> void:
	if free_on_finished_hooked:
		return
	free_on_finished_hooked = true
	finished.connect(queue_free)
