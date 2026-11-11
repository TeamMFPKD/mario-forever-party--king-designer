class_name ItemOutline
extends RefCounted

## 把道具贴图烘成「带黑色外描边」的版本。
## 做法：整图 alpha 做分离式膨胀得到外扩剪影，再对剪影做两遍 3×3 平滑去掉台阶，
## 最后按「原图 over 描边」正确混合。相比在 SVG 里给每个 path 加 stroke，
## 整图外扩不会在多层图形内部叠出黑线。

const OUTLINE_COLOR: Color = Color(0.05, 0.05, 0.05, 1.0)
const SMOOTH_PASSES: int = 1


static func bake(
	source: Texture2D,
	display_size: int,
	outline_px: int,
	padding: int = 0
) -> Texture2D:
	if source == null:
		return null
	var image: Image = source.get_image()
	if image == null:
		return null
	var margin: int = outline_px + padding
	var inner: int = maxi(display_size - margin * 2, 8)
	var factor: float = float(inner) / float(maxi(image.get_width(), image.get_height()))
	var target_w: int = maxi(1, roundi(float(image.get_width()) * factor))
	var target_h: int = maxi(1, roundi(float(image.get_height()) * factor))
	image.resize(target_w, target_h, Image.INTERPOLATE_BILINEAR)
	image.convert(Image.FORMAT_RGBA8)

	var width: int = target_w + margin * 2
	var height: int = target_h + margin * 2
	var canvas: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(image, Rect2i(0, 0, target_w, target_h), Vector2i(margin, margin))

	var pixels: PackedByteArray = canvas.get_data()
	var alpha: PackedByteArray = PackedByteArray()
	alpha.resize(width * height)
	for index: int in range(width * height):
		alpha[index] = pixels[index * 4 + 3]

	# 横向膨胀
	var horizontal: PackedByteArray = PackedByteArray()
	horizontal.resize(width * height)
	for y: int in range(height):
		var row: int = y * width
		for x: int in range(width):
			var value: int = 0
			var from_x: int = maxi(0, x - outline_px)
			var to_x: int = mini(width - 1, x + outline_px)
			for sx: int in range(from_x, to_x + 1):
				value = maxi(value, alpha[row + sx])
			horizontal[row + x] = value

	# 纵向膨胀
	var vertical: PackedByteArray = PackedByteArray()
	vertical.resize(width * height)
	for y: int in range(height):
		for x: int in range(width):
			var value: int = 0
			var from_y: int = maxi(0, y - outline_px)
			var to_y: int = mini(height - 1, y + outline_px)
			for sy: int in range(from_y, to_y + 1):
				value = maxi(value, horizontal[sy * width + x])
			vertical[y * width + x] = value

	# 打散台阶：分离式膨胀出来的边是方形台阶，平滑两遍接近圆角
	var softened: PackedByteArray = _blur(vertical, width, height, SMOOTH_PASSES)

	# 合成：原图 over 描边
	var outline_r: int = int(round(OUTLINE_COLOR.r * 255.0))
	var outline_g: int = int(round(OUTLINE_COLOR.g * 255.0))
	var outline_b: int = int(round(OUTLINE_COLOR.b * 255.0))
	var out_data: PackedByteArray = PackedByteArray()
	out_data.resize(width * height * 4)
	for index: int in range(width * height):
		var offset: int = index * 4
		var src_alpha: float = float(alpha[index]) / 255.0
		var outline_alpha: float = float(softened[index]) / 255.0 * (1.0 - src_alpha)
		var total_alpha: float = src_alpha + outline_alpha
		if total_alpha <= 0.002:
			out_data[offset] = 0
			out_data[offset + 1] = 0
			out_data[offset + 2] = 0
			out_data[offset + 3] = 0
			continue
		out_data[offset] = clampi(
			roundi((float(pixels[offset]) * src_alpha + float(outline_r) * outline_alpha) / total_alpha),
			0, 255
		)
		out_data[offset + 1] = clampi(
			roundi((float(pixels[offset + 1]) * src_alpha + float(outline_g) * outline_alpha) / total_alpha),
			0, 255
		)
		out_data[offset + 2] = clampi(
			roundi((float(pixels[offset + 2]) * src_alpha + float(outline_b) * outline_alpha) / total_alpha),
			0, 255
		)
		out_data[offset + 3] = clampi(roundi(total_alpha * 255.0), 0, 255)

	var result: Image = Image.create_from_data(
		width, height, false, Image.FORMAT_RGBA8, out_data
	)
	return ImageTexture.create_from_image(result)


static func _blur(
	source: PackedByteArray,
	width: int,
	height: int,
	passes: int
) -> PackedByteArray:
	var current: PackedByteArray = source
	for pass_index: int in range(passes):
		var next: PackedByteArray = PackedByteArray()
		next.resize(width * height)
		for y: int in range(height):
			for x: int in range(width):
				var sum: int = 0
				var count: int = 0
				for dy: int in range(-1, 2):
					var ny: int = y + dy
					if ny < 0 or ny >= height:
						continue
					for dx: int in range(-1, 2):
						var nx: int = x + dx
						if nx < 0 or nx >= width:
							continue
						sum += current[ny * width + nx]
						count += 1
				next[y * width + x] = roundi(float(sum) / float(maxi(count, 1)))
		current = next
	return current
