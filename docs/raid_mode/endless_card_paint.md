# 无尽团存档卡：彩色油漆桶卡面

> 需求：百人团模式里，如果某个存档位是**无尽团**的存档，那么这个存档按钮内部显示为彩色
> （多颜色渐变油漆桶填充），并且会滚动。
>
> 落地日期：2026-11-14 ｜ 相关提交：`feat(adventure): rolling multi-color paint fill for endless save cards`

---

## 1. 效果

| 存档类型 | 卡面 | 描边 | 标题 |
| --- | --- | --- | --- |
| 定量团 / 随机档 | 白底（选中时整块填档位色） | 档位色 | 深色 |
| **无尽团** | **滚动的四色渐变（油漆桶），色带缓慢斜向流动 + 周期性高光扫过** | 档位色（选中加粗到 10px） | 白字 + 6px 深色描边 |
| 空槽 / 坏档 | 白底，整体淡化到 72% | 主题描边 | 深色 |

无尽团卡面**选中与未选中都是同一层彩色**，区别只在明度 / 饱和度与描边粗细——
不会像定量团那样被"选中填成纯色"盖掉。

---

## 2. 为什么不用 GDScript 直接动画 StyleBoxFlat

`StyleBoxFlat` 只有一个 `bg_color`，做不出渐变；用 `Tween` 循环改色只能整块变色，
做不到"多颜色渐变 + 滚动"。

现有工程里也没有可复用的现成实现：`shader/` 下 12 个 shader 里没有渐变流动类的。

因此新增一个专用 shader，把颜色计算整体放到 GPU，**每个存档卡每帧只有一次 draw call 的代价**。

---

## 3. 结构

```
Slot1 (Button)                     ← 样式表只画描边，底填充透明
├── Paint (ColorRect)              ← 本方案新增：滚动的彩色卡面
│   ├── material = shader/endless_paint_fill.gdshader（每张卡复制一份）
│   └── script   = script/adventure/adventure_slot_paint.gd
└── Content (VBoxContainer)
    └── Title (Label)
```

`Paint` 排在 `Content` **之前**，绘制顺序保证标题压在彩色之上。

| 文件 | 作用 |
| --- | --- |
| `shader/endless_paint_fill.gdshader` | 四色循环渐变 + 斜向流动 + 高光扫过 + 圆角 SDF 裁切 |
| `script/adventure/adventure_slot_paint.gd` | `AdventureSlotPaint`：同步像素尺寸与圆角、选中态明度、复制共用材质 |
| `script/adventure/adventure_save_slots.gd` | 按 `mode == "endless"` 开关 Paint、把样式表切成"透明底 + 档位色描边" |
| `object/ui/adventure_save_slots.tscn` | 五张卡各加一个 `Paint` 节点（`visible = false` 默认关） |

---

## 4. 关键实现细节

### 4.1 描边还在样式表，圆角在 shader 里切

`Control.clip_children` 只按**矩形**裁，切不出圆角；如果让 ColorRect 直接铺满再靠父节点裁，
四个角会露出直角。所以：

- ColorRect 按描边宽度**内缩 6px**（`offset_*` 在 .tscn 里写死，和 `_card_style` 的 border 宽度一致）；
- shader 里用圆角矩形 SDF 切出 `CARD_RADIUS_PX(10) - INSET_PX(6) = 4` 的圆角。

**改描边宽度时这两个数必须同步改**，否则内圈圆角对不上外圈描边，角上会露白边。

### 4.2 尺寸必须由脚本告诉 shader

卡片在 `HBoxContainer` 里 `size_flags_horizontal = 3` 均分宽度，窗口分辨率一变颜色相位就错。
`AdventureSlotPaint._sync_size()` 在 `_ready` / `resized` / `item_rect_changed` 时把
实测像素尺寸写进 `width_px`，色块大小因此与分辨率解耦。

探针里 `endless_paint_width=339` 就是 1920 宽窗口下实测到的卡面宽度。

### 4.3 材质必须每张卡复制一份

`.tscn` 里的 `ShaderMaterial` 是**共享资源**，五张卡引用同一个对象；
如果直接在 `_ready` 里改 `value_mul`，五张卡会被一起改。

`AdventureSlotPaint._ready()` 里 `shared.duplicate()` 一份再赋回去，
探针用 `endless_material_isolated=true` 守住这条。

### 4.4 关掉时不能只 `visible = false`

Paint 从无尽团切换成定量团时要同时撤掉：

- `Paint.visible = false`（`_set_paint_active`）
- 无尽团专用的字色与描边覆盖撤掉（`_clear_endless_text`）

否则同一个格子换团之后会留着上一套颜色，落在新卡面上可能完全看不见。
探针 `back_to_finite_title=f5fbff`（第 2 档样式表自带的字色）就是这条的回归点：
只要它还等于 `f5fbff`，就说明覆盖确实撤掉了。

---

## 5. 参数

全部在 `endless_paint_fill.gdshader` 顶部，可在编辑器里直接调：

| uniform | 默认 | 说明 |
| --- | --- | --- |
| `style` | 0 | 0 斜向色带 / 1 波浪 / 2 旋转色环 / 3 液态流动 / 4 双色扫光 |
| `band_soft` | 0.5 | 两色交界柔和度；0.5 = 各占一半柔和过渡，越小越窄越硬 |
| `color_a` ~ `color_d` | 蓝 → 紫 → 品红 → 珊瑚 | 四色循环，相邻两色插值 |
| `brush_px` | 210 | 一个完整四色周期的波长（像素），越大色块越宽 |
| `angle_deg` | 34 | 色带倾角，0 = 竖直条纹，90 = 水平波纹 |
| `scroll_speed` | (30, -12) | 每秒推进像素；滚动的来源就是它乘 `TIME` |
| `gloss` | 0.12 | 顶部玻璃高光，"油漆未干"的湿润感，0 = 关闭 |
| `sheen_period` / `sheen_strength` | 5.0 / 0.0 | 白光扫过周期与强度，默认关闭 |
| `value_mul` / `saturation` | 1.0 / 1.0 | 由脚本按选中态写入，**不要在编辑器里改** |
| `width_px` / `corner_radius_px` | 339×76 / 4 | 由脚本写入，**不要在编辑器里改** |

### 5.1 配色怎么定的（两次都错过的弯路）

**第一版：红 / 黄 / 蓝 / 绿四原色 → 否掉。** 这套 UI 是浅灰白底 + 细描边的轻量风格，
四个高饱和原色同时出现像贴了张塑料纸，而且四色之间没有色相关系，眼睛找不到落点。

**第二版：蓝 → 紫 → 品红 → 珊瑚（色相连续）→ 也否掉。** 色相关系对了，但整体还是偏艳、偏"设计感"，
放在这排存档卡里仍然抢眼。

**当前版：低饱和彩虹压亮度、提明度的奶白变种（变种表里的 D5）。**
四色为 `#FBB3B8`（粉）/ `#FBEAB3`（浅黄）/ `#B1F1BE`（薄荷）/ `#B3D8FB`（天蓝），
由原始 D 组 `#E89AA0` / `#E8D69A` / `#9ADFA8` / `#9AC2E8` 统一做 **sat ×0.85、val ×1.08** 得到。
高明度低饱和让它不抢眼，又能与定量团的白卡明确区分。

配色是"放在真实界面上挑"的，不是看孤立色块定的。两个工具：

| 工具 | 作用 |
| --- | --- |
| `tools/endless_palette_stage_shot.tscn` | 四套整组候选（A/B/C/D）依次套到真实舞台上各截一张 |
| `tools/endless_variant_shot.tscn` | 以 C/D 为基准做亮度、饱和度微调，一次出 10 个变种 |

两者的做法都是改 `VARIANTS` 表里的 `[后缀, 基准组, 饱和度倍率, 明度倍率]`，改完重跑即可。

### 5.2 标题字色与卡面明度绑定

卡面配色一变，标题的可读性也会跟着变，这条容易漏：

| 卡面 | 标题 | 理由 |
| --- | --- | --- |
| 早期高饱和彩底 | 白字 + 6px 深色描边 | 深色字在艳色上看不清 |
| **当前 D5 奶白彩底** | **深色字 `#1A1A1F`，无描边** | 卡面本身够亮，白字靠描边反而像贴纸 |

所以 `ENDLESS_TEXT_COLOR` / `ENDLESS_TEXT_OUTLINE` / `ENDLESS_TEXT_OUTLINE_SIZE`
必须和配色一起考虑。**换配色时先看标题还读不读得清**，
`tools/endless_title_shot.tscn` 会把四种字色方案各截一张做对比。

---

## 6. 验证

无头探针（`tools/adventure_stage_ui_probe.tscn`）新增了 7 段断言：

```text
endless_paint_present=true
endless_paint_active=true
finite_paint_off=true
endless_style_alpha=0          # 样式表透明，彩色由 Paint 出
endless_style_border=3f8c5a    # 描边仍是档位色（第 2 档 = 普通）
endless_title_dark=true       # 深色字，和奶白彩底拉开明度差
endless_title_outline=0       # 不靠描边，避免"贴纸感"
endless_selected_border=10     # 选中描边加粗，卡面不换纯色
endless_selected_paint=true
endless_paint_width=339        # 尺寸已同步给 shader
endless_material_isolated=true # 五张卡各用各的材质
back_to_finite_paint_off=true  # 换回定量团后彩色撤掉
back_to_finite_title=f5fbff    # 覆盖撤掉，回到样式表自带的字色
```

截图（窗口化，不加 `--headless`）：

```powershell
Godot --path "<工程根>" res://tools/adventure_stage_shot.tscn
```

`tools/adventure_stage.png` 里第三格现在是无尽团，卡面为彩色渐变；脚本最后还会再截一张
`tools/adventure_stage_endless.png`（选中无尽团存档3）。

滚动无法从单张静态图看出，验证办法是比同一张卡在两个时刻的像素差：
`adventure_stage_loading.png`（0.3s）与 `adventure_stage.png`（7s）里第三格区域的平均通道差为
**R 36.0 / G 25.3 / B 21.4（0~255）**，采样到 **183** 种不同颜色；定量团的卡片在同一区域完全没有变化。

---

## 7. 已知限制

- `Paint` 是 `ColorRect`（矩形），圆角全靠 shader 的 SDF；如果把 `Paint` 换成别的东西（例如 `NinePatchRect`），SDF 那段的坐标假设要一起改。
- 明度 / 饱和度的选中态是硬编码常量（`META_SELECTED_VALUE` 等），换配色时要一起调。
- 打印 / 截图工具拿到的静态图只能看出"颜色在变"，看不出"在滚"；要验证滚动得比对两张不同时刻的截图。
- `style` 1/2/3 是备选风格，目前只有 0 用在正式卡面上；切换风格后 5.1 里的配色规律不一定还成立（例如 2 旋转色环本身就会同时出现多色）。
