extends Node

class_name PlayerDependent

## 依赖玩家的组件基类。
## 玩家身体由 PlayerBodyInjector 延迟一帧调用 inject_player_body() 注入，
## 组件自己不做 group 查找。

## 注入的玩家身体节点
var player_body: Node2D

## 注入入口（由 PlayerBodyInjector 调用）
func inject_player_body(body: Node2D) -> void:
	player_body = body
	_on_player_injected(body)

## 子类覆写：拿到玩家后做自己的初始化
func _on_player_injected(_body: Node2D) -> void:
	pass

## 获取玩家身体：注入值缺失或失效（玩家死亡/重生）时按组兜底重查一次
func get_player_body() -> Node2D:
	if is_instance_valid(player_body):
		return player_body
	if not is_inside_tree():
		return null
	player_body = get_tree().get_first_node_in_group("player") as Node2D
	return player_body
