extends Node

@export var target_container: Container
@export var message_scene: PackedScene

var multiplayer_manager: MultiplayerManager

func _ready() -> void:
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	multiplayer_manager.messages_updated.connect(_on_messages_updated)

func _on_messages_updated() -> void:
	if not multiplayer_manager:
		push_error("MultiplayerManager not found")
		return
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
	var msg_amount = multiplayer_manager.messages.size()
	for m in range(msg_amount):
		var msg_instance = message_scene.instantiate()
		var label = msg_instance.get_node("UiLabel") as Label
		if multiplayer_manager.messages[m]["displayed"]:
			continue
		multiplayer_manager.messages[m]["displayed"] = true
		label.text = \
			multiplayer_manager.messages[m]["player_name"] \
			+ " (" \
			+ multiplayer_manager.messages[m].get("time", "") \
			+ "): " \
			+"\n" \
			+ multiplayer_manager.messages[m]["msg"]

		var fc = func():
			target_container.add_child(msg_instance)
			label.custom_minimum_size.y = label.size.y + 8.0
		fc.call_deferred()

	await get_tree().process_frame
	var scroll = get_parent() as ScrollContainer
	if scroll:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)