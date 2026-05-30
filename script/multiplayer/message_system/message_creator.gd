extends Node

@export var target_container: Container
@export var message_scene: PackedScene

var multiplayer_manager : MultiplayerManager

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
	var message_nodes = target_container.get_children()
	var sys_msg_node = message_nodes[0] if message_nodes.size() > 0 else null
	for node in message_nodes:
		if node == sys_msg_node:
			continue
		node.queue_free()
	for m in multiplayer_manager.messages:
		var msg_instance = message_scene.instantiate()
		var label = msg_instance.get_node("UiLabel") as Label
		label.text = m["player_name"] + ": " + m["msg"]
		var fc = func():
			target_container.add_child(msg_instance)
		fc.call_deferred()