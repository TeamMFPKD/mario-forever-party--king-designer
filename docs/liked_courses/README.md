# 喜欢的关卡重构 + 旧版导入迁移方案

> 状态：v1.0（2026-11-09）
> 标记约定：**[已拍板]** = 已确认；**[建议]** = 本文给出的默认实现；**[风险]** = 落地时容易踩的坑。
> 相关代码：`script/history/**`、`object/level_import_export.tscn`、`project.godot`、`i18n/**`。

---

## 0. 一句话结论

收藏不再复制 `.lvl`，改为 `user://liked courses/liked_courses.cfg` 存**裸文件名索引**，关卡数据只保留 `user://` 根目录一份；
启动时自动把旧版收藏夹里的 `.lvl` 副本迁回根目录并登记索引；
导出按钮改为「三模式选择弹窗」，导入按 zip 内是否带索引自动分流，旧格式收藏包导入时自动完成转换。

---

## 1. 现状与问题

收藏链路目前有 5 个脚本各自硬编码 `"liked courses"` 与路径拼接：

| 文件 | 现状 | 问题 |
| --- | --- | --- |
| `script/history/take_photo.gd` | 按 `photo` 键时把 `user://x.lvl` **复制**到 `user://liked courses/x.lvl`，另存 `x.png` | 同一关卡存两份，浪费空间、不符合 DRY |
| `script/history/liked_courses/load_liked_courses.gd` | `DirAccess` 扫 `liked courses/*.lvl` 生成卡片 | 数据源是副本文件夹 |
| `script/history/history_level_file_path_set_button.gd` | 收藏卡片路径拼成 `user://liked courses/x.lvl` | 与历史列表路径不一致 |
| `script/history/liked_courses/unlike_button.gd` | 删除 `liked courses/x.lvl` + `x.png` | 取消收藏删的是副本；`replace(".lvl", ".png")` 不是按 basename 替换 |
| `script/history/import_export_manager.gd` | 以整个文件夹为单位打包/解压 `.lvl` + `.png` | 收藏包不可独立迁移（离开副本文件夹就没有数据） |

截图链路本身没问题，继续沿用：

- `script/history/liked_courses/capture_texture_setter.gd`：按 `basename` 读 `liked courses/<base>.png`
- `script/history/liked_courses/liked_course_preview.gd`：同上

---

## 2. 目标存储模型 [已拍板]

### 2.1 目录结构

```
user://
├─ mfmp_2026-11-09_12-00-00_xxx_1aaad.lvl   ← 唯一一份关卡数据（历史 / 收藏共用）
└─ liked courses/
   ├─ liked_courses.cfg                     ← 收藏索引（唯一数据源）
   └─ mfmp_2026-11-09_12-00-00_xxx_1aaad.png ← 封面截图（只此一份，必须留在收藏夹）
```

**约定：**

1. `liked courses/` 下**不允许**出现 `.lvl`；旧版迁移完成后只剩 `.png` + `liked_courses.cfg`。
2. 卡片显示的 `LevelFileNameLabel` 仍是**裸文件名**（不带路径），按钮脚本再经 `LikedCourses.level_path()` 解析成 `user://<file>`。
3. 封面路径由文件名派生（`basename + ".png"`），不写进索引，避免索引与文件不同步。

### 2.2 索引文件格式 [已拍板]

路径：`user://liked courses/liked_courses.cfg`，用 `ConfigFile`（与 `user://game_settings.cfg` 风格一致）：

```ini
[liked_courses]
version=2
files=PackedStringArray("mfmp_2026-11-09_12-00-00_xxx_1aaad.lvl", "mfmp_2026-11-08_09-30-10_yyy_2bbbe.lvl")
```

- `files` 只存裸文件名，不存绝对路径（可搬迁、可导入导出）。
- 列表顺序 = 收藏顺序，新收藏**追加到末尾**，行为最接近现有版本。
- 读入时去重、过滤非 `.lvl`、过滤含路径分隔符的非法项。
- 写盘采用 `.tmp` + `rename` 原子替换（与 `script/edit/save_and_load/save_level.gd` 同款），避免写一半断电损坏。
- `version` 当前为 `2`；`1` 不存在（旧版根本没有索引），保留字段供以后演进。

### 2.3 不做的部分 [建议]

- 不做「每关一个元数据文件」：当前不需要额外元数据，单索引读写更简单、导出更省事。
- 不做「自动清理缺失关卡」：见 3.3。
- 不把截图移出收藏夹：截图在根目录会和关卡平铺混淆，且导入导出无法区分归属。

---

## 3. 旧版自动迁移 [已拍板]

### 3.1 触发时机

新增 autoload `LikedCourses`（**必须是 `.gd` 脚本，不能挂 `.tscn`**，否则静态类型退化成 `Node`），在 `_ready()` 里同步执行 `migrate_legacy()`。

- 同一文件系统内的 `rename` 是 O(1)，即使上百个收藏也是瞬间完成，不需要线程。
- 迁移必须**幂等**：每次都扫一遍收藏夹，不靠「有 cfg 就跳过」，防止上次迁移中途崩溃留下半成品。
- 迁移过程中每一步写 `Log.i` / `Log.w`（工程日志必须走 `Log` 单例），最后汇总一条「迁移 N 个收藏」。

### 3.2 算法

```text
migrate_legacy():
    ensure_dir("user://liked courses")
    changed = false
    for f in 收藏夹下的 *.lvl:
        if FileAccess.file_exists("user://" + f):
            # 根目录已有正本：保留正本，丢弃旧副本（绝不反向覆盖）
            DirAccess.remove("liked courses/" + f)
            Log.i("LikedCourses", "迁移：根目录已存在同名关卡，删除旧副本 " + f)
        else:
            err = rename("liked courses/" + f → "user://" + f)
            if err != OK:
                # 兜底：读字节写入根目录，成功后再删副本
                copy_bytes(...)
                删除副本
            Log.i("LikedCourses", "迁移：收藏副本移回根目录 " + f)
        add_to_index_if_absent(f)
        changed = true
    if changed: save_index()
```

### 3.3 关键规则

| 场景 | 处理 |
| --- | --- |
| 根目录有同名 `.lvl` | **保留根目录那份**，删除收藏夹副本；索引照常登记 |
| 根目录没有同名 `.lvl` | 把副本 `rename` 回根目录，然后登记索引（同关不再出现在收藏夹） |
| `rename` 失败 | 复制字节 + 校验 + 删副本；仍失败则 `Log.e` 并保留副本，下次启动重试 |
| `.png` | 原地保留，不参与迁移 |
| 索引里登记的关卡文件缺失 | **不删索引**，加载列表时跳过 + `Log.w`（防云同步/网盘临时缺失误删收藏） |
| 索引里重复条目 | 读入时去重 |
| 迁移期间用户强制关闭 | 下次启动重跑，已迁移的文件不满足「收藏夹里有 `.lvl`」，天然跳过 |

---

## 4. 代码结构

### 4.1 新增 `LikedCourses` autoload [已拍板]

文件：`script/history/liked_courses/liked_courses_store.gd`
注册（`project.godot` 的 `[autoload]`，必须指向 `.gd`）：

```ini
LikedCourses="*res://script/history/liked_courses/liked_courses_store.gd"
```

接口：

```gdscript
func get_files() -> Array[String]          # 读索引，去重 + 合法性过滤（纯读，可在工作线程调用）
func is_liked(file_name: String) -> bool
func add(file_name: String) -> void        # 幂等；已存在则只刷新索引，不重复
func add_many(names: Array[String]) -> int # 返回本次真正新增的条数
func remove(file_name: String) -> void
func level_path(file_name: String) -> String   # user://<file>；不存在时回退 liked courses/<file>（迁移兜底）
func photo_path(file_name: String) -> String   # user://liked courses/<base>.png
func migrate_legacy() -> void
```

实现注意：

- 文件名校验统一走字符串检查（必须以 `.lvl` 结尾，且不含 `/`、`\`、`:`、`..`），拒绝路径成分。
- 选择字符串检查而不是共享 `RegEx` 对象，是为了让 `get_files()` 能在收藏列表的工作线程里安全调用。
- `add()` / `remove()` 采用「重新读盘 → 合并/删除 → 原子写」；**[建议]** 这样多开实例同时收藏不同关卡时不会互相覆盖索引。
- 索引读写失败一律 `Log.e`，返回空列表而不是崩溃。

### 4.2 调用点改造 [已拍板]

| 文件 | 改动 |
| --- | --- |
| `script/history/take_photo.gd` | 删掉复制 `.lvl` 的分支与 `FileAccess` 兜底复制；只保存 `.png` + `LikedCourses.add(path.get_file())`；「是否已收藏」用 `LikedCourses.is_liked()` 判断，不再 `path.contains("liked courses")` |
| `load_liked_courses.gd` | 改读 `LikedCourses.get_files()`；`user://` 下不存在的条目跳过并 `Log.w`；**非 Web 平台**在工作线程读索引、只写 Mutex 保护的共享字段，主线程 `_process` 轮询后再建卡片；**Web 平台**直接在 `_ready` 里主线程读索引后建卡片 |
| `history_level_file_path_set_button.gd` | `level_path_name = LikedCourses.level_path(level_file_name_label.text)` |
| `unlike_button.gd` | 只做 `LikedCourses.remove(name)` + 删 `LikedCourses.photo_path(name)`；**不删原 `.lvl`**；封面路径改用 `get_basename()` 派生 |
| `capture_texture_setter.gd` | 封面异步加载改为「工作线程只写 Mutex 保护的 `PhotoLoadContext`，主线程 `_process` 轮询应用纹理」；不再在线程里 `call_deferred` 回调节点；**Web 平台**直接主线程同步加载 |
| `history_level_list.gd` | 非 Web 平台保持工作线程扫描；**Web 平台**主线程同步扫描；扫描结果为 0 时不再隐藏加载提示，改为把 `no_file_hint_label` 的文案换成「未找到历史关卡。」 |
| `liked_course_preview.gd` | 不改（`level_file_path.get_file().get_basename()` 对新路径同样成立） |
| `object/history/take_photo.tscn` | 不改（信号、音效不变） |

### 4.3 空列表提示

- 加载提示 `LoadingLabel` 仍是房间里那个节点，两个列表脚本通过导出引用 `no_file_hint_label` 绑定它（`room/history.tscn` / `room/liked_course_room.tscn` 里配 NodePath）。
- 历史列表：扫描结果为空 → 文案改为「未找到历史关卡。」并保持可见，同时**不 emit `all_files_loaded`**，跳过原「隐藏提示」的连线。
- 收藏列表：索引为空，或索引条目对应的关卡文件全部缺失（`loaded_count == 0`）→ 显示「未找到喜欢的关卡。」。
- 有关卡时行为不变：正常建卡并 emit `all_files_loaded`，由 `ControlVisibieSet` 隐藏提示。

---

## 5. 导出：五模式弹窗 [已拍板]

### 5.1 交互

点击导入/导出面板上的「导出」图标后，**先弹模式选择面板**，不直接弹系统文件框：

```
选择导出模式
├─ 导出所有关卡（含收藏）+排除关卡+随心挑战存档数据
├─ 导出所有关卡（含收藏）+排除关卡
├─ 导出所有关卡（含收藏）
├─ 仅导出收藏的关卡
├─ 仅导出所有关卡
└─ 取消
```

选完模式 → 关闭弹窗 → 异步 `export_levels(mode)` → 系统保存框 → 统一调用 autoload `Notice.show_notice()` 弹出结果通知（不再用场景内自建的 `ImportExportHint` 面板）。
「取消」或文件框取消时不产生任何文件，提示「导出已取消」。

### 5.2 模式定义

```gdscript
enum ExportMode {
    ALL_WITH_LIKED,          # 原有模式 1
    LIKED_ONLY,              # 原有模式 2
    ALL_ONLY,                # 原有模式 3
    ALL_WITH_LIKED_RAID,     # 新模式 1
    ALL_WITH_LIKED_EXCLUDED, # 新模式 2
}
```

| 模式 | zip 内容 | 失败前置条件 |
| --- | --- | --- |
| 新 1 全部 + 存档 | 全部 `*.lvl` + 收藏索引/封面 + `raid_excluded.cfg` + `raid_saves.cfg` | 根目录无 `.lvl` |
| 新 2 全部 + 排除 | 全部 `*.lvl` + 收藏索引/封面 + `raid_excluded.cfg`（**不写** `raid_saves.cfg`） | 根目录无 `.lvl` |
| 1 所有关卡 + 收藏 | 根目录全部 `*.lvl`（平铺）+ `liked_courses.cfg`（若有收藏）+ `liked_courses/<base>.png`（仅收藏封面） | 根目录无 `.lvl` |
| 2 仅收藏 | 索引引用且根目录存在的 `*.lvl`（平铺）+ `liked_courses.cfg`（只列实际打包的）+ `liked_courses/<base>.png` | 索引为空，或引用关卡全部缺失 |
| 3 仅所有关卡 | 根目录全部 `*.lvl`（平铺）；**不写 cfg、不写 png** | 根目录无 `.lvl` |

两个新模式的随心挑战数据取自 `user://adventure.ini` 的内存副本：
- `raid_excluded.cfg`：`[level.*]` 中 `excluded=true` 的记录（只带 `file` / `excluded` / `exclude_reason` / `excluded_at`，不打包单人样本统计），加 `[raid] kind=excluded`。
- `raid_saves.cfg`：`[run.1]`…`[run.5]` 的完整键，加 `[raid] kind=saves`。
- 排除关卡本身已经是 `user://` 根目录里的 `.lvl`，随「所有关卡」一起打包，这里额外带的是**名单与进度数据**。
- 两个 cfg 都平铺在 zip 根目录，用 `[raid] kind` 防串用；名单为空 / 存档位全空时仍写一个只含 `[raid]` 段的 cfg，方便从包名区分模式。

### 5.3 打包规则

1. `.lvl` **平铺在 zip 根目录**：与旧包、`level_transfer_service` 的「只认 `user://` 根目录」约束保持一致。
2. 封面统一放 `liked_courses/` 子目录，**不能平铺**：否则模式 1 无法区分「收藏封面」与无关 png，导入也无从归属。
3. 模式 1/2 写入 zip 的 cfg 必须是**实际打包关卡集合与索引的交集**（缺失项剔除），保证包自洽；模式 1 没有收藏时不写 cfg、不建 `liked_courses/`（此时内容等同模式 3）。
4. 缺失的收藏关卡跳过，成功提示附「已跳过 N 个」；返回值仍以「导出成功」开头，`_update_export_ui()` 的前缀判定不受影响。
5. zip 默认名按模式区分：
   - 新模式 1：`<device>_mfmp_all_liked_raid_(<earliest>_to_<latest>).zip`
   - 新模式 2：`<device>_mfmp_all_liked_excluded_(<earliest>_to_<latest>).zip`
   - 模式 1：`<device>_mfmp_all_liked_(<earliest>_to_<latest>).zip`
   - 模式 2：`<device>_mfmp_liked_(<earliest>_to_<latest>).zip`
   - 模式 3：`<device>_mfmp_history_(<earliest>_to_<latest>).zip`
6. 日期仍从参与打包的 `.lvl` 文件名提取（`\d{4}-\d{2}-\d{2}`）；一个都提取不到时退回**当天日期**，不再直接报失败。
7. cfg 写入 zip 时用 `ConfigFile.encode_to_text()` 生成文本，不落临时文件。

### 5.4 弹窗实现 [建议]

- 内嵌进共用的 `object/level_import_export.tscn`（历史房间与收藏房间都实例化它，无需各改一次）。
- 结构参照 `ui/notice_panel.tscn`：全屏 `Control`（`mouse_filter=0` 吃掉点击）+ `CenterContainer` + `UiPanel/UiMarginContainer/VBoxContainer`，标题 + 4 个按钮。
- 按钮沿用 `ui/ui_button.tscn`（`focus_mode=0`，符合工程「按钮不接收键盘焦点」的约定）。
- `import_export_manager.gd` 新增 `_on_export_mode_selected(mode)`，弹窗按钮 `pressed` 连线到该方法；导入按钮逻辑不变。

---

## 6. 导入：自动分流 + 旧包转换 [已拍板]

### 6.1 入口不变

导入仍是一个按钮、自动识别包格式；**不需要用户选模式**。
房间差异只影响「无索引旧包」的判定，见 6.4。

### 6.2 条目路由

| zip 条目 | 落点 | 说明 |
| --- | --- | --- |
| 平铺裸 `.lvl`（无路径成分） | `user://<file>` | 已存在同名则**跳过不覆盖**；计入 `imported_lvls` |
| `liked_courses/<base>.png` | `user://liked courses/<base>.png` | 覆盖旧封面 |
| `liked_courses.cfg` | **不直接落盘**，只解析内容 | 用实际文件重建索引，防脏清单 |
| `raid_excluded.cfg` | **不直接落盘**，合并进 `user://adventure.ini` | 校验 `[raid] kind=excluded`；排除名单只增不减，本机已排除的关卡保留原 `exclude_reason` / `excluded_at` |
| `raid_saves.cfg` | **不直接落盘**，按槽位合并进 `user://adventure.ini` | 校验 `[raid] kind=saves`；`[run.1]`…`[run.5]` 整段写回，已有进行中团的槽位跳过并记日志，不覆盖本地进度 |
| 其他（子目录、`..`、盘符、可执行文件等） | 拒绝 + `Log.w` | 顺带修掉现有 `target + file_name` 拼接的路径隐患 |

随心挑战 cfg 也计入导入成功条目；恢复数量附在成功提示末尾（`恢复排除 N / 存档 M`）。旧包（没有这两个 cfg）行为完全不变。

### 6.3 收藏重建规则（关键修正）

模式 1 的 zip 里**所有**关卡都在，如果「包里有 `.lvl` 就收藏」，会把整包历史误判成收藏。因此以**包内 cfg 为准**：

```text
has_cfg = zip 内含 liked_courses.cfg
if has_cfg:
    候选 = 解析 cfg 的 files（正则过滤、去重）
    收藏 = 候选 ∩ (包内落地的 lvl ∪ 本机已存在的同名 lvl)
elif is_liked_room:
    收藏 = 包内落地的全部 lvl        # 旧收藏包 → 自动转换
else:
    收藏 = 空                        # 旧历史包 → 只导关卡
LikedCourses.add_many(收藏)          # 并集合并，不清空本机已有收藏
```

- `cfg` 里的条目即使没打进包、但本机已有同名文件，也照样登记（支持「只发索引」的极端包）。
- 合并语义：导入只增不删；用户要取消收藏仍走卡片上的「取消收藏」。
- 返回值示例：`导入成功：12 个文件（新增收藏 3）`。

### 6.4 旧版本兼容矩阵

| zip 来源 | 导入历史房间 | 导入收藏房间 |
| --- | --- | --- |
| 旧历史包（平铺 lvl，无 cfg） | 关卡落根目录，收藏不变 | 关卡落根目录，**全部登记为收藏**（房间选择即用户意图） |
| 旧收藏包（平铺 lvl + 平铺 png，无 cfg） | 关卡落根目录，收藏不变（png 落根目录，与旧行为一致） | 关卡落根目录 + 全部登记收藏 + png 移入收藏夹 = **自动转换** |
| 模式 1 包（lvl + cfg + `liked_courses/*.png`） | 关卡 + 收藏一起恢复 | 同左 |
| 模式 2 包 | 收藏关卡 + 收藏恢复 | 同左 |
| 模式 3 包（仅 lvl） | 只导关卡 | 全部登记为收藏（与旧历史包同规则） |
| 新模式 1 包（全部 + 收藏 + 随心挑战数据） | 关卡 + 收藏 + 排除名单 + 存档 | 同左 |
| 新模式 2 包（全部 + 收藏 + 排除名单） | 关卡 + 收藏 + 排除名单 | 同左 |

**[风险]** 若用户把旧历史包误导入收藏房间，整包都会变成收藏。这是「房间即意图」的代价；不额外做文件名启发式判断（老包命名不可靠）。

### 6.5 反方向降级

新模式 zip 被**旧版本**游戏导入时：

- 平铺 `.lvl` 仍能落地（旧历史/收藏导入逻辑都按平铺处理）；
- `liked_courses/*.png`、`liked_courses.cfg`、`raid_*.cfg` 会被旧代码忽略或当作非法条目拒绝（提示里多算几个「跳过」），不崩溃；
- 旧版收藏房间导入模式 1 包时，会把所有关卡复制进收藏夹——即旧行为，可接受。

---

## 7. 改动清单

### 7.1 新增

| 文件 | 内容 |
| --- | --- |
| `script/history/liked_courses/liked_courses_store.gd` | autoload `LikedCourses`：索引读写、add/remove、路径解析、旧版迁移 |
| `script/ui/quick_fade_in.gd` | `QuickFadeIn`：贴图异步到位时的快速淡入（见 11.1） |
| `docs/liked_courses/README.md` | 本文档 |

### 7.2 修改

| 文件 | 内容 |
| --- | --- |
| `project.godot` | `[autoload]` 增加 `LikedCourses`（指向 `.gd`） |
| `script/history/take_photo.gd` | 去复制、改登记索引 |
| `script/history/liked_courses/load_liked_courses.gd` | 数据源改为索引 |
| `script/history/liked_courses/unlike_button.gd` | 只删索引 + 封面，不碰原关卡 |
| `script/history/history_level_file_path_set_button.gd` | 路径经 `LikedCourses.level_path()` |
| `script/history/import_export_manager.gd` | `ExportMode` 枚举、五模式导出、条目化安全导入、旧包分流；两个新模式附带 `raid_excluded.cfg` / `raid_saves.cfg`，导入侧按名单与存档位非破坏性合并 |
| `object/level_import_export.tscn` | 内嵌 `ExportModeDialog`（标题 + 5 模式 + 取消，面板加宽到 1200），接按钮信号 |
| `i18n/mfmp_translation.zh_CN.po` / `.en.po` / `.ja.po` | 新增：`选择导出模式`、5 个模式按钮、`取消`、`未找到历史关卡。`、`未找到喜欢的关卡。` |

### 7.3 不改

- `script/history/liked_courses/capture_texture_setter.gd`
- `script/history/liked_courses/liked_course_preview.gd`
- `object/history/take_photo.tscn`
- `script/multiplayer/0_core/services/level_transfer_service.gd`（迁移后收藏关卡都在 `user://` 根目录，白名单天然通过）

---

## 8. 边界与风险

| # | 风险 | 处理 |
| --- | --- | --- |
| 1 | 多开实例同时收藏/取消，索引互相覆盖 | `add()`/`remove()` 写前重读 + 合并；`[风险]` 极端并发仍有窗口，可接受 |
| 2 | 迁移时旧副本与根目录正本内容不同 | **永远保留根目录正本**，不比较、不覆盖，避免用旧快照冲掉玩家新数据 |
| 3 | 索引指向的关卡被删除 | 列表跳过 + 警告，不自动删索引；卡片不显示，用户无法从 UI 取消（如需清理见 9.1） |
| 4 | 收藏封面缺失 | 卡片显示空封面，不阻塞加载（现有行为） |
| 5 | 模式 1 包在旧版导入 | 关卡可用，收藏状态丢失，数据不损坏 |
| 6 | zip 条目带子目录/路径穿越 | 白名单正则 + 只取 basename，拒绝写盘 |
| 7 | 导入后收藏房间列表不刷新 | 现有实现只在 `_ready()` 扫描；`[建议]` 导入成功后调用列表重载，最低限度提示用户重进房间 |
| 8 | 索引文件名含大小写差异 | Windows 不敏感、其他平台敏感；沿用原文件名原样存取，不做大小写归一 |
| 9 | 离开收藏房间时封面还在异步加载 | 卡片先被释放，线程里 `call_deferred` 会报 `Cannot call method 'call_deferred' on a previously freed instance`。**规约：工作线程只写共享数据（Mutex 保护的 context），由主线程 `_process` 轮询应用，线程里不调用任何节点方法。** |
| 10 | Web 导出没有 Thread / WorkerThreadPool 线程支持 | 列表扫描与封面加载统一走 `OS.has_feature("web")` 分支：Web 主线程同步执行，其它平台保持多线程。不要无条件 `Thread.start()`，否则加载信号永远不触发、界面停在“读取中” |

---

## 9. 未决与后续

1. **同名 `.lvl` 导入冲突** [建议默认]：跳过不覆盖，只刷新 png。若玩家确实想用包内的同名文件覆盖，需要另做「强制覆盖」开关。
2. **收藏房间是否显示全部三种模式** [建议默认]：两个房间都显示三种（逻辑统一，代码不分支）；若嫌「导出所有关卡」出现在收藏房间别扭，可只在收藏房间保留模式 2。
3. **缺失收藏的清理入口**：可后续在收藏列表加「清理失效收藏」，一次性移除 `user://` 下不存在的条目，并回收孤儿 png。
4. **编辑已收藏关卡**：历史编辑保存会生成新文件名，收藏仍指旧关卡（与现有快照行为一致）。是否需要「另存后自动转为收藏」待定。
5. **导入完成后的列表刷新**：`load_liked_courses.gd` 增加 `reload()`（清空卡片 + 重新扫描），导入成功后调用。

---

## 10. 验证清单

### 10.1 迁移

- [ ] 全新 `user://`：收藏一关 → `liked courses/` 只有 `liked_courses.cfg` + `<base>.png`，**没有 `.lvl`**；卡片、游玩、查看均正常。
- [ ] 旧目录 3 个 `.lvl`（其中 1 个根目录已有同名正本）+ 3 个 png：启动后索引 3 条、副本全部消失、正本未被覆盖、png 完整。
- [ ] 迁移中途强杀进程，再次启动能继续完成（幂等）。
- [ ] 索引指向的文件被删除：列表跳过该卡片，无报错崩溃，其他卡片正常。
- [ ] 重复收藏同一关：索引不出现重复条目，封面被刷新。

### 10.2 导入导出

- [ ] 模式 1：zip 含平铺 `.lvl` + cfg + `liked_courses/*.png`；导入全新 profile 后关卡齐全且收藏恢复，收藏夹里没有 `.lvl`。
- [ ] 模式 2：zip 只含收藏关卡；导入后只恢复这些收藏。
- [ ] 模式 3：zip 不含 cfg / png；导入后无收藏。
- [ ] 模式 2 在「索引为空」时提示导出失败且不弹文件框。
- [ ] 旧收藏包（无 cfg）导入收藏房间 → 关卡落根目录 + 自动转为收藏 + 封面保留。
- [ ] 旧收藏包导入历史房间 → 只落关卡，不新增收藏。
- [ ] 新模式 1 包导入历史房间 → 关卡与收藏一起恢复（cfg 驱动）。
- [ ] 含 `../evil.lvl`、`a/b.lvl`、`a/b.png` 条目的 zip → 全部拒绝，`user://` 外无文件产生。
- [ ] 任一模式下取消文件框 → 无文件、无索引变化，提示「导出已取消」。
- [ ] 导入相同包两次 → 关卡不重复、收藏不重复、封面刷新，提示成功。

### 10.3 回归

- [ ] 历史列表仍正常扫描 `user://.lvl`（迁移把旧收藏副本移到根目录后，这些关卡出现在历史列表属预期）。
- [ ] 联机关卡传输（`level_transfer_service`）不受影响：收藏关卡路径仍是 `user://<file>`。
- [ ] `game_settings.cfg` 中的滚动条记忆（`liked_scroll` / `history_scroll`）不变。

---

## 11. 实施记录（2026-11-09）

已按本文完成代码落地：

| 项目 | 状态 |
| --- | --- |
| `LikedCourses` autoload + 索引读写 + 幂等迁移 | 完成 |
| 收藏/取消收藏/列表/卡片路径改造 | 完成 |
| 三模式导出 + 模式选择弹窗 | 完成 |
| 条目化安全导入 + 旧包自动转换 + `_import_zip` 解耦 | 完成 |
| 中/英/日 i18n 词条 | 完成 |

无头探针（Godot 4.6.1，隔离真实收藏夹后运行）验证通过：

- 6 个改动脚本全部加载成功；`level_import_export.tscn` 实例化成功，`export_mode_dialog` 绑定成功，模式按钮信号已连接。
- 索引写入 / 去重 / 移除、封面路径派生正确。
- 旧版 `.lvl` 副本迁移后：根目录存在、副本消失、索引已登记。
- 新版带索引 zip 导入：关卡与封面落地，只登记索引中且真实存在的收藏，缺失项不登记。
- 旧版平铺 zip 导入收藏房间：关卡落地 + 全部转为收藏 + 封面归档。
- 路径校验：`a/b.png`、`../a.png` 均被拒绝。

> 触屏/实机 UI（弹窗排版、文件对话框回传）未做自动化验证，需要手点一遍。

### 11.1 封面快速淡入（2026-11-14）

**问题**：封面 png 是异步读盘（工作线程解码 → 主线程 `_process` 应用纹理），拿到之后
`TextureRect.texture = ...` 是一次性赋值，画面在某一帧里**硬弹**出来。收藏房间卡片一多时，
几张封面会在不同帧先后跳出，很扎眼。

**做法**：新增 `script/ui/quick_fade_in.gd`（`class_name QuickFadeIn`，`RefCounted` 静态工具），
贴完纹理后调用 `QuickFadeIn.play(目标 TextureRect)`：

| 项 | 取值 / 行为 |
| --- | --- |
| 时长 | `DEFAULT_DURATION = 0.16s`（`TRANS_QUAD` + `EASE_OUT`） |
| 改动属性 | 只动 `modulate:a`，**不碰 `self_modulate`**（收藏卡片的悬停变色用的是它） |
| 重复调用 | 掐掉上一轮再从 0 重播，避免两条 tween 同时写 alpha |
| 目标释放 | 收尾回调先 `is_instance_valid`，列表重排/离开房间不会报错 |
| `duration <= 0` | 直接置 1，等价于关掉淡入 |

**接入点**（两条封面链路都接）：

- `script/history/liked_courses/capture_texture_setter.gd` → 收藏房间卡片的封面
- `script/history/liked_courses/liked_course_preview.gd` → 游玩/编辑器页左上角的关卡预览

**验证**：`tools/quick_fade_in_probe.tscn`（逐帧采样，要求出现 ≥2 个 0<alpha<1 的中间帧且单调不减）
与 `tools/cover_scripts_compile_probe.tscn`（六个脚本 + 两个场景的加载/实例化）均通过。
