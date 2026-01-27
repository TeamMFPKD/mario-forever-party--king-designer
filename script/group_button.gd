extends Button

@export var item_group: Control

func _ready() -> void:
	pressed.connect(_on_button_pressed)
	if not item_group:
		print("Warning: item_group is not assigned in ItemButton")
	else:
		item_group.visible = false

func _on_button_pressed() -> void:
	if item_group:
		var item_groups = get_tree().get_nodes_in_group("item_group")
		for node in item_groups:
			if node is Control:
				var control = node as Control
				control.visible = false
		item_group.visible = true
	