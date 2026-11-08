class_name AvatarRing
extends RefCounted

## 给头像外圈上色。
##
## 每个头像槽的根节点下面都垫了一个铺满的 Ring(Panel)：样式盒是纯色实心圆，
## 圆角半径在场景里写死成槽位边长的一半（槽位尺寸固定，不需要运行时按尺寸重算）。
## 头像本体（白色圆底 + 圆形裁切贴图 / 名字首字）比 Ring 小一圈居中，
## 露出来的那一圈就是玩家身份色。
##
## 样式盒是场景级 sub_resource，同一场景的多个实例共用一份，
## 所以改颜色前必须先 duplicate，否则会把整个列表染成最后一个人的颜色。


## 把 ring_panel 的实心圆染成 color（重复调用会复写上一次的颜色）。
static func paint(ring_panel: Panel, color: Color) -> void:
	if ring_panel == null:
		return
	var style: StyleBoxFlat = null
	var source: StyleBox = ring_panel.get_theme_stylebox("panel")
	if source is StyleBoxFlat:
		var flat: StyleBoxFlat = source as StyleBoxFlat
		style = flat.duplicate() as StyleBoxFlat
	else:
		style = StyleBoxFlat.new()
	style.bg_color = color
	ring_panel.add_theme_stylebox_override("panel", style)
