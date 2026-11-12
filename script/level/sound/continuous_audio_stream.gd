extends AudioStreamPlayer

class_name ContinuousAudioStream

## 父节点退场时所属的主场景：延迟回调里据此判断"整个场景是不是被卸载了"。
## 不能在此刻判断——Godot 卸载场景时子节点先退出树，此刻场景根还没退出。
var parent: Node
var viewport: Viewport
var tree: SceneTree
var owner_scene: Node
var playing_detect: bool
var free_on_finished_hooked: bool


func _ready() -> void:
	parent = get_parent()
	viewport = parent.get_viewport()
	tree = get_tree()
	if not parent.tree_exiting.is_connected(_on_parent_exiting):
		parent.tree_exiting.connect(_on_parent_exiting)


func _physics_process(_delta: float) -> void:
	if playing_detect and !playing:
		queue_free()


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
	# 换关常在暂停状态下发生，_physics_process 兜底未必跑得到，这里必须当场判。
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
