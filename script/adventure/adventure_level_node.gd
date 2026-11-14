class_name AdventureLevelNode
extends Node2D

## 关卡示意图的一格：白色半透明椭圆 + 中间的关卡编号。
## 椭圆的贴图与尺寸、编号的字体 / 字号 / 颜色 / 描边全部在
## object/adventure/level_node.tscn 里调，编辑器打开场景就能看到效果；
## 脚本只负责按关卡号填文字。

@export var number_label: Label


## endless = true 时显示「?」（无尽团后面的关卡未知）。
func setup(number: int, endless: bool) -> void:
	if number_label == null:
		return
	number_label.text = "?" if endless else str(number)
