extends Button

@export var item_group: Control

func _ready() -> void:
	pressed.connect(_on_button_pressed)
	if not item_group:
		push_error("item_group is not assigned in ItemButton")
	else:
		item_group.visible = false

func _on_button_pressed() -> void:
	if item_group:
		if item_group.visible:
			item_group.visible = false
			return
		var item_groups: Array[Node] = get_tree().get_nodes_in_group("item_group")
		for node: Node in item_groups:
			if node is Control:
				var control: Control = node
				control.visible = false
		item_group.visible = true
	else:
		push_error("item_group is not assigned in ItemButton")
	