extends Node

@export var path_to_text_node: NodePath = ".."
@export var text_node: LineEdit

const MAX_TEXT_LENGTH := 80

func _ready():
	text_node = get_node(path_to_text_node) as LineEdit
	if not text_node:
		push_error("text_node is not found")
	if not text_node is LineEdit:
		push_error("text_node is not a LineEdit")
	text_node.text_changed.connect(_on_text_changed)

func _on_text_changed(_new_text: String) -> void:
	text_node.text = _new_text.substr(0, MAX_TEXT_LENGTH)