extends Button

class_name ItemButton

enum ItemType {
	TILE,
	OBJECT,
	ERASER,
	CLEAR_PIPE,
	OTHER,
}

@export var item_type: ItemType = ItemType.OBJECT
@export var object_name: String = ""

var level_control: LevelControl

func _ready():
	level_control = get_tree().get_first_node_in_group("level_control") as LevelControl
	pressed.connect(_on_button_pressed)

func _on_button_pressed():
	if level_control:
		level_control._on_item_button_pressed(item_type, self)