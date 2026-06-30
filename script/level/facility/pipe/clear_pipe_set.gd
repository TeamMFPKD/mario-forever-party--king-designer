extends Node

class_name ClearPipeSet

enum Direction {
	LEFT,
	HORIZONTAL_MIDDLE,
	RIGHT,
	UP,
	VERTICAL_MIDDLE,
	DOWN,
	LEFT_UP,
	LEFT_DOWN,
	RIGHT_UP,
	RIGHT_DOWN,
}

@export var direction: Direction = Direction.LEFT