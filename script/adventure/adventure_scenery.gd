class_name AdventureScenery
extends Control

## 百人团舞台的景物层：按难度档撒一组**单色剪影**（SVG），只摆在关卡路线上下两侧。
##
## 规则（第一版，规则还在补充中）：
##   简单 → 云 / 灌木（A01 A03 A04 A06）
##   普通 → 圆树（C05 C07）
##   困难 → 台地 / 平顶山（B04 B05 B06 B07）
##   超难 → 标准六边形（F01），自带淡入淡出呼吸
##   随机 → 不画景物
##
## 布局：除超难外，景物不得与 level_node（关卡椭圆）重叠——生成时做拒绝采样，
## 摆不下就少放一件。超难允许重叠，因为它会不断换位置。
##
## 入场：难度切换时由舞台调用 switch_in()，各档动画不同（见该方法注释）。
##
## 全部是单色剪影：SVG 本身是纯白填充，这里只改 modulate 换成墨色或白色，
## 不描边、不叠色。sprite 原点落在剪影底边中点，摇摆就是绕基部转。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const SHAPE_DIR: String = "res://sprite/ui/adventure/scenery/"
const WIPE_SHADER: Shader = preload("res://shader/adventure_scenery_wipe.gdshader")

## 每档的剪影池：档位 1..4，0 = 随机（不画）。
const TIER_SHAPES: Array = [
	[],  # 0 随机
	[    # 1 简单：云与灌木，圆软、无攻击性
		"cloud_three.svg",
		"cloud_tall.svg",
		"bush_low.svg",
		"bush_tall.svg",
	],
	[    # 2 普通：两株圆树
		"tree_wide.svg",
		"tree_tall.svg",
	],
	[    # 3 困难：台地和平顶山，硬朗的地形块
		"terrace_three.svg",
		"terrace_two.svg",
		"plateau_wide.svg",
		"plateau_tall.svg",
	],
	[    # 4 超难：标准六边形，只有一种
		"hexagon.svg",
	],
]

## 单件高度（像素）：按档位调整。困难的块状地形本来就宽，尺寸压小一点，
## 才不至于几条就把面板糊满。
const TIER_SIZE: Array = [0.0, 64.0, 92.0, 74.0, 78.0]
## 同一档内的尺寸抖动倍数
const SIZE_JITTER: Vector2 = Vector2(0.78, 1.22)
## 密度：每件平均占多少平方像素。数字越大越稀。
## 困难档刻意放得比其他档稀很多：块状地形体量大，铺满会压住关卡路线。
const TIER_AREA_PER_ITEM: Array = [0.0, 46000.0, 46000.0, 150000.0, 46000.0]
## 每档的件数上下限（与上面的面积公式一起生效）
const TIER_ITEM_RANGE: Array = [
	Vector2i(0, 0),
	Vector2i(4, 16),
	Vector2i(4, 16),
	Vector2i(3, 7),
	Vector2i(4, 16),
]
## 摆放时给关卡椭圆留的额外安全边距
const AVOID_MARGIN: float = 14.0
## 拒绝采样次数：每件最多试这么多次摆放，全都压到关卡椭圆就退回随机位置
const PLACE_TRIES: int = 96
## 普通 / 困难档：景物之间至少留这么多空白
const SCENERY_GAP: float = 10.0
## 「这件放不下」的哨兵值
const PLACE_FAILED: Vector2 = Vector2(INF, INF)

## 入场动画的错峰间隔（秒）
const STAGGER: float = 0.045
## 困难档逐像素上推的总时长
const WIPE_SEC: float = 1.05
## 超难档呼吸：淡入 / 停留 / 淡出 的时长
const HEX_FADE_IN: float = 0.55
const HEX_HOLD: Vector2 = Vector2(1.4, 3.2)
const HEX_FADE_OUT: float = 0.55

var tint: Color = Color(0.11, 0.16, 0.27, 0.26):
	set(value):
		tint = value
		_apply_tint()
var seed_value: int = 20261115
var tier: int = 0:
	set(value):
		tier = value
		# 换档才算「难度切换」，要播入场；单纯尺寸变化只重建不重播。
		_pending_animate = true
		_queue_rebuild()

## 下次重建完成后是否播 switch_in
var _pending_animate: bool = true
## 舞台是否已经给过布局。没给之前不生成：否则会先按「不避让」撒一遍，
## 等 set_layout 到了再重建一次，既闪一下又白丢一次入场动画。
var _has_layout: bool = false

var _sways: Array[Dictionary] = []
var _tweens: Array[Tween] = []
var _time: float = 0.0
var _rebuilding: bool = false
## 已经排过一次重建就不再排，避免「换档 + 换布局」同一帧里重建两次、动画重播。
var _rebuild_queued: bool = false
var _generation: int = 0

## 关卡椭圆的占位矩形（本控件坐标系）。超难档不理会它。
var _avoid: Array[Rect2] = []
## 本批已经摆好的景物矩形：普通 / 困难档要求景物彼此不重叠，用它们做互斥。
var _placed: Array[Rect2] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_resized)


func _process(delta: float) -> void:
	_time += delta
	for item: Dictionary in _sways:
		var node: Node2D = item["node"] as Node2D
		if is_instance_valid(node):
			node.rotation = sin(_time * float(item["speed"]) + float(item["phase"])) * float(item["amp"])


func _on_resized() -> void:
	_queue_rebuild()


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


## 该档用哪几种剪影；随机档返回空数组。
static func shapes_for_tier(value: int) -> Array:
	if value < 0 or value >= TIER_SHAPES.size():
		return []
	return TIER_SHAPES[value]


# ---------------------------------------------------------------------------
# 布局
# ---------------------------------------------------------------------------

## 舞台把「关卡椭圆占位」传进来，本层按它避让。
func set_layout(avoid_rects: Array[Rect2]) -> void:
	_has_layout = true
	_avoid = avoid_rects
	# 只重排位置，不碰 _pending_animate：换档时它会保持 true，
	# 于是「换档 + 重排」合并成一次重建后仍然播入场动画。
	_queue_rebuild()


## 当前布局里,某个矩形是否压到关卡椭圆。
func _blocked(rect: Rect2) -> bool:
	for avoid: Rect2 in _avoid:
		if avoid.intersects(rect):
			return true
	return false


## 景物之间是否互斥：只有普通（2）与困难（3）要求彼此不重叠。
func _scenery_must_not_overlap() -> bool:
	return tier == 2 or tier == 3


## 是否压到本批已摆好的其他景物。
func _collides(rect: Rect2) -> bool:
	if not _scenery_must_not_overlap():
		return false
	for placed: Rect2 in _placed:
		if placed.intersects(rect):
			return true
	return false


func _rebuild() -> void:
	_rebuild_queued = false
	if _rebuilding:
		return
	_rebuilding = true
	_generation += 1
	_placed.clear()
	_clear()

	var pool: Array = shapes_for_tier(tier)
	if pool.is_empty() or size.x < 160.0 or size.y < 160.0 or not _has_layout:
		_rebuilding = false
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value

	var range_limit: Vector2i = TIER_ITEM_RANGE[clampi(tier, 0, TIER_ITEM_RANGE.size() - 1)]
	var area_per_item: float = float(TIER_AREA_PER_ITEM[clampi(tier, 0, TIER_AREA_PER_ITEM.size() - 1)])
	var target: int = clampi(
		int(size.x * size.y / maxf(area_per_item, 1.0)), range_limit.x, range_limit.y
	)
	for _index: int in range(target):
		var file: String = str(pool[rng.randi_range(0, pool.size() - 1)])
		var texture: Texture2D = load(SHAPE_DIR + file) as Texture2D
		if texture == null:
			continue
		_spawn(rng, texture)
	_apply_tint()
	_rebuilding = false
	if _pending_animate:
		_pending_animate = false
		switch_in()


## 摆一件景物；普通 / 困难档放不下时返回 null（宁可少放，也不许叠）。
func _spawn(rng: RandomNumberGenerator, texture: Texture2D) -> Node2D:
	var holder: Node2D = Node2D.new()
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	var target_h: float = float(TIER_SIZE[clampi(tier, 0, TIER_SIZE.size() - 1)])
	var base_scale: float = target_h / maxf(float(texture.get_height()), 1.0)
	base_scale *= rng.randf_range(SIZE_JITTER.x, SIZE_JITTER.y)
	var flip: float = -1.0 if rng.randf() < 0.5 else 1.0
	var base: Vector2 = Vector2(base_scale * flip, base_scale)
	sprite.scale = base
	# 原点挪到底边中点：摇摆、翻转都绕基部，剪影像「插在地上」。
	sprite.offset = Vector2(0.0, -float(texture.get_height()) * 0.5)
	holder.add_child(sprite)
	sprite.set_meta("base_scale", base)
	# 普通档的灰要「实」，抖动收窄，否则会褪成背景色的暗化版；
	# 困难档反过来，本来就压得更透，允许更大幅度的深浅变化。
	var alpha_pick: float = 1.0
	if tier == 2:
		alpha_pick = rng.randf_range(0.88, 1.0)
	elif tier == 3:
		alpha_pick = rng.randf_range(0.55, 1.0)
	else:
		alpha_pick = rng.randf_range(0.66, 1.0)
	sprite.set_meta("alpha_scale", alpha_pick)
	var pos: Vector2 = _pick_position(rng, texture, base)
	if pos == PLACE_FAILED:
		holder.free()
		return null
	holder.position = pos
	if _scenery_must_not_overlap():
		var half: Vector2 = Vector2(
			float(texture.get_width()) * absf(base.x), float(texture.get_height()) * base.y
		) * 0.5
		_placed.append(_rect_of(pos, half))
	add_child(holder)

	if rng.randf() < 0.42:
		_sways.append({
			"node": holder,
			"amp": rng.randf_range(0.012, 0.030),
			"speed": rng.randf_range(0.55, 1.05),
			"phase": rng.randf_range(0.0, TAU),
		})
	return holder


## 在上下两条带里随机取点；非超难档必须避开所有关卡椭圆。
func _pick_position(rng: RandomNumberGenerator, texture: Texture2D, base: Vector2) -> Vector2:
	var half: Vector2 = Vector2(
		float(texture.get_width()) * absf(base.x), float(texture.get_height()) * base.y
	) * 0.5
	var margin: float = 24.0
	var min_x: float = margin + half.x
	var max_x: float = size.x - margin - half.x
	if max_x <= min_x:
		min_x = size.x * 0.5
		max_x = min_x
	# 超难档（4）允许压住关卡椭圆：它一直在换位置，避让反而会显得拘谨。
	var allow_overlap: bool = tier >= 4
	# 剪影必须整件留在面板里：sprite 原点在底边中点，向上要占满整条高度。
	var full_h: float = half.y * 2.0
	var top_lo: float = minf(full_h + 4.0, size.y * 0.5)
	var top_hi: float = maxf(minf(size.y * 0.28, size.y - full_h - 4.0), top_lo)
	var low_lo: float = maxf(size.y * 0.72, top_hi)
	var low_hi: float = maxf(size.y - 4.0, low_lo)
	var fallback: Vector2 = Vector2(size.x * 0.5, top_lo)
	for _try: int in range(PLACE_TRIES):
		var top: bool = rng.randf() < 0.46
		var pos: Vector2 = Vector2(
			rng.randf_range(min_x, max_x),
			rng.randf_range(top_lo, top_hi) if top else rng.randf_range(low_lo, low_hi)
		)
		fallback = pos
		if allow_overlap:
			return pos
		# 贴地摆放：矩形按「底边中点 = pos」算，向上取高。
		var rect: Rect2 = Rect2(pos - Vector2(half.x, full_h), Vector2(half.x * 2.0, full_h))
		if _blocked(rect.grow(AVOID_MARGIN)):
			continue
		# 普通 / 困难档：景物彼此也不能叠。
		if _collides(rect.grow(SCENERY_GAP)):
			continue
		return pos
	# 普通 / 困难的互斥规则是硬性的：挤不下就干脆少放一件，也不许叠上去。
	if _scenery_must_not_overlap():
		return PLACE_FAILED
	return fallback


## 景物在面板里的占地矩形：原点在底边中点，向上取满高度。
func _rect_of(pos: Vector2, half: Vector2) -> Rect2:
	return Rect2(pos - Vector2(half.x, half.y * 2.0), Vector2(half.x * 2.0, half.y * 2.0))


# ---------------------------------------------------------------------------
# 入场动画
# ---------------------------------------------------------------------------

## 难度切换时的景物入场。
##   简单：整体缩放 0 → (1.0,1.2) → (1.2,1.0) → (1.0,1.0)，抖一下再稳住。
##   普通：横向保持，纵向 0 → 1.1 → 1，像从地里长出来。
##   困难：自下而上逐像素显示（shader 按屏幕纵向位置延迟），越靠上越晚。
##   超难：没有入场扩散，改为自身循环的淡入 / 淡出。
##   随机：没有景物，直接返回。
func switch_in() -> void:
	var items: Array[Node] = get_children()
	if items.is_empty():
		return
	match tier:
		1:
			for index: int in range(items.size()):
				_switch_in_bounce(items[index] as Node2D, index)
		2:
			for index: int in range(items.size()):
				_switch_in_grow(items[index] as Node2D, index)
		3:
			_prepare_wipe()
			for index: int in range(items.size()):
				_switch_in_wipe(items[index] as Node2D, index)
		4:
			for index: int in range(items.size()):
				_start_hex_breathe(items[index] as Node2D, _generation)
		_:
			pass


func _sprite_of(holder: Node2D) -> Sprite2D:
	if holder == null:
		return null
	for child: Node in holder.get_children():
		var sprite: Sprite2D = child as Sprite2D
		if sprite != null:
			return sprite
	return null


func _switch_in_bounce(holder: Node2D, index: int) -> void:
	var sprite: Sprite2D = _sprite_of(holder)
	if sprite == null:
		return
	var base: Vector2 = sprite.get_meta("base_scale", sprite.scale)
	sprite.scale = Vector2.ZERO
	var delay: float = float(index) * STAGGER
	var tween: Tween = create_tween()
	_tweens.append(tween)
	tween.tween_interval(delay)
	# 简单档：0 → (1.0,1.2) → (1.2,1.0) → (1.0,1.0)，像果冻抖一下再稳住。
	tween.tween_property(sprite, "scale", base * Vector2(1.0, 1.2), 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", base * Vector2(1.2, 1.0), 0.14) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", base, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _switch_in_grow(holder: Node2D, index: int) -> void:
	var sprite: Sprite2D = _sprite_of(holder)
	if sprite == null:
		return
	var base: Vector2 = sprite.get_meta("base_scale", sprite.scale)
	sprite.scale = Vector2(base.x, 0.0)
	var delay: float = float(index) * STAGGER
	var tween: Tween = create_tween()
	_tweens.append(tween)
	tween.tween_interval(delay)
	# 普通档：横向不动，纵向 0 → 1.1 → 1，像从地里顶出来。
	tween.tween_property(sprite, "scale", Vector2(base.x, base.y * 1.1), 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", base, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 困难档：给每件景物挂上同一套 wipe 材质，并把它在面板里的竖向区间写进 uniforms。
func _prepare_wipe() -> void:
	var height: float = maxf(size.y, 1.0)
	for holder: Node in get_children():
		var sprite: Sprite2D = _sprite_of(holder as Node2D)
		if sprite == null:
			continue
		var item: Node2D = holder as Node2D
		var half_h: float = float(sprite.texture.get_height()) * sprite.scale.y * 0.5 \
			if sprite.texture != null else 40.0
		var shader_material: ShaderMaterial = ShaderMaterial.new()
		shader_material.shader = WIPE_SHADER
		shader_material.set_shader_parameter("panel_y0", clampf((item.position.y - half_h * 2.0) / height, 0.0, 1.0))
		shader_material.set_shader_parameter("panel_y1", clampf(item.position.y / height, 0.0, 1.0))
		shader_material.set_shader_parameter("reveal", 0.0)
		sprite.material = shader_material


func _switch_in_wipe(holder: Node2D, index: int) -> void:
	var sprite: Sprite2D = _sprite_of(holder)
	if sprite == null or sprite.material == null:
		return
	var shader_material: ShaderMaterial = sprite.material as ShaderMaterial
	if shader_material == null:
		return
	var tween: Tween = create_tween()
	_tweens.append(tween)
	tween.tween_interval(float(index) * STAGGER * 0.5)
	tween.tween_method(
		func(value: float) -> void:
			shader_material.set_shader_parameter("reveal", value),
		0.0, 1.0, WIPE_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 超难档：每件六边形自己一直在淡入 → 停留 → 淡出，淡出后换个位置再淡入。
## gen 是生成批次号：换档重建后旧批的协程会看到批次不匹配，自动退出，
## 不会再去改新批的节点。
func _start_hex_breathe(holder: Node2D, gen: int) -> void:
	var sprite: Sprite2D = _sprite_of(holder)
	if sprite == null:
		return
	_hex_breathe(holder, sprite, gen)


func _hex_breathe(holder: Node2D, sprite: Sprite2D, gen: int) -> void:
	var alpha_scale: float = float(sprite.get_meta("alpha_scale", 1.0))
	var target_alpha: float = tint.a * alpha_scale
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	sprite.modulate.a = 0.0
	while is_instance_valid(holder) and is_instance_valid(sprite) and gen == _generation:
		# 每一轮淡入前先擺好位置：第一次淡入前、以及每次淡出之后都会走到这里。
		holder.position = Vector2(
			rng.randf_range(size.x * 0.06, size.x * 0.94),
			rng.randf_range(size.y * 0.12, size.y * 0.94)
		)
		var tween: Tween = create_tween()
		_track(tween)
		tween.tween_property(sprite, "modulate:a", target_alpha, HEX_FADE_IN)
		await tween.finished
		if not (is_instance_valid(holder) and gen == _generation):
			return
		await _wait(randf_range(HEX_HOLD.x, HEX_HOLD.y))
		if not (is_instance_valid(holder) and gen == _generation):
			return
		var fade_out: Tween = create_tween()
		_track(fade_out)
		fade_out.tween_property(sprite, "modulate:a", 0.0, HEX_FADE_OUT)
		await fade_out.finished
		if not (is_instance_valid(holder) and gen == _generation):
			return
		await _wait(randf_range(0.12, 0.45))


## 登记补间，同时在重建时统一 kill，避免旧补间改到已释放的节点。
func _track(tween: Tween) -> void:
	if tween == null:
		return
	_tweens = _tweens.filter(func(item: Tween) -> bool: return item != null and item.is_valid())
	_tweens.append(tween)


## 退出时的空窗：场景树没了就永远等下去会卡住协程，这里用帧循环兜住。
func _wait(seconds: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(seconds).timeout


# ---------------------------------------------------------------------------
# 配色与清理
# ---------------------------------------------------------------------------

func _apply_tint() -> void:
	for holder: Node2D in get_children():
		for child: Node in holder.get_children():
			var sprite: Sprite2D = child as Sprite2D
			if sprite == null:
				continue
			var alpha_scale: float = float(sprite.get_meta("alpha_scale", 1.0))
			var color: Color = tint
			color.a = tint.a * alpha_scale
			sprite.modulate = color


func _clear() -> void:
	_sways.clear()
	# 旧批的补间立刻掐掉，别让它继续去改已经被释放的 sprite。
	for tween: Tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	for holder: Node in get_children():
		remove_child(holder)
		holder.queue_free()
