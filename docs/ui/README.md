# UI 主题

项目里并存两套正式在用的 UI 主题，外加 `ui/theme/` 下若干未接入的探索稿。两套正式主题都保留，按场景语义选用。

## 1. 全局默认主题 `mfmp_theme.tres`

项目大部分界面（各 `room/*.tscn`、`ui/ui_button.tscn`、`ui/ui_label.tscn`、`ui/ui_line_edit.tscn`、多人消息气泡等 20 余处）挂的就是它。

项目设置里 `gui/theme/custom` 也指向本文件（`project.godot` 的 `[gui]` 段），因此**没有单独设 `theme` 的节点默认就是这套**，新界面一般不需要再显式挂主题。

| 项目 | 取值 |
|---|---|
| `default_font` | `FontVariation`：base `res://font/Super-Mario-Maker-2-NoHanzi.ttf`，fallbacks 指向 `res://font/ChuangKeTieJinGangTi-2.otf`（`variation_embolden = -0.5`、`baseline_offset = -0.05`） |
| `Label/colors/font_color` | `Color(1, 1, 1, 1)` 白色 |
| `Label/colors/font_outline_color` | `Color(0, 0, 0, 1)` 黑色描边 |
| `Panel/styles/panel` | **未定义**，走 Godot 内置 Panel 样式 |
| `Button/styles/normal` | `StyleBoxFlat`：白底、6px 深色边 `(0.169, 0.165, 0.157)`、圆角 10、content margin 32/16 |
| `Button/styles/hover` | 暖白底 `(1, 0.976, 0.902)` + 同款深色边 |
| `Button/styles/pressed` | 米灰底 `(0.937, 0.914, 0.851)` + 黄边 `(1, 0.773, 0.192)`，`content_margin_top` 20 / `bottom` 12 做出按压位移 |
| `Button/styles/disabled` | 灰米底 `(0.894, 0.863, 0.776)` + 灰边 `(0.71, 0.678, 0.608)` |
| `Button/styles/focus` | 不填充，6px 黄边、圆角 15、外扩 5px |
| `Button/colors/font_color` | `Color(0.169, 0.165, 0.157, 1)` 深棕；hover / pressed / focus 同色 |
| `Button/colors/font_disabled_color` | `Color(0.557, 0.525, 0.455, 1)` |
| `Button/font_sizes/font_size` | `36` |
| `Button/constants/outline_size` | `0`，按钮文字不带描边 |

要点：**白字 + 黑描边 + 内置 Panel**，拉丁与假名用马造 2，汉字全部由创客贴金刚体兜底。

> 为什么 base 不是原始的 `Super-Mario-Maker-2.ttf`：马造 2 是日版游戏字库，自带 6682 个汉字且用的是日本字形；而 Godot 的 `FontVariation.fallbacks` **只在缺码位时**才降级，`将`/`径`/`直`/`骨` 这类中日共用码位永远走不到创客，就会出现「同一个界面里一部分是中文形一部分是日文形」。因此另存了一份 `Super-Mario-Maker-2-NoHanzi.ttf`：由原版子集化而来，剔除 U+4E00-9FFF 与 U+F900-FAFF，保留拉丁/数字/假名/符号/全角标点（2.15 MB → 90 KB）。

## 2. 黄色顶部面板主题 `ui/theme/theme_yellow_top.tres`

给「黄色顶部色块」的卡片类面板用。

| 项目 | 取值 |
|---|---|
| `Panel/styles/panel`、`PanelContainer/styles/panel` | `StyleBoxTexture`，贴图 `ui/theme/borders/panel_yellow_top.svg`，`texture_margin` 四边 38，`content_margin` 左 26 / 上 36 / 右 26 / 下 22 |
| `Label/colors/font_color` | `Color(0.1, 0.1, 0.1, 1)` 深色（压在黄块上偏褐） |
| `Label/colors/font_outline_color` | `Color(0, 0, 0, 0)` 透明 |
| `Label/constants/outline_size` | `0`，即**无描边** |

要点：这套主题**本身不定义 `default_font`**，节点挂在它上面时字体仍从所在画布的全局主题继承，因此实际显示的依然是马造 2 + 金刚体 fallback。

目前该文件尚未被任何场景引用，属于已定稿待接入的状态。

## 字体资源 `font/ui_maker_font.tres`

给脚本动态创建的 `Label` 用（无法继承场景主题时）。内容与 `mfmp_theme.tres` 的 `default_font` 完全一致：

- base：`Super-Mario-Maker-2-NoHanzi.ttf`（剔除汉字的马造 2）
- fallbacks：`ChuangKeTieJinGangTi-2.otf` 的 `FontVariation`（`embolden = -0.5`、`baseline_offset = -0.05`）

例子：`script/title/pipe_button.gd` 的水管按钮标签。

**不要**直接 `preload` 裸 `.ttf` 再 `add_theme_font_override`——那样中文只能靠系统 fallback，换机器会变字形。

## 未接入的探索稿

`ui/theme/` 下另有 `theme_maker.tres`、`theme_dark_panel.tres`、`theme_glass_panels.tres`，以及 `panel_large.tres`、`panel_small.tres` 与 `borders/panel_double_84.svg`、`panel_double_92.svg`、`panel_glass.svg`。

这些是早期风格探索，目前没有任何场景引用，保留备查，不要直接删除。

## 选用约定

- 默认就是 `mfmp_theme.tres`（项目设置 `gui/theme/custom` 已全局引用），需要「白字黑边」的界面不要自己再套描边
- 需要「黄色顶块 + 深色无描边文字」的卡片，在 `Panel` / `PanelContainer` 上挂 `theme_yellow_top.tres`
- 脚本里动态创建文字统一用 `res://font/ui_maker_font.tres`
- 新增主题前先确认上面两套是否已经够用，避免再堆第三套
