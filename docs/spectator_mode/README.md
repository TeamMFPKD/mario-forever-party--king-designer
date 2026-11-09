# 观战模式（Spectator Mode）需求与设计

> 注意：本文档写于 2026-11 联机重构之前。重构后 RPC 已迁移到 `MPManager` 的
> `net / lobby / levels / flow / chat` 服务，文中提到的 `register_player_on_host`、
> `store_level_results`、`back_to_title_process`、`player.is_spectator` 等接口
> 需要按 `docs/multiplayer_refactor_plan.md` 的新结构重新设计。

> 状态：已评审（关键决策已确认，待实施）
> 适用范围：`MF: MP`（Godot 4.7.2 / GDScript / ENet）
> 相关文档：[快捷消息系统](../message_system/README.md)

## 目录

1. [目标](#1-目标)
2. [术语与角色](#2-术语与角色)
3. [本期关键决策](#3-本期关键决策)
4. [阶段模型](#4-阶段模型)
5. [角色与数据模型](#5-角色与数据模型)
6. [加入与角色](#6-加入与角色)
7. [各阶段观战行为矩阵](#7-各阶段观战行为矩阵)
8. [游玩观战（方案 A）](#8-游玩观战方案-a)
9. [编辑观战（方案 C：截图流）](#9-编辑观战方案-c截图流)
10. [早完赛自动观战](#10-早完赛自动观战)
11. [观战 HUD 与交互](#11-观战-hud-与交互)
12. [网络协议清单](#12-网络协议清单)
13. [代码改造清单](#13-代码改造清单)
14. [边界与异常](#14-边界与异常)
15. [测试计划](#15-测试计划)
16. [分阶段实施](#16-分阶段实施)
17. [现状核对（其他 AI 已改，需兼容）](#17-现状核对其他-ai-已改需兼容)
18. [待确认问题（剩余）](#18-待确认问题剩余)

## 1. 目标

1. 玩家进入房间时可选择「游玩」或「观战」。
2. 已打完本局全部关卡的玩家（`reach_end`）在等待结果期间自动进入观战。
3. 支持游戏中途加入的观战者；中途加入只能是观战角色。
4. 观战两种画面：
   - **游玩阶段**：跟随被观战玩家的位置与其当前关卡。关卡在观战端本地重演，只同步玩家位置/动画（方案 A）。
   - **编辑阶段**：被观战编辑器推送截图流（方案 C）。
5. 观战者按左/右切换被观战玩家；切换后相机与关卡随之切换。
6. 观战者允许发言（沿用快捷消息系统）。
7. 房主即使是观战者，也可以开始游戏、推进阶段。
8. 游玩人数为 0 时，房主不能开始游戏（按钮禁用）。

### 非目标（本期不做）

- 观战端与玩家端的敌人、机关、砖块、岩浆、自动卷轴等运行时状态同步（方案 B）。
- 观战端自由视角、多画面同屏、画中画。
- 观战者中途转为玩家，或玩家中途转为观战者。
- 录像 / 回放。
- 专用观战服务器（仍由房主主机转发）。

---

## 2. 术语与角色

| 术语 | 定义 |
| --- | --- |
| 玩家（PLAYER） | `is_spectator = false`，参与编辑、收集关卡、游玩、结算 |
| 观战者（SPECTATOR） | `is_spectator = true`，不编辑、不提供关卡、不参与结算、可发言 |
| 房主（HOST） | `multiplayer.is_server()` 的对等体，负责阶段推进与权威数据 |
| 被观战者（TARGET） | 观战者当前跟随的玩家，同一时间只有一个 |
| 阶段（PHASE） | `LOBBY / READY / EDIT / TRANSFER / PLAY / RESULT / TITLE` |
| `reach_end` | 本局把 `random_levels` 全部走完（无论过关还是死亡换关），进入结果房间 |

房主与角色是正交的：房主可以是玩家，也可以是观战者。

---

## 3. 本期关键决策

| 决策 | 结论 |
| --- | --- |
| 游玩观战保真度 | **A**：观战端加载同一关卡 JSON，只同步玩家位置/动画；接受动态物件不同步（已确认） |
| 编辑观战保真度 | **C**：被观战编辑器推送截图流，观战端只读（已确认） |
| 编辑观战抓屏范围 | **只抓关卡画布**（`SubViewport`），不含编辑器工具栏/按钮；画布内的光标、选中框会保留（已确认） |
| 早完赛观战入口 | **结果房间内嵌观战层**，不切走结果房间；结果就绪后自动收起（已确认） |
| 角色确定时机 | 加入时确定；本局内不可更改（v1） |
| 房主观战权限 | 保留房主全部权限：开始游戏、推进阶段、强制继续 |
| 房主侧流程 | **抽取到 `MPManager` / `GameFlow` 持久节点**，房主观战也能驱动准备/编辑/收集/结算（已确认） |
| 观战者发言 | 允许，复用 `MessageOverlay` + 快捷用语 |
| 观战者结算 | 不计入关卡收集、准备人数、结果列表、通过率分母 |
| 观战者连接名额 | 占用 ENet 连接（当前上限 20），v1 不单独预留 |

---

## 4. 阶段模型

### 4.1 枚举

```gdscript
enum GamePhase {
    LOBBY,      # 标题 / 等待房间
    READY,      # 准备倒计时（ready_room）
    EDIT,       # 编辑阶段（edit）
    TRANSFER,   # 关卡收集与传输（level_transfer_room）
    PLAY,       # 游玩阶段（直到所有玩家 reach_end）
    RESULT,     # 结果展示
    TITLE,      # 已回到标题
}
```

### 4.2 权威与广播

- `game_phase` 由房主持有并广播；客户端只读。
- 阶段切换统一走 `phase_changed(phase, payload)`（`authority`、`call_local`、`reliable`）。
- `payload` 建议字段：
  - `deadline_msec`：本阶段剩余时间（`READY` / `EDIT` 使用，0 表示无倒计时）
  - `edit_seconds`：本局编辑时长
  - `random_levels`：`PLAY` 开始时下发
  - `total_levels`
  - `result_ready`：`RESULT` 使用

### 4.3 阶段流转

| 从 | 事件 | 到 | 房主侧动作 |
| --- | --- | --- | --- |
| LOBBY | 房主点「开始」且游玩人数 ≥ 1 | READY | `game_start.rpc`；记录编辑时长；启动准备倒计时 |
| READY | 倒计时结束（约 5.5s，取 `ready_room` 动画长度） | EDIT | 广播 `EDIT` + `deadline_msec`；启动编辑计时 |
| EDIT | 倒计时结束 或 所有玩家「准备完毕」 | TRANSFER | `edit_time_out.rpc`；广播 `TRANSFER` |
| TRANSFER | 所有非观战玩家的关卡数据到齐 | PLAY | 生成 `random_levels` 并 `lets_play_together.rpc`；广播 `PLAY` |
| PLAY | 所有非观战玩家 `reach_end == true` | RESULT | 计算 `clear_rate/score`；`store_level_results.rpc`；广播 `RESULT` |
| RESULT | 房主点「一起回标题」 | TITLE → LOBBY | `back_to_title_process`；广播 `LOBBY` |

> 现有玩家场景仍按自己的本地计时器推进；阶段事件是**观战端的唯一时钟**，也是房主观战时的流程驱动器。

---

## 5. 角色与数据模型

### 5.1 `player` / `players` 字典新增字段

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `is_spectator` | bool | false | 权威值由房主写入；客户端加入时声明，之后不可改 |
| `spectate_target_id` | int | 0 | 仅本地观战者使用，不参与同步 |
| `current_level` | int | 0 | 玩家当前关卡序号（状态表用，低频可靠） |
| `is_in_result` | bool | false | 玩家是否已进入结果房间（用于观战目标过滤） |

`reach_end`、`level_file_name`、`level_data` 等沿用现有字段。

### 5.2 `MultiplayerManager` 新增

| 成员 | 说明 |
| --- | --- |
| `game_phase: GamePhase` | 当前阶段 |
| `phase_deadline_msec: int` | 当前阶段截止时间（`Time.get_ticks_msec()`） |
| `random_levels: Array` | 本局关卡文件名顺序（进入 `PLAY` 前对观战者也要可用） |
| `spectator_status: Dictionary` | `player_id -> {current_level, reach_end, is_in_result, is_dead, lives}` |
| `level_data_cache: Dictionary` | 房主侧：`level_file_name -> level_json`，防止作者掉线后丢失 |
| `spectator_target_id: int` | 本地观战者当前目标 |

### 5.3 唯一过滤入口

新增三个方法，**所有遍历 `players` 的既有逻辑必须改走它们**：

```gdscript
func get_playing_players() -> Array
func get_spectators() -> Array
func get_watchable_players() -> Array   # 非观战、is_in_game、未 reach_end、未进结果房间
```

这是本需求最容易出连锁 bug 的地方，见第 13 节清单。

---

## 6. 加入与角色

### 6.1 大厅 UI

- `HostPage`：新增「以观战身份创建房间」勾选（或二选一按钮组）。
- `JoinPage`：新增「以观战身份加入」勾选。
- 默认值：游玩。
- 角色在 `player.is_spectator` 中随 `register_player_on_host` 一起发送。

### 6.2 服务端校验

`register_player_on_host(player_info)`（`multiplayer_manager.gd:319`）改为：

| 情况 | 处理 |
| --- | --- |
| `is_in_game == false` | 接受；`is_spectator` 按请求写入房主权威列表 |
| `is_in_game == true` 且 `is_spectator == false` | 拒绝；`Notice.show_notice("游戏已开始，只能以观战身份加入。")`，随后断开 |
| `is_in_game == true` 且 `is_spectator == true` | 接受；追加到 `players`；回发 `spectator_snapshot`；同步聊天记录 |

要点：

- 客户端中途不能改 `is_spectator`；房主以加入请求中的值为准并写死。
- 旧 `inform_late_player`（`multiplayer_manager.gd:345`）只对「游玩」角色使用。旧的 `GameInProgressHint` 已被其他 AI 删除，统一改用 `Notice`。
- 观战者加入也要触发 `players_updated`，让玩家列表显示「观战」标签。

### 6.3 加入快照

`spectator_snapshot(snapshot)`（`authority` → 新观战者）：

```gdscript
{
    "phase": int,
    "deadline_msec": int,
    "players_public": Array,      # 不含 level_data，可含结算后的 clear_rate/score
    "status": Dictionary,         # 5.2 的 spectator_status
    "random_levels": Array,
    "total_levels": int,
    "result_ready": bool,
    "results": Array,             # result_ready 时的结算列表；否则空数组
}
```

客户端收到后：

- 设置 `MPManager.game_phase`、`random_levels`、`total_levels`、`spectator_status`、`players`。
- 根据阶段切到观战场景（见第 7 节）；已在观战场景则只刷新内容。
- 观战者不进入 `ready_room / edit / level_transfer_room / play / result_room` 的玩家流程。

### 6.4 开始按钮

- `StartButton`（`room/title.tscn`）新增控制器：当 `get_playing_players().size() == 0` 时 `disabled = true`。
- 房主本身是观战者时，只要还有 ≥1 名玩家，按钮仍可点。
- 非房主隐藏 `StartButton`（当前 UI 对所有玩家显示；点击本来就会被 `is_server` 挡住，但观战者不该看到可点按钮）。
- 本需求只加「0 玩家禁用」；不改变现有「不强制全员准备」的行为。
- `players_updated` 时刷新按钮状态（有人加入/离开/切换角色都要重算）。
- `MpTestBoot._auto_start()`（`script/debug/mp_test_boot.gd:342`）目前用 `players.size() >= expect` 判断，观战者会算进人数；测试脚本要改为只数非观战玩家。

### 6.5 发言

- 观战者在 `players` 列表内，`send_quick_message` 无需改动即可发言。
- 观战者不需要「准备」；`ready_button` 对观战者隐藏或禁用。
- `MessageOverlay` 打开时会屏蔽 `move_left/right`（`player_input_blocker.gd`），观战者的左右切换在面板打开期间被屏蔽——这是期望行为。

---

## 7. 各阶段观战行为矩阵

| 阶段 | 玩家 | 观战者 | 房主（观战者） |
| --- | --- | --- | --- |
| LOBBY | 准备/开始 | 玩家列表、观战标签、聊天 | 可开始、可退出房间 |
| READY | 准备房间倒计时 | 「准备中」等待面板 + 目标列表 | 驱动倒计时，界面同观战者 |
| EDIT | 编辑自己的关卡 | 目标编辑器的截图流（C） | 可提前结束编辑（倒计时/全员完成） |
| TRANSFER | 发送/接收关卡数据 | 「关卡传输中 x/y」等待面板 | 收集关卡数据、生成 `random_levels`、开玩 |
| PLAY | 游玩、推进关卡 | 目标位置 + 目标当前关卡 | 观战；可强制继续/推进阶段 |
| RESULT | 结果列表 | 结果快照 | 计算结果、回标题 |

### 7.1 观战场景的两种承载方式

| 场景 | 用途 | 说明 |
| --- | --- | --- |
| `spectate_room.tscn`（新增） | 中途加入、房主观战 | 独立场景，按 `game_phase` 切换内容；不加载玩家 UI |
| 结果房间内嵌观战层 | 早完赛玩家 | `result_room.tscn` 内实例化同一个 `spectate_view.tscn`，结果就绪后隐藏 |

两者共用 `spectate_view.tscn`（关卡视图 + 相机 + 幽灵 + 截图层 + HUD）。

布局约定：`spectate_view.tscn` 做成**铺满父容器的 `Control`**（内部 `SubViewportContainer` 锚点全开），不自己带 `GameRoomSize`；独立 `spectate_room.tscn` 用 `GameRoomSize + spectate_view`，结果房间则把 `spectate_view` 直接挂在自身 `GameRoomSize` 下。这样两处都不需要复制视口缩放逻辑。

---

## 8. 游玩观战（方案 A）

### 8.1 数据流

```text
玩家客户端                       房主                        观战者
   |  每帧 send_ani_sprite_data   |                              |
   |----------------------------->|（广播/转发）----------------->|
   |  report_player_status(换关)  |                              |
   |----------------------------->|  sync_spectator_status       |
   |                              |----------------------------->|
   |                              |  spectator_level_data        |
   |                              |<---- request_spectator_level |
   |                              |----------------------------->|
   观战者：加载关卡 JSON -> 跳过 player 生成 -> 相机跟随幽灵
```

### 8.2 关卡解析（关键易错点）

目标玩家当前在第 `k` 关，对应关卡文件名是 `random_levels[k]`。这个文件属于**作者**，不是目标玩家本人。房主必须：

1. 用 `random_levels[k]` 找到 `players` 中 `level_file_name == random_levels[k]` 的作者。
2. 取该作者的 `level_data`（JSON）。
3. 压缩后定向发给观战者。

因此：

- 房主在收到 `transfer_level_data` 时（无论在哪个场景）就把每个作者的 `level_data` 缓存进 `level_data_cache[level_file_name]`，否则作者掉线后 `players` 被移除，关卡数据就丢了。
- 关卡来源分两种：
  - **早完赛玩家**：本局已经走过 `TRANSFER`，本地 `user://mfmp_*.lvl` 已有全部关卡文件，可直接按文件名读取。
  - **中途加入的观战者**：没有本地文件，必须向房主请求 `spectator_level_data`。
- 观战者按文件名缓存已加载过的关卡 JSON；切换目标时同一关不重复请求/解析。
- 关卡数据只放内存，**不要写入 `user://mfmp_*.lvl`**，避免污染历史记录、点赞课程、结果统计。直接调用 `LevelManager.load_level_data_from_json()`。
- `level_file_name` 来自 RPC，必须做文件名白名单/`validate_filename()` 校验，拒绝 `..`、绝对路径与超大 payload。

### 8.3 位置与动画

- 沿用 `send_ani_sprite_data`（`multiplayer_manager.gd:599`），字段已包含：`player_id / current_level / ani_pos / suit / power / animation / frame / flip_h / is_dead / scale / rotation`。
- 观战者把本地 `MPManager.current_level_count` 设为目标的 `current_level`，现有过滤条件 `current_level_count != current_level` 即可放行目标关卡的位置包。
- 观战者不要发送该 RPC（没有本地玩家）。
- 现有「第一个没有 meta 的槽位就绑定 player_id」的分配方式会串人（`multiplayer_manager.gd:660`）。改为：
  - 幽灵管理器暴露 `apply_remote_state(player_id, ...)`；
  - 槽位用 `Dictionary[player_id] -> AnimatedSprite2D`；
  - `players_updated` 时增删槽位，目标离开/通关时回收。
- 切换目标或换关时调用 `reset_physics_interpolation()`，避免幽灵从上一关坐标拖一条线过来。

### 8.4 目标列表与切换

- 左/右切换。建议新增输入动作 `spectate_prev / spectate_next`（默认 A/D 或 ←/→），不要复用 `move_left/right` 的游戏语义，避免与玩家/编辑器冲突。
- 列表来源：`get_watchable_players()`，按 `players` 数组顺序（即加入顺序）稳定排序。
- 过滤：自己、其他观战者、`reach_end == true`、`is_in_result == true`。
- 注意：非房主客户端的 `players` 不会自动收到别人的 `reach_end` 更新，所以 `get_watchable_players()` 必须结合 `spectator_status`（房主低频广播）来过滤；这是早完赛玩家在结果房间里也能正确列出剩余玩家的前提。
- 行为：
  - 只有 1 个目标：左右键无效果，HUD 显示 `1/1`。
  - 0 个目标：显示空状态（「其他玩家都已通关，等待结果…」或「暂时没有可观看的玩家」）。
  - 目标掉线 / 进结果房间：自动切到列表中的下一个；没有则空状态。
  - 目标换关：观战端自动加载新关卡并跟随；加载期间显示淡出/「加载中」。
  - 目标死亡重生：位置会瞬移，相机按 `TELEPORT_THRESHOLD`（`script/level_camera.gd:15`）直接吸附，不要平滑拉一条长线。
- 切换只在本地处理，向房主发 `request_watch(target_id)` 仅用于编辑截图流的订阅；游玩阶段可只依赖广播的位置包。

### 8.5 相机

- 新增 `SpectateCamera`（不要直接改 `LevelCamera` 的玩家跟随逻辑，避免影响编辑器/回放）：
  - 跟随目标幽灵的 global_position；
  - 从 `LevelManager` 读取 `level_size` 设置 limit；
  - 目标切换时 `reset_physics_interpolation()`；
  - 不做输入移动。
- 不要依赖 `get_first_node_in_group("player")`；观战场景不会生成本地玩家。

### 8.6 关卡视图

- 新增 `spectate_view.tscn`，按 `play_room_base.tscn` 的 Level 子树裁剪：
  - 保留：`SubViewportContainer + SubViewport + Level`、`DatabaseHolder`（复用 `database/*.tres`）、`LevelManager`、`TileMapLayer + TileSetManager + TileMapLayerSemiSolidCreator`、`SealerCreator`、`ObjectMapLayer`、`BgpManager`、`PipeBuilder`、`PinkCoinCanvasLayer`（如粉币 HUD 会报错则去掉）、`SpectateCamera`、`GhostManager`
  - 去掉：`TileMapDraw`、`ObjectMapDraw`、`InputHandler`、`TestNode`、编辑器 UI、`GameTimeHUD`、`MarginContainer`（编辑按钮）、`GameModeDetect`、`MobileControlManager`
  - `LevelManager` 的 `clear_pipe_draw` 可留空，`pipe_builder` 指向 `PipeBuilder`；加载 JSON 时管道会通过 `build_pipes_from_lines` 重建
- `ObjectMapLayer` 新增 `@export var spawn_player: bool = true`，观战视图里设为 `false`；或在 `load_object_data` 中对 `object_name == "player"` 且 `GameMode.SPECTATE` 时跳过。否则观战端会生成一个可被本地键盘控制的玩家，并被相机跟随。
- `ObjectMapLayer._ready()` 会调用 `setup_input_handler()`，在没有 `InputHandler` 时**自动创建一个**并接管点击（`object_map_layer.gd:81-89`）。观战视图必须跳过这段（例如 `if not spawn_player: return`），否则会在观战场景里多出一个输入处理器；虽然 `_on_input_clicked` 在非 EDIT 模式会提前返回，但没必要留这个入口。
- 不要把 `play_room_base.tscn` 里的 `TimeoutManager / RandomCapture / BadLevelDetect / LifeDisplay / SaveLevel` 带进观战视图：
  - `TimeoutManager` 会切场景；
  - `RandomCapture` 会污染 `RandomCaptureManager` 截图；
  - `BadLevelDetect` 找不到 player 会判定「坏关」；
  - `SaveLevel` 会写文件。

### 8.7 已知保真度限制（需要在 UI 明示）

- 敌人、移动平台、砖块、开关、岩浆、自动卷轴等运行时状态**完全不同步**；观战端的关卡从 t=0 开始模拟。
- 目标可能站在观战端「不存在」的平台上，或已消灭的敌人仍在。
- BGM/音效不跟随目标。
- 观战 HUD 应显示「简化观战画面」提示，避免玩家误以为画面完全一致。
- 若后续要求完全一致，可把游玩阶段也升级为方案 C（截图流）；`spectate_view` 的截图层可直接复用。

### 8.8 无本地玩家带来的对象风险

观战端跳过了 player 对象，但关卡里的敌人/机关仍会被实例化，其中一部分会找 `player` 组：

- `script/level/enemy/magikoopa/magikoopa_magic.gd:22`
- `script/level/enemy/magikoopa/magic.gd:6`
- `script/level/facility/sealer.gd:10`
- `script/level/component/player_dependent.gd:27`
- `script/level/facility/atchi_muite_block.gd:31`

大多数使用点有 `is_instance_valid` 保护，不会崩，但可能出现「敌人原地不动」「机关不触发」「朝向错误」等现象。

建议：

1. 先逐点抽查上述脚本，确认无 `push_error` / 空引用。
2. 给 `spectate_view` 增加 `@export var freeze_dynamic_objects: bool = true`：
   - `true`：加载后把 `ObjectMapLayer` 下的敌人/投射物/机关设为 `process_mode = DISABLED`（或加载时跳过），只保留地形/背景/管道。画面最稳定、CPU 最低，但看不到敌人。
   - `false`：允许本地模拟，接受敌人行为异常与状态错位。
3. 如果后续要「看得像」，优先升级整帧截图流，而不是逐个同步敌人。

---

## 9. 编辑观战（方案 C：截图流）

### 9.1 方案

被观战编辑器客户端按固定频率抓取自己的**关卡画布**（`SubViewport`），压缩后只发给「正在看自己」的观战者；观战端用 `TextureRect` 显示。观战端不加载编辑器场景，因此天然只读，不存在误操作/误保存风险。

不抓整个游戏窗口：编辑器工具栏、按钮、聊天等不含在内；画布内的放置光标、网格、选中框仍会显示。

### 9.2 订阅链路

```text
观战者 --request_watch(target_id)--> 房主
房主 --watch_granted(target_id)--> 观战者
房主 --editor_stream_subscribe(spectator_peer_id)--> 目标编辑者
目标编辑者 --editor_frame(frame_id, jpeg, size)--> 订阅的观战者（仅订阅者）
观战者切换/离开 --request_watch(new_id) / 断线--> 房主通知旧目标 unsubscribe
```

- 没人观看时目标编辑者**完全停发**，不要做无订阅广播。
- 目标掉线、观战者掉线、切目标、阶段切到 `TRANSFER` 都要清理订阅。
- 房主需要维护 `target_id -> Set[spectator_peer_id]`，避免重复订阅。

### 9.3 抓屏参数（默认值，可配置）

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| 抓屏源 | 关卡画布 `GameRoomSize/SubViewportContainer/SubViewport` | 只含关卡区域、网格、光标、选中框；不含工具栏/按钮/聊天 |
| 输出分辨率 | 480×360 | 4:3，与 `SubViewport`（1280×960）一致，避免黑边 |
| 帧率 | 4 fps | 编辑操作不需要 30fps |
| 格式 | JPEG quality 65 | `Image.save_jpg_to_buffer()` |
| 空闲降频 | 2 秒无输入 → 1 fps | 保活即可 |
| 变化检测 | 可选 | 图像变化小则跳过；可用降采样后的 CRC 比较 |

预估带宽（单观战者，4:3 画布）：

| 分辨率 | 质量 | 单帧 | 4 fps | 备注 |
| --- | --- | --- | --- | --- |
| 480×360 | 65 | 15–25 KB | 60–100 KB/s | 推荐默认 |
| 640×480 | 70 | 25–40 KB | 100–160 KB/s | 画面更清楚 |
| 960×720 | 75 | 55–85 KB | 220–340 KB/s | FRP/家庭上行可能吃紧 |

多观战者时按人数线性叠加；建议在文档/设置里给出「同时观战人数 ≤ 3」的软限制。

### 9.4 实现要点

- 抓屏节点放在编辑器根节点下，取关卡画布：
  - `get_node("GameRoomSize/SubViewportContainer/SubViewport").get_texture().get_image()`
  - 不要用根窗口 `get_viewport()`，否则会把工具栏、按钮、聊天一起抓进来。
  - 画布的 `render_target_update_mode` 需为 `ALWAYS`（`play_room_base.tscn` 里是 4；编辑器底座需确认同值），否则没有玩家输入时可能不刷新。
- `Image.resize()` 后再 `save_jpg_to_buffer(0.65)`，避免先编码再缩放。
- 用 `Timer` 固定节拍，不要 `_process` 每帧抓；`get_image()` 会同步 GPU 读回，开销明显。
- `editor_frame` 用 `unreliable`；丢帧不影响编辑，下一帧会覆盖。
- 观战端 `TextureRect` 用 `expand_mode = IGNORE_SIZE` / `stretch_mode = KEEP_ASPECT_CENTERED`，`texture_filter = NEAREST`。
- 首次收到帧前显示「正在获取编辑器画面…」；超过 3 秒无帧显示「目标画面暂不可用」。

### 9.5 只读保证

- 观战端没有任何编辑器节点、没有 `InputHandler`、没有 `CommandStack`，无法编辑。
- 观战者不能调用 `transfer_level_data / set_edit_ready / my_players_data_are_ready` 等玩家 RPC；房主按 `get_remote_sender_id()` 拒绝观战者的玩家侧 RPC。
- 截图流不包含存档/加载操作；观战者也无法触发。

### 9.6 编辑器观战的边界

- 目标在 `EDIT` 阶段但还没打开/加载关卡时，截图为空关卡画布，正常显示。
- 目标切换关卡主题/尺寸/管道时，截图流自动反映，无需额外同步。
- 观战者看到的编辑画面有 0–250ms 延迟，属于可接受范围。
- 观战者看不到编辑器工具栏/按钮，只能看到画布与画布内光标；需要判断「对方在选什么工具」时要另行约定（本期不做）。
- 如果目标窗口被最小化，`SubViewport` 的渲染更新是否继续取决于 `render_target_update_mode` 与平台；需要实测 GL Compatibility，必要时在最小化时降频/暂停并显示「画面暂停」。

---

## 10. 早完赛自动观战

### 10.1 触发

玩家把 `random_levels` 全部走完，进入 `result_room`；`reach_end_notifier._ready()`（`script/multiplayer/6_result/reach_end_notifier.gd:11`）上报 `reach_end`。此时：

- 本地标记 `did_finish = true`。
- 如果还没收到 `result_updated`，显示观战层。
- `result_updated` 到达后，收起观战层，显示结果列表。

### 10.2 结果房间内嵌观战层

- `result_room.tscn` 新增 `SpectateOverlay`（实例化 `spectate_view.tscn` + HUD），默认隐藏。
- `reach_end_notifier` 上报后调用 `SpectateOverlay.show_for_waiting()`：
  - 目标列表 = `get_watchable_players()`（用 `spectator_status` 过滤已 `reach_end`/进结果房间的人）；
  - 阶段 = `PLAY`（全局可能仍是 PLAY，因为还有人在玩）；
  - 左右切换、截图/游玩观战逻辑与独立观战房间一致。
- 结果就绪（`result_updated`）时 `hide()`，显示原有结果表。
- 房主如果也是早完赛玩家：房主的 `result_room` 同样显示观战层；房主的权威「全员 reach_end」检测不能依赖这个场景（见 10.3）。

### 10.3 房主侧「全员 reach_end」检测

现有实现是房主在 `result_room` 里轮询 `players`（`reach_end_notifier.gd:18-25`），这要求房主自己在结果房间。房主观战或还在游玩时不成立。

**改为**：`reach_end` RPC（`multiplayer_manager.gd:543`）更新 `p.reach_end = true` 后，房主立即调用 `_check_all_reach_end()`：

- 只统计 `get_playing_players()`；
- 全部为 true 时计算 `clear_rate / score`，清空 `level_data`，`store_level_results.rpc`，广播 `RESULT`；
- `result_room` 的轮询可删除或保留为空壳（兼容旧场景）。

同理，`my_players_data_are_ready`（`multiplayer_manager.gd:486`）在房主侧更新后应立即检查「所有非观战玩家 ready」，到齐就生成 `random_levels` 并开玩；不要依赖房主站在 `level_transfer_room` 里。

### 10.4 结算过滤

- `store_level_results`（`multiplayer_manager.gd:553`）只遍历 `get_playing_players()`；观战者没有 `level_file_name`，不能写盘。
- `result_list.gd` 只显示 `get_playing_players()`。
- `score_level_pass` 的分母改为 `get_playing_players().size()`（`reach_end_notifier.gd:35`）。
- 观战者不占 `random_levels`，不参与 `total_levels`。

---

## 11. 观战 HUD 与交互

| 元素 | 内容 |
| --- | --- |
| 顶部徽章 | 「观战中」+ 目标玩家名 + `n/N` |
| 关卡信息 | `第 k / total 关`、关卡作者名、目标生命/状态 |
| 操作提示 | `←/→ 切换玩家`、`Esc/返回 退出观战` |
| 空状态 | 「暂时没有可观看的玩家」/「其他玩家都已通关，等待结果…」 |
| 简化提示 | 「简化观战画面：只同步玩家位置」 |
| 聊天 | 复用 `MessageOverlay` 右侧按钮 |
| 移动端 | 左右切换按钮，不要显示移动/跳跃虚拟键 |
| 退出 | 观战者：`退出房间`（复用 `disconnect_and_cleanup`） |
| 房主控场 | 房主观战时额外显示 `结束本局 / 一起回标题`，走现有 `back_to_title_together` 流程 |

输入：

- 新增 `spectate_prev / spectate_next` 输入动作；用 `_unhandled_input` 处理，避免与 UI 焦点冲突。
- 不注册 `player` 组，不生成玩家，不发送玩家 RPC。
- 聊天面板打开时 `PlayerInputBlocker` 会临时移除 `PLAYER_ACTIONS` 里的事件；把 `spectate_prev / spectate_next` 加入该列表，面板打开期间就不能切换（推荐，行为一致）；不加入则面板打开时仍可切换，需要在 HUD 上说明。

---

## 12. 网络协议清单

| RPC | 方向 | 模式 | 载荷 | 频率 |
| --- | --- | --- | --- | --- |
| `register_player_on_host` | client → host | reliable | `player_info`（含 `is_spectator`） | 加入一次 |
| `spectator_snapshot` | host → spectator | reliable | phase/status/random_levels/players_public | 加入一次 |
| `phase_changed` | host → all | reliable, call_local | `phase, payload` | 阶段切换 |
| `report_player_status` | player → host | reliable | `level_index, reach_end, is_in_result` | 换关/进结果时 |
| `sync_spectator_status` | host → all（含早完赛玩家） | reliable | `Dictionary` | 状态变化时 |
| `request_watch` | spectator → host | reliable | `target_id` | 切换目标 |
| `watch_granted` | host → spectator | reliable | `target_id` | 切换结果 |
| `editor_stream_subscribe` | host → target | reliable | `spectator_peer_id` | 订阅变化 |
| `editor_stream_unsubscribe` | host → target | reliable | `spectator_peer_id` | 订阅变化 |
| `editor_frame` | target → subscribers | unreliable | `frame_id, jpeg, source_size` | 4 fps |
| `request_spectator_level` | spectator → host | reliable | `level_index` | 需要时 |
| `spectator_level_data` | host → spectator | reliable | `level_index, file_name, compressed_json` | 需要时 |
| `send_ani_sprite_data` | player → all | unreliable_ordered | 现有字段 | 每物理帧 |
| `transfer_level_data` | player → all | reliable | 现有字段 | 传输阶段 |
| `lets_play_together` | host → all | reliable, call_local | `random_levels` | 开玩一次 |
| `reach_end` | player → host | reliable | `player_id` | 进结果房间 |
| `store_level_results` | host → all | reliable, call_local | `players` | 结算一次 |

安全规则：

- 所有 `any_peer` RPC 都用 `multiplayer.get_remote_sender_id()` 校验身份，不能信载荷里的 `player_id`。
- 观战者只能调用 `request_watch / request_spectator_level / send_quick_message`；其余玩家侧 RPC 一律拒绝并记日志。
- `spectator_level_data` 的 `file_name` 必须来自房主自己的 `random_levels`，不能直接用客户端传来的路径打开文件。

---

## 13. 代码改造清单

### 13.1 核心（P0，必须先做，否则观战者会破坏现有流程）

| 文件 | 改动 |
| --- | --- |
| `script/multiplayer/0_core/multiplayer_manager.gd` | `player` 默认字段加 `is_spectator`；`register_player_on_host` 角色分支；`players` 过滤方法；`report_player_status` / `sync_spectator_status`；`spectator_snapshot`；`request_watch` / `watch_granted`；`level_data_cache`；`_check_all_level_data_ready` / `_check_all_reach_end` 移入本类；`send_ani_sprite_data` 改为 `apply_remote_state(player_id, ...)`；`store_level_results` 过滤观战者 |
| `script/multiplayer/4_level_transfer_room/level_sender_node.gd` | 观战者跳过发送/等待；`all_players_data_ready` 只数非观战者；房主观战时不依赖本节点 |
| `script/multiplayer/4_level_transfer_room/lets_play_together.gd` | 收集关卡只遍历非观战者；观战者不踢 |
| `script/multiplayer/4_level_transfer_room/level_transfer_progress_label.gd` | 分母改为非观战者人数；观战者不显示或显示「观战中」 |
| `script/multiplayer/3_edit_room/edit_ready_button.gd` | 观战者隐藏/禁用；分母改为非观战者 |
| `script/multiplayer/1_game_hall/player_list.gd` + `ui/list/player_list.tscn` | 显示「观战」标签 |
| `script/multiplayer/1_game_hall/game_start.gd` | 0 玩家禁用开始；房主观战仍可开始；阶段广播 |
| `script/multiplayer/6_result/reach_end_notifier.gd` | 观战者不报告；房主等待逻辑移入 MPManager；早完赛显示观战层 |
| `script/multiplayer/6_result/result_list.gd` | 过滤观战者 |
| `script/multiplayer/back_to_title_process.gd` | 观战者清理；阶段回 LOBBY |
| `script/multiplayer/0_core/multiplayer_manager.gd` 的 `restore_origin_player_data` | 重置 `is_spectator`（避免下一局仍带着观战身份）；具体以大厅角色选择为准 |
| `script/timeout_manager.gd` | 观战者不参与；房主编时逻辑抽到 MPManager |
| `script/multiplayer/1_game_hall/ready_button.gd` | 观战者不参与准备 |

### 13.2 游玩观战（P1）

| 文件/新增 | 改动 |
| --- | --- |
| `script/utils/game_mode.gd` | 新增 `SPECTATE` 枚举（或独立标志），避免误走 `PLAY` 分支 |
| `script/level_camera.gd` | 不改玩家跟随；新增 `SpectateCamera`（新文件） |
| `script/multiplayer/5_play/multiplayer_ani_sprite_manager.gd` | 拆出 `apply_remote_state(player_id, ...)`；槽位按 player_id；观战模式不发送本地数据。注意 `MPManager.mp_ani_manager` 目前是 `MpAniSpriteManagerScript` 类型，接入观战管理器时必须改成一个共同接口（或弱类型 + `has_method`），否则类型不匹配 |
| `script/edit/save_and_load/load_level.gd` | 观战路径改为按快照加载，不依赖 `MPManager.current_level_count` 的文件名 |
| `script/edit/objectmap/object_map_layer.gd` | 新增 `spawn_player` 开关，观战视图跳过 player 对象 |
| `script/multiplayer/random_capture/random_capture.gd` | 观战场景不实例化 |
| `room/play.tscn` / `room/base/play_room_base.tscn` | 不直接复用；新建 `spectate_view.tscn` 承载 Level 子树 |
| 新增 `room/spectate_room.tscn` | 独立观战场景：背景 + `GameRoomSize` + `spectate_view` + HUD + 等待面板 |
| 新增 `object/spectator/spectate_view.tscn` | SubViewport + Level + SpectateCamera + GhostManager + 截图层 |
| 新增 `script/spectator/spectate_camera.gd` | 跟随目标、limit、瞬移吸附 |
| 新增 `script/spectator/spectate_ghost_manager.gd` | player_id 槽位、远程状态应用、目标高亮 |
| 新增 `script/spectator/spectate_hud.gd` | 目标切换、空状态、关卡/生命显示 |

### 13.3 编辑观战（P2）

| 文件/新增 | 改动 |
| --- | --- |
| 新增 `script/spectator/editor_streamer.gd` | 订阅集合、定时抓取 `SubViewport` 关卡画布、缩放/JPEG、空闲降频、`rpc_id` 定向发送 |
| 新增 `object/spectator/editor_stream_view.tscn` | `TextureRect` + 加载/失败提示 |
| `room/edit.tscn` / `room/base/edit_room_base.tscn` | 挂 `EditorStreamer`（或作为子节点由脚本创建），不改变编辑逻辑 |

### 13.4 大厅/测试（P0/P3）

| 文件 | 改动 |
| --- | --- |
| `room/title.tscn` + `HostPage` / `JoinPage` | 角色选择控件；`JumpToScene`（标题 → 准备房间）加分支：本地是观战者时改跳 `spectate_room` |
| `script/multiplayer/1_game_hall/join_button.gd` / `host_button.gd` | 读取角色写进 `MPManager.player` |
| `script/debug/mp_test_flags.gd` | 新增 `--mp-role=spectate`、`--mp-watch=<name>`、`--mp-join-delay=<s>` |
| `script/debug/mp_test_boot.gd` | 观战角色不 ready、自动选择目标、日志标记；`_auto_start` 只数玩家 |
| `tools/mp_test.ps1` | 新增观战实例场景（1 host + 1 player + 1 spectator） |

### 13.5 房主流程抽取（已确认）

为了让「房主观战」不依赖玩家房间场景，把下面三件事从房间节点抽到 `MultiplayerManager`（或一个持久 `GameFlow` 节点）：

1. `begin_ready_phase(seconds)`：房主准备倒计时，结束广播 `EDIT`。
2. `begin_edit_phase(seconds)`：房主编辑计时，结束 `edit_time_out.rpc()` + 广播 `TRANSFER`。
3. 关卡收集与结算检查：`my_players_data_are_ready` / `reach_end` 更新后立即检查是否全员到齐。

房间节点只负责「本地保存 / 本地切场景 / UI」，不再持有房主权威循环。这样房主在 `spectate_room` 里也能推进全部阶段。

---

## 14. 边界与异常

| 场景 | 期望行为 |
| --- | --- |
| 0 名游玩玩家（全观战） | 开始按钮 disabled；HUD 提示「至少需要 1 名玩家」 |
| 房主观战 + 1 名玩家 | 房主可开始；房主进入观战场景；玩家正常编辑/游玩 |
| 观战者加入时游戏已开始 | 接受；发送 snapshot；进入对应阶段观战 |
| 观战者以「游玩」身份加入已开始的游戏 | 拒绝并 `Notice` 提示「只能观战」；可选「以观战加入」重连（v1 不做自动重连） |
| 观战者加入时正在 `TRANSFER` | 显示「关卡传输中」；到 `PLAY` 后自动进入观战 |
| 观战者加入时正在 `RESULT` | 显示结果快照（结果列表 + 分数） |
| 目标掉线 | 自动切下一个；无目标显示空状态 |
| 目标进结果房间 | 目标从列表移除；自动切下一个 |
| 目标换关 | 观战端加载新关；加载失败显示错误并保留上一关画面 |
| 目标死亡重生 | 相机吸附；不重载关卡（v1） |
| 关卡 JSON 请求失败/超时 | 显示「关卡数据获取失败」；可手动重试 |
| 作者掉线导致关卡数据丢失 | 房主用 `level_data_cache` 兜底；仍无则提示「该关卡数据不可用」 |
| 观战者掉线 | 房主清理订阅；目标停止发送；玩家列表更新 |
| 房主掉线 | 现有逻辑全员断开；观战者也回标题并提示 |
| 观战者人数过多 | 受 ENet 20 连接上限约束；超出时加入失败并 `Notice` |
| 观战者尝试玩家 RPC | 房主拒绝并记录警告 |
| 恶意超长 `level_file_name` / payload | 校验文件名与大小，拒绝并断开 |

---

## 15. 测试计划

### 15.1 手工测试矩阵

| # | 场景 | 步骤 | 期望 |
| --- | --- | --- | --- |
| 1 | 0 玩家 | 房主选观战，无其他玩家 | 开始按钮 disabled |
| 2 | 房主观战 | 房主观战 + 1 玩家 | 能开始；房主看到编辑截图 → 游玩幽灵 → 结果 |
| 3 | 大厅观战 | 2 玩家 + 1 观战，游戏中加入 | 观战者出现在列表；不参与准备；可发言 |
| 4 | 编辑中途加入 | 编辑阶段加入 | 看到目标编辑器截图；左右切换 |
| 5 | 传输中途加入 | 传输阶段加入 | 看到进度/等待；开玩后自动进入游玩观战 |
| 6 | 游玩中途加入 | 游玩阶段加入 | 加载目标当前关卡；位置跟随；切关跟随 |
| 7 | 结果中途加入 | 结果阶段加入 | 看到结果快照 |
| 8 | 早完赛 | 1 人先打完所有关卡 | 结果房间内自动出现观战层；结果就绪后收起 |
| 9 | 目标异常 | 目标掉线 / 通关 / 换关 | 自动切换/加载/空状态 |
| 10 | 房主观战推进 | 房主观战，玩家编辑中 | 房主可提前结束编辑；可强制继续/推进 |
| 11 | 多人观战 | 3 个观战者同时看 1 个编辑器 | 目标只发送给订阅者；带宽可接受 |
| 12 | 断线重连 | 观战者退出再以观战加入 | 重新拉 snapshot；正常观战 |

### 15.2 自动化

复用 `tools/mp_test.ps1`，新增：

```powershell
tools\mp_test.bat auto -Spectator
# 1 host (player) + 1 player + 1 spectator
# 参数：--mp-role=spectate --mp-watch=test2 --mp-join-delay=...
```

日志标记建议：

```text
SPECTATE] joined role=spectator
SPECTATE] phase=EDIT target=test2
SPECTATE] editor_frame=...
SPECTATE] phase=PLAY target=test2 level=1/3
SPECTATE] switch target=test3 level=2/3
SPECTATE] result snapshot
```

验收：无 `push_error`、无「玩家列表分母错误」、无「关卡数据为空」、观战者不进入玩家场景。

---

## 16. 分阶段实施

| 阶段 | 内容 | 验收 |
| --- | --- | --- |
| P0 | 角色字段、服务端校验、`players` 过滤、0 玩家禁用开始、聊天、房间 UI 标签 | 观战者加入不破坏现有 3 人流程；0 玩家不能开始 |
| P1 | 阶段机 + snapshot + 独立观战场景骨架（等待面板） | 中途加入能看到正确阶段；房主观战可推进 |
| P2 | 游玩观战：关卡加载、幽灵、相机、左右切换、状态表 | 目标换关跟随；掉线/通关自动切换 |
| P3 | 编辑截图流（订阅、抓屏、JPEG、降频） | 3 个观战者同时看 1 个编辑器；目标空闲停发 |
| P4 | 早完赛自动观战、结果快照、结算过滤、异常收尾 | 早完赛进入观战层；结果就绪收起；统计正确 |
| P5 | 测试脚本、压测、i18n、文档 | `mp_test.ps1` 观战用例通过 |

---

## 17. 现状核对（其他 AI 已改，需兼容）

| 改动 | 对本需求的影响 |
| --- | --- |
| 新增 `Notice` autoload（`script/ui/notice_manager.gd`） | 加入被拒、连接失败统一用 `Notice.show_notice`；旧的 `GameInProgressHint` 已删除 |
| `multiplayer_manager.gd` 新增端口校验、连接超时、`_restore_lobby_page` / `_show_player_page` | 观战加入失败也要退回正确页面；不要破坏这些分支 |
| `MessageOverlay` 取代 `MessageSidebar` | 观战者发言直接复用；观战场景不要重复实例化 |
| `MpTestBoot` 自动命名/自动开始/三实例 | 测试要区分玩家/观战者；`_auto_start` 不能把观战者算进 `expect` |
| `game_in_progress_hint.gd` 删除 | 不要再引用该节点/脚本 |
| `tools/mp_test.ps1` | 新增观战实例参数与日志断言 |

---

## 18. 待确认问题（剩余）

已确认：游玩观战方案 A、早完赛结果房间内嵌观战层、编辑器只抓关卡画布、房主侧流程抽取。

剩余待定：

1. **目标死亡重生**：观战端是否需要重载关卡以对齐玩家的死亡重置？本文 v1 不重载，只吸附相机。
2. **观战人数上限**：是否需要为观战者单独预留连接名额（当前 ENet 上限 20）？
3. **编辑器画布分辨率**：480×360 / 4fps / JPEG 65 是否作为默认值，还是需要提供设置项（低/中/高）？
