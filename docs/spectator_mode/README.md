# 观看模式（Spectator Mode）需求与设计

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
7. [各阶段观看行为矩阵](#7-各阶段观看行为矩阵)
8. [游玩观看（方案 A）](#8-游玩观看方案-a)
9. [编辑观看（方案 C：截图流）](#9-编辑观看方案-c截图流)
10. [早完赛自动观看](#10-早完赛自动观看)
11. [观看 HUD 与交互](#11-观看-hud-与交互)
12. [网络协议清单](#12-网络协议清单)
13. [代码改造清单](#13-代码改造清单)
14. [边界与异常](#14-边界与异常)
15. [测试计划](#15-测试计划)
16. [分阶段实施](#16-分阶段实施)
17. [现状核对（其他 AI 已改，需兼容）](#17-现状核对其他-ai-已改需兼容)
18. [已确认与默认值](#18-已确认与默认值)
19. [关卡分发与掉线重连鲁棒性](#19-关卡分发与掉线重连鲁棒性)
20. [前端演示场景](#20-前端演示场景)

## 1. 目标

1. 玩家进入房间时可选择「游玩」或「观看」。
2. 已打完本局全部关卡的玩家（`reach_end`）在等待结果期间自动进入观看。
3. 支持游戏中途加入的观看者；中途加入只能是观看角色。
4. 观看按阶段使用两种不同通道，**不是二选一**：
   - **游玩阶段（方案 A，传坐标）**：观看端加载目标当前关卡的 JSON，只同步玩家位置/动画；关卡内物件不做同步。
   - **编辑阶段（方案 C，传截图）**：被观看编辑器推送关卡画布截图；观看端不加载关卡、不传坐标。
5. 观看者按左/右切换被观看玩家；切换后相机与关卡随之切换。
6. 观看者允许发言（沿用快捷消息系统）。
7. 房主即使是观看者，也可以开始游戏、推进阶段。
8. 游玩人数为 0 时，房主不能开始游戏（按钮禁用）。

### 非目标（本期不做）

- 观看端与玩家端的敌人、机关、砖块、岩浆、自动卷轴等运行时状态同步（方案 B）。
- 观看端自由视角、多画面同屏、画中画。
- 观看者中途转为玩家，或玩家中途转为观看者。
- 录像 / 回放。
- 专用观看服务器（仍由房主主机转发）。

---

## 2. 术语与角色

| 术语 | 定义 |
| --- | --- |
| 玩家（PLAYER） | `is_spectator = false`，参与编辑、收集关卡、游玩、结算 |
| 观看者（SPECTATOR） | `is_spectator = true`，不编辑、不提供关卡、不参与结算、可发言 |
| 房主（HOST） | `multiplayer.is_server()` 的对等体，负责阶段推进与权威数据 |
| 被观看者（TARGET） | 观看者当前跟随的玩家，同一时间只有一个 |
| 阶段（PHASE） | `LOBBY / READY / EDIT / TRANSFER / PLAY / RESULT / TITLE` |
| `reach_end` | 本局把 `random_levels` 全部走完（无论过关还是死亡换关），进入结果房间 |

房主与角色是正交的：房主可以是玩家，也可以是观看者。

---

## 3. 本期关键决策

| 决策 | 结论 |
| --- | --- |
| 游玩观看保真度 | **A**：观看端加载同一关卡 JSON，只同步玩家位置/动画；接受动态物件不同步（已确认） |
| 编辑观看保真度 | **C**：被观看编辑器推送截图流，观看端只读（已确认） |
| 编辑观看抓屏范围 | **只抓关卡画布**（`SubViewport`），不含编辑器工具栏/按钮；画布内的光标、选中框会保留（已确认） |
| 早完赛观看入口 | 早完赛玩家上报 `reach_end` 后进入 **`spectate_room` 观看等待**；结果就绪后统一切到结果页（不再停在「等待其他玩家」文案）（已确认） |
| 角色确定时机 | 加入时确定；本局内不可更改（v1） |
| 房主观看权限 | 保留房主全部权限：开始游戏、推进阶段、强制继续 |
| 房主侧流程 | **抽取到 `MPManager` / `GameFlow` 持久节点**，房主观看也能驱动准备/编辑/收集/结算（已确认） |
| 观看者发言 | 允许，复用 `MessageOverlay` + 快捷用语 |
| 观看者结算 | 不计入关卡收集、准备人数、结果列表、通过率分母 |
| 观看者连接名额 | 占用 ENet 连接（当前上限 20），v1 不单独预留 |
| 数据通道 | **PLAY 只传坐标/动画；EDIT 只传截图**；按阶段切换，不混用（已确认） |
| 关卡缓存目录 | 沿用现有 `user://mfmp_*.lvl`；关卡会被反复游玩，不另建会话目录（已确认） |
| 缺失关卡 | **缺的人本地跳过该关**，`random_levels` 全员一致；不全局删关（已确认） |
| 观看者关卡 | 清单 + **全量关卡**（目标当前关优先，其余后台预取）（已确认） |
| 掉线重连 | `device_id` 保持身份；宽限期 **20s**；宽限内恢复玩家记录（已确认） |

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
| TRANSFER | 所有非观看玩家的关卡数据到齐 | PLAY | 生成 `random_levels` 并 `lets_play_together.rpc`；广播 `PLAY` |
| PLAY | 所有非观看玩家 `reach_end == true` | RESULT | 计算 `clear_rate/score`；`store_level_results.rpc`；广播 `RESULT` |
| RESULT | 房主点「一起回标题」 | TITLE → LOBBY | `back_to_title_process`；广播 `LOBBY` |

> 现有玩家场景仍按自己的本地计时器推进；阶段事件是**观看端的唯一时钟**，也是房主观看时的流程驱动器。

---

## 5. 角色与数据模型

### 5.1 `player` / `players` 字典新增字段

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `is_spectator` | bool | false | 权威值由房主写入；客户端加入时声明，之后不可改 |
| `spectate_target_id` | int | 0 | 仅本地观看者使用，不参与同步 |
| `current_level` | int | 0 | 玩家当前关卡序号（状态表用，低频可靠） |
| `is_in_result` | bool | false | 玩家是否已进入结果房间（用于观看目标过滤） |

`reach_end`、`level_file_name`、`level_data` 等沿用现有字段。

### 5.2 `MultiplayerManager` 新增

| 成员 | 说明 |
| --- | --- |
| `game_phase: GamePhase` | 当前阶段 |
| `phase_deadline_msec: int` | 当前阶段截止时间（`Time.get_ticks_msec()`） |
| `random_levels: Array` | 本局关卡文件名顺序（进入 `PLAY` 前对观看者也要可用） |
| `spectator_status: Dictionary` | `player_id -> {current_level, reach_end, is_in_result, is_dead, lives}` |
| `level_data_cache: Dictionary` | 房主侧：`level_file_name -> level_json`，防止作者掉线后丢失 |
| `spectator_target_id: int` | 本地观看者当前目标 |

### 5.3 唯一过滤入口

新增三个方法，**所有遍历 `players` 的既有逻辑必须改走它们**：

```gdscript
func get_playing_players() -> Array
func get_spectators() -> Array
func get_watchable_players() -> Array   # 非观看、is_in_game、未 reach_end、未进结果房间
```

这是本需求最容易出连锁 bug 的地方，见第 13 节清单。

---

## 6. 加入与角色

### 6.1 大厅 UI

- `HostPage` / `JoinPage`：新增「参与模式」一行，按钮显示当前角色（`游戏` / `观看`），点击切换；不再使用勾选框。
- 默认值：游戏。
- 角色在 `player.is_spectator` 中随加入请求一起发送；大厅内也可以通过 `player list` 的本地行按钮切换，走 `LobbyService.set_spectator()`。

### 6.2 服务端校验

`register_player_on_host(player_info)`（`multiplayer_manager.gd:319`）改为：

| 情况 | 处理 |
| --- | --- |
| `is_in_game == false` | 接受；`is_spectator` 按请求写入房主权威列表 |
| `is_in_game == true` 且 `is_spectator == false` | 拒绝；`Notice.show_notice("游戏已开始，只能以观看身份加入。")`，随后断开 |
| `is_in_game == true` 且 `is_spectator == true` | 接受；追加到 `players`；回发 `spectator_snapshot`；同步聊天记录 |

要点：

- 客户端中途不能改 `is_spectator`；房主以加入请求中的值为准并写死。
- 旧 `inform_late_player`（`multiplayer_manager.gd:345`）只对「游玩」角色使用。旧的 `GameInProgressHint` 已被其他 AI 删除，统一改用 `Notice`。
- 观看者加入也要触发 `players_updated`，让玩家列表显示「观看」标签。

### 6.3 加入快照

`spectator_snapshot(snapshot)`（`authority` → 新观看者）：

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
- 根据阶段切到观看场景（见第 7 节）；已在观看场景则只刷新内容。
- 观看者不进入 `ready_room / edit / level_transfer_room / play / result_room` 的玩家流程。

### 6.4 开始按钮

- `StartButton`（`room/title.tscn`）新增控制器：当 `get_playing_players().size() == 0` 时 `disabled = true`。
- 房主本身是观看者时，只要还有 ≥1 名玩家，按钮仍可点。
- 非房主隐藏 `StartButton`（当前 UI 对所有玩家显示；点击本来就会被 `is_server` 挡住，但观看者不该看到可点按钮）。
- 本需求只加「0 玩家禁用」；不改变现有「不强制全员准备」的行为。
- `players_updated` 时刷新按钮状态（有人加入/离开/切换角色都要重算）。
- `MpTestBoot._auto_start()`（`script/debug/mp_test_boot.gd:342`）目前用 `players.size() >= expect` 判断，观看者会算进人数；测试脚本要改为只数非观看玩家。

### 6.5 发言

- 观看者在 `players` 列表内，`send_quick_message` 无需改动即可发言。
- 观看者不需要「准备」；`ready_button` 对观看者隐藏或禁用。
- `MessageOverlay` 打开时会屏蔽 `move_left/right`（`player_input_blocker.gd`），观看者的左右切换在面板打开期间被屏蔽——这是期望行为。

---

## 7. 各阶段观看行为矩阵

| 阶段 | 玩家 | 观看者 | 房主（观看者） |
| --- | --- | --- | --- |
| LOBBY | 准备/开始 | 玩家列表、观看标签、聊天 | 可开始、可退出房间 |
| READY | 准备房间倒计时 | 「准备中」等待面板 + 目标列表 | 驱动倒计时，界面同观看者 |
| EDIT | 编辑自己的关卡 | 目标编辑器的截图流（C） | 可提前结束编辑（倒计时/全员完成） |
| TRANSFER | 发送/接收关卡数据 | 「关卡传输中 x/y」等待面板 | 收集关卡数据、生成 `random_levels`、开玩 |
| PLAY | 游玩、推进关卡 | 目标位置 + 目标当前关卡 | 观看；可强制继续/推进阶段 |
| RESULT | 结果列表 | 结果快照 | 计算结果、回标题 |

### 7.1 观看场景的两种承载方式

| 场景 | 用途 | 说明 |
| --- | --- | --- |
| `spectate_room.tscn`（新增） | 中途加入、房主观看、早完赛等待 | 独立场景，按 `game_phase` 切换内容；PLAY 时实例化裁剪后的 `play_room_base`，EDIT/TRANSFER 显示等待提示 |
| 结果页 | 所有人 | RESULT 阶段由 `MatchFlowService` 统一切到 `result_room`，观看者也能看结果 |

PLAY 观看视图复用 `play_room_base.tscn`，运行时裁掉 `TimeoutManager / RandomCapture / BadLevelDetect / MarginContainer / GameTimeHUD / MobileControlManager / SaveLevel`，并设置 `ObjectMapLayer.spawn_player = false`、`LoadLevel.report_progress = false`、`MpAniSpriteManager.spectate_mode = true`。相机沿用 `LevelCamera`，运行时把 `player` 指向目标幽灵。

---

## 8. 游玩观看（方案 A）

### 8.1 数据流

```text
玩家客户端                       房主                        观看者
   |  上传关卡（分块/CRC）        |                              |
   |----------------------------->| level_cache                  |
   |  每帧 send_ani_sprite_data   |                              |
   |----------------------------->|（广播/转发）----------------->|
   |  report_player_status(换关)  |                              |
   |----------------------------->|  sync_spectator_status       |
   |                              |----------------------------->|
   |                              |  level_manifest + 全量关卡   |
   |                              |----------------------------->|
   观看者：目标当前关优先加载 -> 跳过 player 生成 -> 相机跟随幽灵 -> 后台预取其余关卡
```

### 8.2 关卡解析（关键易错点）

目标玩家当前在第 `k` 关，对应关卡文件名是 `random_levels[k]`。这个文件属于**作者**，不是目标玩家本人。观看端加载时：

1. 先查本地 `user://mfmp_*.lvl` 是否已有该文件（早完赛玩家、已预取的观看者）。
2. 没有则向房主请求 `level_chunk`（房主从 `level_cache` 取）。
3. 加载后跳过 player 生成，只保留地形/背景/管道。

因此：

- 房主在收到上传时就缓存进 `level_cache[level_file_name]`，**不要**把 JSON 塞回 `players` 字典；否则作者掉线后数据就丢了，`sync_players_list` 也会被大字符串拖爆。
- 关卡来源分三种：
  - **早完赛玩家**：本局已经走过 `TRANSFER`，本地 `user://mfmp_*.lvl` 已有全部关卡文件，可直接按文件名读取。
  - **中途加入的观看者**：没有本地文件，加入时先拉清单 + 目标当前关，其余后台预取。
  - **掉线重连的玩家**：优先拉当前关，其余后台补。
- 观看者按文件名缓存已加载过的关卡 JSON；切换目标时同一关不重复请求/解析。
- **缓存目录沿用现有 `user://mfmp_*.lvl`**：关卡后续要反复游玩，观看者/重连玩家收到的关卡也写这个目录；文件会出现在历史列表里，这是预期行为。
- `level_file_name` 来自 RPC，必须做文件名白名单/`validate_filename()` 校验，拒绝 `..`、绝对路径与超大 payload。

### 8.3 位置与动画

- 沿用 `send_ani_sprite_data`（`multiplayer_manager.gd:599`），字段已包含：`player_id / current_level / ani_pos / suit / power / animation / frame / flip_h / is_dead / scale / rotation`。
- 观看者把本地 `MPManager.current_level_count` 设为目标的 `current_level`，现有过滤条件 `current_level_count != current_level` 即可放行目标关卡的位置包。
- 观看者不要发送该 RPC（没有本地玩家）。
- 现有「第一个没有 meta 的槽位就绑定 player_id」的分配方式会串人（`multiplayer_manager.gd:660`）。改为：
  - 幽灵管理器暴露 `apply_remote_state(player_id, ...)`；
  - 槽位用 `Dictionary[player_id] -> AnimatedSprite2D`；
  - `players_updated` 时增删槽位，目标离开/通关时回收。
- 切换目标或换关时调用 `reset_physics_interpolation()`，避免幽灵从上一关坐标拖一条线过来。

### 8.4 目标列表与切换

- 左/右切换。建议新增输入动作 `spectate_prev / spectate_next`（默认 A/D 或 ←/→），不要复用 `move_left/right` 的游戏语义，避免与玩家/编辑器冲突。
- 列表来源：`get_watchable_players()`，按 `players` 数组顺序（即加入顺序）稳定排序。
- 过滤：自己、其他观看者、`reach_end == true`、`is_in_result == true`。
- 注意：非房主客户端的 `players` 不会自动收到别人的 `reach_end` 更新，所以 `get_watchable_players()` 必须结合 `spectator_status`（房主低频广播）来过滤；这是早完赛玩家在结果房间里也能正确列出剩余玩家的前提。
- 行为：
  - 只有 1 个目标：左右键无效果，HUD 显示 `1/1`。
  - 0 个目标：显示空状态（「其他玩家都已通关，等待结果…」或「暂时没有可观看的玩家」）。
  - 目标掉线 / 进结果房间：自动切到列表中的下一个；没有则空状态。
  - 目标换关（关卡索引变化）：观看端加载另一张关卡文件并跟随；加载期间显示淡出/「加载中」。这不是为了同步物件，而是目标已经不在同一张地图上。
  - 目标死亡重生：位置会瞬移，相机按 `TELEPORT_THRESHOLD`（`script/level_camera.gd:15`）直接吸附，**不重载关卡**，因为物件本就不同步。
  - 切换到同一关的另一名玩家：不重新加载关卡，只移动相机/切换幽灵。
- 切换只在本地处理，向房主发 `request_watch(target_id)` 仅用于编辑截图流的订阅；游玩阶段可只依赖广播的位置包。

### 8.5 相机

- 新增 `SpectateCamera`（不要直接改 `LevelCamera` 的玩家跟随逻辑，避免影响编辑器/回放）：
  - 跟随目标幽灵的 global_position；
  - 从 `LevelManager` 读取 `level_size` 设置 limit；
  - 目标切换时 `reset_physics_interpolation()`；
  - 不做输入移动。
- 不要依赖 `get_first_node_in_group("player")`；观看场景不会生成本地玩家。

### 8.6 关卡视图

- 直接复用 `play_room_base.tscn`，在 `spectate_room.gd` 里实例化后**运行时裁剪**（见 `STRIP_PATHS`）：
  - 保留：`SubViewportContainer + SubViewport + Level`、`DatabaseHolder`、`LevelManager`、`TileMapLayer + TileSetManager + TileMapLayerSemiSolidCreator`、`SealerCreator`、`ObjectMapLayer`、`BgpManager`、`PipeBuilder`、`PinkCoinCanvasLayer`、`LevelCamera`、`MultiplayerAniSpriteManager`
  - 去掉：`TimeoutManager`、`BgmManager`、`GameTimeHUD`、`RandomCapture`、`MarginContainer`（编辑按钮 + GameModeDetect）、`MobileControlManager`、`SaveLevel`
  - 必须移除而不是只隐藏：这些节点的 `_ready` 仍会执行，隐藏不能阻止切场景/抓屏/写盘
- `ObjectMapLayer` 新增 `@export var spawn_player: bool = true`，观看视图里设为 `false`；`_ready` 在 `spawn_player == false` 时直接返回，不创建 `InputHandler`，`load_object_data` 跳过 `player` 对象。
- `LoadLevel` 新增 `report_progress`；观看视图设为 `false`，避免把目标的关卡索引写回自己的进度。
- `MultiplayerAniSpriteManager` 新增 `spectate_mode`（只收不发）与 `get_ghost(player_id)`；观看相机把 `LevelCamera.player` 指向目标幽灵即可，不需要新相机脚本。
- `GhostCacheService` 只在 `current_level == MPManager.current_level_count` 时转发位置；观看端把 `current_level_count` 设成目标关卡即可收到同关幽灵。

### 8.7 已知保真度限制（需要在 UI 明示）

- 敌人、移动平台、砖块、开关、岩浆、自动卷轴等运行时状态**完全不同步**；观看端的关卡从 t=0 开始模拟。
- 目标可能站在观看端「不存在」的平台上，或已消灭的敌人仍在。
- BGM/音效不跟随目标。
- 观看 HUD 应显示「简化观看画面」提示，避免玩家误以为画面完全一致。
- **不重载**：目标死亡重生时不重新加载关卡；只有目标进入下一关（关卡索引变化）才加载新地图。
- 若后续要求完全一致，可把游玩阶段也升级为方案 C（截图流）；`spectate_room` 的 HUD 可直接复用。

### 8.8 无本地玩家带来的对象风险

观看端跳过了 player 对象，但关卡里的敌人/机关仍会被实例化，其中一部分会找 `player` 组：

- `script/level/enemy/magikoopa/magikoopa_magic.gd:22`
- `script/level/enemy/magikoopa/magic.gd:6`
- `script/level/facility/sealer.gd:10`
- `script/level/component/player_dependent.gd:27`
- `script/level/facility/atchi_muite_block.gd:31`

大多数使用点有 `is_instance_valid` 保护，不会崩，但可能出现「敌人原地不动」「机关不触发」「朝向错误」等现象。

建议：

1. 先逐点抽查上述脚本，确认无 `push_error` / 空引用。
2. 给观看视图增加 `@export var freeze_dynamic_objects: bool = true`：
   - `true`：加载后把 `ObjectMapLayer` 下的敌人/投射物/机关设为 `process_mode = DISABLED`（或加载时跳过），只保留地形/背景/管道。画面最稳定、CPU 最低，但看不到敌人。
   - `false`：允许本地模拟，接受敌人行为异常与状态错位。
3. 如果后续要「看得像」，优先升级整帧截图流，而不是逐个同步敌人。

---

## 9. 编辑观看（方案 C：截图流）

### 9.1 方案

被观看编辑器客户端按固定频率抓取自己的**关卡画布**（`SubViewport`），压缩后只发给「正在看自己」的观看者；观看端用 `TextureRect` 显示。观看端不加载编辑器场景，因此天然只读，不存在误操作/误保存风险。

不抓整个游戏窗口：编辑器工具栏、按钮、聊天等不含在内；画布内的放置光标、网格、选中框仍会显示。

编辑阶段**只传截图，不传坐标，也不需要加载关卡文件**；观看端只显示 `TextureRect`。

### 9.2 订阅链路

```text
观看者 --request_watch(target_id)--> 房主
房主 --watch_granted(target_id)--> 观看者
房主 --editor_stream_subscribe(spectator_peer_id)--> 目标编辑者
目标编辑者 --editor_frame(frame_id, jpeg, size)--> 订阅的观看者（仅订阅者）
观看者切换/离开 --request_watch(new_id) / 断线--> 房主通知旧目标 unsubscribe
```

- 没人观看时目标编辑者**完全停发**，不要做无订阅广播。
- 目标掉线、观看者掉线、切目标、阶段切到 `TRANSFER` 都要清理订阅。
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

预估带宽（单观看者，4:3 画布）：

| 分辨率 | 质量 | 单帧 | 4 fps | 备注 |
| --- | --- | --- | --- | --- |
| 480×360 | 65 | 15–25 KB | 60–100 KB/s | 推荐默认 |
| 640×480 | 70 | 25–40 KB | 100–160 KB/s | 画面更清楚 |
| 960×720 | 75 | 55–85 KB | 220–340 KB/s | FRP/家庭上行可能吃紧 |

多观看者时按人数线性叠加；建议在文档/设置里给出「同时观看人数 ≤ 3」的软限制。

### 9.4 实现要点

- 抓屏节点放在编辑器根节点下，取关卡画布：
  - `get_node("GameRoomSize/SubViewportContainer/SubViewport").get_texture().get_image()`
  - 不要用根窗口 `get_viewport()`，否则会把工具栏、按钮、聊天一起抓进来。
  - 画布的 `render_target_update_mode` 需为 `ALWAYS`（`play_room_base.tscn` 里是 4；编辑器底座需确认同值），否则没有玩家输入时可能不刷新。
- `Image.resize()` 后再 `save_jpg_to_buffer(0.65)`，避免先编码再缩放。
- 用 `Timer` 固定节拍，不要 `_process` 每帧抓；`get_image()` 会同步 GPU 读回，开销明显。
- `editor_frame` 用 `unreliable`；丢帧不影响编辑，下一帧会覆盖。
- 观看端 `TextureRect` 用 `expand_mode = IGNORE_SIZE` / `stretch_mode = KEEP_ASPECT_CENTERED`，`texture_filter = NEAREST`。
- 首次收到帧前保持紫色背景/边框，不显示中央文字（按 2026-11-10 的 UI 反馈）；超过 3 秒无帧仍显示空画布。

### 9.5 只读保证

- 观看端没有任何编辑器节点、没有 `InputHandler`、没有 `CommandStack`，无法编辑。
- 观看者不能调用 `transfer_level_data / set_edit_ready / my_players_data_are_ready` 等玩家 RPC；房主按 `get_remote_sender_id()` 拒绝观看者的玩家侧 RPC。
- 截图流不包含存档/加载操作；观看者也无法触发。

### 9.6 编辑器观看的边界

- 目标在 `EDIT` 阶段但还没打开/加载关卡时，截图为空关卡画布，正常显示。
- 目标切换关卡主题/尺寸/管道时，截图流自动反映，无需额外同步。
- 观看者看到的编辑画面有 0–250ms 延迟，属于可接受范围。
- 观看者看不到编辑器工具栏/按钮，只能看到画布与画布内光标；需要判断「对方在选什么工具」时要另行约定（本期不做）。
- 如果目标窗口被最小化，`SubViewport` 的渲染更新是否继续取决于 `render_target_update_mode` 与平台；需要实测 GL Compatibility，必要时在最小化时降频/暂停并显示「画面暂停」。

### 9.7 实际实现（2026-11-10）

- `MPManager/EditorStreamService`（`script/multiplayer/0_core/services/editor_stream_service.gd`）：稳定 RPC 节点，负责主机侧订阅表、目标侧订阅者集合、JPEG 编码与定向 `rpc_id` 发送。
- `room/edit.tscn` 新增 `EditorStreamer`（`script/spectator/editor_streamer.gd`）：只抓 `GameRoomSize/SubViewportContainer/SubViewport`，`0.25s` 一次；没有订阅者时不抓屏，headless 下跳过。
- 订阅流程：
  1. 观看者 `spectate_room` 在 EDIT 阶段请求当前目标；
  2. 主机把 `spectator_peer_id -> target_id` 写入订阅表，并通知目标编辑器；
  3. 目标编辑器只向订阅者发送 480×360 / JPEG 65 帧，带 `frame_id`；
  4. 观看者丢弃 `frame_id` 不大于上一帧的乱序旧帧；
  5. 观看者切换目标/离开 EDIT 时取消旧订阅。
- 观看端 `Hud/EditorView`（`TextureRect`，4:3、NEAREST）显示截图；没有帧时保持紫色背景与边框，不显示中央文字。
- 新增文案已加入 `i18n/mfmp_translation.en.po` / `.ja.po` / `.zh_CN.po`；`TargetName` 禁用自动翻译，避免把玩家名当词条翻译。
- 实测截图：
  - `tools/editor_spectate.png`：客户端观看者看房主编辑器（边框为主机玩家色）；
  - `tools/editor_spectate_host.png`：房主观看者看客户端编辑器（边框为客户端玩家色）。

---

## 10. 早完赛自动观看

### 10.1 触发

玩家把 `random_levels` 全部走完时：

1. `play_next_level_manager.next_level()` / `load_level` 先调用 `MPManager.flow.notify_reach_end()`；
2. 如果全局阶段仍是 `PLAY`，切到 `spectate_room`（早完赛等待）；
3. 主机集齐所有玩家的 `reach_end` 后广播 `RESULT`，所有人统一切到 `result_room`。

这样早完赛玩家不会停在结果房间的「等待其他玩家游玩所有关卡……」文案，而是直接进入观看。

### 10.2 早完赛观看行为

- 与普通观看者共用 `spectate_room`；目标列表会自动排除已 `reach_end`/`is_in_result` 的玩家。
- PLAY 阶段：加载目标当前关卡 + 幽灵 + 相机，左右切换；结果就绪后由阶段机切到结果页。
- 房主如果也是早完赛玩家：同样进入 `spectate_room`；房主的权威「全员 reach_end」检测在 `MatchFlowService` 内，不依赖结果房间场景（见 10.3）。

### 10.3 房主侧「全员 reach_end」检测

现有实现是房主在 `result_room` 里轮询 `players`（`reach_end_notifier.gd:18-25`），这要求房主自己在结果房间。房主观看或还在游玩时不成立。

**改为**：`reach_end` RPC（`multiplayer_manager.gd:543`）更新 `p.reach_end = true` 后，房主立即调用 `_check_all_reach_end()`：

- 只统计 `get_playing_players()`；
- 全部为 true 时计算 `clear_rate / score`，清空 `level_data`，`store_level_results.rpc`，广播 `RESULT`；
- `result_room` 的轮询可删除或保留为空壳（兼容旧场景）。

同理，`my_players_data_are_ready`（`multiplayer_manager.gd:486`）在房主侧更新后应立即检查「所有非观看玩家 ready」，到齐就生成 `random_levels` 并开玩；不要依赖房主站在 `level_transfer_room` 里。

### 10.4 结算过滤

- `store_level_results`（`multiplayer_manager.gd:553`）只遍历 `get_playing_players()`；观看者没有 `level_file_name`，不能写盘。
- `result_list.gd` 只显示 `get_playing_players()`。
- `score_level_pass` 的分母改为 `get_playing_players().size()`（`reach_end_notifier.gd:35`）。
- 观看者不占 `random_levels`，不参与 `total_levels`。

---

## 11. 观看 HUD 与交互

| 元素 | 内容 |
| --- | --- |
| 信息栏（关卡视口外） | 左上角唯一面板：`正在观看` + 玩家名；`关卡进度` + `x/y` |
| EDIT 阶段信息栏 | 隐藏「关卡进度」标签，把 `x/y` 替换为「编辑中」；屏幕中央不显示额外说明 |
| 面板样式 | 固定深紫半透明底、**无描边**、不随目标玩家改色；所有文字白色 + 黑色描边 |
| 目标幽灵 | 被观看玩家 **完全不透明**；同房间其他玩家保留 0.25 半透明幽灵 |
| 边框颜色 | **只给关卡边框**使用该玩家在房间里的身份色（`MPManager.player_color`） |
| 布局 | 信息栏固定放在关卡视口左侧，不覆盖 SubViewport；不再显示玩家列表面板/底部提示面板 |
| 切换目标 | `← / →`；同一关内不重新加载关卡，只换相机、幽灵透明度和边框颜色 |
| 空状态 | 「暂时没有可观看的玩家」/「其他玩家都已通关，等待结果…」 |
| 简化提示 | 「简化观看画面：只同步玩家位置」 |
| 聊天 | 复用 `MessageOverlay` 右侧按钮 |
| 移动端 | 左右切换按钮，不要显示移动/跳跃虚拟键 |
| 退出 | 观看者：`退出房间`（复用 `disconnect_and_cleanup`） |
| 房主控场 | 房主观看时额外显示 `结束本局 / 一起回标题`，走现有 `back_to_title_together` 流程 |

输入：

- 直接复用 `move_left / move_right`（已包含方向键与 A/D）；用 `_input` 处理，避免 ScrollContainer 等 UI 先消费方向键。
- 不注册 `player` 组，不生成玩家，不发送玩家 RPC。
- 聊天面板打开时 `PlayerInputBlocker` 会临时移除 `move_left / move_right`，面板打开期间不能切换。

---

## 12. 网络协议清单

> 两套通道按阶段二选一：`PLAY` 只使用 `send_ani_sprite_data`；`EDIT` 只使用 `s2c_editor_frame`。不要同时开。

| RPC | 方向 | 模式 | 载荷 | 频率 |
| --- | --- | --- | --- | --- |
| `register_player_on_host` | client → host | reliable | `player_info`（含 `is_spectator`） | 加入一次 |
| `spectator_snapshot` | host → spectator | reliable | phase/status/random_levels/players_public | 加入一次 |
| `phase_changed` | host → all | reliable, call_local | `phase, payload` | 阶段切换 |
| `report_player_status` | player → host | reliable | `level_index, reach_end, is_in_result` | 换关/进结果时 |
| `sync_spectator_status` | host → all（含早完赛玩家） | reliable | `Dictionary` | 状态变化时 |
| `c2s_request_watch` | spectator → host | reliable | `target_id` | 切换/退出观看 |
| `s2c_add_subscriber` / `s2c_remove_subscriber` | host → target editor | reliable | `spectator_peer_id` | 订阅变化 |
| `s2c_editor_frame` | target editor → spectator | unreliable | `frame_id, JPEG PackedByteArray` | 4 fps |
| `request_spectator_level` | spectator → host | reliable | `level_index` | 需要时 |
| `spectator_level_data` | host → spectator | reliable | `level_index, file_name, compressed_json` | 需要时 |
| `send_ani_sprite_data` | player → all | unreliable_ordered | 现有字段 | 每物理帧 |
| `transfer_level_data` | player → all | reliable | 现有字段 | 传输阶段 |
| `lets_play_together` | host → all | reliable, call_local | `random_levels` | 开玩一次 |
| `reach_end` | player → host | reliable | `player_id` | 进结果房间 |
| `store_level_results` | host → all | reliable, call_local | `players` | 结算一次 |

安全规则：

- 所有 `any_peer` RPC 都用 `multiplayer.get_remote_sender_id()` 校验身份，不能信载荷里的 `player_id`。
- 观看者只能调用 `request_watch / request_spectator_level / send_quick_message`；其余玩家侧 RPC 一律拒绝并记日志。
- `spectator_level_data` 的 `file_name` 必须来自房主自己的 `random_levels`，不能直接用客户端传来的路径打开文件。

---

## 13. 代码改造清单

> **2026-11-09 更新**：实际代码已迁移到 `script/multiplayer/0_core/services/*`。本节保留为需求清单，实际文件与完成状态见 19.12。

### 13.1 核心（P0，必须先做，否则观看者会破坏现有流程）

| 文件 | 改动 |
| --- | --- |
| `script/multiplayer/0_core/multiplayer_manager.gd` | `player` 默认字段加 `is_spectator`；`register_player_on_host` 角色分支；`players` 过滤方法；`report_player_status` / `sync_spectator_status`；`spectator_snapshot`；`request_watch` / `watch_granted`；`level_data_cache`；`_check_all_level_data_ready` / `_check_all_reach_end` 移入本类；`send_ani_sprite_data` 改为 `apply_remote_state(player_id, ...)`；`store_level_results` 过滤观看者 |
| `script/multiplayer/4_level_transfer_room/level_sender_node.gd` | 观看者跳过发送/等待；`all_players_data_ready` 只数非观看者；房主观看时不依赖本节点 |
| `script/multiplayer/4_level_transfer_room/lets_play_together.gd` | 收集关卡只遍历非观看者；观看者不踢 |
| `script/multiplayer/4_level_transfer_room/level_transfer_progress_label.gd` | 分母改为非观看者人数；观看者不显示或显示「观看中」 |
| `script/multiplayer/3_edit_room/edit_ready_button.gd` | 观看者隐藏/禁用；分母改为非观看者 |
| `script/multiplayer/1_game_hall/player_list.gd` + `ui/list/player_list.tscn` | 显示「观看」标签 |
| `script/multiplayer/1_game_hall/game_start.gd` | 0 玩家禁用开始；房主观看仍可开始；阶段广播 |
| `script/multiplayer/6_result/reach_end_notifier.gd` | 观看者不报告；房主等待逻辑移入 MPManager；早完赛显示观看层 |
| `script/multiplayer/6_result/result_list.gd` | 过滤观看者 |
| `script/multiplayer/back_to_title_process.gd` | 观看者清理；阶段回 LOBBY |
| `script/multiplayer/0_core/multiplayer_manager.gd` 的 `restore_origin_player_data` | 重置 `is_spectator`（避免下一局仍带着观看身份）；具体以大厅角色选择为准 |
| `script/timeout_manager.gd` | 观看者不参与；房主编时逻辑抽到 MPManager |
| `script/multiplayer/1_game_hall/ready_button.gd` | 观看者不参与准备 |

### 13.2 游玩观看（P1）

| 文件/新增 | 改动 |
| --- | --- |
| `script/utils/game_mode.gd` | 沿用 `PLAY`；观看视图内部用 `spectate_mode` 标志，不再新增枚举 |
| `script/level_camera.gd` | 沿用 `LevelCamera`；运行时把 `player` 指向目标幽灵，不新增相机脚本 |
| `script/multiplayer/5_play/multiplayer_ani_sprite_manager.gd` | 新增 `spectate_mode`（观看只收不发）与 `get_ghost(player_id)`；幽灵槽位按游玩玩家数创建 |
| `script/edit/save_and_load/load_level.gd` | 新增 `report_progress`；观看视图不写回目标关卡索引 |
| `script/edit/objectmap/object_map_layer.gd` | 新增 `spawn_player` 开关，观看视图跳过 player 对象与 InputHandler |
| `script/multiplayer/random_capture/random_capture.gd` | 观看视图运行时移除 |
| `room/base/play_room_base.tscn` | 直接复用；`spectate_room.gd` 实例化后按 `STRIP_PATHS` 裁剪 |
| 新增 `room/spectate_room.tscn` | 独立观看场景：根 Control + 背景/等待 HUD + 动态关卡视图 |
| 新增 `script/spectator/spectate_room.gd` | 阶段切换、目标列表/左右切换、实例化/裁剪关卡、相机跟随、HUD |

### 13.3 编辑观看（P2）

| 文件/新增 | 改动 |
| --- | --- |
| 新增 `script/spectator/editor_streamer.gd` | 定时抓取 `SubViewport` 关卡画布；没有订阅者时不抓屏 |
| 新增 `script/multiplayer/0_core/services/editor_stream_service.gd` | 订阅表、`rpc_id` 定向发送、缩放/JPEG、4 fps、headless 跳过 |
| `room/edit.tscn` | 挂 `EditorStreamer`，不改变编辑逻辑 |
| `room/spectate_room.tscn` + `script/spectator/spectate_room.gd` | `Hud/EditorView` 显示截图；EDIT 切目标时重新订阅 |

### 13.4 大厅/测试（P0/P3）

| 文件 | 改动 |
| --- | --- |
| `room/title.tscn` + `HostPage` / `JoinPage` | 角色选择控件；`JumpToScene`（标题 → 准备房间）加分支：本地是观看者时改跳 `spectate_room` |
| `script/multiplayer/1_game_hall/join_button.gd` / `host_button.gd` | 读取角色写进 `MPManager.player` |
| `script/debug/mp_test_flags.gd` | 新增 `--mp-role=spectate`、`--mp-watch=<name>`、`--mp-join-delay=<s>` |
| `script/debug/mp_test_boot.gd` | 观看角色不 ready、自动选择目标、日志标记；`_auto_start` 只数玩家 |
| `tools/mp_test.ps1` | 新增观看实例场景（1 host + 1 player + 1 spectator） |

### 13.5 房主流程抽取（已确认）

为了让「房主观看」不依赖玩家房间场景，把下面三件事从房间节点抽到 `MultiplayerManager`（或一个持久 `GameFlow` 节点）：

1. `begin_ready_phase(seconds)`：房主准备倒计时，结束广播 `EDIT`。
2. `begin_edit_phase(seconds)`：房主编辑计时，结束 `edit_time_out.rpc()` + 广播 `TRANSFER`。
3. 关卡收集与结算检查：`my_players_data_are_ready` / `reach_end` 更新后立即检查是否全员到齐。

房间节点只负责「本地保存 / 本地切场景 / UI」，不再持有房主权威循环。这样房主在 `spectate_room` 里也能推进全部阶段。

---

## 14. 边界与异常

| 场景 | 期望行为 |
| --- | --- |
| 0 名游玩玩家（全观看） | 开始按钮 disabled；HUD 提示「至少需要 1 名玩家」 |
| 房主观看 + 1 名玩家 | 房主可开始；房主进入观看场景；玩家正常编辑/游玩 |
| 观看者加入时游戏已开始 | 接受；发送 snapshot；进入对应阶段观看 |
| 观看者以「游玩」身份加入已开始的游戏 | 拒绝并 `Notice` 提示「只能观看」；可选「以观看加入」重连（v1 不做自动重连） |
| 观看者加入时正在 `TRANSFER` | 显示「关卡传输中」；到 `PLAY` 后自动进入观看 |
| 观看者加入时正在 `RESULT` | 显示结果快照（结果列表 + 分数） |
| 目标掉线 | 自动切下一个；无目标显示空状态 |
| 目标进结果房间 | 目标从列表移除；自动切下一个 |
| 目标换关 | 观看端加载新关；加载失败显示错误并保留上一关画面 |
| 目标死亡重生 | 相机吸附；**不重载关卡**（物件本就不同步） |
| 关卡 JSON 请求失败/超时 | 显示「关卡数据获取失败」；可手动重试；重试仍失败则标记该关不可用 |
| 玩家缺少某关 | 该玩家本地跳过该关，继续下一关；不全局删关 |
| 作者掉线导致关卡数据丢失 | 房主用 `level_cache` 兜底；仍无则该关不可用，缺的人跳过 |
| 观看者掉线 | 房主清理订阅；目标停止发送；玩家列表更新 |
| 房主掉线 | 现有逻辑全员断开；观看者也回标题并提示 |
| 观看者人数过多 | 受 ENet 20 连接上限约束；超出时加入失败并 `Notice` |
| 观看者尝试玩家 RPC | 房主拒绝并记录警告 |
| 恶意超长 `level_file_name` / payload | 校验文件名与大小，拒绝并断开 |

---

## 15. 测试计划

### 15.1 手工测试矩阵

| # | 场景 | 步骤 | 期望 |
| --- | --- | --- | --- |
| 1 | 0 玩家 | 房主选观看，无其他玩家 | 开始按钮 disabled |
| 2 | 房主观看 | 房主观看 + 1 玩家 | 能开始；房主看到编辑截图 → 游玩幽灵 → 结果 |
| 3 | 大厅观看 | 2 玩家 + 1 观看，游戏中加入 | 观看者出现在列表；不参与准备；可发言 |
| 4 | 编辑中途加入 | 编辑阶段加入 | 看到目标编辑器截图；左右切换 |
| 5 | 传输中途加入 | 传输阶段加入 | 看到进度/等待；开玩后自动进入游玩观看 |
| 6 | 游玩中途加入 | 游玩阶段加入 | 加载目标当前关卡；位置跟随；切关跟随 |
| 7 | 结果中途加入 | 结果阶段加入 | 看到结果快照 |
| 8 | 早完赛 | 1 人先打完所有关卡 | 自动进入 `spectate_room` 观看；结果就绪后切到结果页 |
| 9 | 目标异常 | 目标掉线 / 通关 / 换关 | 自动切换/加载/空状态 |
| 10 | 房主观看推进 | 房主观看，玩家编辑中 | 房主可提前结束编辑；可强制继续/推进 |
| 11 | 多人观看 | 3 个观看者同时看 1 个编辑器 | 目标只发送给订阅者；带宽可接受 |
| 12 | 断线重连 | 观看者退出再以观看加入 | 重新拉 snapshot；正常观看 |

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

验收：无 `push_error`、无「玩家列表分母错误」、无「关卡数据为空」、观看者不进入玩家场景。

---

## 16. 分阶段实施

| 阶段 | 内容 | 验收 |
| --- | --- | --- |
| P0 | 角色字段、服务端校验、`players` 过滤、0 玩家禁用开始、聊天、房间 UI 标签 | 观看者加入不破坏现有 3 人流程；0 玩家不能开始 |
| P1 | 阶段机 + snapshot + 独立观看场景骨架（等待面板） | 中途加入能看到正确阶段；房主观看可推进 |
| P2 | 游玩观看：关卡加载、幽灵、相机、左右切换、状态表 | 目标换关跟随；掉线/通关自动切换 |
| P3 | 编辑截图流（订阅、抓屏、JPEG、降频） | 3 个观看者同时看 1 个编辑器；目标空闲停发 |
| P4 | 早完赛自动观看、结果快照、结算过滤、异常收尾 | 早完赛进入观看层；结果就绪收起；统计正确 |
| P5 | 测试脚本、压测、i18n、文档 | `mp_test.ps1` 观看用例通过 |

---

## 17. 现状核对（其他 AI 已改，需兼容）

| 改动 | 对本需求的影响 |
| --- | --- |
| 新增 `Notice` autoload（`script/ui/notice_manager.gd`） | 加入被拒、连接失败统一用 `Notice.show_notice`；旧的 `GameInProgressHint` 已删除 |
| `multiplayer_manager.gd` 新增端口校验、连接超时、`_restore_lobby_page` / `_show_player_page` | 观看加入失败也要退回正确页面；不要破坏这些分支 |
| `MessageOverlay` 取代 `MessageSidebar` | 观看者发言直接复用；观看场景不要重复实例化 |
| `MpTestBoot` 自动命名/自动开始/三实例 | 测试要区分玩家/观看者；`_auto_start` 不能把观看者算进 `expect` |
| `game_in_progress_hint.gd` 删除 | 不要再引用该节点/脚本 |
| `tools/mp_test.ps1` | 新增观看实例参数与日志断言 |

---

## 18. 已确认与默认值

已确认：

- 游玩观看方案 A（只传坐标/动画，不传截图）。
- 编辑器观看方案 C（只抓关卡画布，480×360 / 4fps / JPEG 65）。
- 早完赛进入 `spectate_room` 观看等待，结果就绪后统一切结果页。
- 房主侧流程抽取到 `MPManager` / `GameFlow`。
- 目标死亡重生**不重载关卡**，只吸附相机。
- 掉线重连宽限期 **20s**。
- 缺失关卡的玩家**本地跳过该关**，`random_levels` 保持全员一致，不全局删关。
- 观看者获得**全量关卡**：清单 + 目标当前关优先 + 其余后台预取。
- 关卡缓存沿用现有 `user://mfmp_*.lvl` 目录，后续可反复游玩。

默认值（后续可做成设置项）：

- 观看者不单独预留连接名额，沿用 ENet 上限 20。
- 编辑器画布 480×360 / 4fps / JPEG 65。

---

## 19. 关卡分发与掉线重连鲁棒性

> **2026-11-09 更新**：工程已重构为服务化架构（`NetPeer / SessionRegistry / LobbyService / LevelTransferService / MatchFlowService / ChatService`）。本节 19.1–19.11 保留为最初的设计目标；**实际落点与本次已完成的代码见 19.12**。`LevelTransferService` 已实现分块上传、SHA-256、45s 超时与主机中继，原 R0/R1 已基本完成。

### 19.1 现状问题

| 问题 | 位置 | 后果 |
| --- | --- | --- |
| 本地关卡无效时静默 `return` | `level_sender_node.gd:15-18` | 房主永远等不到，全房间卡死 |
| 等待循环无上限 | `level_sender_node.gd:37-51`、`56-67` | 少一个包就无限等 |
| 缺关卡被当成掉线踢掉 | `lets_play_together.gd:12-16` | 作者掉线/数据缺失时直接删人删关 |
| 全量广播 N×N | `multiplayer_manager.gd:449-484` | 大关卡 + 多人时 reliable 通道拥塞 |
| 无校验/无重试 | `transfer_level_data` / `level_receiver_node.gd` | 截断/损坏的 JSON 直接写盘 |
| 掉线立即删除玩家 | `multiplayer_manager.gd:368-398` | 重连是新 peer id，身份/关卡/统计全丢 |
| `level_data` 存在 `players` 字典 | `multiplayer_manager.gd:731-759`、`reach_end_notifier.gd:40-42` | 每次同步都可能重发大字符串；结算时被清空 |
| 结果页一次性 RPC | `store_level_results` | 晚加入/重连看不到 |
| 观看者没有关卡分发 | 仅停留在计划 | 切到另一关只能干等 |

**根因**：把关卡二进制当成玩家字典的字段。必须先拆成独立的 `level_cache`，再谈分块、重连、观看分发。

### 19.2 目标协议：房主中心 + 分块 + 校验

```text
玩家A --upload_meta/chunk/finish--> 房主 level_cache
玩家B --upload_meta/chunk/finish--> 房主
房主 --level_manifest(清单)--> 玩家 + 观看者
玩家/观看者 --request_level(file_name)--> 房主
房主 --level_chunk(file_name, index)--> 请求者
请求者 --chunk_ack(file_name, index)--> 房主
```

| 参数 | 建议值 | 说明 |
| --- | --- | --- |
| chunk 大小 | 16 KB | 5 MB 关卡约 320 块 |
| ACK | 每块 | 收到 `chunk_ack` 才发下一块，或窗口 4 块 |
| 超时 | 2s / 块 | 超时重发，最多 3 次 |
| 单关截止 | 30s | 超过标记 `available=false` |
| 阶段截止 | 60–90s | 到点用可用关卡开局，不无限等 |
| 压缩 | DEFLATE | 沿用现有 `compress/decompress_dynamic` |
| 校验 | CRC32（压缩字节） | 收到先比对 CRC，再解压 |
| 解压上限 | 32 MB | 防止压缩炸弹 |
| 格式校验 | JSON parse + 必需字段 | `tilemap_data` / `object_data` / `version` |

### 19.3 数据结构

```gdscript
# 房主
var level_cache: Dictionary = {}       # file_name -> JSON String
var level_meta: Dictionary = {}        # file_name -> {crc32, raw_size, compressed_size, owner_device_id, available}
var upload_sessions: Dictionary = {}   # upload_id -> {file_name, chunks, received_mask}
var delivery: Dictionary = {}          # peer_id -> {file_name: acked_chunk_mask}
var player_registry: Dictionary = {}   # device_id -> 持久玩家记录
var last_results: Array = []

# 客户端
var local_levels: Dictionary = {}      # file_name -> {json, crc32, path}
```

`players` 字典只保留轻量字段：`level_file_name`、`level_ready`、`level_crc`、`current_level`、`reach_end`、`is_spectator`、`connected`。**不再放 `level_data`**。

### 19.4 上传与分发流程

1. 玩家保存关卡（编辑房间按钮或倒计时保存）：
   - 写本地 `user://mfmp_*.lvl`（现有目录）；
   - 同时后台向房主上传（`upload_meta/chunk/finish`）。
2. 房主收到后：解压、CRC、JSON parse、写 `level_cache` 与 `level_meta`；可选落盘同一 `user://` 目录。
3. 房主广播 `level_manifest`（file_name / owner / size / crc / available）。
4. 玩家/观看者按清单请求缺失关卡；房主按 `level_chunk` 分块下发。
5. 请求者收齐后 ACK，房主标记该 peer 的该关已交付。
6. 房主根据 `level_cache` 生成 `random_levels`；**只包含房主可用的关卡**。
7. 阶段截止时仍有缺失：
   - 房主有、某个玩家没有：该玩家**本地跳过**该关（见 19.5）；
   - 房主也没有：该关不进 `random_levels`（全局都没有，没人能玩）。

> 不建议再让玩家把整包广播给所有人。房主中心化后上传是 N 份、分发按需，且房主可以校验一次。

### 19.5 缺失关卡：缺的人本地跳过

语义：

- `random_levels` 是全员一致的数组。
- 每个玩家的 `current_level_count` 是本地独立的。
- 玩家在加载/进入下一关前检查：

```gdscript
func _ensure_level_available() -> bool:
    while MPManager.current_level_count < MPManager.total_levels:
        var file_name: String = MPManager.random_levels[MPManager.current_level_count]
        if FileAccess.file_exists(file_name):
            return true
        Log.w("缺少关卡，跳过：%s" % file_name)
        MPManager.report_player_status.rpc_id(1, MPManager.current_level_count + 1, false)
        MPManager.current_level_count += 1
    return false
```

- 如果返回 `false`：该玩家已无可用关卡，直接进结果房间（`reach_end`）。
- 跳过不增加 `level_pass_count`，也不记死亡；只是该玩家没玩这一关。
- 观看者缺少某关：向房主请求；仍失败则显示「该关卡数据不可用」，允许切到别的目标，不影响玩家。
- 房主不能因为某个玩家缺关而删关；`random_levels` 不变。

### 19.6 掉线重连（宽限 20s）

身份：

- 用 `device_id` 做持久键，peer id 只作为当前连接标识。
- 房主维护 `player_registry[device_id]`，包含 `name / is_spectator / level_file_name / level_crc / current_level / reach_end / lives / stats / connected / last_seen_msec`。

掉线：

- `_on_peer_disconnected` 不立即删人；`connected=false`，启动 **20s** 宽限计时。
- UI 显示「重连中…」；连接名额保留（避免被新玩家占满）。
- 20s 内重连：按 `device_id` 找回记录，更新 peer id，发 `reconnect_snapshot`。
- 20s 后：标记 `abandoned`；如果关卡已上传，**仍保留在 `random_levels`**；如果还没上传且还在 EDIT，则从玩家列表移除。

重连快照：

```gdscript
{
    "phase": int,
    "deadline_msec": int,
    "random_levels": Array,
    "manifest": Array,
    "missing_levels": Array,
    "player_record": Dictionary,   # current_level/lives/stats/reach_end
    "results": Array,              # RESULT 阶段
}
```

各阶段：

| 阶段 | 重连行为 | 关卡 |
| --- | --- | --- |
| `EDIT` | 回编辑器；进程重启则加载本地自动保存 | 不需要分发；重新上传 |
| `TRANSFER` | 回传输房间；补上传/拉缺失 | 清单 + 缺失块 |
| `PLAY` | 回当前关起点，恢复 `current_level/lives/score`；位置不恢复 | **当前关优先**，其余后台拉 |
| `RESULT` | 直接看结果页 | 不需要 |
| `reach_end` 后 | 只能观看/看结果 | 不需要 |

补充：

- **编辑器自动保存**：每 5–10 秒（或命令防抖）写本地 `user://editor_autosave/`；纯网络掉线时内存状态直接继续。
- **重连位置**：游玩阶段不做位置同步，重连从当前关起点复活；如果后续要更友好，可低频记录最后位置，但只作参考。
- **身份校验**：`device_id + name`；如需更严，房主首次加入发 `session_token`，重连时带上。
- **房主掉线**：本方案不做房主迁移；现有逻辑全员断开，观看者也回标题。

### 19.7 观看者全量关卡分发

| 对象 | 分发内容 | 时机 |
| --- | --- | --- |
| 玩家 | 清单 + 全部关卡 | 上传后按需拉齐，开玩前必须齐 |
| 观看者（PLAY） | 清单 + **全量关卡**（目标当前关优先） | 加入先拉目标关，其余后台预取 |
| 观看者（EDIT） | 不需要关卡 | 只收截图 |
| 早完赛玩家 | 本地已有全部关卡文件 | 直接读 |
| 重连玩家 | 清单 + 当前关优先 + 其余后台 | 进入快照后开始 |

- 预取限速/限并发（一次 1 关），不要和玩家开玩前的拉取抢带宽。
- 切换目标：
  - 同一关：不加载；
  - 不同关且已预取：直接加载；
  - 不同关未预取：请求 + 加载动画；
  - 目标死亡：不重载；
  - 目标进下一关：加载下一关（换地图，不是同步物件）。
- 房主缓存缺该关：`level_unavailable`，观看端显示不可用。

### 19.8 结果页内容分发

- 房主保存 `last_results`（含每个玩家的 `clear_rate/score/level_pass_count` 和 `level_results` 每关通过/死亡数）。
- 新增 `result_snapshot`：加入/重连/主动请求时下发；`store_level_results` 做成**幂等**，可重复调用。
- 观看者、早完赛玩家、重连玩家都能看结果页；`result_list` 过滤观看者，可额外显示「观看人数」。
- 截图：`RandomCaptureManager` 目前按 `player_id` 存；改为按 `device_id` 或 `level_file_name`，取不到时显示占位图「无截图」。
- `reach_end_notifier` 不再清 `level_data`（已经没有这个字段）；结果页数据由 `last_results` 提供。
- 「一起回标题」仍由房主控制；观看者只能退出房间。

### 19.9 代码改造清单

| 文件 | 改动 |
| --- | --- |
| `script/multiplayer/0_core/multiplayer_manager.gd` | `level_cache/level_meta`；上传/清单/分块/ACK RPC；`player_registry`；`last_results`/`result_snapshot`；`players` 只留轻量字段 |
| `script/edit/save_and_load/save_level.gd` | 保存后写 `level_cache` 并触发后台上传；不再写 `player.level_data` |
| `script/multiplayer/4_level_transfer_room/level_sender_node.gd` | 从 `level_cache` 取本地关卡；上传/等待改为协议驱动，带超时 |
| `script/multiplayer/4_level_transfer_room/level_receiver_node.gd` | 从 `level_cache` 写 `user://mfmp_*.lvl`；按 file_name 去重；CRC 校验 |
| `script/multiplayer/4_level_transfer_room/lets_play_together.gd` | 从房主缓存/清单生成 `random_levels`；缺关不踢人 |
| `script/multiplayer/4_level_transfer_room/level_transfer_progress_label.gd` | 显示清单/分块/重试进度；分母只数非观看玩家 |
| `script/edit/save_and_load/load_level.gd` | 进入关卡前检查文件存在；缺失则本地跳过 |
| `script/multiplayer/5_play/play_next_level_manager.gd` | 下一关同样做可用性检查；跳过时上报状态 |
| `script/multiplayer/6_result/reach_end_notifier.gd` | 不再清 `level_data`；结果计算后写 `last_results` |
| `script/multiplayer/6_result/result_list.gd` | 截图按 `device_id`/file_name 取，取不到用占位图 |
| `script/debug/mp_test_flags.gd` / `mp_test_boot.gd` / `tools/mp_test.ps1` | 增加掉线/重连/缺关/大关卡的测试参数与断言 |

### 19.10 测试矩阵

| 场景 | 期望 |
| --- | --- |
| 传输中 1 人数据无效 | 30s 后该关标记不可用；其余人正常开局；缺的人跳过 |
| 传输中 1 人掉线（已上传） | 保留关卡；20s 内可重连；不卡流程 |
| 传输中 1 人掉线（未上传） | 20s 后该关不可用；其余人开局 |
| 分块丢包/截断 | ACK 超时重发；CRC 不符重试；最终失败则标记不可用 |
| 20 人 / 5MB 关卡 | 有进度、有超时、内存可控 |
| 游玩中断线重连 | 回到当前关起点，恢复关卡/命数/分数 |
| 结果页晚加入 | `result_snapshot` 能看到完整成绩 |
| 观看者中途加入 | 先拿目标当前关，再后台预取；切关有加载态 |
| 房主观看 | 仍能收关卡、生成清单、推进阶段 |
| 版本不一致 | 明确提示，不进入游玩；观看者仍可看截图 |

### 19.11 分阶段实施

| 阶段 | 内容 | 验收 |
| --- | --- | --- |
| R0 | `level_data` 拆到 `level_cache`；`players` 轻量化；CRC；同目录写盘 | 现有流程不回归；玩家字典不再有大 JSON |
| R1 | 房主中心上传 + 清单 + 分块 + ACK + 超时回退 | 缺一关不会卡死；到点可用关卡开局 |
| R2 | 提前上传 + 进度 UI + 缺失关卡本地跳过 | 传输房间等待下降；缺关者能跳过 |
| R3 | 20s 重连注册表 + 各阶段快照 | 编辑/传输/游玩/结果掉线重连都能回 |
| R4 | 观看者全量关卡 + 后台预取 + 结果快照 | 中途加入观看者能切关；晚加入能看结果 |
| R5 | 编辑器自动保存 + 版本校验 + 压测 | 进程崩溃可恢复；20 人/大关卡不超时 |

### 19.12 服务化重构后的实际落点（2026-11-09）

#### 已由重构完成

| 能力 | 实际实现 |
| --- | --- |
| 阶段机 | `RoomPhase` + `MatchFlowService`；主机权威，客户端只跟随 `s2c_phase_changed` |
| 玩家资料 | `PlayerProfile`；关卡 JSON 正文不再进玩家字典，只保留 `level_file_name / has_level / level_ok` |
| 关卡上传 | 客户端 `c2s_level_begin/chunk/end` 分块（32KB）上传到主机 |
| 完整性 | SHA-256 校验；`MAX_LEVEL_SIZE = 16MB`；路径白名单；原子写盘 |
| 超时 | `TRANSFER_TIMEOUT_MSEC = 45000` |
| 主机中继 | 主机收齐后 `s2c_level_begin/chunk/end` 分块下发 |
| 结果缓存 | `MatchFlowService.last_results`；结果场景 `_ready` 补读 |
| 幽灵缓存 | `GhostCacheService` 12Hz 录制，按关卡存 `user://ghosts/` |
| 协议版本 | `NetPeer.PROTOCOL_VERSION` |

#### 本次已落地

| 文件 | 改动 |
| --- | --- |
| `player_profile.gd` | 新增 `is_spectator / connected / abandoned / disconnected_at_msec / level_failed / missing_levels / current_level / is_in_result`，并纳入 wire / reset |
| `lobby_service.gd` | 观看角色加入；任意阶段允许观看；同 `device_id + 同名` 的 **20s 重连**；掉线不立即删人；`playing_profiles()/playing_count()`；准备/编辑完成过滤观看者；0 玩家禁止开始 |
| `level_transfer_service.gd` | 房主观看跳过本机关卡；观看者不提交关卡；中继不阻塞观看者；接收失败只记 `missing_levels`，不再踢作者；缺关/超时标记 `level_failed` 不踢人；`relay_all_to()` 给中途加入/重连者补全量关卡；PLAY 阶段允许补发 |
| `match_flow_service.gd` | 关卡列表/分数/结算过滤观看者；`s2c_sync_phase_to()` 补发当前阶段；PLAY 载荷带 `current_level`；观看者切到 `spectate_room`；`report_current_level()`；**房主权威编辑计时 `HostEditTimer`（5.5s 准备 + edit_seconds）**；RESULT 阶段所有人切结果页 |
| `multiplayer_manager.gd` | 观看角色贯穿 join；意外掉线 **20s 自动重连**（`net.join` 循环）；`_cleanup_session` 保留观看身份 |
| `load_level.gd` | 缺关本地跳过；全部缺关则 `notify_reach_end` + 进入观看/结果；新增 `report_progress` 开关，观看重演关卡不再上报进度 |
| `play_next_level_manager.gd` | 换关上报 `current_level`；打完最后一关先 `notify_reach_end`，再进入 `spectate_room` 等待结果 |
| `object_map_layer.gd` | 新增 `spawn_player`；观看视图不生成可操作玩家、不创建 InputHandler |
| `multiplayer_ani_sprite_manager.gd` | 新增 `spectate_mode`（观看视图只收不发）与 `get_ghost()`；幽灵槽位按游玩玩家数创建 |
| `game_start.gd` | 开始按钮：非房主隐藏、0 游玩玩家禁用 |
| `host_button.gd` / `join_button.gd` + `role_toggle_button.gd` | 运行时注入「参与模式」一行：Label + 角色按钮（显示当前角色，点击切换）；`--mp-spectate` 测试开关 |
| `player_list.gd` + `ui/list/player_list.tscn` | 矩形角色按钮（绿「游戏」/ 蓝「观看」，固定 140×44，白字黑边、主题字体）；仅本地玩家可点击切换，准备后禁用；不再在名字后拼「（观看）」 |
| `ready_button.gd` / `edit_ready_button.gd` / `level_transfer_progress_label.gd` | 观看者隐藏准备按钮、分母只数玩家 |
| `script/spectator/spectate_room.gd` + `room/spectate_room.tscn` | PLAY 实际画面：实例化裁剪后的 `play_room_base`，加载目标当前关卡、显示幽灵、`LevelCamera` 跟随目标；左右键切换目标；目标换关重建；左上信息栏只显示「正在观看 / 玩家名 / 关卡进度 / x/y」，无描边、不随目标改色；EDIT 阶段把进度替换为「编辑中」，用 `Hud/EditorView` 显示目标的关卡画布截图；TRANSFER 仍显示中央传输提示；紫色 `psc.png` 视差背景 + `game_border.png` 边框；关卡边框使用目标玩家色；目标幽灵不透明、其他半透明 |
| `script/multiplayer/0_core/services/editor_stream_service.gd` + `script/spectator/editor_streamer.gd` | EDIT 观看截图流：稳定 RPC 节点、主机订阅表、目标端订阅者集合、480×360 / JPEG 65 / 4fps、定向 `rpc_id`；只抓 `SubViewport`，无订阅者不抓屏 |
| `tools/spectate_demo.tscn` / `tools/spectate_demo.gd` | 前端演示场景：两张演示关卡、四个假目标（两关各两人）；1/2/3 切换 PLAY/EDIT/TRANSFER，←/→ 切换目标；可输出 `tools/spectate_demo*.png` |
| `mp_test_boot.gd` / `mp_test_flags.gd` | 观看实例不自动准备；`--mp-expect` 只数玩家；`--mp-spectate` |

#### 已验证

- 1 主机玩家 + 1 玩家 + 1 观看者（headless）：
  - 观看者加入不被踢；
  - `spectate_room` 依次进入 `EDIT → TRANSFER → PLAY → RESULT`；
  - 观看者收到两关 `level cached`；
  - 主机 `transfer complete players=2`，观看者不阻塞；
  - 结果正常进入 `RESULT count=2`。
- 玩家硬掉线后用同名同 `device_id` 重连：主机日志出现「等待玩家 test2 在 20 秒内重连」→「玩家 test2 已重连」。
- 观看视图探针（`tools/spectate_shot.tscn`）：`spectate_room` 成功加载关卡（`LevelManager Level loaded`），截图可见地形、HUD、目标信息。
- 编辑器观看双窗口实测：
  - 客户端观看者看房主编辑器：`tools/editor_spectate.png`，关卡画布正常显示，边框为主机玩家色；
  - 房主观看者看客户端编辑器：`tools/editor_spectate_host.png`，关卡画布正常显示，边框为客户端玩家色；
  - 两侧日志均出现「关卡画布绑定成功」与「观看者 X 订阅玩家 Y 的编辑器」，无 RPC/节点错误。
- 房主观看 + 1 名玩家：`HostEditTimer` 到点后正常 `transfer complete players=1`，随后进入 PLAY；不再卡在编辑阶段。
- 早完赛：`play_next_level_manager` 在最后一关先 `notify_reach_end`，再切 `spectate_room`；不再停在「等待其他玩家」文案。

#### 仍待完成

1. **结果页晚加入快照**：当前 `s2c_sync_phase_to` 已带 `results`，需要实测中途加入 RESULT 的观看者能看到完整结果。
2. **缺关本地跳过**：已接 `load_level`，还需要在 `play_next_level_manager` 的「最后一关缺失」路径补一次验证。
3. **编辑器自动保存**：进程崩溃恢复。
4. **20 人/大关卡压测**：分块并发、超时回退、重连风暴。
6. **聊天**：观看者发言已复用 `MessageOverlay`，需在观看场景验证按钮可见性。
7. **观看画面细节**：目标标签高亮、目标死亡/重生的提示、多观看者带宽；PLAY 观看端是本地重演，敌人/机关状态不同步（方案 A 的已知限制）。

#### 已知噪音（非本次引入）

- Headless 下 `RandomCapture` 报 `Parameter "t" is null`（无渲染目标），实机不存在。
- 编辑房间加载空关卡时 `Level has no content.`，属于新关卡首次加载的既有日志。
- 退出时 `ObjectDB instances leaked / resources still in use` 为工程既有退出噪音。

---

## 20. 前端演示场景

直接运行 `tools/spectate_demo.tscn`（F6）即可预览观看界面，不依赖联机：

- 自动生成两张演示关卡：`user://spectate_demo.lvl` 和 `user://spectate_demo_2.lvl`；
- 四个假目标：「演示玩家」「演示玩家2」在关卡 0，「演示玩家3」「演示玩家4」在关卡 1；
- 紫色 `psc.png` 视差背景 + `game_border.png` 边框 + 左上信息栏 + 等待面板；
- `1` 游玩、`2` 编辑、`3` 传输；`← / →` 切换目标，目标在另一关时会自动加载另一张地图，**关卡边框**会跟着目标玩家色变化；左上信息栏保持固定样式；
- 可选参数：
  - `-- --demo-phase=edit|transfer` 启动时直接看等待界面；
  - `-- --demo-shot` 3 秒后截图到 `tools/spectate_demo*.png` 并退出；
  - `-- --demo-switch` 启动 1 秒后模拟一次右键，验证目标切换/边框颜色切换；
  - `-- --demo-switch-level` 连按两次右键，切到关卡 1 的「演示玩家3」，验证跨场景加载。

生成的效果图：

- `tools/spectate_demo.png`：关卡 0 画面 + 目标幽灵 + HUD；
- `tools/spectate_demo_level2.png`：切到关卡 1 的「演示玩家3」，进度 `2/2`，边框变为该玩家色；
- `tools/spectate_demo_edit.png`：EDIT 界面，左上角显示「编辑中」，屏幕中央无说明，保留紫色背景与边框。

> 演示场景不连网，所以 EDIT 阶段只演示「编辑中」布局，不会出现编辑器画布；真实编辑器画布见 9.7 的双窗口截图。
