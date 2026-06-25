class_name GreenSweet extends Node

# Wait and process used for await and temporary timer
class HelperTimer extends Timer:
	var fun: Callable


	func _physics_process(delta):
		fun.call(delta)


static func wait_and_process(node: Node, time: float, process: Callable):
	var timer = HelperTimer.new()
	timer.fun = process
	timer.wait_time = time
	timer.autostart = true
	node.add_child(timer, false, INTERNAL_MODE_FRONT)
	await timer.timeout
	timer.queue_free()
