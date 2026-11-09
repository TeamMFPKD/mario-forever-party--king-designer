# 快捷消息系统（SMM2 风格）

参考《超级马力欧创作家 2》的快捷聊天：常驻侧栏已移除，改为「全屏快捷用语面板 + 左下角消息气泡」。

## 参考图

快捷用语面板（顶部 4 列 × 6 行的半透明圆角按钮，其余区域点击关闭）：

灰色底板紧贴屏幕上边缘（左 / 右 / 上三边都是满宽，只有下边缘留圆角），高度由代码按按钮网格的最小高度 + 上下留白（32 / 40）自动撑开，所以加删用语导致行数变化时底板会跟着长高，始终包住全部按钮。

![快捷用语面板](ref_smm2_quick_panel.png)

消息气泡（左下角：头像 + 气泡上方的玩家名 + 白色气泡内的消息文本）：

![消息气泡](ref_smm2_message_bubble.png)

## 交互流程

1. 点击屏幕右侧的消息按钮 → 全屏面板淡入，顶部展示 21 条快捷用语（4 列 × 6 行，按钮高 76）。
2. 面板打开期间游戏不暂停，但玩家操作被临时屏蔽（键盘 + 手柄）；遮罩覆盖整个屏幕。
3. 点击空白区域 → 面板淡出、玩家操作恢复。
4. 点击某条用语 → 该按钮变黄并保持到消息展示结束（约 2.3 秒），面板关闭并发送；左下角气泡从下方滑入弹出（头像 + 玩家名 + 文本），停留约 2 秒后向左滑出并淡出。
5. 发送后进入约 2.3 秒冷却，冷却期间 21 个按钮变暗且点击无效（自己的气泡淡出前无法再次发送）；此时再次打开面板，按钮上方会居中盖一层「正在发送消息中……」，冷却结束自动消失。
6. 同时到达的消息直接堆叠显示，最多 8 条；超出时最早的一条淡出。

## 系统消息（玩家离开 / 与主机断开）

- `MultiplayerPlayerLeft` 仍负责监听玩家列表变化与断线事件，但不再自己弹独立提示；
- 统一调用 `MessageOverlay.show_system_message(text)`，与快捷消息共用同一套滑入、2 秒停留、淡出和 8 条上限，两种消息可以混排堆叠；
- 外观保持原来的纯文字样式（25 号白字 + 黑色描边，无头像、无白色底板），气泡高度 40。

## 实现结构

| 文件 | 作用 |
| --- | --- |
| `object/multiplayer/message_system/message_overlay.tscn` | autoload（`MessageOverlay`）：入口按钮、全屏遮罩、快捷用语网格、气泡层、音频节点 |
| `script/multiplayer/message_system/message_overlay.gd` | 面板开关、CD、消息分发、气泡堆叠布局 |
| `object/multiplayer/message_system/quick_message_button.tscn` | 半透明圆角快捷用语按钮 |
| `object/multiplayer/message_system/message_bubble.tscn` | 单条消息气泡 |
| `script/multiplayer/message_system/message_bubble.gd` | 气泡滑入 / 淡出动画 |
| `script/multiplayer/message_system/player_input_blocker.gd` | 面板期间的玩家输入屏蔽（临时移除 InputMap 事件） |
| `script/multiplayer/message_system/quick_message_table.gd` | 21 条用语的翻译 key 表 |
| `script/multiplayer/0_core/multiplayer_player_left_manager.gd` | 玩家离开 / 断线事件 → 转交 `MessageOverlay.show_system_message()` |

数据与本地化：

- 联机只同步用语序号（`MSG_QUICK_01` … `MSG_QUICK_21`），各端按自己的语言渲染。
- 文本配置在 `i18n/mfmp_translation.csv`（en / zh_CN / ja）。

参数（`message_overlay.gd`）：

- `MAX_BUBBLES = 8`：气泡上限，超出时最早的淡出。
- `SEND_COOLDOWN = 2.3`：发送冷却，对应气泡展示 2.0s + 淡出 0.3s。
- `BUBBLE_MARGIN_LEFT / BOTTOM`：气泡距屏幕左边 / 下边距离。

## 音效

音效来自 SMM2 romfs 导出，命名规则：英文 + `MM2_` 前缀，统一放在 `res://sound/`。

| 文件 | 用途 | 触发 |
| --- | --- | --- |
| `MM2_MultiPlayMessage_Pop.wav` | 消息弹出 | 气泡出现时（同时发出 `message_popped` 信号） |
| `MM2_MultiPlayMessage_In.wav` | 消息列表进场 / 面板开关 | 打开与关闭快捷用语面板共用这一个音效（发送时关闭不播放，避免与 Enter 叠音） |
| `MM2_MultiPlayMessage_Enter.wav` | 发送确认 | 点击某条用语发送 |
| `MM2_MultiPlayMessage_Cursor.wav` | 光标移动 | 鼠标移入某条用语按钮 |

音效节点都在 `message_overlay.tscn`：`MessageSound` / `MsgOpen` / `MsgClose` / `MsgEnter` / `MsgCursor`。
系统消息（玩家离开 / 断线）保持原来的无声提示。

## 头像

气泡左侧是头像槽：头像本体仍是 84×84 的圆形，外面再套一圈 8 像素的玩家身份色圆环（槽位整体 100×100，头像尺寸不变）。显示顺序：

1. 按玩家同步过来的 `avatar_id` 从内置头像库取贴图；
2. 取不到（旧消息、素材缺失）时回退到玩家名首字。

圆形效果由 `shader/avatar_circle.gdshader` 把头像 `TextureRect` 裁成圆形，所以素材只要画在正方形里即可，画到圆外也不会溢出。

### 玩家身份色

头像外圈与消息气泡描边共用一套身份色，按玩家在房间名单里的位置（也就是玩家列表里的 1P / 2P …）分配：

| 位置 | 1P | 2P | 3P | 4P | 5P | 6P | 7P | 8P | 9P 起 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 颜色 | 白 | 红 | 绿 | 蓝 | 橙 | 青 | 黄 | 紫 | 回到红，7 色循环 |

- 位置是各端一致的确定信息，所以颜色完全由本地计算（`PlayerColor.for_index()` / `MPManager.player_color()`），**不进网络包**；
- 有人进出房间时名单顺序会变，颜色随位置重新排（这是位置分配的必然结果）；
- 头像槽的场景结构都一样：`Ring(Panel)` 铺满整个槽位当彩色圆底，头像本体（白底圆 + 贴图 / 名字首字）内缩后居中，露出来的一圈就是身份色；
- 已应用的位置：玩家列表每行（48 + 6）、头像选择器预览（84 + 8）、消息气泡（84 + 8）、结算页每行名字左侧（64 + 8，结算数据里的 `avatar_id` 由 `PlayerProfile.to_result_dict()` 下发）。

### 内置头像（不开放用户上传）

| 文件 | 作用 |
| --- | --- |
| `sprite/avatar/avatar_pack.tres` | 头像清单：把 PNG 拖进 `textures` 数组就等于内置一个头像 |
| `script/multiplayer/avatar/avatar_pack.gd` | 清单资源定义（`AvatarPack`） |
| `script/multiplayer/avatar/avatar_library.gd` | autoload `Avatars`，把清单读成「id → 贴图」查表 |
| `script/multiplayer/avatar/player_color.gd` | `PlayerColor`：身份色色表（1P 白，2P 起红绿蓝橙青黄紫循环） |
| `script/multiplayer/avatar/avatar_ring.gd` | `AvatarRing`：把头像槽里的 `Ring(Panel)` 染成玩家色（消息气泡与玩家列表共用） |
| `object/multiplayer/avatar/avatar_selector.tscn` | 头像选择器 `(<) 头像预览 (>)` |
| `script/multiplayer/avatar/avatar_selector.gd` | 选择器逻辑 |

新增头像的步骤：

1. 准备正方形 PNG（现有占位素材是 84×84，正好等于气泡里的显示尺寸，1:1 显示不会有缩放锯齿）；
2. 放进 `sprite/avatar/`；
3. 打开 `sprite/avatar/avatar_pack.tres`，把 PNG 拖进 `textures` 数组，**追加到末尾**。

约定：

- 头像 id 由数组序号决定（`avatar_00`、`avatar_01`……）。联机只同步这个 id，各端用自己那份清单还原贴图，所以改了素材要一起更新；
- 插在数组中间会让已保存的玩家选择整体后移，新增请追加到末尾；
- **素材改名 / 删除后要同步从数组里移除**：`.tres` 里残留旧路径会让整份清单解析失败（早先表现为选择器只剩 `?`、左右不可切换）。`Avatars` 已带文本兜底，清单解析失败时会按文本里的路径重新读一遍，跳过失效项，日志里会打 `按文本兜底加载 N 个头像`；
- 选中结果保存在 `user://game_settings.cfg` 的 `network/avatar_id`，同时写进 `MPManager.player["avatar_id"]` 随玩家信息同步；
- 快捷消息会带上发送者的 `avatar_id`，气泡据此显示头像。

### 选择入口

标题界面「组织游戏」「加入游戏」两个页面里，玩家名称下方各有一个头像选择器：

```
(<)  头像预览  (>)
```

左右按钮循环切换；两份选择器共用 `MPManager.player["avatar_id"]`，页面重新显示时会自动同步。玩家列表每行也会显示对应头像。

## 封存内容

旧的常驻侧栏（`message_sidebar.tscn`）、自定义消息输入（`message_sender.gd`）、消息记录落盘（`message_cache.gd`）与历史列表渲染（`message_creator.gd`）均保留在工程中但不再加载，作为日后恢复的参考。
