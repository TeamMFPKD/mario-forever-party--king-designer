extends Node

@export var canvas_layer: CanvasLayer

func fold_paper():
	if not canvas_layer:
		return
	
	var tween = create_tween().set_parallel(true)
	# 1. X 轴逐渐缩小到接近 0，保留微小值避免行列式为零
	tween.tween_property(canvas_layer, "scale:x", 0.001, 0.3).set_ease(Tween.EASE_IN_OUT)
	# 2. Y 轴略微压扁（可选，增强立体感）
	tween.tween_property(canvas_layer, "scale:y", 0.5, 0.3).set_ease(Tween.EASE_IN_OUT)
	# 3. 添加切变（skew），使纸片倾斜，模拟翻折
	# 通过修改 transform.y.x 实现水平切变
	var start_skew = canvas_layer.transform.y.x
	tween.tween_method(func(progress): 
		var t = canvas_layer.transform
		t.y.x = start_skew + (0.8 * progress)   # 逐渐增加倾斜
		canvas_layer.transform = t
	, 0.0, 1.0, 0.3)
	# 4. 淡出
	tween.tween_property(canvas_layer, "modulate:a", 0.0, 0.3)
	
	await tween.finished
	canvas_layer.visible = false
