class_name RoundTex
## Przycina teksturę do koła (border-radius 50%).
static var _cache: Dictionary = {}
static func circle(t: Texture2D) -> Texture2D:
	if t == null:
		return null
	var key := t.resource_path if t.resource_path != "" else str(t.get_instance_id())
	if _cache.has(key):
		return _cache[key]
	var img := t.get_image()
	if img == null:
		return t
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var cx := w * 0.5
	var cy := h * 0.5
	var r := minf(w, h) * 0.5
	for y in h:
		for x in w:
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d > r:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > r - 1.0:
				var c := img.get_pixel(x, y)
				c.a *= r - d
				img.set_pixel(x, y, c)
	var out := ImageTexture.create_from_image(img)
	_cache[key] = out
	return out
