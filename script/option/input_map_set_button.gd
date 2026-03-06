extends Button

@export var input_map_name: String

var is_waiting_for_input: bool = false

const MAX_SLOTS = 3

func _ready() -> void:
    pressed.connect(_on_button_pressed)
    _update_button_text()

func _on_button_pressed() -> void:
    is_waiting_for_input = true
    text = tr("请按下一个键")

func _input(event: InputEvent) -> void:
    if not is_waiting_for_input:
        return
    if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
        return
    if not event.is_pressed():
        return

    # Escape 取消绑定
    if event is InputEventKey and event.keycode == KEY_ESCAPE:
        is_waiting_for_input = false
        _update_button_text()
        get_viewport().set_input_as_handled()
        return

    _append_or_overwrite(event)
    get_viewport().set_input_as_handled()

## 追加到空槽位；满了则淘汰最旧的（slot 0），其余前移，新键放末位
func _append_or_overwrite(event: InputEvent) -> void:
    var slots: Array = _load_slots()  # Array of InputEvent? (null = 空槽)

    # 找第一个空槽
    var target_slot := -1
    for i in range(MAX_SLOTS):
        if slots[i] == null:
            target_slot = i
            break

    if target_slot == -1:
        # 全满：前移淘汰最旧，新键放末位
        slots[0] = slots[1]
        slots[1] = slots[2]
        slots[2] = event
    else:
        slots[target_slot] = event

    _save_slots(slots)
    _apply_to_input_map(slots)
    is_waiting_for_input = false
    _update_button_text()

func _apply_to_input_map(slots: Array) -> void:
    InputMap.action_erase_events(input_map_name)
    for ev in slots:
        if ev != null:
            InputMap.action_add_event(input_map_name, ev)

func _save_slots(slots: Array) -> void:
    var config = GameConfig.config
    for i in range(MAX_SLOTS):
        var key := "%s:%d" % [input_map_name, i]
        if slots[i] != null:
            config.set_value("input_event", key, var_to_str(slots[i]))
        else:
            if config.has_section_key("input_event", key):
                config.erase_section_key("input_event", key)
    GameConfig.save()

func _load_slots() -> Array:
    var slots: Array = [null, null, null]
    var config = GameConfig.config
    for i in range(MAX_SLOTS):
        var key := "%s:%d" % [input_map_name, i]
        var saved_str: String = config.get_value("input_event", key, "")
        if saved_str != "":
            var ev = str_to_var(saved_str)
            if ev is InputEvent:
                slots[i] = ev
    return slots

func _update_button_text() -> void:
    var slots := _load_slots()
    var labels: Array = []

    for ev in slots:
        if ev != null:
            labels.append(_simplify_event_text(ev.as_text()))

    if labels.is_empty():
        # 配置里没有，从 InputMap 读默认值
        for ev in InputMap.action_get_events(input_map_name):
            labels.append(_simplify_event_text(ev.as_text()))

    if labels.is_empty():
        text = tr("未设置")
    else:
        text = "  /  ".join(labels)

func _simplify_event_text(raw: String) -> String:
    var simplified := raw.replace(" (Physical)", "").replace(" - Physical", "")
    
    # 手柄摇杆
    var axis_regex := RegEx.new()
    axis_regex.compile(r"Joypad Motion on Axis (\d+).*?Value ([-\d.]+)")
    var axis_match := axis_regex.search(simplified)
    if axis_match:
        var axis := axis_match.get_string(1).to_int()
        var value := axis_match.get_string(2).to_float()
        var axis_names := {
            0: ["L-Stick ←", "L-Stick →"],
            1: ["L-Stick ↑", "L-Stick ↓"],
            2: ["R-Stick ←", "R-Stick →"],
            3: ["R-Stick ↑", "R-Stick ↓"],
            4: ["L2", "L2"],
            5: ["R2", "R2"],
        }
        if axis in axis_names:
            return axis_names[axis][0 if value < 0 else 1]
        return "Axis%d %s" % [axis, "−" if value < 0 else "+"]
    
    # 手柄按钮
    var btn_regex := RegEx.new()
    btn_regex.compile(r"Joypad Button (\d+).*")
    var btn_match := btn_regex.search(simplified)
    if btn_match:
        var idx := btn_match.get_string(1).to_int()
        var btn_names := {
            0:  "A / ✕",
            1:  "B / ○",
            2:  "X / □",
            3:  "Y / ▲",
            4:  "L1",
            5:  "R1",
            6:  "L2",
            7:  "R2",
            8:  "Select",
            9:  "Start",
            10: "R1",
            11: "D-Up",
            12: "D-Down",
            13: "D-Left",
            14: "D-Right",
            15: "Home",
        }
        return btn_names.get(idx, "JBtn %d" % idx)
    
    return simplified  # 返回简化后的字符串