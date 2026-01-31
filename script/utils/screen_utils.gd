extends Node

class_name ScreenUtils

static func get_screen_rect(node : Node) -> Rect2:
	var viewport := node.get_viewport()
	var viewport_rect := viewport.get_visible_rect()
	var canvas_transform := viewport.get_canvas_transform()
	var inverse_transform := canvas_transform.affine_inverse()
	var result := Rect2(inverse_transform * viewport_rect.position, viewport_rect.size)
	return result
