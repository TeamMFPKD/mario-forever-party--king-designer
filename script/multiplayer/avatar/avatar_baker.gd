class_name AvatarBaker
extends RefCounted

## 把 AvatarSource 场景（Control 分层树）纯 CPU 合成为一张 ImageTexture。
##
## 为什么不用 SubViewport：无头（--headless）下 dummy 渲染驱动拿不到真实像素，
## 而项目所有验证探针都跑在 headless 里。纯 Image 合成不依赖 GPU，结果确定。
##
## 支持的节点（先序深度优先绘制）：
##   ColorRect     —— 用 color 填充自身矩形
##   Panel         —— 取 StyleBoxFlat 的 bg_color + 圆角
##   TextureRect   —— 绘制 texture，按 stretch_mode 换算
##   其它 Control  —— 仅作分组容器，不绘制
##
## 坐标一律读 offset_*（场景未进树时 Control.size 还是 0，offset 才是准的）。

const OUT_SIZE: int = 144


static func bake(scene: PackedScene, out_size: int = OUT_SIZE) -> ImageTexture:
	var img: Image = bake_image(scene, out_size)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)


static func bake_image(scene: PackedScene, out_size: int = OUT_SIZE) -> Image:
	if scene == null:
		return null
	var root: Node = scene.instantiate()
	if root == null:
		return null
	var canvas: Image = _bake_node(root, out_size)
	root.free()
	return canvas


static func _bake_node(root: Node, out_size: int) -> Image:
	var source_size: Vector2 = _source_size(root)
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return null

	var canvas: Image = Image.create(out_size, out_size, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.0, 0.0, 0.0, 0.0))

	var k: float = float(out_size) / source_size.x
	_draw_tree(root, canvas, k)
	return canvas


## 源场景尺寸：取根 Control 的 offset 矩形，读不到就回退 OUT_SIZE。
static func _source_size(root: Node) -> Vector2:
	var control: Control = root as Control
	if control != null:
		var sz: Vector2 = _offset_size(control)
		if sz.x > 0.0 and sz.y > 0.0:
			return sz
	return Vector2(float(OUT_SIZE), float(OUT_SIZE))


static func _offset_size(control: Control) -> Vector2:
	return Vector2(
		control.offset_right - control.offset_left,
		control.offset_bottom - control.offset_top
	)


static func _offset_rect(control: Control) -> Rect2:
	return Rect2(
		Vector2(control.offset_left, control.offset_top),
		_offset_size(control)
	)


static func _draw_tree(node: Node, canvas: Image, k: float) -> void:
	if node is ColorRect:
		_draw_color_rect(node as ColorRect, canvas, k)
	elif node is Panel:
		_draw_panel(node as Panel, canvas, k)
	elif node is TextureRect:
		_draw_texture_rect(node as TextureRect, canvas, k)
	for child: Node in node.get_children():
		if child is CanvasItem:
			_draw_tree(child, canvas, k)


static func _draw_color_rect(rect: ColorRect, canvas: Image, k: float) -> void:
	if rect.color.a <= 0.0:
		return
	var area: Rect2i = _scaled_rect(rect, canvas, k)
	if area.size.x <= 0 or area.size.y <= 0:
		return
	var fill: Image = Image.create(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
	fill.fill(rect.color)
	canvas.blend_rect(fill, Rect2i(Vector2i.ZERO, fill.get_size()), area.position)


static func _draw_panel(panel: Panel, canvas: Image, k: float) -> void:
	var box: StyleBox = panel.get_theme_stylebox("panel")
	var flat: StyleBoxFlat = box as StyleBoxFlat
	if flat == null or flat.bg_color.a <= 0.0:
		return
	var area: Rect2i = _scaled_rect(panel, canvas, k)
	if area.size.x <= 0 or area.size.y <= 0:
		return
	var fill: Image = Image.create(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
	fill.fill(flat.bg_color)
	var radius_f: float = float(flat.corner_radius_top_left) * k
	var radius: int = roundi(radius_f)
	if radius > 0:
		_apply_corner_alpha(fill, radius)
	canvas.blend_rect(fill, Rect2i(Vector2i.ZERO, fill.get_size()), area.position)


static func _draw_texture_rect(rect: TextureRect, canvas: Image, k: float) -> void:
	if rect.texture == null:
		return
	var area: Rect2i = _scaled_rect(rect, canvas, k)
	if area.size.x <= 0 or area.size.y <= 0:
		return
	var src: Image = _texture_image(rect.texture)
	if src == null:
		return
	# blend_rect 要求源图与画布同格式；24 位 PNG（无 alpha）直接 blend 会变成纯白，
	# 所以统一先转成 RGBA8。
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	# TextureRect.flip_h —— 场景里勾了水平翻转的，合成时同样翻一次
	if rect.flip_h:
		src.flip_x()
	var target: Rect2i = _fit_texture(src.get_size(), area, rect.stretch_mode)
	if target.size.x <= 0 or target.size.y <= 0:
		return
	src.resize(target.size.x, target.size.y, Image.INTERPOLATE_NEAREST)
	canvas.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), target.position)


static func _scaled_rect(rect: Control, canvas: Image, k: float) -> Rect2i:
	var local: Rect2 = _offset_rect(rect)
	var px: float = local.position.x * k
	var py: float = local.position.y * k
	var pw: float = local.size.x * k
	var ph: float = local.size.y * k
	var x: int = roundi(px)
	var y: int = roundi(py)
	var w: int = roundi(pw)
	var h: int = roundi(ph)
	var left: int = maxi(x, 0)
	var top: int = maxi(y, 0)
	var right: int = mini(x + w, canvas.get_width())
	var bottom: int = mini(y + h, canvas.get_height())
	if right <= left or bottom <= top:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(left, top, right - left, bottom - top)


## 取贴图像素。AtlasTexture 的 get_image() 返回的是整张图集，
## 必须按 region 再裁一次，否则精灵表会连同相邻帧一起被画进来。
static func _texture_image(texture: Texture2D) -> Image:
	var atlas: AtlasTexture = texture as AtlasTexture
	if atlas != null:
		if atlas.atlas == null:
			return null
		var full: Image = atlas.atlas.get_image()
		if full == null:
			return null
		var region: Rect2 = atlas.region
		var region_i: Rect2i = Rect2i(
			Vector2i(roundi(region.position.x), roundi(region.position.y)),
			Vector2i(roundi(region.size.x), roundi(region.size.y))
		)
		if region_i.size.x <= 0 or region_i.size.y <= 0:
			return null
		return full.get_region(region_i)
	return texture.get_image()


static func _fit_texture(src_size: Vector2i, area: Rect2i, stretch_mode: int) -> Rect2i:
	if src_size.x <= 0 or src_size.y <= 0:
		return Rect2i(0, 0, 0, 0)
	var sw: float = float(src_size.x)
	var sh: float = float(src_size.y)
	var aw: float = float(area.size.x)
	var ah: float = float(area.size.y)
	match stretch_mode:
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED, TextureRect.STRETCH_KEEP_ASPECT_COVERED:
			var sx: float = aw / sw
			var sy: float = ah / sh
			var sc: float = maxf(sx, sy) if stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED else minf(sx, sy)
			var w: int = maxi(roundi(sw * sc), 1)
			var h: int = maxi(roundi(sh * sc), 1)
			var half_w: float = (aw - float(w)) * 0.5
			var half_h: float = (ah - float(h)) * 0.5
			var px: int = area.position.x + roundi(half_w)
			var py: int = area.position.y + roundi(half_h)
			return Rect2i(px, py, w, h)
		TextureRect.STRETCH_KEEP_ASPECT, TextureRect.STRETCH_KEEP_CENTERED:
			return Rect2i(area.position, src_size)
		_:
			return Rect2i(area.position, area.size)


static func _apply_corner_alpha(img: Image, radius: int) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var half_min: float = float(mini(w, h)) * 0.5
	var r: int = mini(radius, roundi(half_min))
	if r <= 0:
		return
	var rr: float = float(r)
	for y: int in range(r):
		for x: int in range(r):
			var dx: float = float(r - x) - 0.5
			var dy: float = float(r - y) - 0.5
			if dx * dx + dy * dy > rr * rr:
				var clear: Color = Color(0.0, 0.0, 0.0, 0.0)
				img.set_pixel(x, y, clear)
				img.set_pixel(w - 1 - x, y, clear)
				img.set_pixel(x, h - 1 - y, clear)
				img.set_pixel(w - 1 - x, h - 1 - y, clear)
