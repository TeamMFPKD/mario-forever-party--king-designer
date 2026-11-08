class_name PlayerColor
extends RefCounted

## 玩家身份色：头像外圈与消息气泡描边共用这一份色表。
##
## 分配规则（按玩家在房间名单里的位置，也就是玩家列表里显示的 1P / 2P …）：
##   1P 白，2P 起按「红 绿 蓝 橙 青 黄 紫」循环
##   1P 白 / 2P 红 / 3P 绿 / 4P 蓝 / 5P 橙 / 6P 青 / 7P 黄 / 8P 紫 / 9P 红 ……
##
## 位置是各端都一样的确定信息，所以颜色完全由本地算出来，不进网络包。

## 1P 的颜色（也用作算不出位置时的兜底色）
const FIRST: Color = Color(1.0, 1.0, 1.0, 1.0)

## 2P 起的循环色，顺序：红 绿 蓝 橙 青 黄 紫
const CYCLE: Array[Color] = [
	Color(0.91, 0.24, 0.24, 1.0),
	Color(0.24, 0.73, 0.34, 1.0),
	Color(0.22, 0.51, 0.93, 1.0),
	Color(0.97, 0.56, 0.13, 1.0),
	Color(0.16, 0.78, 0.85, 1.0),
	Color(0.97, 0.84, 0.18, 1.0),
	Color(0.66, 0.36, 0.92, 1.0),
]


## 第 index 位玩家（0 = 1P）的身份色；index 为负（不在房间名单里）按 1P 处理。
static func for_index(index: int) -> Color:
	if index <= 0:
		return FIRST
	return CYCLE[(index - 1) % CYCLE.size()]
