extends StaticBody2D

class_name GreensweetBody

var shape_cast_result = preload("uid://x8i0lm5so3q1")

@export var path_to_shape_cast: NodePath = "/ShapeCast2D"

var velocity : Vector2
var shape_cast: ShapeCast2D

func _ready() -> void:
	shape_cast = get_node(path_to_shape_cast)
	if shape_cast == null:
		push_error("shape_cast is null!")

func move_and_slide():
	position += velocity
	var results = shape_cast_result.shape_query(self, shape_cast)
	
