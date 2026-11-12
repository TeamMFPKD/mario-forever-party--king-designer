# 百人团（打团）模式设计方案

> 状态：v0.6（2026-11-12）
> v0.1：数据层 + 通过率 + 4 档 + 排除 + 联机先验。
> v0.2：拍板 4 项核心决策；补充专属入口/舞台场景、命数经济、HUD、跳过本关、关卡过渡动画。
> v0.3：跳过拆成"永久排除/仅本次"两种；两种都不扣命；无尽团固定档位但成员实时重算；无尽 HUD 显示命数；每通过 2 关 +1 命；定量团关数 5–50（10–100 命）。
> v0.4：命数总上限 100；无尽团抽空降档、所有关卡玩过则重置轮次继续；通过率改为 `pass / attempt`（进入关卡先记一次失败，跳关计入分母）；定量团也享受每 2 关 +1。
> v0.5：联机 pass/death 改回存 `.lvl`（恢复每个客户端写本地关卡文件）；`adventure.ini` 只存单人/百人团数据；两套统计彻底分开。
> v0.6：游玩 HUD 改为左侧关卡信息面板（沿用 history play 右侧信息卡的视觉），命数固定放面板顶部、图标用 mario_small walk 一帧；新增 `solo_skip_soft` 只统计软跳过。
> 标记约定：**[已拍板]** = 你已确认；**[待拍板]** = 仍需确认；**[建议]** = 我给出的默认答案；**[风险]** = 实现时容易踩的坑。

---

## 0. 一句话结论

把每个 `.lvl` 关卡当成"可统计的题库"：

1. **联机通过率**写进关卡文件 `.lvl` 的 `pass_count/death_count`；**单人/百人团通过率**写进 `user://adventure.ini`；两套数据分开；
2. 用玩家自己的战绩把关卡动态划进 **4 个难度档**（联机数据只做先验）；
3. 标题页新增「百人团」入口，进入一个类似《马里奥制造 1》百人团的**舞台场景**，在那里选数据源 / 难度 / 流程；
4. 定量团：初始命数 = 关数 × 2，抽 N 关连续打；无尽团：初始 30 命，显示命数 + 已通过关数；
5. 每过一关播放一段短过渡动画；打不过的关可以当场「本关不可通过」跳过；
6. 样本不够时锁掉档位选择，只允许随机抽；
7. 永远打不过的关卡可以永久排除，排除记录也写进 `adventure.ini`。

---

## 1. 已确认的需求

| # | 需求 | 设计落点 |
| --- | --- | --- |
| 1 | 联机通过率和个人单机通过率分开存储 | 联机 `pass_count/death_count` 存 `.lvl`（该关全体玩家合计，所有客户端写本地文件）；单人/百人团 `solo_*` 存 `adventure.ini` |
| 2 | 关卡池由玩家选：所有关卡 / 喜欢的关卡 | `[settings].pool_source` + `PoolBuilder` |
| 3 | 样本不足时不能选难度，只能随机抽 | 样本门槛 + 档位禁用 + 随机模式 |
| 4 | 无解关卡可排除，记录在配置里 | `[level.<key>].excluded` |
| 5 | 4 档难度，由自己游玩动态调整 | 个人分位分档 + 在线先验 + 每次团结束重算 |
| 6 | 百人团有专门入口：标题画面新增按钮 | `room/title.tscn` 的 `ChooseModePanel` |
| 7 | 进入后有类似《马里奥制造 1》百人团的专属舞台场景；SVG 绘制景物；扁的、略倾斜的椭圆表示关卡；背景主题色表示难度 | `room/adventure_stage.tscn` + `sprite/ui/adventure/*.svg` |
| 8 | 玩家在舞台上选数据源、难度、流程（打几关） | 舞台上的设置面板 |
| 9 | 定量团初始命数 = 选择关数 × 2；无尽团初始 30 命 | `[run].lives_total` |
| 10 | 每过一关有简短过渡动画 | `AdventureTransition` 覆盖层 |
| 11 | 跳过分两种：本关不可能通过（永久排除）／我打不过（以后仍会抽到），都不扣命 | 暂停菜单 + `skipped_hard/soft` + `solo_skip` |
| 12 | 专属 HUD：左侧关卡信息面板，顶部固定显示剩余命数（mario small walk 一帧作图标），下方为当前关卡 / 本关死亡 / 通过 / 软跳过，底部一行显示已通过进度与档位 | `object/ui/adventure_level_info.tscn` |

---

## 2. 核心定义（已拍板）

### 2.1 「团」的结构

**[已拍板 2026-11-09]** 单人连续攻关：

- 一次团 = 从池里抽 N 关按顺序打；
- "百人"指池子来自海量玩家关卡、通过率来自海量对局，不要求 100 人同时在线；
- 多人同房间版本放到阶段 3，单独立项。

### 2.2 4 档的定义

**[已拍板 2026-11-09]** **个人分位**：

- 在玩家本次选中的池子里，按个人难度值排序，均分成 4 档；
- 档位边界随玩家水平移动；
- 某一档为空时禁用该档并提示，不硬塞。

### 2.3 联机通过率的作用

**[已拍板 2026-11-09]** **只做先验**：

- 你没打过的关，用联机通过率估计初始难度；
- 联机通过率来自 `.lvl` 的 `pass_count/death_count`（每个客户端本地文件，联机结算写入）；
- 你打得越多，个人数据权重越大；
- 联机样本最多相当于 4 次个人伪尝试。

### 2.4 两种流程

| 流程 | 入口选项 | 关卡来源 | 初始命数 | HUD |
| --- | --- | --- | --- | --- |
| **定量团** | 选「打几关」，范围 5–50，默认 10 | 开局一次性抽 N 关，顺序固定 | `N * 2`（10–100 命） | 左侧面板：命数 + `已通过 c / N` |
| **无尽团** | 选「无尽」 | 每过一关现抽下一关，池子不重复 | `30` | 左侧面板：命数 + `已通过 N 关`（不显示总数） |

- 两种流程共用同一套池子、分档、样本和排除。
- 无尽团没有"总关卡数"概念；当前档抽空、所有关卡玩过后的行为见 7.6。
- **[已拍板]** 无尽团的难度档**固定为开局所选档**，不会自动升档；但档内的关卡成员会随着实时通过率变化而重新计算，见 2.6。
- **[已拍板]** 无尽团 HUD 显示剩余命数，不显示总数。

### 2.5 命数经济（已拍板）

```text
定量团：lives_total = run_length * 2        # 5–50 关 → 10–100 命
无尽团：lives_total = 30
成长：  每通过 2 关 +1 命（两种模式都适用）
```

- 命数是**整团共享**的，不再有"每关 N 条命"。
- 死亡一次扣 1 命，在本关重试；命数归零 → 本团失败。
- 通过不扣命；每累计通过 2 关奖励 1 命（`cleared_count % 2 == 0` 时触发）。
- **两种跳过都不扣命**：
  - 「本关不可能通过」→ 永久排除，以后不再抽到；
  - 「我打不过」→ 只记跳关次数，以后仍会抽到。
- 奖励的命可以超过初始命数（例如 5 关定量团 10 命，全通后 12 命），但**总命数上限 100**：`lives_left = min(lives_left + 1, 100)`。
- 命数不跨团累计；每团重新计算。
- 团模式使用自己的 `[run].lives_left`，**不直接改 `LifeManager.lives`**，避免污染其他模式。

### 2.6 无尽团的"固定档 + 动态成员"

**[已拍板]** 无尽团开局的档位数字（1–4）固定不变，但**档内包含哪些关卡**是动态的：

- 每次要抽下一关之前，用最新样本重算所有关卡的 `d` 和 4 档分布；
- 下一关从"当前仍属于该档、且本团没玩过、未被排除"的关卡里抽；
- 因此一关可能在团进行中从 2 档移动到 3 档，也可能从你选的档里移出去；
- 已玩过的关卡**仍参与分档计算**（否则每次抽关后分位边界都会跳），但不再进入抽取候选；
- 已玩过的关卡不会因为档位变化而重新进入本团；
- 如果当前档的可用关卡被抽空，**允许降档**：3→2→1，弹文字提示「本档已抽空，已降为 X 档」；
- 如果所有档位的可玩关卡都玩过，**不结束**：清空本轮 `cycle_played`、`cycle += 1`，回到开局所选档继续，提示「所有关卡已玩过，开始新一轮」；
- 只有"完全没有可玩关卡"（全部被永久排除 / 文件缺失 / 池子为空）或命数归零才结束。

定量团不做这件事：开局快照固定，运行中不重算，保证同一团的关卡序列稳定、可断点续团。

---

## 3. 术语

| 术语 | 含义 | 代码名 |
| --- | --- | --- |
| 关卡池 Pool | 本次团允许抽取的关卡集合 | `PoolBuilder` |
| 团 Run | 一次完整游玩：有序关卡列表 + 当前进度 + 剩余命数 | `AdventureRun` / `[run]` |
| 定量团 | 固定 N 关的团 | `mode=finite` |
| 无尽团 | 没有固定终点；命数归零或完全没有可玩关卡才结束 | `mode=endless` |
| 样本 Sample | 一次进入关卡的记录（成功/失败/跳过） | `solo_attempt` / `solo_pass` / `solo_skip` |
| 跳过 Skip | 玩家跳过本关（永久排除或仅本次），不通过也不死亡 | `solo_skip` / `skipped_count` / `skipped_soft` / `skipped_hard` |
| 单人样本 solo | 本机玩家在单机流程里的记录 | `[level.<key>].solo_*` |
| 联机样本 online | 该关全体玩家的通过/死亡合计 | `.lvl` 的 `pass_count/death_count` |
| 难度值 d | 由通过率换算的连续值，越大越难 | `TierCalculator` |
| 档位 Tier | 4 个难度档之一，1 最易、4 最难 | `tier` |
| 排除 Excluded | 永久不参与本模式抽取的关卡 | `excluded` |
| 指纹 Fingerprint | 关卡布局的内容哈希，用于检测"同名但内容变了" | `fingerprint` |
| 舞台 Stage | 类似 SMM1 百人团的地图场景 | `adventure_stage.tscn` |

---

## 4. 数据层：`user://adventure.ini`

### 4.1 为什么是 ini，以及和现有文件的边界

- 用 Godot `ConfigFile`，它本身就是 INI 语法，和现有 `GameConfig`（`script/utils/game_config.gd`，文件 `user://game_settings.cfg`）同一套 API。
- 文件用 `user://adventure.ini`，按你的命名；扩展名不影响 `ConfigFile`。
- **联机统计写 `.lvl`**：联机结算把每关的 `pass_count/death_count` 写进每个客户端本地的 `.lvl`（你已拍板）。
- **百人团单机不写 `.lvl`**：单人/百人团的 `solo_*` 只写 `adventure.ini`；玩百人团不会改关卡文件。
- **不往 `game_settings.cfg` 里塞**：那个文件是设置，误删会丢键位/分辨率；`adventure.ini` 误删只丢单人统计，可以放心让玩家备份或删除。
- 不用 JSON：section/key 结构、原子保存、和现有代码风格一致，都更省事。

**现状提醒**：重构后的 `_finish_match()` 只在主机调用 `_write_level_results_to_files()`，客户端不写；而重构前的 `store_level_results` 是 `@rpc("authority", "call_local")`，所有客户端都会写本地 `.lvl`。这次要**恢复客户端写回**，见 4.5。

### 4.2 完整 Schema 示例

```ini
[meta]
schema=1
saved_at="2026-11-09T21:30:00"

[settings]
pool_source="all"          ; all | liked
tier=0                     ; 0=随机，1..4=指定档
mode="finite"              ; finite | endless
run_length=10              ; 定量团关数，5..50
endless_lives=30           ; 无尽团初始命数
prefer_low_sample=true
order="random"             ; random | easy_to_hard

[level.mfmp_2026-11-09_12-00-00_alice_ab12c]
file="mfmp_2026-11-09_12-00-00_alice_ab12c.lvl"
fingerprint="3f9a1c0d7e5b2a48"
generation=0
solo_attempt=8             ; 进入关卡次数；失败 = attempt - pass - skip
solo_pass=2
solo_death=5               ; 仅展示/分析，不直接进公式
solo_skip=0
solo_skip_soft=0           ; solo_skip 的子集：只统计「我打不过」的软跳过
solo_last=1762700000
; 联机 pass_count/death_count 不在这里，存在 .lvl 文件里
excluded=false
exclude_reason=""
excluded_at=0

[run]
active=false
id=""
mode="finite"
seed=0
tier=2                     ; 开局所选档
active_tier=2              ; 当前实际档；无尽团降档后变化
started_at=0
index=0
total_levels=10            ; 无尽团为 -1
lives_total=20             ; 初始命数，不含每 2 关奖励
lives_left=20
lives_cap=100
cleared_count=0
skipped_count=0
skipped_soft=0             ; 「我打不过」跳过次数
skipped_hard=0             ; 「本关不可能通过」跳过次数
cycle=1                    ; 无尽团第几轮（所有关卡玩过后 +1）
cycle_played=[]            ; 当前轮已玩过的 key；新一轮清空
level_keys=[]              ; 本团完整抽取历史，有序
level_fingerprints=[]      ; 与 level_keys 一一对应

[stats]
runs_finite=0
runs_endless=0
runs_completed=0
runs_failed=0
runs_abandoned=0
attempts_total=0
best_endless_cleared=0
endless_total_cleared=0
endless_total_deaths=0
```

说明：

- 每个关卡一个 section：`level.<关卡文件名>`。ConfigFile 里通过 `config.set_value("level." + key, "solo_pass", n)` 写入。
- section 名里不要出现 `]`、换行等会破坏 INI 的字符；关卡文件名由 `validate_filename()` 产生，正常安全。加载时对非法 section 名直接跳过并 `Log.w`。
- 字典值（如 `level_keys`）直接用 ConfigFile 的 Variant 支持，不手写字符串拼接。

### 4.3 字段表

| Section.key | 类型 | 含义 | 谁写 |
| --- | --- | --- | --- |
| `meta.schema` | int | 数据结构版本，用于迁移 | 初始化 |
| `settings.pool_source` | String | 上次选择的池来源 | 舞台设置面板 |
| `settings.tier` | int | 上次选择的档位，0=随机 | 舞台设置面板 |
| `settings.mode` | String | `finite` / `endless` | 舞台设置面板 |
| `settings.run_length` | int | 定量团的关卡数 | 舞台设置面板 |
| `settings.endless_lives` | int | 无尽团初始命数，默认 30 | 舞台设置面板 |
| `level.<key>.file` | String | 当前文件名（key 的冗余副本，便于人工排查） | 扫描/记录 |
| `level.<key>.fingerprint` | String | 布局内容哈希前 16 位 | 扫描 |
| `level.<key>.generation` | int | 内容变更次数；变更时样本清零并 +1 | 记录 |
| `level.<key>.solo_attempt` | int | 本机单人进入关卡的次数；未通过/未跳过的 attempt 即为失败 | 进入关卡 |
| `level.<key>.solo_pass` | int | 本机单人通过次数 | 单人通过 |
| `level.<key>.solo_death` | int | 本机单人死亡次数（仅展示/分析） | 单人死亡 |
| `level.<key>.solo_skip` | int | 本机单人跳过次数（两种跳过都计） | 跳过本关 |
| `level.<key>.solo_skip_soft` | int | 「我打不过」的软跳过次数；`solo_skip` 的子集，用于左侧关卡信息面板 | 跳过本关（B） |
| `level.<key>.solo_last` | int | 最后一次单机样本的 Unix 时间 | 记录 |
| —（不写 ini） | — | 联机通过/死亡读 `.lvl` 的 `pass_count/death_count` | 联机结算 |
| `level.<key>.excluded` | bool | 是否永久排除 | 排除 UI |
| `level.<key>.exclude_reason` | String | `manual` / `unsolvable` / 空 | 排除 UI |
| `level.<key>.excluded_at` | int | 排除时间 | 排除 UI |
| `run.*` | 混合 | 当前团的快照和进度，用于断点续团 | 运行控制器 |
| `stats.*` | int | 累计统计 | 结算 |

### 4.4 关卡身份：key + 指纹

**key = `.lvl` 文件名（含扩展名）**

理由：

- 联机传输、收藏复制、另存为都保留文件名；`mfmp_时间_作者_设备码` 的冲突概率极低。
- `user://` 根目录和 `user://liked courses/` 里的同名文件天然合并成一条统计，不会重复计数。
- 不需要为了建池去解析全部关卡，扫描目录即可。

**fingerprint = 布局内容哈希（前 16 位）**

- 参与哈希的字段：`level_size`、`level_theme`、`tilemap_data`、`object_data`、`pipe_line_data`、`lives`。
- 不参与：`version`、`time_used`、`pass_count`、`death_count`（这些要么是编辑器元数据，要么会被联机结算改写）。
- 规范化：新建一个固定 key 顺序的 Dictionary，再 `JSON.stringify(data, "")`，然后 SHA-256。
- 缓存：用「文件 mtime + 文件大小」做缓存键；没变就不重算哈希。跨机器复制导致 mtime 变化时重算一次，内容相同则哈希相同，统计不丢。
- 指纹变化 = 同名关卡被改过：`generation += 1`，`solo_*` 清零，`Log.w` 记录；`.lvl` 的联机 pass/death 等下一次联机结算覆盖。不要试图把旧单人样本迁移到新版本。

**[风险]** 如果只做文件名、不做指纹，玩家在历史编辑里改了关卡后，旧样本会污染新版本，分档会明显失真。

### 4.5 联机统计存 `.lvl`，单人统计存 `adventure.ini`

**[已拍板 2026-11-09]** 两套统计分开存：

| 数据 | 存哪 | 字段 | 写入者 |
| --- | --- | --- | --- |
| 联机通过/死亡（**全体玩家合计**） | 关卡文件 `.lvl` | `pass_count` / `death_count` | 联机结算时，每个客户端写自己本地的 `.lvl` |
| 单人/百人团（**我自己**） | `adventure.ini` | `solo_attempt/pass/death/skip` | 百人团/单机游玩 |

**联机写入的关键：恢复重构前的"每个客户端都写"**

- 重构前（`3928406` 及以前）：`store_level_results` 是 `@rpc("authority", "call_local")`，主机广播后，主机和所有客户端都执行，各自写本地 `.lvl`。
- 重构后（`8f8f254`）：`_finish_match()` 只在主机调 `_write_level_results_to_files()`，客户端不再写。
- 本次决定：**恢复客户端写回**。在 RESULT 阶段，每个客户端用 `last_results`（需要补 `level_file_name`）写自己的 `.lvl`。

**语义说明（重要）**：

- `.lvl` 是**每个关卡一个文件**，文件名带创建时间 + 作者 + 设备码；派对模式每次都是现做关卡，所以每个文件只对应它被做出来的那一局。
- `pass_count/death_count` 是**这一关全体玩家**的通过/死亡合计：`pass_count` = 所有玩家在这关通过的次数，`death_count` = 所有玩家在这关死亡的次数；不是我个人、也不是跨关卡累计。
- 同一个 `.lvl` 如果被再次游玩（例如手动导入/复用），统计会被这一局覆盖；当前"每局现做"的流程不会发生。
- 百人团单机**不写** `.lvl`；只有联机结算写。
- 历史/收藏卡片显示联机通过率时，读 `.lvl`，标注「联机（本关）」。

**客户端写回需要的改动**：

1. `PlayerProfile.to_result_dict()` 增加 `level_file_name`；
2. `MatchFlowService._apply_result_phase()` 在每个客户端执行，遍历 `results`，找到本地 `.lvl`，写 `pass_count/death_count`；
3. **只写本局有样本的关卡**（`cause_pass + cause_death > 0`）；0/0 不覆盖旧值，避免把"本局没人玩到"的关卡统计清零；
4. 写入用 `.tmp` + rename，失败只 `Log.e`，不影响结算；
5. 主机也走同一条路径（不再单独调 `_write_level_results_to_files()`，或保留它但改成同一实现）。

**风险**：

- 同一个 `.lvl` 被重复游玩时 p/d 会被覆盖；当前"每局现做"流程不会发生。
- 客户端写 `.lvl` 会改变关卡文件；这是你明确接受的行为。百人团单机仍然不写 `.lvl`，两者不冲突。
- 如果作者在结算前掉线，result 里可能没有他的 `level_file_name`，该关本次不写。

### 4.6 写入策略

- **原子写**：`adventure.ini.tmp` → 删除旧文件 → `rename`。沿用 `match_flow_service.gd` 现有的 `.tmp` + rename 写法（Windows 上直接 rename 覆盖会失败，必须先删）。
- **写频率**：死亡/通过/跳过只改内存并置 `dirty`；在「关卡结束、团结束、设置页离开、退出游戏」时落盘。不要每次死亡都写盘。
- **并发**：本机多开（联机测试）会共用 `user://`，两个进程同时写会丢更新。v1 按单实例假设；需要支持多开时，在保存前 `config.load()` 后按 key 合并再写。
- **损坏**：`config.load()` 返回非 OK → 把原文件重命名为 `adventure.ini.bak.<时间戳>`，新建空配置，`Log.e`。不要静默清空。
- **未知字段**：ConfigFile 会保留已加载的未知 section，保存时一并写回；迁移只改已知键。

---

## 5. 通过率与 4 档

### 5.1 两条样本通道与"尝试"口径

| 来源 | 记录点 | 写入字段 | 说明 |
| --- | --- | --- | --- |
| 单人 | 历史/收藏的单机游玩；百人团 | `adventure.ini` 的 `solo_attempt` / `solo_pass` / `solo_skip` / `solo_death` | 每次进入关卡 `attempt+1`；通过 `pass+1`；跳过 `skip+1`；死亡只做展示 |
| 联机 | 现有派对模式结算；未来的联机团 | `.lvl` 的 `pass_count` / `death_count` | **这一关全体玩家**的通过/死亡合计；关卡现做现玩，不跨关累计 |

**划分原则**：按"这一局是否只有你一个人"划分，而不是按"入口场景"。单人团 → `adventure.ini`；联机团/派对 → `.lvl`。

**联机口径**：`.lvl` 只有 pass/death，没有"进入关卡"记录，所以：

```text
online_pass    = .lvl 的 pass_count
online_attempt = .lvl 的 pass_count + .lvl 的 death_count
online_skip    = 0
```

玩家中途退出/掉线不会进 `.lvl`，所以联机通过率会漏掉这部分；这是 `.lvl` 口径的固有限制。

**尝试口径（已拍板）**：

- 关卡**成功加载后**立即 `attempt += 1`；此时先按"未通过"记，等价于一次失败。
- 通过：`pass += 1`，这次 attempt 变成成功。
- 跳过：`skip += 1`，这次 attempt 变成跳过（不算失败，也不算成功）。
- 退出、崩溃、放弃、中途关游戏：attempt 已经记了，但 `pass/skip` 没加，因此自然留在失败里。
- 失败数 `fail = attempt - pass - skip`；死亡数 `death` 单独记，只用于展示和分析，不直接进公式。
- **通过率**：`p = pass / attempt = pass / (pass + fail + skip)`。
- 加载失败（缺文件/JSON 损坏）不算 attempt，避免脏数据。

这条口径保证"进入关卡只要没通关就先算失败"，也让"打不过跳过"和"直接退出"都能被计入分母。

### 5.2 平滑与收缩

设某关：

```text
n = solo_attempt                              # adventure.ini
m = online_attempt                            # .lvl 的 pass_count + death_count

p_solo   = (solo_pass + 1) / (n + 2)          # 拉普拉斯平滑，先验 0.5
p_online = (pass_count + 1) / (m + 2)         # pass_count 来自 .lvl

k = K_MAX * m / (m + M_HALF)                  # K_MAX=4, M_HALF=10
p = (solo_pass + k * p_online) / (n + k)      # n=0 时 p = p_online
```

- `pass` 在分子；`fail` 和 `skip` 都在分母里（因为 `n = attempt = pass + fail + skip`）。
- `+1/+2` 防止「打一次就死」被算成 0%，也防止「一次通过」被算成 100%。
- `k` 是联机先验的"伪尝试次数"：联机样本越多，先验越可信，但最多只值 `K_MAX` 次个人尝试。
- 当你自己打了 10 次以上，个人数据基本主导。
- `solo_death` 不进入这个公式；死亡多但通过次数也多的关卡，通过率仍可能不低，这符合"尝试次数"口径。

### 5.3 难度值

```text
p = clamp(p, 0.02, 0.98)
d = ln((1 - p) / p)
```

- `d` 越大越难；UI 展示时用 `1 - p` 的百分比更直观。
- 用 logit 而不是 `1-p`：50%→80% 和 90%→95% 的体感差距不同，logit 让分档边界更合理。

### 5.4 分档算法（个人分位）

输入：玩家本次选中的池子里，**已采样**的关卡（`solo_attempt + online_attempt > 0`，未排除，文件存在）。

```text
按 d 升序排序（容易 → 困难）
N = 已采样关卡数
for rank in 0..N-1:
    tier = clamp(floor(rank * 4 / N) + 1, 1, 4)
```

- N=16 时正好每档 4 关；N=17 时分布为 5/4/4/4。
- 排序在 `d` 相同时用 `(n + m, key)` 兜底，保证每次打开舞台结果一致。
- 未采样关卡**不参与分档**，但仍可在随机模式里被抽到；抽到并打完后自动进入下一次分档。
- 每次「打开舞台」和「团结束」重算一次；运行中的团只认开局快照。

**动态调整的含义**：你越打，`d` 越准，关卡在 4 档之间移动；你的池子变了（换 all/liked、排除关卡），边界也会重算。这就是"由自己游玩动态调整"。

### 5.5 样本不足与降级

| 门槛 | 默认值 | 不满足时 |
| --- | --- | --- |
| 池内可玩关卡数 `MIN_POOL` | 5 | 不能开局，提示"池子太小" |
| 已采样关卡数 `MIN_SAMPLED` | 16 | 4 个档位全部禁用，只能随机抽 |
| 单档关卡数 `MIN_TIER_LEVELS` | 3 | 该档禁用（灰掉并显示原因） |
| 定量团关数 > 该档关卡数 | — | 本次团缩短到该档实际数量，至少 3 关；或提示换档 |
| 单关尝试数（`attempt`）< 2 | — | 标记"低置信"，仍参与分档，UI 显示 `?` |

- `MIN_SAMPLED = 16` 的理由：4 档 × 每档 4 关，保证每档至少能凑一小团。常量集中放在 `TierCalculator` 里，便于调整；也可以写进 `[settings]` 做高级选项。
- 随机模式**永远可用**（只要池子 ≥ `MIN_POOL`），并且默认"优先抽低样本关卡"，让玩家用随机团把样本刷起来。这是整个模式的飞轮：**随机 → 采样 → 解锁 4 档**。

### 5.6 动态调整与迟滞

- 默认**不加迟滞**：4 档本身样本就少，迟滞会让档位长期不动，玩家感受不到"动态"。
- 如果实测发现"死一次就跳档"太跳，可以加一个可选的边界缓冲：新档位与旧档位不同且 `|d - 边界| < 0.2` 时保持旧档。
- 每次团结束记录 `tier_snapshot`（每关当时的档位），结算页可以显示"本次有 3 关档位发生变化"。

---

## 6. 关卡池

### 6.1 池来源

| `pool_source` | 扫描范围 | 说明 |
| --- | --- | --- |
| `all` | `user://` 根目录所有 `.lvl` ∪ `user://liked courses/` 下的 `.lvl` | 按 key 去重，保证"所有关卡"名副其实 |
| `liked` | `user://liked courses/` 下的 `.lvl` | 现有"喜欢的关卡" |

- 收藏是把关卡文件复制到 `liked courses/`，所以同名文件会在两个目录同时存在；按 key 去重后只算一条。
- `custom`（手动勾选）留接口，v2 再做。
- 扫描放 `Thread`，照抄 `history_level_list.gd` 的线程 + `await process_frame` 分帧模式，避免大目录卡 UI。

### 6.2 去重

- 按 key（文件名）去重：根目录和收藏目录的同名文件只保留一条。
- 内容相同但文件名不同（另存为）在 v1 不去重：key 不同，会显示两条。v2 可以用 fingerprint 去重，但需要决定"合并统计还是保留两条"，先不做。

### 6.3 排除 vs 跳过

这是两个不同层级的概念；其中「跳过」再分两种：

| 动作 | 写 ini | 以后是否抽到 | 影响当前团 | 消耗命 |
| --- | --- | --- | --- | --- |
| **跳过 A：本关不可能通过** | `solo_skip += 1`（不计 `solo_skip_soft`）；`excluded=true`，`exclude_reason="unsolvable"` | **永不抽到** | 立刻跳过，并从快照剩余部分移除 | 不消耗 |
| **跳过 B：我打不过（但可能能过）** | `solo_skip += 1`；`solo_skip_soft += 1` | **下一团仍会抽到** | 跳过本关；本团不再抽到，但不写排除 | 不消耗 |
| **永久排除（设置页）** | `excluded=true`，`exclude_reason="manual"` | **永不抽到** | 从当前池快照移除 | 不涉及 |

**暂停菜单的跳过流程**：

1. 玩家在暂停菜单看到两个入口：
   - 「本关不可能通过」；
   - 「我打不过，跳过本关」。
2. 选择「本关不可能通过」时二次确认：
   - 提示"该关会被永久排除，以后所有团都不会再抽到"；
   - 确认后：`solo_skip += 1`、`excluded=true`、`skipped_count += 1`、`skipped_hard += 1`（不写 `solo_skip_soft`）；
   - 从当前团的剩余快照中移除该 key。
3. 选择「我打不过，跳过本关」时：
   - 不写 `excluded`，只写 `solo_skip += 1`、`solo_skip_soft += 1`、`skipped_count += 1`、`skipped_soft += 1`；
   - 该关在本团不再抽到，但下一团仍可能被抽到。
4. 两种跳过都**不计通过、不计死亡、不扣命**，播放过渡动画后进入下一关。

**永久排除的其他入口**：

- 舞台设置面板「管理排除关卡」列表（可搜索、可恢复）；
- 历史/收藏的关卡信息卡（可选，阶段 2）。

**疑似无解提示**：

- `solo_attempt >= 20 且 solo_pass == 0`，或 `solo_skip >= 3`，或 `online_attempt >= 50 且 online_pass == 0`；
- 在舞台设置面板高亮「疑似无解」，但不自动排除；
- 玩家确认后才写 `excluded`。

**[风险]** 不允许把池子排除到少于 `MIN_POOL`；提示玩家先恢复几关。排除只影响百人团，不删除文件、不影响历史/收藏/派对模式。

### 6.4 池快照与动态抽取

**定量团**：

- 开局时把 `level_keys`、`level_fingerprints`、`seed`、`tier` 写进 `[run]`；
- 运行中只认快照，不重新扫目录（防止游玩过程中新存关卡导致索引错位）；
- 关卡文件在运行中被删除：跳过，记 `missing`，不消耗命；全部缺失 → 中止并回舞台；
- 关卡文件在运行中被修改（指纹不符）：本关样本标记 `dirty`，不计数，仍可玩；Log 警告。

**无尽团**：

- 开局只抽第一关；每次要抽下一关之前，重新计算最新样本下的 `d` 和 4 档分布；
- 档位数字固定为开局所选档，但该档的成员会动态变化；
- 下一关从"当前属于该档、本团没玩过、未被排除、文件存在"的关卡里按权重抽；
- 因为玩家在打，通过率实时变化，所以每关结果写入 ini 后立即影响下一次抽取，不是开局一次性算死；
- `level_keys` 逐步追加，已玩过的关卡不会再进入本团；
- 因为池子可能抽空，见 7.6。

---

## 7. 一次团的流程

### 7.1 状态机

```text
IDLE
  └─(舞台点开始)→ PLANNING（建池、分档、抽关、算命、写快照）
        └→ PLAYING(index)   ← 关卡成功加载时 solo_attempt += 1
             ├─(通过)→ RECORD_PASS → solo_pass+1 → cleared_count+1
             │                       ├ cleared_count 为偶数 → lives_left = min(lives_left+1, 100)
             │                       └ (无尽) 抽下一关前重算档位成员 → 过渡动画 → index+1 → PLAYING
             ├─(死亡)→ RECORD_DEATH → solo_death+1 → lives_left-1
             │                       ├ 还有命 → 重载本关（重载即新 attempt）
             │                       └ 命数=0 → FAILED
             ├─(跳过 A：不可能通过)→ solo_skip+1（不计 soft）→ 写 excluded → 从快照移除 → 过渡 → 下一关
             ├─(跳过 B：我打不过)→ solo_skip+1、solo_skip_soft+1 → 本团不再抽，下一团仍可抽 → 过渡 → 下一关
             └─(放弃/退出)→ ABANDONED
FINISHED / FAILED / ABANDONED → SUMMARY → IDLE
```

- **尝试口径**：每次成功加载关卡 `solo_attempt += 1`；未通过也未跳过的 attempt 即失败（`fail = attempt - pass - skip`）。
- **定量团**：`index` 走到 `total_levels` 时结束（无论通过还是跳过），结果为"走完"；`cleared_count` 可能小于 `total_levels`。开局快照固定，运行中不重算档位。
- **无尽团**：没有 `total_levels`；命数归零或完全没有可玩关卡时结束；每次抽下一关前按最新数据重算档位成员；当前档抽空则降档并提示，所有关卡都玩过则清空本轮记录、回到所选档继续（不结束）。
- 通过不扣命，且**每通过 2 关 +1 命（上限 100）**；死亡扣 1；两种跳过都不扣命。
- 中途退出 → `ABANDONED`，**已经产生的样本保留**，不白打。
- 失败/放弃都不删除任何关卡，也不自动排除；排除必须由玩家确认。

### 7.2 抽取算法

```text
rng = RandomNumberGenerator.new()
rng.seed = run.seed

候选 = 池内未排除、文件存在、不在本团已选列表中的关卡

权重 w = 1 + PREFER_LOW_SAMPLE * 1 / (1 + n + m / 4)
       # PREFER_LOW_SAMPLE=3；n/m 为该关 solo_attempt / online_attempt
       # prefer_low_sample=false 时 w=1（均匀随机）

定量团：一次抽 min(run_length, 候选数) 关
无尽团：每次抽 1 关
```

- 同一团内不重复；池子不足时**缩短团长度**（定量团）或结束（无尽团），不做重复抽取，避免样本膨胀。
- 顺序默认随机；可选「由易到难」（按 `d` 升序），给想要爬坡感的玩家。
- seed 存进 `[run]`，便于复现和排查"为什么抽到这一关"。

### 7.3 死亡 / 通过 / 跳过 / 放弃

| 事件 | 样本 | 命数 | 进度 | 下一步 |
| --- | --- | --- | --- | --- |
| 进入关卡（加载成功） | `solo_attempt += 1`（先按未通过记） | 不变 | 不变 | 开局/重载 |
| 通过 | `solo_pass += 1` | 每累计通过 2 关 `+1`，上限 100 | `cleared_count += 1` | 过渡动画 → 下一关 |
| 死亡 | `solo_death += 1` | `lives_left -= 1` | 不变 | 有命：重载本关（新 attempt）；没命：结算（失败） |
| 跳过 A：本关不可能通过 | `solo_skip += 1`（不计 `solo_skip_soft`）；`excluded=true` | 不变 | `skipped_count+1`、`skipped_hard+1` | 从快照移除 → 过渡 → 下一关 |
| 跳过 B：我打不过 | `solo_skip += 1`；`solo_skip_soft += 1` | 不变 | `skipped_count+1`、`skipped_soft+1` | 过渡 → 下一关 |
| 放弃/退出 | `attempt` 已在进入时记录，pass/skip 不变 → 自然算失败 | 不变 | — | 结算（放弃） |

- **失败数**：`fail = solo_attempt - solo_pass - solo_skip`。死亡、退出、崩溃都落在失败里；`solo_death` 只是失败的一个子集，用于展示。
- **通过率**：`solo_pass / solo_attempt`；跳过会增大分母，但不会增大分子。
- **每通过 2 关 +1 命**：先 `cleared_count += 1`，若为偶数则 `lives_left = min(lives_left + 1, 100)`；HUD 播放一次 `+1` 动画。这条规则定量团和无尽团都适用。
- 死亡重试是**同一关**重载，不是换关；这是和现有派对模式"各玩各的"最大的语义区别。
- 跳过 A 会立刻从当前池快照的剩余部分移除该 key，后续不会再抽到；跳过 B 只在本团标记为"已尝试"，下一团仍可能抽到。
- 定量团最后一关被跳过：团仍然结束，"走完"但 `cleared_count < total`。
- 无尽团跳过不减少通过数，也不扣命；连续跳过会以 `solo_skip` 形式积累，用于"疑似无解"提示。

### 7.4 与现有死亡/通关逻辑的关系

现有链路：

- `goal_gate.gd` 在 `_on_body_entered` 里 `emit_signal("next_level")`；
- `player_dead.gd` 在 `GameMode.PLAY` 下等 1.2 秒后 `emit_signal("next_level")`；
- 两者都会找 group `play_next_level_manager` 并调用 `next_level_pass()` / `next_level_die()`（`play_next_level_manager.gd`）。

新场景放一个 `AdventureRunController` 到 `play_next_level_manager` 组，实现这两个方法，**复用现有信号分发**。

但 `player_dead.gd` 在 `HISTORY_PLAY` 分支会自己 `GlobalTransition.reload_current_scene()`，不会走 group。所以：

- **方案 A（建议）**：新增 `GameModeType.ADVENTURE`。`player_dead.gd` 的 ADVENTURE 分支照抄 `PLAY` 分支（等 1.2 秒后 `emit_signal("next_level")`），由场景里的 `AdventureRunController` 负责记录/扣命/重试；`load_level.gd` 加 ADVENTURE 分支从 `Adventure` 取当前关卡路径；`goal_gate.gd` 不用改（它已经会找 `play_next_level_manager` 组）。代价是要核对所有 `GameModeType` 引用点（见 9.2）。
- **方案 B**：复用 `HISTORY_PLAY`，再在 `player_dead.gd` 里加 `if Adventure.is_running` 守卫。改动小，但会把历史模式的 UI/行为带进团模式，后续容易互相污染。

**[风险]** `play_room_base.tscn` 里的 `LevelManager` 会用关卡 JSON 的 `lives` 覆盖 `LifeManager.lives`。团模式每关的命数属于"团"而不是"关卡"，ADVENTURE 分支里必须跳过这次覆盖（或在加载后重新写入团的 `lives_left`）。

### 7.5 结算

结算页显示：

- 定量团：`已通过 c / N`、`跳过（打不过）s / 永久排除 h`、`剩余命数`、`死亡次数`、总用时；
- 无尽团：`已通过 N 关`、`跳过（打不过）s / 永久排除 h`、`剩余命数`、`死亡次数`、总用时；刷新 `best_endless_cleared` 时高亮"新纪录"；
- 每关：通过/跳过 A/跳过 B/失败、死亡次数、用时、当时档位；
- 新增单人样本数；
- 本次有多少关的档位发生变化（对比开局快照；无尽团为"实时重算次数"）；
- 疑似无解提示（`death` 很多且 0 通过 / 多次跳过 B）；
- 「再来一团」「返回舞台」「返回标题」。

写入：`[stats]` 累计、`[run].active=false`、清空快照。**百人团不写 `.lvl`**；联机结算的 pass/death 另由联机流程写 `.lvl`。

### 7.6 断点续团与无尽团边界

**断点续团**：

- `[run].active=true` 时，下次启动在标题页提示「继续上次的团 / 放弃」；
- 续团从 `index` 继续，`lives_left`、`cleared_count`、`skipped_count`、`skipped_soft`、`skipped_hard` 保留；
- 如果 `level_keys` 数量与 `level_fingerprints` 不一致、或关卡文件缺失，只允许放弃（避免用错关卡继续打）；
- 玩家在团中途改设置（池/档位）不影响当前团，只影响下一团。

**无尽团边界**：

- **当前档抽空**：`active_tier` 在当前实时分档下没有"本团本轮没玩过、未排除、文件存在"的关卡 → **降档**（3→2→1），弹文字提示「本档已抽空，已降为 X 档」，用新档继续抽。
- **所有档位都抽空**（所有可玩关卡都在本轮玩过）：**不结束**。清空 `cycle_played`、`cycle += 1`、`active_tier = 开局所选档`，提示「所有关卡已玩过，开始新一轮」，允许重复关卡。
- **完全没有可玩关卡**（全部被永久排除、文件全部缺失、池子为空）：结束本团，显示"无可玩关卡"。
- 关卡文件在无尽团进行中被删除：跳过，不扣命，继续抽下一关。
- 无尽团不设"总关卡数"；HUD 显示剩余命数 + `已通过 N 关`，不显示分母。
- 续团时必须恢复 `active_tier`、`cycle`、`cycle_played`，否则降档/新一轮的状态会丢。

---

## 8. 场景与 UI

### 8.1 入口

- 标题页 `room/title.tscn` 的 `ChooseModePanel`（现有 Host / Join / History / Options 四个按钮）新增「百人团」按钮。
- 点击进入 `room/adventure_stage.tscn`。

### 8.2 百人团舞台场景 `adventure_stage.tscn`

这是整个模式的"门面"，参考《马里奥制造 1》百人团的世界地图：

- 全屏 1920×1080，横向卷轴；
- 背景主题色由难度档决定；
- 关卡用**扁的、略倾斜的椭圆**排在一条路径上；
- 已通过 / 当前 / 跳过 / 未打 有明确的状态区分；
- 下方或左侧叠一个设置面板，选数据源 / 难度 / 流程；
- 起始后椭圆路径就是本次团的路线，过渡动画也复用同一套视觉。

**图层结构**：

```text
AdventureStage (Control, 1920x1080)
├── Background (ColorRect / 渐变 + 主题色)
├── FarLayer (Parallax2D / 手写视差)
│   ├── Cloud_1..n
│   └── HillFar_1..n
├── MidLayer
│   ├── HillNear_1..n
│   ├── Bush_1..n
│   └── Castle
├── PathLayer
│   ├── Ellipse_1..n（LevelEllipse 组件）
│   └── AvatarMarker
├── Foreground (草地/装饰)
└── UiLayer
    ├── SettingsPanel
    ├── SampleStatusLabel
    └── StartButton
```

**关卡椭圆（LevelEllipse）**：

- 使用 `level_ellipse.svg`（约 220×130），在场景里 `scale = Vector2(1.0, 0.55)`、`rotation = deg_to_rad(-8)`，得到"扁扁的带一点倾斜"的效果；
- 椭圆内部放编号 `Label`（反向旋转，保持文字水平）；
- 状态：
  - `pending`：白色/半透明描边；
  - `current`：主题色发光 + 轻微上下浮动（Tween 循环）；
  - `cleared`：填充绿色 + 对勾；
  - `skipped`：填充灰色 + 叉；
  - `failed`：暗红 + 裂纹（可选）。
- 椭圆之间用虚线/小圆点连接，形成"路线"。

**SVG 素材清单**（`sprite/ui/adventure/`）：

```text
cloud.svg
hill_far.svg
hill_near.svg
bush.svg
castle.svg
flag.svg
level_ellipse.svg
level_ellipse_cleared.svg
level_ellipse_skipped.svg
avatar_marker.svg
icon_life.svg
```

- 全部用 SVG，Godot 导入为可缩放纹理；在 `TextureRect` / `Sprite2D` 里设置合适的 `expand_mode` / `scale`。
- 背景不一定要 4 张 SVG：可以用一张 `bg.svg` + `ColorRect`/渐变做主题色，减少素材量；但 4 套配色更容易做出"难度氛围"。
- 装饰物用 `Parallax2D` 或手写视差，云可以缓慢漂移；不做复杂物理。

**主题色（建议初始值，可调）**：

| 档位 | 名称 | 背景主色 | 点缀色 | 氛围 |
| --- | --- | --- | --- | --- |
| 1 | 轻松 | 天蓝 `#BFE9FF` | 草绿 `#7BC96F` | 明亮、白天 |
| 2 | 标准 | 暖黄 `#FFE7A3` | 橙 `#F2A24B` | 黄昏、暖色 |
| 3 | 困难 | 紫 `#E3B5FF` | 深紫 `#8E44AD` | 傍晚、压迫感 |
| 4 | 极限 | 暗红 `#5A0F1A` | 亮红 `#FF5252` | 夜晚、危险 |

- 不要只靠颜色区分：椭圆/面板上同时显示「档位 3 · 困难」文字，照顾色弱玩家。

### 8.3 舞台上的设置面板

```text
┌──────────────────────────────┐
│ 百人团                       │
│                              │
│ 数据源： (●) 所有关卡  ( ) 喜欢 │
│          可玩 128 · 已采样 34 │
│                              │
│ 难度：  [1 轻松][2 标准]      │
│         [3 困难][4 极限]      │
│         [随机]  ← 样本不足灰掉 │
│         本档 9 关              │
│                              │
│ 流程： (●) 定量  ( ) 无尽     │
│        [——●————] 10 关        │
│        初始命数：20            │
│                              │
│ [管理排除关卡]   [开始打团]   │
└──────────────────────────────┘
```

- 切换数据源/档位/流程时，舞台上的椭圆路径实时重排：
  - 定量团：显示 N 个椭圆；
  - 无尽团：显示一排"?"椭圆，向内延伸；开局后每抽到新的一关，路径末尾追加一个椭圆；
- 样本不足时，四档按钮全部禁用，顶部显示进度：「已采样 9/16 关，随机模式可继续采样」；
- 初始命数实时显示：定量 `N*2`（5–50 关 → 10–100 命），无尽 `30`；
- 「管理排除关卡」打开列表，每行：文件名、个人通过率、联机通过率、排除开关。

### 8.4 游玩 HUD：左侧关卡信息面板 `adventure_level_info.tscn`

**[已拍板 2026-11-12]** 不再用顶部横条 HUD，改为在**屏幕左侧**放一块关卡信息面板。
样式直接沿用 history play 右侧信息卡（`ui/ui_panel.tscn` 半透明底 + `ui/ui_label.tscn` 白字描边），
固定挂在 `GameRoomSize` 左上（约 `(24, 100)`），高度按内容自适应。

```text
┌──────────────────┐
│ 🍄 × 18          │  ← 命数：mario_small walk 动画其中一帧 + 剩余命数
├──────────────────┤
│ 当前关卡          │
│ 14 / 30          │  ← 定量团：当前关 / 总关数；无尽团只显示 14
│ 本关死亡数        │
│ 0                │
│ 本关通过数        │
│ 3                │
│ 本关跳过数        │
│ 0                │
└──────────────────┘
```

- **命数**：固定显示在面板最上方（不再单独放顶部 HUD）；图标取 `mario_small.tres` 的 `walk` 动画第 3 帧（帧索引 2，atlas `(32, 32, 32, 34)`，最近邻放大 2×）；文字 `× N`，满 100 显示 `× MAX`；
- **当前关卡**：定量团显示 `当前关 / 总关数`（`run.index + 1` / `total_levels`）；无尽团没有总数，只显示当前关号；
- **本关死亡数 / 通过数**：这一关在 `adventure.ini` 里的单人累计（`solo_death` / `solo_pass`）；
- **本关跳过数**：**只统计「我打不过」的软跳过**（`solo_skip_soft`）；「本关不可能通过」的永久排除不计入；
- 面板不再显示「已通过 / 档位」那一行（2026-11-12 移除），进度信息只在结算页呈现；
- 数据统一走 `Adventure.current_level_stats()`，面板监听 `Adventure.run_changed` 刷新，换关时场景重载自然刷新；
- 面板 `mouse_filter = IGNORE`，不影响停玩输入与暂停菜单。

**反馈动画**（后续可加）：通过时命数数字短促放大；每通过 2 关 `+1 命` 时图标弹一下；降档/新一轮的提示文案改为在面板下方飘一行。

**暂停菜单**（`Esc` / 手柄 Start）：

- 继续；
- 「本关不可能通过」（永久排除，见 6.3）；
- 「我打不过，跳过本关」（只记跳关次数，见 6.3）；
- 放弃本团（二次确认）；
- 返回标题（二次确认）。

- 暂停菜单必须 `process_mode = ALWAYS`，因为终点/死亡流程里 `get_tree().paused` 会被置 true。

### 8.5 关卡过渡动画

百人团在**每次通过一关之后**插一段转场。这一段和联机模式现有的「关卡传送房间」是两套东西：
联机那套负责把玩家送进下一关，这里这套只负责**演出「角色又往前走了一步」**。

#### 8.5.1 触发位置：关卡视口内，不走场景切换

转场**在关卡场景自己的视口里播**，不另开场景、不切 `CanvasLayer` 到别的场景。

- 覆盖层挂到当前关卡场景下（`room/play.tscn` 或冒险关卡的根节点），
  或由 `Adventure` autoload 持有一个常驻 `CanvasLayer`，两者择一，
  但**必须位于关卡视口之内**，这样遮挡关系与黑边裁切和游戏画面一致。
- 播完才调用 `GlobalTransition.reload_current_scene()` 进下一关，避免双重闪屏。
- `process_mode = PROCESS_MODE_ALWAYS`（终点判定会把 `get_tree().paused` 置 true）。

#### 8.5.2 画面：宣传片同款黄色转场

复用 `object/ui/section_transition.tscn`（从 MFMP 宣传片 `transition.tscn` 搬运而来）：

| 元素 | 说明 |
| --- | --- |
| 底色 | 纯橙黄 `Color(1, 0.502, 0)`，1920×1080 |
| 两侧锯齿 | `Polygon2D` ×2（左右各一），顶点数据逐字取自宣传片，上下咬合成拉链条 |
| 装饰道具 | 22 个 `Sprite2D`（640×480 空间 `scale = 1`，等价原版 1920 空间 `scale = 2`）；画布左右外侧预置额外道具用于补位；跳跃时与关卡串同步左移 **0.5 × `NODE_GAP`**（视差）；划入/划出时自身再左移 **4 × `NODE_GAP`**（272px）；位移只作用在道具自身，容器与裁切框固定，道具被 `clip_contents` 裁在黄板内 |
| 道具材质 | `color_filter_replace.gdshader`，筛选色 → 目标色（默认黑→白） |

道具贴图统一取 `sprite/bonus/` 下的奖励道具：

```
beetroot.png        29×105（首帧 29×35）
fire_flower.png     33×128（首帧 33×32）
lui.png             33×128（首帧 33×32）
mushroom.png        31×32
```

> 注：宣传片里用的是预先抠好的 `*_white.png` 白色剪影；本方案改用 shader 现场染色，
> 少维护一套素材。染色参数（`filter_color` / `target_color` / `tolerance`）
> 建议在 `section_transition.tscn` 的 `ShaderMaterial` 上调，不要写死在脚本里。

#### 8.5.3 动画：角色原地跳 + 关卡整体左移

转场期间播放两个并行动作，表达「角色向前推进了一关」：

1. **角色原地跳**——顶部的角色精灵（或队伍图标）做周期性上抛：
   - 重力式抛物线，`y = -h * 4 * t * (1 - t)`（`t` 为单次跳跃的 0~1 进度），
     单次约 0.35 秒，循环到转场结束；
   - 起跳高度建议 36~48 px（乘上节点自身的 `scale` 后折算）。
2. **脚下关卡全员左移**——角色下方代表「关卡队列」的元素整体向左滚动：
   - 队列节点横向位移 `x -= speed * delta`，`speed` 约 480 px/s；
   - 移出左边界后循环补到队尾，营造无限前进感；
   - 队列内容建议用关卡缩略图或关卡序号牌，数量不少于 6 个以保证无缝。

两者用**同一个 `Tween` / `AnimationPlayer` 时间轴**驱动，保证起跳节奏与滚动节奏对齐。

#### 8.5.4 时序与时长

| 阶段 | 时长 | 说明 |
| --- | --- | --- |
| 淡入 | 0.25s | 黄色层从 `modulate.a = 0` 到 1，同时遮住上一关的残留 |
| 主体 | 1.2~2.0s | 角色跳 + 关卡左移，此时可显示 `第 3/10 关` |
| 淡出 | 0.25s | 交给 `GlobalTransition` 的截图淡出衔接 |

- **任意输入可在总时长 0.4s 之后跳过**，跳过时直接跳到「淡出」阶段，不打断下一关的加载。
- 通过一关与跳过一关的转场可共用同一套动画，仅文案与音效不同。

#### 8.5.5 与舞台椭圆路径的关系

8.2 描述的舞台椭圆路径（`adventure_stage.tscn`）是**选关/看进度时的静态视图**，
本节的转场是**过关瞬间的演出**，二者不复用同一套坐标：

- 舞台椭圆：展示「这一团走到了第几个椭圆」，由舞台场景持有；
- 关卡内转场：只表达「往前一步」，不渲染完整椭圆图；
- 若后续想让两者视觉一致，可把椭圆路径抽成共用组件，但 v1 不做。

#### 8.5.6 实现清单

| 文件 | 改动 |
| --- | --- |
| `object/ui/section_transition.tscn` | 已建，黄色底 + 锯齿 + 24 个道具 |
| `shader/color_filter_replace.gdshader` | 已建，筛选染色 |
| 新增 `script/adventure/adventure_clear_transition.gd` | 驱动淡入 / 跳跃 / 左移 / 淡出 |
| `script/adventure/adventure_stage.gd` | 过关回调里调用转场，再进下一关 |
| `docs/raid_mode/README.md` | 本节 |

**[风险]** 终点判定里 `get_tree().paused = true` 会暂停普通节点；过渡层和暂停菜单必须显式 `PROCESS_MODE_ALWAYS`，否则动画不动。

**[风险]** 转场挂在关卡场景里时，`reload_current_scene()` 会连带销毁覆盖层——
必须先播完淡出、再调切换，且覆盖层自身 `queue_free` 要放在切换之后（或用 `GlobalTransition` 持有的常驻层规避）。

### 8.6 结算页

- 可以复用 `room/result_room.tscn` 的布局，但数据源换成 `Adventure` 的 `[run]` 结果；不要走 `MPManager.flow.last_results`。
- 定量团和无限团的字段不同，用两个布局或动态隐藏。

### 8.7 历史/收藏的关卡信息卡

- 在 `level_info.tscn` 的通过率行下面加两行：
  - `单机 2/7 (28.6%)`
  - `联机 31/43 (72.1%)`
- 联机通过率读 `.lvl` 的 `pass_count/death_count`，标注「联机（本关全体）」。
- 加一个「本关不参与百人团」开关（写 `excluded`）。

---

## 9. 代码接入点

### 9.1 建议新增的模块

```text
script/adventure/adventure_manager.gd        # autoload Adventure（门面 + 当前团状态）
script/adventure/adventure_store.gd          # adventure.ini 读写（RefCounted）
script/adventure/level_identity.gd           # key + fingerprint + 缓存
script/adventure/pool_builder.gd             # 扫描目录 / 去重 / 排除 / 池快照
script/adventure/tier_calculator.gd          # 通过率 → d → 4 档
script/adventure/run_planner.gd              # seed + 加权抽取
script/adventure/adventure_run_controller.gd # 场景内推进（group play_next_level_manager）
script/adventure/adventure_stage_view.gd     # 舞台/椭圆路径的布局与状态
script/adventure/adventure_transition.gd     # 过渡覆盖层
script/adventure/adventure_level_info.gd     # 左侧关卡信息面板数据绑定
room/adventure_stage.tscn                    # 入口 + 设置 + 路径预览
room/adventure_play.tscn                     # 游玩场景
room/adventure_result.tscn                   # 结算
object/ui/adventure_level_info.tscn
object/adventure/adventure_pause_menu.tscn
sprite/ui/adventure/*.svg
```

**autoload 必须是脚本**：`Adventure="*res://script/adventure/adventure_manager.gd"`。项目里已有教训：autoload 指向 `.tscn` 时静态类型会退化成 `Node`，`Adventure.xxx` 全部编译失败。

### 9.2 需要改动的现有文件

| 文件 | 改动 | 风险 |
| --- | --- | --- |
| `project.godot` | 新增 autoload `Adventure` | 低 |
| `script/utils/game_mode.gd` | 新增 `GameModeType.ADVENTURE` + 对应信号 | 低 |
| `script/level/player/player_dead.gd` | ADVENTURE 分支照抄 PLAY（等待后 emit `next_level`），由场景控制器记录 | 低 |
| `script/level/facility/goal_gate.gd` | 理论上不用改；确认场景里有 `play_next_level_manager` 组节点即可 | 低 |
| `script/edit/save_and_load/load_level.gd` | ADVENTURE 分支 → 从 `Adventure.current_level_path` 取路径 | 低 |
| `script/edit/level_manager.gd` | ADVENTURE 下不要用关卡 `lives` 覆盖团的命数 | 中 |
| `room/title.tscn` | 入口按钮 | 低 |
| `script/history/level_info.gd` | 显示双通过率 + 排除开关 | 中，影响历史/收藏卡片 |
| `script/multiplayer/0_core/player_profile.gd` | `to_result_dict()` 增加 `level_file_name` | 低 |
| `script/multiplayer/0_core/services/match_flow_service.gd` | 恢复每个客户端写本地 `.lvl` 的 `pass_count/death_count` | 中，改 RESULT 处理 |
| `script/multiplayer/0_core/services/level_transfer_service.gd` | 允许收藏目录/池子分发 | 中（阶段 3） |

**`GameModeType` 的引用点**：搜索命中 19 个文件，其中 `script/utils/game_mode.gd` 是定义本身，其余 18 个需要在新增枚举后逐个确认"ADVENTURE 应该走哪个分支"：

`game_time_manager.gd`、`edit/tilemap/tilemap_draw.gd`、`edit/spawner_set.gd`、`edit/save_and_load/load_level.gd`、`edit/play_button.gd`、`edit/objectmap/object_map_layer.gd`、`edit/life_display.gd`、`edit/level_manager.gd`、`time_manager.gd`、`test_time_label.gd`、`multiplayer/random_capture/random_capture.gd`、`multiplayer/game_mode_detect.gd`、`multiplayer/5_play/multiplayer_ani_sprite_manager.gd`、`level_camera.gd`、`multiplayer/0_core/services/match_flow_service.gd`、`level/player/player_dead.gd`、`level/facility/goal_gate.gd`、`level/facility/door.gd`。

大多数是 `== EDIT/TEST` 的判断，ADVENTURE 自然落到"非编辑"分支；需要重点看的是 `load_level`、`player_dead`、`goal_gate`、`level_manager`（lives 初始化）、`level_camera`。

### 9.3 为什么不复用 `MPManager`

- `MPManager` 是联机门面，单机团不该依赖它；否则无 peer、断线、测试模式下行为不可控。
- 但可以复用它的**原子写**、**路径校验**、**分片传输**代码（抽成 `script/utils/` 的公共函数），不要复制粘贴。

---

## 10. 联机扩展（阶段 3，不在 v1）

### 10.1 现有联机流程的限制

- 现在「一人提交一关 → `levels.shuffle()` → 各玩各的 → 结算聚合」，没有"同一个关卡序列"的概念。
- `LevelTransferService._is_safe_level_path()` 只接受 `user://` 根目录 `.lvl`，收藏目录和任意池子文件进不了传输通道。
- 各客户端关卡索引独立，谁先打完谁先走；团模式如果要"同一关同时开打"，需要主机权威的进度广播。
- `_apply_level_result` 只按关卡作者聚合 `cause_pass/cause_death`，没有"每关每玩家"的明细。
- 重构 `8f8f254` 删掉了旧 `store_level_results` 的 `call_local` 落盘，现在客户端不再写 `.lvl`；需要恢复客户端写回，见 10.2。

### 10.2 建议的联机方案

1. 大厅增加房间模式字段：`party` / `adventure`。
2. 主机选池、档位、流程；客户端只读显示。
3. 主机把抽中的关卡列表下发；客户端缺文件时向主机请求（复用分片 + SHA-256 传输）。
4. 每关开始前主机广播 `level_index` 和 `seed`；死亡的玩家本地重试，但只有主机能推进"全团进度"。
5. 结算时主机广播每关 `pass/death`，各客户端写回自己本地的 `.lvl`（`pass_count/death_count`），恢复重构前 `store_level_results` 的 `call_local` 行为。

### 10.3 100 人规模

如果"百人"是字面 100 人同房：

- ENet 单主机 100 peer、每关 N 个文件的分发、100 份结算聚合，都需要压测；
- 关卡不要整池预传，按当前关卡"按需分发"；
- 玩家列表要虚拟化（现有 UI 是逐个实例化）；
- 建议先做 8~16 人验证流程，再谈 100 人。

**[待拍板]** v1 是否完全不碰联机团。**[建议]** 是：先把单机数据层、舞台、4 档跑通，联机团单独立项。

---

## 11. 命数经济与加命平衡（已拍板，待调参）

### 11.1 已拍板规则

```text
定量团：初始 = 关数 × 2              # 5–50 关 → 10–100 命
无尽团：初始 = 30
死亡： -1
通过： 每累计通过 2 关 +1
跳过 A / B：0
总上限：100
```

- 定量团总共可用命数约为 `min(100, 2N + floor(cleared/2))`。
- 无尽团每 2 关回 1 命，等价于"平均每关允许 0.5 次死亡"的收支平衡点；上限 100 兜底。
- 两种跳过都不扣命，所以"关卡质量问题"不会惩罚玩家。
- **50 关定量团初始就是 100（= 上限）**，此时每 2 关 +1 会被上限吃掉；这是当前规则的直接结果，见 11.3。

### 11.2 这条规则的实际效果

设玩家平均每关死亡次数为 `r`：

```text
命数净变化 ≈ +0.5 - r   （每关，未到 100 上限时）
```

- `r < 0.5`：命数缓慢上涨；到 100 后封顶，无尽团仍可能拉得很长。
- `r ≈ 0.5`：收支平衡，无尽团在 30 命附近波动。
- `r > 0.5`：命数缓慢下降，最终归零；这是大多数玩家的自然终点。
- 4 档的作用就是让 `r` 接近 0.5：低档容易涨命，高档容易掉命。
- 定量团的预算（`2N` + 奖励，上限 100）比较宽松，主要服务"走完流程 + 看关卡"的体验，不追求极限压力。

### 11.3 需要观察与可能调整的旋钮

上限 100 已生效。如果实测出现以下情况，再考虑调整：

| 现象 | 可能调整 |
| --- | --- |
| 高手在 1 档无尽团无限续命，几十关不结束 | 上限已兜底；仍太长就改成「每 3 关 +1」，或低档不奖励命、只有 3–4 档奖励 |
| 50 关定量团初始 100，奖励命数完全无效 | 把初始改成 `1.8N`（50 关 = 90），或把上限提到 120；需要你拍板 |
| 大多数玩家 10 关内结束 | 把「每 2 关」改成「每 1 关」；或初始 30 → 40 |
| 定量团几乎不可能失败，缺紧张感 | 定量团不加命；或初始从 `2N` 降到 `1.5N` |
| 命数显示一直很大，玩家没感觉 | HUD 只显示数字 + 每 2 关 `+1` 飘字；不做过多的命数动画 |

**目标区间**（用于后续调参）：

- 无尽团中位数：40–60 关；
- 定量团完成率：60–70%（允许因命数耗尽失败）；
- 1 档和 4 档的 `r` 应该有明显差异，否则说明分档没有起作用。

### 11.4 需要记录的数据

`[stats]` 增加：

```ini
best_endless_cleared=0
runs_endless=0
endless_total_cleared=0
endless_total_deaths=0
```

每团结束再记录一条轻量 run 摘要（可选，保留最近 20 条）：`mode/tier/cleared/deaths/lives_left/duration`。用于计算"平均能走多远"和调参。只统计本机，不上传。

### 11.4 需要记录的数据

`[stats]` 增加：

```ini
best_endless_cleared=0
runs_endless=0
endless_total_cleared=0
endless_total_deaths=0
```

用于计算"平均能走多远"和调 K。只统计本机，不上传。

---

## 12. 边界情况

| 场景 | 行为 |
| --- | --- |
| 关卡文件被删除 | 从池中剔除；运行中删除则跳过本关、不消耗命 |
| 关卡被改名 | 旧 key 的统计成为孤儿；新 key 从 0 开始。UI 可显示孤儿条目并允许清理（v2） |
| 同名关卡被编辑 | 指纹变化 → 样本清零、`generation+1` |
| 收藏副本与根目录同名 | 按 key 合并，只算一条 |
| 两关内容相同但文件名不同 | v1 视为两关；v2 可指纹去重 |
| `adventure.ini` 损坏 | 备份为 `.bak.<时间戳>`，新建空配置，继续运行 |
| 两个实例同时写 | v1 假设单实例；多开测试时可能丢更新，需 reload+merge |
| 团进行中改设置 | 不影响当前团，只影响下一团 |
| 团进行中退出游戏 | 保留 `[run].active=true`，下次提示续团 |
| 排除到池子不足 | 拒绝开局并提示恢复 |
| 样本为 0 的关卡 | 不参与分档；随机模式可抽，抽到即采样 |
| 联机 `.lvl` 与单人 `ini` 不一致 | 两条独立通道，不做比较：联机读 `.lvl`，单人读 `ini` |
| 无尽团当前档抽空 | 降档（3→2→1），提示「本档已抽空，已降为 X 档」 |
| 无尽团所有档位都抽空 | 清空 `cycle_played`、`cycle+1`、回到开局所选档，提示「所有关卡已玩过，开始新一轮」，不结束 |
| 无尽团完全没有可玩关卡 | 结束本团，显示"无可玩关卡" |
| 无尽团实时重算导致当前关移出该档 | 已开始的关卡继续打；只影响下一关抽取 |
| 定量团全跳过 | 团结束，`cleared_count=0`，仍算"走完"，结算如实显示 |
| 跳过 A：本关不可能通过 | 写 `excluded`，当前快照移除，以后所有团排除 |
| 跳过 B：我打不过 | 只记 `solo_skip`，当前团跳过，以后仍可能抽到 |
| 进入关卡后直接退出/崩溃 | `attempt` 已在进入时 +1，pass/skip 不变 → 算一次失败 |
| 通过数达到 2、4、6… | `lives_left = min(lives_left + 1, 100)`，HUD 飘 `+1` |
| 命数达到 100 | 封顶，不再增长；HUD 显示 `MAX` |
| 过渡动画期间按键 | 0.4 秒后可跳过，直接进入下一关 |
| 暂停菜单与终点暂停 | 暂停菜单/过渡层必须 `PROCESS_MODE_ALWAYS` |

---

## 13. 实施计划

### P0：数据层（不改任何现有玩法）

- `adventure.ini` 读写、原子保存、schema 校验、损坏恢复。
- `LevelIdentity`：key + 指纹 + mtime/size 缓存。
- 单人样本记录：历史/收藏游玩时死亡/通过写入 `solo_*`。
- 单测/探针：构造临时关卡，验证字段、指纹、排除、样本门槛。

### P1：舞台 + 随机团

- 标题入口、`adventure_stage.tscn`（SVG 景物 + 椭圆路径 + 设置面板）。
- 池构建、随机抽取、`adventure_play.tscn`、HUD、结算。
- 断点续团。
- 排除管理 UI。
- 此时还没有 4 档，只有随机；但已经能产生样本。

### P2：4 档 + 命数 + 过渡 + 两类跳过

- `TierCalculator`、档位 UI、样本门槛/降级、档位变化提示。
- 定量团初始命数 `2N`、无尽团 30；每通过 2 关 `+1` 命。
- 过渡动画覆盖层：黄色转场（复用 `object/ui/section_transition.tscn`）+ 角色原地跳 +
  脚下关卡左移，细节见 §8.5。关卡视口内播放，播完再进下一关。
- 暂停菜单两条跳过路径：永久排除 / 仅本次跳过。
- 无尽团每次抽下一关前按最新数据重算档位成员。
- 关卡信息卡显示双通过率 + 排除开关。

### P3：联机统计与联机团

- 恢复每个客户端写回本地 `.lvl` 的 `pass_count/death_count`（旧 `store_level_results` 的 `call_local` 行为）；`to_result_dict()` 补 `level_file_name`。
- 联机团房间模式、池子分发、主机权威进度（较大，单独评审）。

### P4：命数调参

- 收集 30–50 次团数据（`cleared/deaths/lives_left/tier`）。
- 看无尽团中位数是否落在 40–60 关；偏离时按第 11.3 节调整（每 2 关改每 3 关、加命上限、定量团是否加命）。

---

## 14. 验收标准

1. **入口**：标题页有「百人团」按钮，能进入舞台场景。
2. **舞台**：SVG 景物正常显示；切换档位时背景主题色变化；椭圆是扁的、略倾斜的，状态可区分。
3. **设置**：数据源（所有/喜欢）、难度（4 档）、流程（定量/无尽 + 关数）都能选；样本不足时四档禁用。
4. **命数**：定量团开局 `2N` 命（5–50 关 → 10–100 命），无尽团 30 命；死亡扣 1；每通过 2 关 +1，总上限 100；两种跳过都不扣。
5. **HUD**：左侧面板顶部显示命数（mario walk 一帧图标 + `× N`，满 100 显示 `× MAX`）；面板含当前关卡、本关死亡数、本关通过数、本关跳过数（只算软跳过）；底部显示已通过进度（定量 `c / N`、无尽 `N 关`）与档位。
6. **过渡**：通过/跳过一关后有 1.2–2.0 秒动画，可用输入跳过。
7. **跳过**：暂停菜单有两条路径——「本关不可能通过」会永久排除；「我打不过」只记 `solo_skip`，以后仍会抽到。两者都不扣命、不计通过。
8. **百人团不写 `.lvl`**：完成一轮百人团后，所有 `.lvl` 的修改时间不变（哈希不变）；联机派对模式结算写 `.lvl` 是明确例外。
9. **尝试口径**：进入关卡 `attempt+1`；死 3 次再通过 1 次 → `attempt=4, pass=1, fail=3, skip=0`，通过率 25%。进入后直接退出 → `attempt+1`、`pass/skip` 不变，算一次失败。跳过 B → `attempt+1, skip+1`，通过率 = `pass / attempt`。
10. **双通道独立**：联机结算后 `.lvl` 的 `pass_count/death_count` 被这一关的结果更新，`adventure.ini` 的 `solo_*` 不被覆盖；联机 attempt = `pass_count + death_count`。
11. **4 档**：构造 20 关样本，四档各 5 关；只有 15 关样本时四档按钮禁用，随机可用。
12. **动态**：再打 5 关后重新打开舞台，档位分布按新数据重算。
13. **无尽**：档位数字固定；每次抽下一关前按最新样本重算档位成员；当前档抽空 → 降档并提示；所有关卡玩过 → 清空本轮、回到所选档继续，不结束；只有完全没有可玩关卡或命数归零才结束；HUD 显示命数 + 已通过数；`best_endless_cleared` 会刷新。
14. **续团**：恢复 `active_tier`、`cycle`、`cycle_played`、`lives_left`、`cleared_count`，降档/新一轮状态不丢。
15. **回归**：现有派对模式、历史列表、收藏列表、单机游玩流程不变；旧通过率显示不变。
16. **日志**：所有新增日志走 `Log.i/w/e`，不手写时间戳。
17. **静态检查**：用 4.6.1 console headless 探针跑通，且不引入新的 GDScript 警告（项目把多条警告设为错误）。

---

## 15. 决策记录与剩余问题

### 已拍板（2026-11-09）

| # | 决策 | 结论 |
| --- | --- | --- |
| 1 | 团的结构 | 单人连续攻关；"百人"指池子/样本规模；联机版阶段 3 |
| 2 | 4 档定义 | 个人分位：按个人通过率在池内均分 4 档 |
| 3 | 联机数据权重 | 只做先验；个人数据随游玩次数逐渐主导 |
| 4 | 失败规则 | 命数用尽即本团结束；命数整团共享 |
| 5 | 两种流程 | 定量团（选关数）+ 无尽团（30 命） |
| 6 | 初始命数 | 定量 `N*2`（5–50 关 → 10–100 命）；无尽 `30`；总上限 `100` |
| 7 | 入口/场景 | 标题新按钮 → SMM1 风格舞台场景，SVG 景物 + 扁倾斜椭圆 + 主题色 |
| 8 | 跳过分两种 | A「本关不可能通过」永久排除；B「我打不过」只记 `solo_skip`，以后仍会抽到；两者都不扣命 |
| 9 | 过渡 | 每通过/跳过一关播放短动画 |
| 10 | HUD | 左侧关卡信息面板：顶部命数（mario walk 一帧 + `× N`/`× MAX`）+ 当前关卡 + 本关死亡/通过/软跳过 + 底部已通过进度与档位 |
| 11 | 无尽档位 | 数字固定；每次抽下一关前重算成员；当前档抽空降档并提示；所有关卡玩过则清空本轮、回到所选档继续，不结束 |
| 12 | 加命 | 每通过 2 关 +1 命，两种模式都适用；总上限 100 |
| 13 | 通过率口径 | `pass / attempt`；进入关卡即 `attempt+1`（未通过先算失败）；跳关计入分母；失败 = attempt - pass - skip |
| 14 | 联机统计存储 | `pass_count/death_count` 写 `.lvl`；每个客户端写自己本地文件；百人团单人不写 `.lvl` |
| 15 | `.lvl` 的 p/d 语义 | 每个关卡一个文件、现做现玩；p/d 是这一关**全体玩家**的通过/死亡合计，不是个人数据；同一文件重复游玩才覆盖 |

### 仍待确认

1. **50 关定量团的奖励失效**：初始 `2N = 100` 正好等于上限，每 2 关 +1 完全被吃掉。是保持现状、把初始改成 `1.8N`，还是把上限提到 120？
2. **极端降档**：如果当前档抽空、且更低的档也没有未玩关卡，但更高的档还有，是"切到任意仍有未玩关卡的档"，还是直接进入新一轮？
3. **新一轮回到哪个档**：当前设计是回到开局所选档；是否要留在降档后的最低档？
4. **同一 `.lvl` 被重复游玩时**：当前直接覆盖（p/d 是这一关的统计）；如果以后允许复用历史关卡，是否需要按 `match_id` 追加或保留多份统计？
5. **客户端写回时机**：RESULT 收到就写，还是离开结算页再写？建议收到就写，避免玩家直接关游戏导致丢失。
6. **作者结算前掉线**：该关的 `level_file_name` 可能不在 result 里，本次不写；是否接受？
7. **"所有关卡"是否包含 `liked courses/` 里"只收藏、没留在根目录"的关卡**（建议包含）。
8. **档位名称/主题色**：1 轻松 / 2 标准 / 3 困难 / 4 极限，主题色按 8.2 的表，是否合适？
9. **过渡动画时长与跳过**：建议 1.2–2.0 秒、0.4 秒后可跳过；是否需要更短/更长？
10. **50 关的舞台排布**：横向滚动 / 蛇形多行 / 分页，仍未定。

---

## 附录 A：分档伪代码

```gdscript
# 输入：pool: Array[LevelStat]
# 输出：Dictionary[key -> tier 1..4]
func assign_tiers(pool: Array[LevelStat]) -> Dictionary:
    var sampled: Array[LevelStat] = []
    for s in pool:
        if s.excluded or not s.file_exists:
            continue
        if s.solo_attempt + s.online_attempt > 0:
            sampled.append(s)

    sampled.sort_custom(func(a, b):
        if not is_equal_approx(a.difficulty, b.difficulty):
            return a.difficulty < b.difficulty
        var na := a.solo_attempt + a.online_attempt
        var nb := b.solo_attempt + b.online_attempt
        if na != nb:
            return na < nb
        return a.key < b.key
    )

    var result: Dictionary = {}
    var n: int = sampled.size()
    for i in range(n):
        var tier: int = clampi(int(floor(float(i) * 4.0 / float(n))) + 1, 1, 4)
        result[sampled[i].key] = tier
    return result
```

## 附录 B：常量表（v1 建议值）

| 常量 | 值 | 位置 |
| --- | --- | --- |
| `MIN_POOL` | 5 | `TierCalculator` |
| `MIN_SAMPLED` | 16 | `TierCalculator` |
| `MIN_TIER_LEVELS` | 3 | `TierCalculator` |
| `K_MAX` | 4.0 | `TierCalculator` |
| `M_HALF` | 10.0 | `TierCalculator` |
| `PRIOR` | 0.5 | `TierCalculator` |
| `P_CLAMP` | [0.02, 0.98] | `TierCalculator` |
| `PREFER_LOW_SAMPLE` | 3.0 | `RunPlanner` |
| `DEFAULT_RUN_LENGTH` | 10 | `Adventure` |
| `RUN_LENGTH_MIN` | 5 | `Adventure` |
| `RUN_LENGTH_MAX` | 50 | `Adventure` |
| `FINITE_LIVES_FACTOR` | 2 | `Adventure` |
| `ENDLESS_LIVES` | 30 | `Adventure` |
| `LIVES_CAP` | 100 | `Adventure` |
| `LIFE_BONUS_EVERY` | 2 | `Adventure` |
| `TRANSITION_SEC` | 1.5 | `AdventureTransition` |
| `TRANSITION_SKIP_SEC` | 0.4 | `AdventureTransition` |
| `SAVE_DEBOUNCE` | 关卡结束/团结束/退出 | `AdventureStore` |

## 附录 C：与现有文档/代码的对照

- 联机架构基线：`docs/multiplayer_refactor_plan.md`
- 观看视图（裁剪 `play_room_base` 的坑）：`docs/spectator_mode/README.md`
- 唯一持久化单例：`script/utils/game_config.gd`（`user://game_settings.cfg`）
- 关卡 JSON schema：`script/edit/level_manager.gd` 的 `get_level_data_json()`
- 关卡文件名规则：`script/edit/save_and_load/save_level.gd`
- 历史列表扫描：`script/history/history_level_list.gd`
- 收藏列表扫描：`script/history/liked_courses/load_liked_courses.gd`
- 旧通过率展示：`script/history/level_info.gd`
- 联机结算/回写：`script/multiplayer/0_core/services/match_flow_service.gd`
- 关卡传输路径白名单：`script/multiplayer/0_core/services/level_transfer_service.gd`
- 死亡/通关分发：`script/level/player/player_dead.gd`、`script/level/facility/goal_gate.gd`、`script/multiplayer/5_play/play_next_level_manager.gd`
- 场景过渡：`script/utils/global_transition_fade_out.gd`（0.25s 截图淡出）
- 项目 GDScript 警告即错误：`project.godot` 的 `[debug] gdscript/warnings/*=2`
