extends Node

## 内置头像库（autoload 名：Avatars）。
##
## 数据源：res://sprite/avatar/avatar_pack.tres
##   - pack.scenes   ：分层头像场景，运行时用 AvatarBaker 合成成贴图（优先）
##   - pack.textures ：单张贴图（旧数据，scenes 为空时回退）
##
## **头像 id 是字符串，由素材自身决定**（场景的 avatar_id 字段 / 贴图文件名），
## 不再是数组序号。这样增删头像不会让已有玩家选中的 id 失效；
## 数组顺序只用来决定选择器左右切换的顺序。

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

	if not pack.scenes.is_empty():
		_load_from_scenes(pack)
	else:
		_load_from_textures(pack)


## 首选：分层场景逐个烘焙成贴图。headless 下同样有效（纯 CPU，不依赖 GPU）。
func _load_from_scenes(pack: AvatarPack) -> void:
	var described: PackedStringArray = PackedStringArray()
	for index: int in range(pack.scenes.size()):
		var scene: PackedScene = pack.scenes[index]
		if scene == null:
			Log.w("Avatars", "第 %d 个场景为空，跳过" % index)
			continue
		var avatar_id: String = _peek_id(scene, index)
		if avatar_id.is_empty():
			Log.w("Avatars", "第 %d 个场景没有填 avatar_id，跳过" % index)
			continue
		if _textures.has(avatar_id):
			Log.w("Avatars", "重复的头像 id：%s，跳过第 %d 个" % [avatar_id, index])
			continue
		var texture: ImageTexture = AvatarBaker.bake(scene)
		if texture == null:
			Log.w("Avatars", "烘焙失败：%s" % avatar_id)
			continue
		_textures[avatar_id] = texture
		_order.append(avatar_id)
		described.append(avatar_id)
	Log.i("Avatars", "已加载 %d 个分层头像：%s" % [_order.size(), ", ".join(described)])


## 从场景根节点读 avatar_id（不进入树，只实例化后立刻释放）。
func _peek_id(scene: PackedScene, index: int) -> String:
	var node: Node = scene.instantiate()
	var id: String = ""
	if node != null:
		if "avatar_id" in node:
			id = str(node.get("avatar_id"))
		node.free()
	if id.is_empty():
		id = "scene_%02d" % index
	return id


## 旧数据：单张贴图，id 取文件名（不含扩展名）。
func _load_from_textures(pack: AvatarPack) -> void:
	var described: PackedStringArray = PackedStringArray()
	for index: int in range(pack.textures.size()):
		var texture: Texture2D = pack.textures[index]
		if texture == null:
			continue
		var avatar_id: String = texture.resource_path.get_file().get_basename()
		if avatar_id.is_empty():
			avatar_id = "avatar_%02d" % index
		if _textures.has(avatar_id):
			Log.w("Avatars", "重复的头像 id：%s，跳过" % avatar_id)
			continue
		_textures[avatar_id] = texture
		_order.append(avatar_id)
		described.append("%s(%s)" % [avatar_id, texture.resource_path.get_file()])
	Log.i("Avatars", "已加载 %d 个贴图头像：%s" % [_order.size(), ", ".join(described)])


## 兜底：从 .tres 文本里抓 type="Texture2D" path="res://..." 按出现顺序加载。
func _load_from_text() -> void:
	var text: String = FileAccess.get_file_as_string(PACK_PATH)
	if text.is_empty():
		return
	var regex: RegEx = RegEx.new()
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
		var avatar_id: String = path.get_file().get_basename()
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
