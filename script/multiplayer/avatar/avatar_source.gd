class_name AvatarSource
extends Control

## 单个头像的「源场景」根节点。
##
## 一个头像 = 一个 tscn，内部用若干 Control 子节点分层叠出来：
##
##   AvatarXxx (Control, 144x144)   ← 本脚本
##   ├── Background (ColorRect)      ← 底色，通常纯白
##   ├── Base       (TextureRect)    ← 主体素材
##   └── Overlay    (TextureRect)    ← 可选：配件 / 高光 / 描边
##
## 运行时由 AvatarBaker 按子节点顺序纯 CPU 合成成一张 ImageTexture，
## 所以这里只允许 ColorRect 与 TextureRect 两种子节点（可再嵌套 Control 分组）。
##
## 尺寸固定 144×144：头像槽本身是 100px，144 缩到 100 是缩小，能保住像素边缘。

## 头像 id，联机同步与存档都用这个字符串。改名等于换一个新头像。
@export var avatar_id: String = ""

## 合成边长（不用 size 这个名字，会和 Control.size 冲突）。
@export var canvas_size: int = 144


func _ready() -> void:
	# 编辑器里只当普通 Control 显示，不做任何运行时逻辑。
	if Engine.is_editor_hint():
		return
