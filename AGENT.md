# AGENT.md

面向 AI Agent 的工程说明，重点是 `tools/` 下的测试脚本：怎么跑、结果看哪里、什么算通过、踩过哪些坑。

工程是 Godot 4.6 的 GDScript 项目（`MF: MP`，多人马里奥制造，无 C# 脚本），测试脚本只用于本地验证，不属于游戏运行时逻辑。

> 最后核对：2026-11-10（本地 Godot 4.7.2 实测命令可用；CI 导出仍用 4.6.1）

---

## 1. 运行环境

| 项 | 值 |
| --- | --- |
| 工程根 | `d:\Windows\GreenSweet\Game\Tasks\Mario Forever\Mario Forever Party：King Designer\mario-forever-party--king-designer` |
| Godot（本地首选） | `D:\Windows\GreenSweet\Game\Software\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe` |
| 主场景 | `room/title.tscn` |
| 结果目录 | `tools/`（`*_result.txt` / `*.png` / `mp_test_logs/`；本地验证产物，除非用户要求留档，不要主动提交） |

- 本地跑无头测试用 **console 版**（无控制台版也能跑，但拿不到 stdout）；截图脚本用窗口版可执行文件，**不能加 `--headless`**。
- 工程已有 `.godot/` 导入缓存。新拉仓库或新增素材后先跑一次
  `--headless --path "<工程根>" --import`，否则 `load()` 可能拿不到贴图。
- 命令行运行任意场景（会覆盖主场景）：
  `Godot --headless --path "<工程根>" res://tools/xxx.tscn`

### 1.1 无头运行的 PowerShell 模板

不要直接用 `& $Godot ... | Out-String`，长时间无输出容易被判卡死；用 `Start-Process` + 重定向 + 超时：

```powershell
$Godot   = "D:\Windows\GreenSweet\Game\Software\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe"
$Project = "d:\Windows\GreenSweet\Game\Tasks\Mario Forever\Mario Forever Party：King Designer\mario-forever-party--king-designer"
$Scene   = "res://tools/adventure_probe.tscn"
$Out     = Join-Path $env:TEMP "mfmp_probe_out.txt"
$Err     = Join-Path $env:TEMP "mfmp_probe_err.txt"

$p = Start-Process -FilePath $Godot -PassThru -NoNewWindow `
    -ArgumentList "--headless --path `"$Project`" $Scene" `
    -RedirectStandardOutput $Out -RedirectStandardError $Err
if (-not $p.WaitForExit(180000)) {
    Stop-Process -Id $p.Id -Force
    throw "probe timeout"
}
Get-Content -LiteralPath $Out -Encoding UTF8
Get-Content -LiteralPath $Err -Encoding UTF8
```

要点：

- `--path` 的值必须自己带引号（工程路径含空格），否则 Godot 报 `Invalid project path`。
- 读取日志必须显式 `-Encoding UTF8`。
- 绝大多数探针几十秒内自己 `get_tree().quit()`；`WaitForExit` 返回后即可读结果文件。例外见 4.4（`adventure_start_probe` 会切场景继续跑）。

---

## 2. 验证铁律与实现约束

1. **断言看结果文件，不看 stdout、不看退出码。**
   探针统一用 `FileAccess` 把 `key=value` 写进 `res://tools/*_result.txt`；无头下 `print` 可能丢，退出时的引擎报错也不代表业务失败。
2. **截图脚本必须窗口化运行。**
   `--headless` 使用 dummy 渲染，`get_viewport().get_texture().get_image()` 拿不到有效画面；截图脚本一律不加 `--headless`。
3. **不要用 `--check-only` 验证脚本。**
   它不会实例化 autoload，`Log`、`MpTest`、`Adventure`、`MPManager` 等全局标识符会全部报 "not present on the inferred type Node"；只能参考纯类型错误，不能作为通过依据。
4. **直接跑探针/场景时，退出码和清理日志是噪音。**
   无头退出常见 `ObjectDB instances were leaked at exit`、`resources still in use at exit`、`找不到进程标识符`（进程已提前退出时 `Stop-Process` 报的），只要结果文件正确就不算失败。
5. **禁止在脚本里直接手写前端，UI 必须落地为场景节点。**
   不要用 `Control.new()` / `Label.new()` 之类在 `_ready()` 里搭界面；新增或改造的 UI 一律保存为 `.tscn`（节点树、样式、文本、信号连接都在场景文件里），脚本只负责数据绑定、动画与交互逻辑。调试用的一次性状态条可以例外，但也应尽量做成场景。已有的代码搭 UI 逐步迁移，新代码不再新增。
6. **用户没让你 commit，就不要 commit。**
   改完就停在工作区，把改了哪些文件、为什么改、怎么验证的写清楚交给用户，由用户决定什么时候提交。
   同理，**也不要主动 push、不要主动建分支、合并、rebase、回滚或 amend**——这些动作一旦发生就难以撤销，一并交给用户指令。
   （提交信息的格式规范见 2.1，那是"用户要求提交时"才知道该照什么写，不是"可以自己提交"的许可。）

### 2.1 提交信息（commit message）规范

summary 必须是 **前缀 + 冒号 + 内容**，并且 **summary 与 body 全程使用英文**：不留中文、全角标点（，。：（）——）或其他非 ASCII 字符。

```text
feat(input): three direction groups for sticks, arrow keys and IJKL
fix(edit): WASD moves only the camera while arrow keys drive the UI
chore(multiplayer): drop unused signaling fallback
```

- 前缀 = 类型，或 `类型(范围)`。允许的类型：`feat` / `fix` / `refactor` / `perf` / `style` / `docs` / `chore` / `test`。
- 冒号后一个空格再写内容；summary 不以句号结尾，尽量不超过 72 字符。
- 范围可选，用简短名词，如 `ui` / `input` / `multiplayer` / `adventure` / `title`。
- body 与 summary 之间空一行，同样只用英文，分段落写动机、方案与影响；引用代码标识符可直接用反引号。
- 检查办法：`git --no-pager log -1 --pretty=%s` 应能匹配 `^[a-z]+(\([a-z0-9-]+\))?: .+`，且 `git log -1 --pretty=%B` 无中文。

---

## 3. 测试脚本总览

### 3.1 无头断言探针（probe）

| 场景 | 验证内容 | 结果文件 |
| --- | --- | --- |
| `tools/adventure_probe.tscn` | 百人团关卡池构建、4 档分档、抽取、单人统计读写 | `tools/adventure_probe_result.txt` |
| `tools/adventure_state_probe.tscn` | 一局内的通过 / 死亡 / 软跳过 / 硬跳过与命数、结算 | `tools/adventure_state_probe_result.txt` |
| `tools/adventure_resume_probe.tscn` | 断点续跑：通过一关后检测续跑、恢复索引与关卡路径 | `tools/adventure_resume_probe_result.txt` |
| `tools/adventure_slots_probe.tscn` | 5 个存档位：旧 `[run]` 迁移、开团占位、满位拒绝、按槽续团、放弃腾位 | `tools/adventure_slots_probe_result.txt` |
| `tools/adventure_start_probe.tscn` | 开局参数校验 + 切到 `Adventure.PLAY_SCENE` | `tools/adventure_start_probe_result.txt` |
| `tools/adventure_play_probe.tscn` | 真正加载游玩场景，检查 `player` 组、`run_active`、`run_index` | `tools/adventure_play_probe_result.txt` |
| `tools/adventure_mobile_pause_probe.tscn` | 检查百人团暂停键（默认桌面，加 `--probe-mobile` 伪装 Android）能显示、开菜单并用「继续」恢复 | `tools/adventure_mobile_pause_probe_result.txt` |
| `tools/title_pipe_probe.tscn` | 正式标题页的水管菜单：五个目标路径能否解析、点击「组织游戏」能否打开 HostPage | `tools/title_pipe_probe_result.txt` |
| `tools/pipe_menu_probe.tscn` | `ui/title/pipe_menu.tscn` 里五根水管预设的贴图（编辑器里看到的颜色） | `tools/pipe_menu_probe_result.txt` |
| `tools/pipe_diff.tscn` | 水管 SVG 与参考位图的逐像素差异 | `tools/pipe_diff_result.txt` |
| `tools/theme_probe.tscn` | 全局主题 `mfmp_theme.tres` 的 Button / Label / Panel 实效值 | `tools/theme_probe_result.txt` |

`tools/pipe_variant_bake.tscn` 不是探针：改过 `sprite/ui/pipe/warp_pipe.svg` 后跑它，刷新 `variant_*.png` 五色贴图。

### 3.2 截图脚本（shot，需窗口）

| 场景 | 输出 |
| --- | --- |
| `tools/adventure_stage_shot.tscn` | `tools/adventure_stage_loading.png`（0.3s）、`tools/adventure_stage.png`（4.7s）、`..._selected.png`（选中「新存档」）、`..._resume.png`（选中存档1）、`..._endless.png`（选中无尽团存档3） |
| `tools/adventure_play_shot.tscn` | `tools/adventure_play.png`（加载游玩场景 3s 后） |
| `tools/adventure_pause_shot.tscn` | `tools/adventure_pause.png`（打开暂停菜单） |
| `tools/adventure_mobile_pause_shot.tscn` | `tools/adventure_mobile_pause.png`、`tools/adventure_mobile_pause_menu.png`、`..._flip_a/b.png`（默认桌面，鼠标点击暂停键）；加 `--shot-mobile` 伪装 Android 并输出带 `_mobile` 后缀的图 |
| `tools/adventure_transition_shot.tscn` | `tools/adventure_transition.png`（过关过渡动画中） |
| `tools/adventure_button_pv.tscn` | `tools/adventure_button_pv.png`（已采用的 V4 按钮布局单版预览） |
| `tools/title_pipe_shot.tscn` | `tools/title_pipe.png`（1920×1080）、`tools/title_pipe_small.png`（1120×640，顺带验证多分辨率适配） |
| `tools/spectate_shot.tscn` | `tools/spectate.png`（观看视图，读取 `user://` 最新 `.lvl`） |
| `tools/endless_palette_stage_shot.tscn` | `tools/endless_palette_a.png` ~ `_d.png`（把四套候选配色依次套到真实舞台的无尽团存档卡上，用于挑配色） |

### 3.3 交互演示（人工看）

| 场景 | 说明 |
| --- | --- |
| `tools/adventure_button_pv.tscn` | 已采用的 V4 按钮布局单版预览，`S` 截图 |
| `tools/spectate_demo.tscn` | 无联机的观看界面演示，`1/2/3` 切 PLAY/EDIT/TRANSFER，`←/→` 切目标 |

### 3.4 联机三实例

| 入口 | 说明 |
| --- | --- |
| `tools\mp_test.bat` / `tools\mp_test.ps1` | 本机 3 实例（host + 2 clients）联机测试，见第 7 节 |

---

## 4. 无头探针逐个说明

所有探针都使用 1.1 的无头模板，只需把 `$Scene` 换成下面对应的场景；跑完会自己退出，结果写到 `res://tools/*_result.txt`。判据是“关键行符合预期”，不是“文件存在”。

### 4.1 adventure_probe

验证百人团数据层：关卡池、在线通过/死亡统计、4 档分档、抽取、`AdventureStore` 单人计数（场景 `res://tools/adventure_probe.tscn`）。

正常输出样例（`pool_size` 随本机 `user://` 关卡数变化，不要硬编码）：

```text
pool_size=1310
probe_level=ok
online_pass=3
online_death=9
fingerprint_len=16
sampled=20
counts=[5, 5, 5, 5]
selectable=true
tier3=5
drawn=5
drawn_unique=5
solo_attempt=1
solo_pass=1
solo_skip=1
solo_death=0
```

关键判据：`probe_level=ok`、`sampled=20`、`counts=[5, 5, 5, 5]`、`tier3=5`、`drawn=5`、`drawn_unique=5`、`solo_attempt/solo_pass/solo_skip=1`、`solo_death=0`。
探针会写入自建关卡 `user://adventure_probe_level.lvl` 并在结束时清理。

### 4.2 adventure_state_probe

验证单局状态机：初始 10 命（5 关定量团）、每过 2 关 +1 命、死亡 -1、软跳过不扣命、最后一关被硬跳过后补位、打完替补关才结算。

关键判据：

```text
start=true
initial_lives=10
after_pass_1=10
after_pass_2_lives=11
cleared=2
after_death_lives=10
after_skip_soft_soft=1
after_pass_3_lives=10
last_slot_number=5
last_skip_running=true
last_skip_index_same=true
last_skip_replaced=true
last_skip_key_exists=true
finished=true
summary_result=completed
summary_cleared=4
summary_skipped_hard=1
```

`last_skip_replaced=true` 是「最后一关永久排除后换一关补位」的核心判据：序号不变、关卡 key 变了、团仍在进行。

命数经济或结算规则改动后，这里要同步更新期望值再跑。

### 4.3 adventure_resume_probe

验证断点续跑：通过一关 → `_check_resume()` → `resume_run()`。

```text
start=true
index_after_pass=1
cleared_after_pass=1
resume_available=true
resume_ok=true
resume_index=1
resume_path_exists=true
```

`resume_key` 是具体关卡文件名，不固定；只校验 `resume_path_exists=true`。

### 4.3.1 adventure_slots_probe

验证 5 个存档位（`[run.1]` … `[run.5]`）：

```text
migrate_ok=true
migrate_cleared=true
opened=5
used=5
full=true
resume_available=true
slots=5
valid=5
sixth_blocked=true
sixth_error=存档位已满（5/5），请先继续其中一个团并结算或放弃
used_after_block=5
resume_slot3=true
resume_slot=3
resume_index=0
resume_keys=5
used_after_abandon=4
slot3_cleared=true
start_after_abandon=true
used_after_start_again=5
new_slot=3
```

关键判据：`migrate_ok=true`（旧单团存档搬到槽 1）、`full=true`、`sixth_blocked=true`、
`valid=5`、`slot3_cleared=true`、`new_slot=3`（放弃后空出的槽被新团复用）。
探针用 `user://adventure_slots_probe.ini`，结束时清理；不会碰玩家的 `adventure.ini`。

### 4.4 adventure_start_probe

只验证开局参数与第一关路径，然后切换到游玩场景。**这个探针在 `start=true` 时不会自己 `quit()`**：它调用 `GlobalTransition.change_scene_to_file(Adventure.PLAY_SCENE)` 后继续运行。所以要么在命令里加 `--quit-after <帧数>`，要么看到结果文件写入后手动结束进程；无头帧率不稳定，以结果文件出现为准，不要按秒估算。

```text
start=true
error=
key=<关卡文件名>
path=user://<关卡文件名>
exists=true
```

`start=true` 且 `error=` 为空、`exists=true` 即通过。结果文件在切换场景前就已写好，不依赖进程退出。该探针没有清理 `user://adventure_probe_play.ini`，单独跑完可手动删除（`adventure_play_probe` 会清理同名文件）。

### 4.5 adventure_play_probe

加载真实游玩场景，4 秒后检查：

```text
start=true
error=
key=<关卡文件名>
path=user://<关卡文件名>
path_exists=true
player_found=true
run_active=true
run_index=0
```

`path_exists`、`player_found`、`run_active` 应全为 `true`；`run_index` 是当前关序号（首关通常为 0），不固定写死。`player_found` 来自 `get_tree().get_first_node_in_group("player")`，若为 `false`，先确认 `room/adventure_play.tscn` 的玩家实例化路径是否改了，而不是直接怀疑 `Adventure` 数据层。

### 4.7 adventure_mobile_pause_probe

默认按真实桌面平台加载百人团游玩场景；加 `--probe-mobile` 才伪装 Android（手机端已单独验证通过）：

```text
expect_mobile=false
platform_name=Windows
is_mobile=false
is_desktop=true
emulate_touch_from_mouse=false
emulate_mouse_from_touch=true
start=true
layer_found=true
button_found=true
button_visible=true
pause_layer_count=1
menu_found=true
paused_after_open=true
menu_visible_after_open=true
border_found=true
panel_found=true
panel_size=(1320.0, 1000.0)
border_size=(1320.0, 1000.0)
panel_size_matches_border=true
continue_ok=true
paused_after_close=false
is_mobile_after_clear=false
emulate_touch_after_clear=false
```

手机模式对应 `expect_mobile=true`、`platform_name=Android`、`is_mobile=true`、`is_desktop=false`、`emulate_touch_from_mouse=true`，其余关键行相同。暂停键不再按平台隐藏，`button_visible=true` 在两种模式下都必须成立。

暂停菜单 UI 是 `object/ui/adventure_pause_menu.tscn`（`room/adventure_play.tscn` 里实例化），脚本 `script/adventure/adventure_pause_menu.gd` 只做翻转与菜单动作。面板尺寸取 `GameRoomSize/SubViewportContainer/Node2D/GameBorderTextureRect` 的全局矩形，因此 `panel_size` 必须与 `border_size`（默认 1320×1000）完全一致，不能退回成 SubViewportContainer 的 1280×928。

翻转是真实透视而不是横向缩放：卡片放在 `CardViewport`（SubViewport）里，翻转期间用 `MeshInstance2D` + `shader/adventure_pause_flip.gdshader` 对 32×32 细分网格逐顶点做 Y 轴旋转 + 透视投影，正面采样关卡 SubViewport 贴图并叠 `sprite/game_border.png`，背面采样卡片贴图；正反面由同一个 `yaw` uniform 在着色器内切换（≤90° 正面、>90° 背面并把 UV.x 翻回来），不会出现换面滞后。动画结束隐藏网格、显示 `CardContainer`（SubViewportContainer）恢复按钮交互。注意 `SubViewportContainer` 隐藏时子视口可能停更，翻转期间必须保持容器可见，用 `modulate.a = 0` + `mouse_filter = IGNORE` 代替隐藏。

正面贴图必须按 SubViewport 实际尺寸映射到边框内框（`inner_min` / `inner_size` uniform），不能铺满整块装饰边框——铺满会把关卡放大，翻转时视口会盖住外框。

翻转姿态每次打开暂停时随机：翻转方向、pitch、roll、上抛高度、透视距离都在固定范围内取值，同一轮关闭沿用这套参数；总角度固定 180°，否则卡片落不平。

整体缩放跟着 `sin(π·eased)` 走：开始/结束时 `scale = 1.0`，时间中点降到 `0.8`（`MID_SCALE`），再回到 1.0。截图结果里的 `flip_a_scale` 可以核对中间帧是否在 0.8~1.0 之间。

`paused_after_open` / `continue_ok` / `paused_after_close` 是核心三项。`is_mobile_after_clear=false`、`emulate_touch_after_clear=false` 用来确认伪装可以撤销（在 Windows 上跑）。

伪装成 Android/iOS 时会自动打开两个输入模拟开关，退出伪装时还原：

- `Input.set_emulate_touch_from_mouse(true)`：桌面鼠标点击变成 `InputEventScreenTouch`，虚拟按键（TouchScreenButton / FingerInputHolder）才能用鼠标操作；
- `Input.set_emulate_mouse_from_touch(true)`：触摸再转回鼠标，普通 Button 照常响应。

截图脚本默认就是桌面模式（加 `--shot-mobile` 才伪装 Android）：桌面下不模拟触摸，鼠标直接命中普通 Button。结果里的 `mouse_opened=true` 即表示点击链路生效；手动注入 `InputEventMouseButton` 时必须带 `button_mask`，否则 Control 的按钮掩码判定不通过。

伪装平台的三种入口（`PlatformUtils`）：

| 方式 | 写法 | 生效时机 |
| --- | --- | --- |
| 引擎参数 | `--fake-platform=android`（放在 `--` 之前） | autoload `_ready` 就能读到 |
| 用户参数 | `-- --fake-platform=android` | 同上，`OS.get_cmdline_user_args()` 也认 |
| 脚本内 | `PlatformUtils.set_debug_platform("Android")` | 只影响调用之后的代码 |

需要虚拟按键一起出现时，**必须用命令行参数**：`OnScreenControls` 在 autoload `_ready` 里读平台，脚本内设置已经太晚。仅验证暂停键时三种都行（按钮在游玩场景 `_ready` 才创建）。

---

## 5. 截图脚本

统一跑法（去掉 `--headless`，其余同 1.1 模板）：

```powershell
$p = Start-Process -FilePath $Godot -PassThru `
    -ArgumentList "--path `"$Project`" res://tools/title_pipe_shot.tscn"
$p.WaitForExit(120000)
```

- `adventure_stage_shot.tscn`：0.3s 截加载界面，4.7s 截舞台正式画面，随后依次截「选中新存档」「选中存档1（定量团）」「选中存档3（无尽团，彩色卡面）」；五张图都会覆盖。存档3 种子为 `mode: "endless"`，用来确认无尽存档卡的滚动彩色卡面。
- `adventure_play_shot.tscn`：先 `Adventure.start_run()` 再加载 `Adventure.PLAY_SCENE`，3s 后隐藏 `AdventurePauseMenu` 截图；依赖 `user://` 里有可用的 `.lvl` 关卡池。
- `adventure_pause_shot.tscn`：2s 后打开暂停菜单截图，退出前会 `get_tree().paused = false`。
- `adventure_transition_shot.tscn`：2s 后触发 `play_transition("pass", "res://room/title.tscn")`，0.5s 时截过渡层。
- `adventure_button_pv.tscn`：V4 按钮布局单版预览，窗口设为 1920×1080，首帧后自动导出 `tools/adventure_button_pv.png`；加 `--pv-shot` 导出后退出。
- `title_pipe_shot.tscn`：加载 `room/title.tscn`，2.5s 后截 1920×1080；再把窗口缩到 1120×640 截第二张，用于确认水管菜单在缩放窗口下仍贴底居中。截图前会把鼠标挪到角落，避免 hover 把管口道具顶出来。
- `spectate_shot.tscn`：从 `user://` 找最新、且大于 128 字节的 `.lvl`，加载 `room/spectate_room.tscn`，3s 后截 `tools/spectate.png`。没有可用 `.lvl` 时 `push_error` 后直接退出，不出图。

截图脚本的判据：**PNG 文件时间戳更新且不是全黑/全白**。Agent 可以直接用 `read_file` 打开 PNG 看布局、颜色、文字。

---

## 6. 交互演示

### 6.1 adventure_button_pv

已采用的 V4 按钮布局单版预览：`tools/adventure_button_pv.tscn`。
脚本内画布按 1920×1080 设计并自动缩放，`S` 截图；其余三套按钮布局与四套整体 UI 方案均已废除。

### 6.2 spectate_demo

无联机依赖的观看演示：`tools/spectate_demo.tscn`。
自动生成两张演示关卡（`user://spectate_demo.lvl`、`user://spectate_demo_2.lvl`），四个假幽灵分处两关。

可选启动参数（`--` 之后）：

| 参数 | 作用 |
| --- | --- |
| `--demo-phase=edit` / `--demo-phase=transfer` | 启动直接进入等待界面 |
| `--demo-shot` | 3 秒后截图到 `tools/spectate_demo*.png` 并退出 |
| `--demo-switch` | 1 秒后模拟一次右键，验证目标切换 |
| `--demo-switch-level` | 连按两次右键，验证跨关卡加载 |

例：

```powershell
$p = Start-Process -FilePath $Godot -PassThru `
    -ArgumentList "--path `"$Project`" res://tools/spectate_demo.tscn -- --demo-shot"
$p.WaitForExit(60000)
```

`--demo-shot` 的落图规则：PLAY → `spectate_demo.png`；EDIT → `spectate_demo_edit.png`；TRANSFER → `spectate_demo_transfer.png`；切到第 2 关 → `spectate_demo_level2.png`。

---

## 7. 联机三实例测试

入口：`tools\mp_test.bat`（内部调 `tools/mp_test.ps1`，优先 `pwsh`，没有则 `powershell`）。

### 7.1 常用命令

```powershell
tools\mp_test.bat                 # human：3 个窗口，人工准备 + 开局
tools\mp_test.bat auto            # 无头自动：大厅冒烟（连上 -> 准备 -> 开局 -> 退出）
tools\mp_test.bat auto -Full      # 全链路：编辑 -> 传输 -> 游玩 -> 结算 -> 退出
tools\mp_test.bat auto -ShowWindows   # 自动流程但保留窗口，便于观察
tools\mp_test.bat human -Pads 0,1,2   # 三个手柄各控一个实例
tools\mp_test.bat -Stop           # 杀掉带 --mp-role= 的测试实例
```

`auto` 模式：3 个实例全部 `--headless`，自动准备、自动开局、按标记等待、打印 PASS/FAIL，退出码 0/1。
`human` 模式：窗口平铺，脚本只负责把 host/join 按下去；之后人工在每个窗口点“准备完毕”，在 host 点“开始”。

### 7.2 判定标记

`auto` 通过日志标记判 PASS（日志行带 `[MPTEST]` 前缀）：

- `host listening`：主机已在端口监听
- `joined`：两个客户端都连上
- `all players ready`：3 人准备完毕、主机已点开始
- `-Full` 追加：`transfer complete` → `phase PLAY` → `phase RESULT` → `quit after result`
- 非 `-Full`：`quit after game_start`

日志在 `tools/mp_test_logs/test1.log`（host）、`test2.log`、`test3.log`。脚本每次启动会先 `Stop-TestInstances`、删除旧日志；`tools/mp_test_logs/` 已被 `.gitignore` 忽略。

### 7.3 启动参数（ps1）

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `-Mode human\|auto` | `human` | 也可作为第一个位置参数：`tools\mp_test.bat auto` |
| `-Port` | `8914` | 主机端口，被占用时 `auto` 直接 FAIL |
| `-Ip` | `127.0.0.1` | 客户端连接地址 |
| `-WinSize` | `640x360` | 三个窗口平铺尺寸，格式 `宽x高` |
| `-Pads` | 空 | 必须正好 3 个设备号，如 `0,1,2` |
| `-GodotPath` | 空 | 显式指定 Godot；不填时按 `GODOT_BIN` → 4.7.2 mono（无头时优先 console 版）→ 4.7.2 stable → PATH 的 `godot` 顺序找 |
| `-ShowWindows` | 关 | `auto` 模式保留窗口 |
| `-KeepRunning` | 关 | 结束后不杀实例，便于排查 |
| `-Stop` | 关 | 只杀测试实例并退出 |
| `-Full` | 关 | 全链路自动测试 |

### 7.4 实例参数（`--` 之后）

| 参数 | 说明 |
| --- | --- |
| `--mp-role=host\|join` | 角色；`MpTestBoot` 只在 host/join 时自动操作标题页 |
| `--mp-name=<名>` | 玩家名；三名必须不同（关卡文件名含玩家名） |
| `--mp-slot=1\|2\|3` | 仅用于命名 test1/2/3 |
| `--mp-ip` / `--mp-port` | 加入地址 / 端口 |
| `--mp-win=宽x高+x+y` | 窗口尺寸与位置，无头忽略 |
| `--mp-pad=<设备号>` | 只接受该手柄设备；会重写 8 个输入动作的手柄事件 device |
| `--mp-no-ready-timeout` | 关闭“失焦 10s / 无输入 20s 自动取消准备” |
| `--mp-auto-ready` | 连上后自动准备，之后每 3s 补一次 |
| `--mp-auto-start` | 主机等满 `--mp-expect` 人且全准备后自动开始 |
| `--mp-expect=<人数>` | 期望玩家人数，默认 3 |
| `--mp-edit-seconds=<秒>` | 覆盖大厅编辑时限滑条（10~300） |
| `--mp-auto-exit` | 开局后 8s 退出；配合 `--mp-auto-finish` 改为等结算 |
| `--mp-auto-finish` | 自动完成编辑、自动 `notify_reach_end()`，配合 `-Full` 使用 |
| `--mp-spectate` | 观看身份（不准备、不供关）；与 `--mp-role` 一起用 |
| `--mp-join-retries=<次>` | 加入重试次数，默认 40（每次间隔 1s） |

### 7.5 编辑器多实例（人工）

`Debug → Customize Run Instances` 设 3 个实例后直接 F5，**不需要任何参数**：

- 每个实例抢 `127.0.0.1:39731~39733` 回环端口，抢到第几个就叫 `test1/test2/test3`；
- 只有同时存在 2 个以上实例才生效，单个 F5 会恢复原玩家名；
- 也可以给每个实例填 `--mp-slot=1|2|3` 强制命名。

### 7.6 注意事项

- 三个实例同机时，键盘事件只发给当前焦点窗口；要三人同时玩必须用 3 个手柄（`-Pads 0,1,2`）或分机。
- 玩家名重复会导致关卡文件重名（`user://mfmp_<时间>_<玩家名>_<id>.lvl`）。
- 残留实例会占端口，跑之前先 `-Stop`；`auto` 发现端口占用会直接失败。
- 修改联机代码后最低回归：`auto`；提交前：`auto -Full`。

---

## 8. 新增测试脚本的写法

放在 `tools/`，场景根节点挂脚本，`_ready()` 里跑完调用 `get_tree().quit()`。无头探针模板：

```gdscript
extends Node

## 无头探针：验证 XXX。运行：
##   Godot --headless --path . res://tools/xxx_probe.tscn

const OUTPUT: String = "res://tools/xxx_probe_result.txt"

func _ready() -> void:
	var lines: Array[String] = []
	# ... 执行验证，追加 "key=value"
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	get_tree().quit()
```

配套 `.tscn`：

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/xxx_probe.gd" id="1_probe"]

[node name="XxxProbe" type="Node"]
script = ExtResource("1_probe")
```

规则：

- **结果一律写文件**，用 `res://tools/xxx_probe_result.txt`；不要只 `print`。
- **清理自己创建的 `user://` 临时文件**（`AdventureStore` 的 `.ini`、演示 `.lvl` 等），尤其不要碰真实的 `user://adventure.ini`、`liked courses` 等玩家数据。
- **GDScript 警告是错误**：`project.godot` 把 `untyped_declaration`、`inferred_declaration`、`unsafe_*` 等设为 2（错误）。所有变量显式写类型；探针里必须做 unsafe 调用时，文件头加：
  `@warning_ignore_start("unsafe_cast", "unsafe_call_argument")`
- 新增 `.gd` 后让 Godot 编辑器导入生成 `.uid`，不要手写 `uid://`。
- 场景文件名、脚本名、结果文件名保持一一对应，方便后续 Agent 查找。
- 异步逻辑（`await`、计时器）要留足等待时间，并在结果文件里写阶段标记，便于判断卡在哪一步。
- 需要渲染/截图的脚本不要加 `--headless`，并优先用 `get_viewport().get_texture().get_image()`。

---

## 9. 已知噪音与排查

| 现象 | 处理 |
| --- | --- |
| 退出时 `ObjectDB instances were leaked at exit` / `resources still in use at exit` | 引擎清理顺序，忽略 |
| `Stop-Process: 找不到进程标识符` | 进程已自己退出，忽略；用 `$p.WaitForExit()` 判断结束 |
| `--check-only` 报一堆 `Identifier not found: Log/MpTest` | 已知假错误，不要用 `--check-only` 验证 |
| 探针无输出、进程长时间不退 | 先看 stderr 是否脚本 parse error；再确认 `_ready` 是否卡在 `await`；最后加 `WaitForExit` 超时 |
| `auto` 报 `host did not report listening within 45s` | 端口被占（先 `-Stop`）、Godot 路径不对、或主场景初始化报错；看 `tools/mp_test_logs/test1.log` |
| 截图全黑/空 | 加了 `--headless`，或窗口还没渲染完就截图 |
| `spectate_shot` 不出图 | `user://` 没有大于 128 字节的 `.lvl`，先造一关或跑一次联机 |
| 联机三人准备不了 | 没加 `--mp-no-ready-timeout` 时，失焦 10s / 无输入 20s 会自动取消准备 |

---

## 10. 相关文档

- `docs/raid_mode/README.md`：百人团（adventure；正式名「随心挑战 / Challenge」，本阶段不改名）模式设计与规则，探针里的数值期望以它为准。
- `docs/ui/README.md`：UI 主题体系——全局 `mfmp_theme.tres`（内置 Panel + 白字黑描边）与 `ui/theme/theme_yellow_top.tres`（黄色顶块 + 深色无描边）的取值、字体 fallback 约定，改界面配色前先看它。
- `docs/spectator_mode/README.md`：观看模式、演示场景参数、已实测截图。
- `docs/multiplayer_refactor_plan.md`：联机架构分期与每阶段验收命令（`mp_test.bat auto` / `auto -Full`）。
- `script/debug/mp_test_flags.gd`、`script/debug/mp_test_boot.gd`：联机测试参数与自动流程的唯一实现，参数含义以文件头注释为准。
