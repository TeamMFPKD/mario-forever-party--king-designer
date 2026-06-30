extends AudioStreamPlayer

class_name ContinuousAudioStream

var parent: Node
var viewport: Viewport
var playing_detect: bool

func _ready() -> void:
	parent = get_parent()
	viewport = parent.get_viewport()
	parent.connect("tree_exiting", _on_parent_exiting)

func _physics_process(_delta: float) -> void:
	if playing_detect and !playing:
		queue_free()

func _on_parent_exiting() -> void:
	if parent:
		parent.remove_child(self)
	var fn = func():
		if viewport:
			viewport.add_child(self)
		playing_detect = true
	fn.call_deferred()
	finished.connect(queue_free)
