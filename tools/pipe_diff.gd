extends Node

## 一次性比对：把 SVG 复刻版缩放到素材尺寸后逐像素对比，验证复刻精度。
## 运行：Godot --headless --path . res://tools/pipe_diff.tscn

const OUTPUT: String = "res://tools/pipe_diff_result.txt"


func _ready() -> void:
	var lines: Array[String] = []
	var webp_texture: Texture2D = load("res://sprite/ui/pipe/warp_pipe.webp") as Texture2D
	var svg_texture: Texture2D = load("res://sprite/ui/pipe/warp_pipe.svg") as Texture2D
	if webp_texture == null or svg_texture == null:
		lines.append("LOAD_FAIL webp=%s svg=%s" % [webp_texture, svg_texture])
	else:
		var source: Image = webp_texture.get_image()
		var target: Image = svg_texture.get_image()
		target.resize(source.get_width(), source.get_height(), Image.INTERPOLATE_BILINEAR)
		var width: int = source.get_width()
		var height: int = source.get_height()
		var total: float = 0.0
		var count: int = 0
		var worst: float = 0.0
		var worst_at: String = ""
		var over_40: int = 0
		for y: int in range(height):
			for x: int in range(width):
				var a: Color = source.get_pixel(x, y)
				var b: Color = target.get_pixel(x, y)
				if a.a < 0.5 and b.a < 0.5:
					continue
				var diff: float = maxf(
					absf(a.r - b.r),
					maxf(absf(a.g - b.g), absf(a.b - b.b))
				) * 255.0
				total += diff
				count += 1
				if diff > 40.0:
					over_40 += 1
				if diff > worst:
					worst = diff
					worst_at = "x=%d y=%d src=(%d,%d,%d) svg=(%d,%d,%d)" % [
						x, y, a.r8, a.g8, a.b8, b.r8, b.g8, b.b8
					]
		lines.append("size=%dx%d" % [width, height])
		lines.append("pixels=%d" % count)
		lines.append("avg_diff=%.2f" % (total / maxf(float(count), 1.0)))
		lines.append("worst_diff=%.2f %s" % [worst, worst_at])
		lines.append("pixels_over_40=%d (%.2f%%)" % [
			over_40, 100.0 * float(over_40) / maxf(float(count), 1.0)
		])
		lines.append("--- rows with largest diff ---")
		var rows: Array[String] = []
		for y: int in range(height):
			var row_sum: float = 0.0
			var row_count: int = 0
			for x: int in range(width):
				var a: Color = source.get_pixel(x, y)
				var b: Color = target.get_pixel(x, y)
				if a.a < 0.5 and b.a < 0.5:
					continue
				row_sum += maxf(
					absf(a.r - b.r),
					maxf(absf(a.g - b.g), absf(a.b - b.b))
				) * 255.0
				row_count += 1
			if row_count > 0:
				rows.append("y=%d avg=%.1f" % [y, row_sum / float(row_count)])
		var sorted: Array[String] = rows.duplicate()
		sorted.sort_custom(func(a: String, b: String) -> bool: return a.get_slice("avg=", 1).to_float() > b.get_slice("avg=", 1).to_float())
		for index: int in range(mini(12, sorted.size())):
			lines.append(sorted[index])
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	get_tree().quit()
