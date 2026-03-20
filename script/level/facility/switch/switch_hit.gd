class_name SwitchHit
extends BlockHit

var switch_status: SwitchStatus

func _ready() -> void:
	super._ready()
	var fc = func():
		switch_status = get_tree().get_first_node_in_group("switch_status")
		if not switch_status:
			switch_status = SwitchStatus.new()
			switch_status.add_to_group("switch_status")
			parent.add_sibling(switch_status)
		_update_idle_animation()
	fc.call_deferred()

func on_bumped() -> void:
	super.on_bumped()
	switch_status.is_on = not switch_status.is_on
	# switched 信号自动触发 _update_idle_animation

func on_block_bump() -> void:
	super.on_block_bump()
	sprite.play("bumped_on" if switch_status.is_on else "bumped_off")

func _update_idle_animation() -> void:
	sprite.play("default_on" if switch_status.is_on else "default_off")
	switch_status.switched.connect(_update_idle_animation)