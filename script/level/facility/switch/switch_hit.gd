class_name SwitchHit
extends BlockHit

var switch_status: SwitchStatus

func _ready() -> void:
	add_to_group("switch_hit")
	super._ready()
	var fc = func():
		switch_status = get_tree().get_first_node_in_group("switch_status")
		if not switch_status:
			switch_status = SwitchStatus.new()
			switch_status.add_to_group("switch_status")
			parent.add_sibling(switch_status)
		switch_status.switched.connect(_on_switched)
		_update_idle_animation()
	fc.call_deferred()

func on_block_bump() -> void:
	if _bump_state != BumpState.IDLE:
		return
	_bump_state = BumpState.BUMPING
	_bump_state_timer = 0
	emit_signal("block_bump")

	if hidden:
		set_visible()

	switch_status.is_on = not switch_status.is_on
	sprite.play("bumped_on" if switch_status.is_on else "bumped_off")
	Callable(_create_bump_area).call_deferred()

func on_bumped() -> void:
	_bump_state = BumpState.IDLE
	bumping = false
	if bumpable_one_shot:
		bumpable = false
	_update_idle_animation()

func _on_switched() -> void:
	# bumping 期间不响应其他 switch 广播的信号
	if bumping:
		return
	_update_idle_animation()

func _update_idle_animation() -> void:
	var anim = "default_on" if switch_status.is_on else "default_off"
	sprite.play(anim)
	# 同步到场景里其他 switch 的当前帧
	var others = get_tree().get_nodes_in_group("switch_hit")
	for other in others:
		if other == self:
			continue
		if other.sprite.animation == anim and not other.bumping:
			sprite.frame = other.sprite.frame
			sprite.frame_progress = other.sprite.frame_progress
			break
