extends Node

## 内置头像库（autoload 名：Avatars）。
##
## 只做一件事：把 res://sprite/avatar/avatar_pack.tres 读成「id → 贴图」的查表，
## 供头像选择器（avatar_selector.gd）与消息气泡（message_bubble.gd）使用。
## 素材怎么加见 script/multiplayer/avatar/avatar_pack.gd 文件头。
##
## id 由数组序号决定（avatar_00、avatar_01……），因此同一份工程里各端一定一致；
## 新增头像请追加到 avatar_pack.tres 数组末尾，插在中间会让已有玩家的选择整体后移。

const PACK_PATH: String = "res://sprite/avatar/avatar_pack.tres"

## id → 贴图
var _textures: Dictionary = {}
## 选择器左右切换的顺序，元素是 id
var _order: PackedStringArray = PackedStringArray()


func _ready() -> void:
	reload()


## 重新读取头像清单（改完 avatar_pack.tres 后可在编辑器里手动调一次）。
func reload() -> void:
	_textures.clear()
	_order.clear()
	if not ResourceLoader.exists(PACK_PATH):
		Log.w("Avatars", "找不到头像清单：%s" % PACK_PATH)
		return
	var pack: AvatarPack = load(PACK_PATH) as AvatarPack
	if pack == null:
		# 典型症状：清单里某个素材被改名 / 删除，ext_resource 的 uid 还指向旧文件，
		# 整份 .tres 解析失败。这时按文本里的 path 逐个补读，别让头像系统静默变空。
		Log.e("Avatars", "清单加载失败（可能引用了已被改名或删除的素材），改用文本兜底：%s" % PACK_PATH)
		_load_from_text()
		return
	# 日志用：id(素材文件名)，方便对着 avatar_pack.tres 检查
	var described: PackedStringArray = PackedStringArray()
	for index: int in range(pack.textures.size()):
		var texture: Texture2D = pack.textures[index]
		if texture == null:
			continue
		var avatar_id: String = "avatar_%02d" % index
		_textures[avatar_id] = texture
		_order.append(avatar_id)
		described.append("%s(%s)" % [avatar_id, texture.resource_path.get_file()])
	Log.i("Avatars", "已加载 %d 个内置头像：%s" % [_order.size(), ", ".join(described)])


## 兜底：从 .tres 文本里抓 type="Texture2D" path="res://..." 按出现顺序加载。
## 顺序与 textures 数组一致，所以兜底后 id 仍然对得上。
func _load_from_text() -> void:
	var text: String = FileAccess.get_file_as_string(PACK_PATH)
	if text.is_empty():
		return
	var regex: RegEx = RegEx.new()
	# 兼容编辑器写出的 [ext_resource type="Texture2D" uid="..." path="..."] 形式
	if regex.compile("\\[ext_resource type=\"Texture2D\"[^\\]]*path=\"(res://[^\"]+)\"") != OK:
		return
	var described: PackedStringArray = PackedStringArray()
	for result: RegExMatch in regex.search_all(text):
		var path: String = result.get_string(1)
		if not ResourceLoader.exists(path):
			Log.w("Avatars", "跳过无法加载的头像素材：%s" % path)
			continue
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			Log.w("Avatars", "跳过无法加载的头像素材：%s" % path)
			continue
		var avatar_id: String = "avatar_%02d" % _order.size()
		_textures[avatar_id] = texture
		_order.append(avatar_id)
		described.append("%s(%s)" % [avatar_id, path.get_file()])
	Log.w("Avatars", "按文本兜底加载 %d 个头像：%s" % [described.size(), ", ".join(described)])


## 可选头像总数
func count() -> int:
	return _order.size()


## 是否一个头像都没有（此时界面回退到「名字首字」外观）
func is_empty() -> bool:
	return _order.is_empty()


## 第 index 个头像的 id，越界返回空串
func get_id(index: int) -> String:
	if index < 0 or index >= _order.size():
		return ""
	return _order[index]


## 第 index 个头像的贴图，越界返回 null
func get_texture(index: int) -> Texture2D:
	return get_texture_by_id(get_id(index))


## id 在清单里的序号，找不到返回 -1
func index_of(avatar_id: String) -> int:
	return _order.find(avatar_id)


## id 对应的贴图；id 为空或该端没有这个头像时返回 null，调用方回退到名字首字
func get_texture_by_id(avatar_id: String) -> Texture2D:
	var texture: Variant = _textures.get(avatar_id)
	if texture is Texture2D:
		return texture
	return null


## 默认头像（清单里的第一个）；清单为空时返回空串
func default_id() -> String:
	return get_id(0)
