class_name PipeTint
extends RefCounted

## 把水管素材的绿色换成目标主色：只做色相旋转 + 饱和度/亮度缩放。
## 黑描边与白色高光的饱和度接近 0，几乎不受影响，明暗结构原样保留。
## 供 tools/title_design/scheme_f_pipe.gd 与 tools/pipe_tint_preview.gd 共用。

static func variant(source: Image, target: Color, source_main: Color) -> ImageTexture:
	var hue_shift: float = target.h - source_main.h
	var sat_scale: float = target.s / maxf(source_main.s, 0.001)
	var val_scale: float = target.v / maxf(source_main.v, 0.001)
	var width: int = source.get_width()
	var height: int = source.get_height()
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y: int in range(height):
		for x: int in range(width):
			var color: Color = source.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			image.set_pixel(
				x,
				y,
				Color.from_hsv(
					fposmod(color.h + hue_shift, 1.0),
					clampf(color.s * sat_scale, 0.0, 1.0),
					clampf(color.v * val_scale, 0.0, 1.0),
					color.a
				)
			)
	return ImageTexture.create_from_image(image)
