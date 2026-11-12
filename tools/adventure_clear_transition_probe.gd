extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 自检：转场场景能否播放完、play 场景里能否找到挂载点。

const OUTPUT: String = "res://tools/adventure_clear_transition_probe.txt"

var _finished_count: int = 0


func _on_finished() -> void:
	_finished_count += 1


## 划入阶段纵向必须完全不动：采样 Chain 与 Player 的 global y。
func _vertical_line(transition: CanvasLayer, tag: String) -> String:
	var player: AnimatedSprite2D = transition.get_node("Root/Yellow/Player") as AnimatedSprite2D
	var chain: Control = transition.get_node("Root/Yellow/Chain") as Control
	return "%s chain_y=%.2f player_y=%.2f" % [tag, chain.global_position.y, player.global_position.y]


## 检查最近的一颗关卡椭圆中心与玩家可见中心的 x 偏差。
func _alignment_line(transition: CanvasLayer, tag: String) -> String:
	var row: Node2D = transition.get_node("Root/Yellow/Chain/LevelRow") as Node2D
	var player: AnimatedSprite2D = transition.get_node("Root/Yellow/Player") as AnimatedSprite2D
	var player_center: float = player.global_position.x + 32.0 * 0.8 * 0.5
	var best_diff: float = 9999.0
	var best_x: float = 0.0
	for child: Node in row.get_children():
		var node_2d: Node2D = child as Node2D
		if node_2d == null:
			continue
		if absf(node_2d.global_position.x - player_center) < absf(best_diff):
			best_diff = node_2d.global_position.x - player_center
			best_x = node_2d.global_position.x
	return "%s player=%.2f nearest=%.2f diff=%.2f" % [tag, player_center, best_x, best_diff]


func _ready() -> void:
	var lines: PackedStringArray = PackedStringArray()

	var packed: PackedScene = load("res://object/ui/adventure_clear_transition.tscn") as PackedScene
	if packed == null:
		lines.append("TRANSITION_SCENE LOAD_FAIL")
	else:
		var transition: CanvasLayer = packed.instantiate() as CanvasLayer
		add_child(transition)
		transition.connect("finished", _on_finished)
		transition.call("play", 3, 10)
		await get_tree().create_timer(0.1).timeout
		lines.append(_vertical_line(transition, "y_at_0.1"))
		await get_tree().create_timer(0.2).timeout
		lines.append(_vertical_line(transition, "y_at_0.3"))
		await get_tree().create_timer(0.15).timeout
		lines.append(_alignment_line(transition, "before_jump"))
		await get_tree().create_timer(0.6).timeout
		lines.append(_alignment_line(transition, "after_jump"))
		await get_tree().create_timer(1.2).timeout
		lines.append("TRANSITION finished=%d visible=%s" % [_finished_count, str(transition.visible)])
		transition.queue_free()

	var play_packed: PackedScene = load("res://room/adventure_play.tscn") as PackedScene
	if play_packed == null:
		lines.append("PLAY_SCENE LOAD_FAIL")
	else:
		var play: Node = play_packed.instantiate()
		add_child(play)
		await get_tree().process_frame
		var node: Node = play.get_node_or_null("GameRoomSize/SubViewportContainer/SubViewport/AdventureClearTransition")
		var size_text: String = "n/a"
		if node != null:
			var layer: CanvasLayer = node as CanvasLayer
			var root: Control = layer.get_child(0) as Control
			if root != null:
				size_text = str(root.size)
		lines.append("PLAY_SCENE mount=%s size=%s" % [str(node != null), size_text])
		play.queue_free()

	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	get_tree().quit()
