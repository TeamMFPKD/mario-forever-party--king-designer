extends Node

@export var target_container: Container
@export var message_scene: PackedScene

var multiplayer_manager: MultiplayerManager

func _ready() -> void:
	multiplayer_manager = MPManager
	multiplayer_manager.messages_updated.connect(_on_messages_updated)

func _on_messages_updated() -> void:
	if not target_container:
		push_error("TargetContainer not found")
		return
	'''
	var message_nodes = target_container.get_children()
	var sys_msg_node = message_nodes[0] if message_nodes.size() > 0 else null
	for node in message_nodes:
		if node == sys_msg_node:
			continue
		node.queue_free()
	'''
	var msg_amount: int = multiplayer_manager.messages.size()
	for m: int in range(msg_amount):
		var msg_instance: Node = message_scene.instantiate()
		var label: Label = msg_instance.get_node("UiLabel") as Label
		var message: Dictionary = multiplayer_manager.messages[m]
		if message["displayed"]:
			continue
		message["displayed"] = true
		var player_name: String = message["player_name"]
		var time_str: String = message.get("time", "")
		var msg: String = _get_message_text(message)
		label.text = \
			player_name \
			+ " (" \
			+ time_str \
			+ "): " \
			+"\n" \
			+ msg

		var fc: Callable = func() -> void:
			target_container.add_child(msg_instance)
			label.custom_minimum_size.y = label.size.y + 8.0
		fc.call_deferred()

	await get_tree().process_frame
	var scroll: ScrollContainer = get_parent() as ScrollContainer
	if scroll:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


## 快捷用语只带序号，按本地语言渲染；封存前的自定义文本消息仍按原文显示。
func _get_message_text(message: Dictionary) -> String:
	var quick_id_variant: Variant = message.get("quick_id", 0)
	var quick_id: int = 0
	if quick_id_variant is int:
		quick_id = quick_id_variant
	if QuickMessageTable.is_valid_id(quick_id):
		return QuickMessageTable.text_of(quick_id)
	return str(message.get("msg", ""))