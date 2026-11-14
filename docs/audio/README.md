# 音效重复触发策略（移植自 MFGTE）

> 2026-11-14 · 对应 `script/level/sound/continuous_audio_stream.gd`

## 1. 问题

关卡里几乎所有可交互对象都自带一个音效节点（`object/level/sound/sound_effect.tscn`，
被砖块、敌人、道具、弹簧、食人花、门、开关等 30+ 个场景实例化）。原先它们一律直接
`play()`，因此同一帧内多个对象同时触发**同一个音效**时会完全叠加：

- 一排砖同时被顶/碎 → `bump.se.wav` / `break.se.wav` 叠成一片噪音
- 连吃一串金币 → `coin.se.wav` 每一枚都起播，尾音互相踩踏，听感是"糊"
- 一群敌人同时被火焰球打中 → 同类死亡音叠加

MFGTE 已经解决了这个问题，MFMP 这边一直没有。本次把它移植过来。

## 2. 两种策略

```gdscript
enum RepeatPolicy {
    OVERLAP = 0,   # 叠加（默认）
    RESTART = 1,   # 重播截断
}
```

| | **OVERLAP**（叠加） | **RESTART**（重播截断） |
|---|---|---|
| 行为 | 允许叠加，但同资源并发超过上限后，新实例音量压到 `overflow_volume_db` | 新实例起播时**停掉**同资源的其它实例，只留最新这一击 |
| 适合 | 群体事件：一片砖同时碎、一群敌人同时被踩 | 连击音效：金币、顶砖、时间滴答 |
| 听感 | 不会整段静音，只是超出上限的那几次听不见 | 每次只听到最新一击，不叠成噪音也不断续 |
| 参数 | `max_same_stream_voices`（默认 8）、`overflow_volume_db`（默认 -60） | 无 |

**为什么不能只用 OVERLAP**：连吃金币时，前 8 枚正常、第 9 枚起被压成静音，
表现为"音效少了/断续"，比叠加更难受。所以高频连击型必须用 RESTART。

## 3. 统一轮询器

`AudioStreamPlayer` 没有"开始播放"信号，只能比对 `playing` 状态捕捉上升沿。
原先 GT 版给每个音效节点各写一个 `_Process`；MFMP 移植时改成**集中轮询**：

- `script/level/sound/audio_voice_poller.gd`——常驻 `SceneTree.Root` 下的单节点，
  每帧调用一次 `ContinuousAudioStream.poll_all_playback()`
- 首次有音效节点入场时按需创建（等同 autoload，但**不改 `project.godot`**）
- `ProcessMode` 保持 Inherit，与原先逐节点回调一样随暂停停止

代价是压制晚一帧生效（60Hz 下 ≤16ms，刚好落在音效起振段，听感无碍），
换来的是 1 个回调代替上百个。

> ⚠️ 轮询器脚本必须用运行时 `load` 而非 `preload`：`audio_voice_poller.gd` 里要调用
> `ContinuousAudioStream` 的静态方法，`preload` 会构成 A↔B 循环引用，两个脚本都解析失败。

## 4. 接入方式

新增 `object/level/sound/sound_effect_restart.tscn`——就是 `sound_effect.tscn` 的实例，
只改 `repeat_policy = 1`。要哪个音效走 RESTART，就把该节点的 `instance=` 指过去。

已接入：

| 场景 | 节点 | 音效 | 策略 |
|---|---|---|---|
| `block/coin.tscn` | CoinSound | coin.se.wav | **RESTART** |
| `block/question_block.tscn` | BumpSound | coin.se.wav | **RESTART** |
| `block/question_block.tscn` | BreakSound | break.se.wav | OVERLAP（默认） |

碎砖保留 OVERLAP 是刻意的：一排砖同时碎属于"群体事件"，叠加 + 上限压制正是想要的效果。

## 5. 保留的换关保护

MFMP 原有的 `ContinuousAudioStream` 逻辑**全部保留**（GT 版没有这部分）：

- 父节点退场时把实例搬到 `Viewport`，让正在播的一次性音效播完再释放
  （玩家死亡音等"起播即随父销毁"的音效靠这一手才听得见）
- 临时摘掉 `autoplay`，防止重新入树时从头再播一遍（旧音效"诈尸"）
- 主场景已卸载（切关/死亡重开）时一律 `queue_free`，不把上一关声音串到新场景

## 6. 验证

| 探针 | 断言 |
|---|---|
| `tools/audio_repeat_policy_probe.tscn` | OVERLAP 超限压制到 -60dB、停播后还原；RESTART 起播时旧实例 `playing=false` |
| `tools/audio_restart_wiring_probe.tscn` | 金币音/顶砖音 `repeat_policy=1`，碎砖音 `=0`，stream 均已设置 |

实测输出：

```
overlap_c_db=-60.0          overlap_c_suppressed=true
overlap_c_restored=true     overlap_all_playing=true
restart_a_playing_after=false   restart_cut_old=true
CoinSound_repeat_policy=1   BreakSound_repeat_policy=0
```
