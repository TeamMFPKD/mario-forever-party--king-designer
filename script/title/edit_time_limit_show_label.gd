extends Label

@export var bar : HScrollBar

func _process(_delta: float) -> void:
	text = str(int(bar.value)) + "s"
