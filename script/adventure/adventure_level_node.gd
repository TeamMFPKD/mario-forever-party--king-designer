class_name AdventureLevelNode
extends Node2D

## 关卡示意图的一格：白色半透明椭圆 + 中间的关卡编号。
## 椭圆的贴图与尺寸、编号的字体 / 字号 / 颜色 / 描边全部在
## object/adventure/level_node.tscn 里调，编辑器打开场景就能看到效果；
## 脚本只负责按关卡号填文字。

@export var number_label: Label


## 无尽团也照实写关卡号：示意图套在进度上的 10 格窗口里，每一格都是已知的关号
## （第 360 关就显示 351…360），不再用「?」表示未知。
func setup(number: int) -> void:
	if number_label == null:
		return
	number_label.text = str(number)
