# 手柄适配方案

> 状态：**设计稿**。本文只描述方案与落地顺序，代码尚未实现。
> 目标：让 MFMP 在**纯手柄**环境下可用，同时不破坏现有的键鼠 / 触屏体验。

---

## 0. 现状

### 0.1 已有的输入动作

`project.godot` 的 `[input]` 段已定义 9 个动作，每个都同时绑了键盘和手柄：

| 动作 | 键盘 | 手柄按键 | 手柄摇杆 |
|---|---|---|---|
| `move_up` | ↑ / W | 11（十字上） | axis 1 = -1 |
| `move_down` | ↓ / S | 12（十字下） | axis 1 = +1 |
| `move_left` | ← / A | 13（十字左） | axis 0 = -1 |
| `move_right` | → / D | 14（十字右） | axis 0 = +1 |
| `move_jump` | Z / K | 0（A） | — |
| `move_fire` | X / J | 1（B） | — |
| `restart` | Q | 9（Start） | — |
| `photo` | C | 10 | — |
| `pause` | P | 6 | — |

`deadzone = 0.2`。

### 0.2 当前的焦点策略：一律禁止

`script/utils/button_focus_blocker.gd`（autoload 名 `NoButtonFocus`）做了三件事：

1. 节点进入场景树时，把 **所有** `BaseButton`（Button / TextureButton / CheckBox / CheckButton / OptionButton / MenuButton / LinkButton）的 `focus_mode` 强制设为 `FOCUS_NONE`；
2. 监听每个 `Viewport` 的 `gui_focus_changed`，一旦焦点落到 BaseButton 上就立即 `release_focus()`；
3. 对 autoload 之前已在树上的节点也做一次全树扫描。

**这是个全局强制策略，不区分平台、不区分设备。** 其结果就是：Tab / 方向键 / Enter / Space 在任何界面都无法选中或触发按钮，Godot 原生的焦点导航完全失效。

### 0.3 已试做的菜单光标

`script/ui/menu_cursor.gd` + `ui/menu_cursor.tscn` 已在 `room/history.tscn` 接了一个四角光标，走**完全自研**的选中逻辑（不碰 `focus_mode`）。这份代码可以保留，但它绕过了引擎焦点系统，和本文后续方案不是同一路线——见 §6。

---

## 1. 总体设计：三层

```
┌─────────────────────────────────────────────┐
│ 设备层  InputDeviceMonitor                   │  「现在有什么设备可用」
│         ├ 手柄插拔监听                       │
│         ├ 键鼠最后活动时间                    │
│         └ 当前主导设备（keyboard/mouse/pad）  │
├─────────────────────────────────────────────┤
│ 策略层  UiFocusPolicy                        │  「这个节点该不该可聚焦」
│         ├ 平台判定（移动端 / PC / 主机）      │
│         ├ 设备判定（手柄在场 / 不在场）       │
│         └ 节点判定（有无 metadata 标记）      │
├─────────────────────────────────────────────┤
│ 表现层  原生焦点 + MenuCursor                │  实际怎么画、怎么响应
└─────────────────────────────────────────────┘
```

**核心思路：不再"一律禁止焦点"，而是"按设备决定要不要放开"，并且只放开被显式标记过的节点。**

---

## 2. 元数据标记机制

### 2.1 标记名

```gdscript
const META_GAMEPAD_FOCUS: StringName = &"gamepad_focus"
```

挂在需要参与手柄导航的控件上，值可以是 `true` 或一个字典（用于扩展）：

```gdscript
# 最简单：这个按钮参与手柄导航
button.set_meta(&"gamepad_focus", true)

# 进阶：指定导航分组 / 初始焦点
button.set_meta(&"gamepad_focus", {
    "group": "main_menu",
    "initial": true,
})
```

### 2.2 `NoButtonFocus` 的改造

现在的逻辑是"见到 BaseButton 就禁"。改成：

```gdscript
func _block(button: BaseButton) -> void:
    # 标记过的节点：记下原本的 focus_mode，交给策略层决定
    if button.has_meta(META_GAMEPAD_FOCUS):
        if not button.has_meta(META_ORIGINAL_FOCUS_MODE):
            button.set_meta(META_ORIGINAL_FOCUS_MODE, button.focus_mode)
        button.set_meta(META_FOCUS_MANAGED, true)
        UiFocusPolicy.apply_to(button)
        return
    # 没标记的：照旧禁用
    button.focus_mode = Control.FOCUS_NONE
    button.set_meta(META_FOCUS_MANAGED, true)
```

### 2.3 复原

```gdscript
func restore(button: BaseButton) -> void:
    if not button.has_meta(META_ORIGINAL_FOCUS_MODE):
        return
    button.focus_mode = button.get_meta(META_ORIGINAL_FOCUS_MODE)
```

**关键点：要记原值。** 不是统一复原成 `FOCUS_ALL`——原场景里可能有节点本来就设的是 `FOCUS_CLICK` 或别的。

### 2.4 为什么用 metadata 而不是分组

- `metadata` 存在节点上，**场景文件里就能写**，不需要运行时注册；
- 分组（`add_to_group`）必须在代码里调用，场景实例化后才有，编辑器里看不出来；
- metadata 可以在编辑器检查器里直接加，策划/美术改场景时不会漏。

---

## 3. 设备检测

### 3.1 手柄在场判定

```gdscript
func _has_gamepad() -> bool:
    return not Input.get_connected_joypads().is_empty()
```

监听插拔：

```gdscript
func _ready() -> void:
    Input.joy_connection_changed.connect(_on_joy_changed)

func _on_joy_changed(device: int, connected: bool) -> void:
    _refresh()
```

### 3.2 主导设备（用于键鼠/手柄自动切换）

只靠"有没有插手柄"不够——**插着手柄也可能在用鼠标**。所以需要记录最后一次输入来自哪类设备：

```gdscript
var _last_device: StringName = &"keyboard"

func _input(event: InputEvent) -> void:
    if event is InputEventJoypadButton or event is InputEventJoypadMotion:
        _last_device = &"gamepad"
        _refresh()
    elif event is InputEventKey or event is InputEventMouseButton \
        or event is InputEventMouseMotion:
        # 摇杆漂移会持续产生 motion 事件，键盘/鼠标事件才切回
        if event is InputEventMouseMotion and event.relative.length() < 2.0:
            return
        _last_device = &"keyboard"
        _refresh()
```

> **注意**：很多手柄有摇杆漂移，会持续输出 `InputEventJoypadMotion`。判定"手柄活动"时要加**幅度阈值**（比如 `abs(axis_value) > 0.3`），否则键鼠会被反复抢回去。

### 3.3 平台判定

沿用现有的 `PlatformUtils`：

```gdscript
static func is_mobile() -> bool:
    var name: String = PlatformUtils.get_platform()   # 已处理 debug 伪装
    return name == "Android" or name == "iOS"
```

---

## 4. 焦点策略

### 4.1 决策表

| 平台 | 手柄 | 被标记节点 | 未标记节点 |
|---|---|---|---|
| **移动端** | — | `FOCUS_NONE` | `FOCUS_NONE` |
| **PC / 主机** | 无 | `FOCUS_NONE` | `FOCUS_NONE` |
| **PC / 主机** | **有** | **复原原值** | `FOCUS_NONE` |

对应需求：

> 2 仅移动端默认这些 none 的 focus 设置
> 3 如果检测到手柄，那么把设置为 none 且有 metadata 标记的节点复原为手柄可以操控

### 4.2 为什么移动端即使插着手柄也不放开

移动端 UI 是触屏尺寸布局，按钮间距、点击热区都按手指设计。手柄光标在触屏布局上"跳来跳去"体验很差，且移动端外接手柄是极少数场景。

如果要支持，把 §4.1 的表改成"移动端 + 手柄 → 放开"即可，是策略层一行判断的事。

### 4.3 焦点恢复时的连锁问题

放开 `focus_mode` 后，Godot 的默认行为是：

- 按方向键时，引擎按**几何邻近**自动找下一个可聚焦控件；
- 这个"自动邻居查找"**不区分视觉效果**，经常跳到视觉上不相邻的地方。

两个应对：

1. **显式指定邻居**——在场景里给关键按钮设 `focus_neighbor_left/right/top/bottom` 和 `focus_next` / `focus_previous`；
2. **接管导航**——保留 `MenuCursor` 的自研导航（见 §6），只用原生焦点做"当前是谁"的状态存储，方向键自己处理。

**推荐 2。** 原因：原生导航的"相邻"是像素几何，遇到布局复杂（嵌套容器、滚动区域）时很容易乱跳；自研导航可以按业务语义排序。

---

## 5. 键位映射

### 5.1 需求原文

> 4 PC 端应该支持↑↓←→，并且确认、取消逻辑如下：Enter / move_jump 确认、Esc / move_fire 取消

### 5.2 落地方式

新增两个**逻辑动作**（不是物理按键），由脚本把它们和物理输入解耦：

```ini
# project.godot [input]
ui_menu_accept={
"deadzone": 0.2,
"events": [
  InputEventKey(physical_keycode=KEY_ENTER),
  InputEventKey(physical_keycode=KEY_KP_ENTER),
  InputEventJoypadButton(button_index=0),   # A
  InputEventJoypadButton(button_index=1),   # B
]}
ui_menu_cancel={
"deadzone": 0.2,
"events": [
  InputEventKey(physical_keycode=KEY_ESCAPE),
  InputEventJoypadButton(button_index=1),   # B
]}
```

**但这里有个冲突**：需求说"Enter / **move_jump** 确认"，而 `move_jump` 是游戏内跳跃键（Z / K / 手柄 A）。如果直接把 `move_jump` 绑到 `ui_menu_accept`，那么：

- 在菜单里按 Z/K 也会确认 —— 符合需求；
- 但游戏内按 Z 会同时触发"跳跃"和"菜单确认" —— **需要在游戏内屏蔽 ui_menu_accept**。

处理方式：**不要直接复用 `move_jump`**，而是新增 `ui_menu_accept` 并把同样的物理键绑上去，然后在游戏内主动 `set_process_unhandled_input(false)` 或用一个门控变量屏蔽。这样菜单和游戏互不干扰。

> 同理，"取消 = Esc / move_fire"也照此处理。**注意 `move_fire` 是 X/J/B，与 `move_jump` 分开绑是必要的。**

### 5.3 与 `ui_left/right/up/down` 的关系

Godot 内置的 `ui_left` 等默认绑的是**方向键 + D-pad**，和项目里的 `move_left` 等**重复**（都绑了方向键和 D-pad）。

现在的做法：`MenuCursor` 用 `ui_*`，游戏用 `move_*`。两套并存，靠"当前在菜单还是游戏内"区分。**这点要保持**，不要合并。

---

## 6. edit.tscn 的特殊处理

### 6.1 需求原文

> 5 edit.tscn 比较特殊，WSAD 和上下左右都可以移动镜头，如果是键鼠操作，那么键盘不允许 focus 到任何 UI；如果检测到手柄，那么十字键操控 UI，摇杆控制光标用于编辑

### 6.2 现状

`script/level_camera.gd` 的镜头移动直接读 `move_up/down/left/right`：

```gdscript
if Input.is_action_pressed("move_up"):
    direction += Vector2.UP
    speed = max_speed
if Input.is_action_pressed("move_down"):
    direction += Vector2.DOWN
    ...
```

而 `move_up` 同时绑了 ↑/W **和** D-pad 上和 axis 1 = -1。所以在 edit 里，**方向键、WASD、D-pad、左摇杆全都在移动镜头**，没有区分。

### 6.3 目标状态

| 设备 | 方向键 / 十字键 | 左摇杆 | 鼠标 |
|---|---|---|---|
| **键鼠** | 移动镜头 | —（无） | 编辑光标 |
| **手柄** | **操控 UI**（切换焦点） | **移动编辑光标** | — |

### 6.4 落地方式

**第一步：拆分动作**

把 `move_*` 拆成两组语义：

```
move_up/down/left/right   ← 只保留 WASD（和 shift 等），改绑为"镜头移动"
pad_up/down/left/right    ← D-pad 和左摇杆，用于 UI 导航与编辑光标
```

**第二步：`LevelCamera` 按设备读不同动作**

```gdscript
func _physics_process(delta: float) -> void:
    var direction: Vector2 = Vector2.ZERO
    if InputDeviceMonitor.last_device == &"keyboard":
        # 键鼠：WASD / 方向键 移动镜头
        direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    else:
        # 手柄：不移动镜头（镜头跟随编辑器光标，由别处驱动）
        pass
    ...
```

**第三步：编辑光标**

编辑光标现在由鼠标驱动。手柄模式要改成摇杆驱动的虚拟光标：

```gdscript
# 手柄模式下，每帧把摇杆位移累加到虚拟光标位置
if InputDeviceMonitor.is_gamepad():
    var axis: Vector2 = Input.get_vector("pad_left", "pad_right", "pad_up", "pad_down")
    if axis.length() > 0.2:
        _virtual_cursor += axis * CURSOR_SPEED * delta
    _world_cursor = _virtual_cursor   # 供点击判定使用
```

**第四步：UI 焦点**

手柄模式下，D-pad 用于切换 UI 焦点，此时要**暂时禁用摇杆→编辑光标**，否则 D-pad 和摇杆同时操作会互相打架。做法：用一个模式开关（`edit_mode: UIFocus / EditCursor`），由某个按键（比如 Start）切换。

---

## 7. 实施顺序

按依赖关系排，每步都可独立验证：

| 阶段 | 内容 | 依赖 | 可验证 |
|---|---|---|---|
| **P1** | `InputDeviceMonitor`：手柄插拔 + 主导设备判定 | 无 | 打印日志，插拔手柄看输出 |
| **P2** | `NoButtonFocus` 改造：metadata 标记 + 记原值 | P1 | 给一个按钮打标记，看 focus_mode 是否复原 |
| **P3** | `UiFocusPolicy`：决策表落地 | P1, P2 | 三种状态（移动端/PC无手柄/PC有手柄）分别验证 |
| **P4** | 新增 `ui_menu_accept` / `ui_menu_cancel` | 无 | 菜单里按 Enter/Esc 有响应 |
| **P5** | 游戏内屏蔽菜单动作 | P4 | 游戏内按 Z/X 不触发菜单 |
| **P6** | 给主要菜单场景打 metadata 标记 | P3 | 逐个场景验证手柄可达 |
| **P7** | `MenuCursor` 接管导航（替换 P6 的原生导航） | P3, P6 | 方向键切换，视觉正确 |
| **P8** | edit.tscn 特殊处理（§6） | P7 | 键鼠/手柄两种模式分别验证 |

**P1～P3 是基础设施，P4～P5 是键位，P6～P8 是逐界面上线。**

---

## 8. 风险与注意事项

### 8.1 摇杆漂移导致设备判定抖动

已在 §3.2 提到。除了幅度阈值，还可以加**迟滞**：手柄需要持续活动 200ms 才切换过去，键鼠事件一次就切回。

### 8.2 `focus_mode` 复原的时机

如果在 `_ready` 里复原，但此时手柄还没插上（USB 枚举需要几十毫秒），会复原失败。所以：

- 复原动作要**幂等**，可以重复调用；
- `Input.joy_connection_changed` 触发后重新扫一遍当前场景的可标记节点。

### 8.3 场景切换后标记丢失

`NoButtonFocus` 是靠 `get_tree().node_added` 挂钩子的，场景切换后新节点会经过它，没问题。但如果某个场景是 `@tool` 脚本在编辑器里造的节点，运行时可能不带 metadata——**需要在场景文件里写，不要在代码里动态加**。

### 8.4 移动端的触摸与焦点

移动端放开焦点后，触摸事件仍然正常（触摸不走焦点系统）。但要小心：某些控件在获得焦点后会有视觉反馈（描边），触摸时出现这个反馈很奇怪。用 `focus_mode = FOCUS_ALL` 且不让触摸路径触发 `grab_focus` 即可。

### 8.5 `MenuCursor` 与原生焦点的取舍

两条路线：

| | 原生焦点 | 自研 MenuCursor |
|---|---|---|
| 实现量 | 小（引擎自带） | 大（自己写导航） |
| 邻居控制 | 需手工设 `focus_neighbor_*` | 完全自由 |
| 视觉 | 无（要自己画高亮） | 已有（四角光标） |
| 复杂布局 | 容易乱跳 | 可按语义排序 |

**结论：视觉上必须自己画（项目没有原生焦点描边），所以原生焦点只能当"状态存储"，实际导航仍由 MenuCursor 做。** 这决定了 P7 是必须的，不能只做 P6。

---

## 9. 对照需求的完成度

| 需求 | 对应章节 | 状态 |
|---|---|---|
| 1 新开 metadata 记录被取消聚焦的节点 | §2 | ⬜ 待实现 |
| 2 仅移动端默认 none | §4.1 | ⬜ 待实现 |
| 3 检测到手柄时复原有标记的节点 | §4.1 / §2.3 | ⬜ 待实现 |
| 4 PC 端 ↑↓←→ + Enter/move_jump 确认、Esc/move_fire 取消 | §5 | ⬜ 待实现 |
| 5 edit.tscn 特殊处理 | §6 | ⬜ 待实现 |

---

## 10. 附：为什么不用 Godot 内置的 `Input.get_connected_joypads()` 单独判断

它只回答"插了几个手柄"，回答不了"用户现在在用哪个"。而 UI 要不要放开焦点，取决于**用户是否正在用手柄**，不是"手柄在不在"。

这两者差别很大：PC 玩家插着手柄但一直用鼠标点菜单，如果因为"有手柄"就放开焦点，方向键就会在菜单里乱跳，反而更糟。

所以必须有 §3.2 的"主导设备"判定。
