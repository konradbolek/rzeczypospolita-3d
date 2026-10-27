class_name UnitArt
## Rysowane sylwetki jednostek (bez assetów). Współrzędne lokalne ~ -16..16.

const SKIN := Color(0.93, 0.76, 0.6)
const STEEL := Color(0.78, 0.8, 0.85)
const WOOD := Color(0.45, 0.3, 0.15)
const DARK := Color(0.1, 0.08, 0.06)

static func kind_of(unit_id: String) -> String:
	match unit_id:
		"enemy_p": return "piechota"
		"enemy_l": return "lucznicy"
		"enemy_j": return "jazda"
		"piechota", "lucznicy", "jazda", "arkebuzerzy", "dragonia", "husaria", "halabardnicy", "kusznicy", "lisowczycy": return unit_id
		"karolinska_piechota", "janczarzy", "strzelcy", "muszkieterowie", "kozacy": return "arkebuzerzy"
		"rajtarzy", "sipahi", "kirasjerzy": return "dragonia"
		"bojarzy", "molojcy": return "jazda"
		"wilk", "niedzwiedz": return unit_id
	return "piechota"


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


static func _horse(ci: CanvasItem, coat: Color) -> void:
	var o := coat.darkened(0.5)
	for x in [-8.0, -4.0, 5.0, 9.0]:
		ci.draw_line(Vector2(x, 4), Vector2(x, 13), o, 2.2)
	_ellipse(ci, Vector2(0, 3), 11, 5.5, coat)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(11, -8), Vector2(16, -6), Vector2(15, -3), Vector2(11, 3)]), coat)
	ci.draw_line(Vector2(-11, 1), Vector2(-15, 8), o, 2.0) # ogon
	ci.draw_line(Vector2(9, -6), Vector2(8, 0), o, 1.5) # grzywa


static func _rider(ci: CanvasItem, col: Color, y: float) -> void:
	ci.draw_rect(Rect2(-3, y - 9, 6, 9), col)
	ci.draw_circle(Vector2(0, y - 12), 3.0, SKIN)


static var _tex_cache: Dictionary = {}

## PNG z res://assets/units/<id>.png (najpierw unit_id, potem typ bazowy). null = brak.
static func texture_for(unit_id: String) -> Texture2D:
	for key in [unit_id, kind_of(unit_id)]:
		if _tex_cache.has(key):
			if _tex_cache[key] != null:
				return _tex_cache[key]
			continue
		var path := "res://assets/units/%s.png" % key
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
		if tex == null and FileAccess.file_exists(path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			if img:
				tex = ImageTexture.create_from_image(img)
		_tex_cache[key] = tex
		if tex:
			return tex
	return null


static func draw_unit(ci: CanvasItem, unit_id: String, c: Vector2, size: float, col: Color, face_left: bool = false) -> void:
	var k := size / 20.0
	ci.draw_set_transform(c, 0.0, Vector2(-k if face_left else k, k))
	var tex := texture_for(unit_id)
	if tex:
		_ellipse(ci, Vector2(0, 14), 14, 4, Color(0, 0, 0, 0.4))
		_ellipse(ci, Vector2(0, 14), 12, 3, Color(col.r, col.g, col.b, 0.55)) # kolor strony
		var tint := Color(1, 1, 1).lerp(Color(col.r, col.g, col.b), 0.12)
		if col.v < 0.35:
			tint = tint.darkened(0.4)
		ci.draw_texture_rect(tex, Rect2(-21, -27, 42, 42), false, tint)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	_ellipse(ci, Vector2(0, 14), 13, 3.5, Color(0, 0, 0, 0.35))
	var trim := col.lightened(0.35)
	match kind_of(unit_id):
		"piechota":
			ci.draw_line(Vector2(-3, 12), Vector2(-3, 4), DARK, 2.5)
			ci.draw_line(Vector2(3, 12), Vector2(3, 4), DARK, 2.5)
			ci.draw_rect(Rect2(-5, -6, 10, 11), col)
			ci.draw_circle(Vector2(0, -9), 3.5, SKIN)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-4.5, -10), Vector2(0, -15), Vector2(4.5, -10)]), STEEL)
			ci.draw_line(Vector2(8, 12), Vector2(8, -17), WOOD, 1.6)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(6.5, -16), Vector2(8, -21), Vector2(9.5, -16)]), STEEL)
			_ellipse(ci, Vector2(-6, 0), 4, 6, trim)
			ci.draw_line(Vector2(-6, -5), Vector2(-6, 5), col.darkened(0.4), 1.2)
		"lucznicy":
			ci.draw_line(Vector2(-3, 12), Vector2(-3, 4), DARK, 2.5)
			ci.draw_line(Vector2(3, 12), Vector2(3, 4), DARK, 2.5)
			ci.draw_rect(Rect2(-4.5, -6, 9, 11), col)
			ci.draw_circle(Vector2(0, -9), 3.5, SKIN)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-4, -9), Vector2(-1, -15), Vector2(4, -10), Vector2(0, -12)]), col.darkened(0.3))
			ci.draw_arc(Vector2(5, -2), 10.0, -1.2, 1.2, 12, WOOD, 1.8)
			ci.draw_line(Vector2(5 + 10 * cos(-1.2), -2 + 10 * sin(-1.2)), Vector2(5 + 10 * cos(1.2), -2 + 10 * sin(1.2)), Color(0.9, 0.9, 0.85), 0.8)
			ci.draw_rect(Rect2(-8, -8, 3, 9), WOOD) # kołczan
		"arkebuzerzy":
			ci.draw_line(Vector2(-3, 12), Vector2(-3, 4), DARK, 2.5)
			ci.draw_line(Vector2(3, 12), Vector2(3, 4), DARK, 2.5)
			ci.draw_rect(Rect2(-5, -6, 10, 11), col)
			ci.draw_rect(Rect2(-5, -1, 10, 2), trim)
			ci.draw_circle(Vector2(0, -9), 3.5, SKIN)
			ci.draw_rect(Rect2(-7, -13, 14, 2), DARK)
			ci.draw_rect(Rect2(-3, -17, 6, 4), DARK)
			ci.draw_line(Vector2(-2, 0), Vector2(16, -6), WOOD, 2.2)
			ci.draw_line(Vector2(6, -3), Vector2(17, -6.5), DARK, 1.6)
			ci.draw_circle(Vector2(18, -7), 1.5, Color(1, 0.7, 0.2, 0.8))
		"halabardnicy":
			ci.draw_line(Vector2(-3, 12), Vector2(-3, 4), DARK, 2.5)
			ci.draw_line(Vector2(3, 12), Vector2(3, 4), DARK, 2.5)
			ci.draw_rect(Rect2(-6, -7, 12, 12), STEEL)
			ci.draw_rect(Rect2(-6, 2, 12, 3), col)
			ci.draw_circle(Vector2(0, -10), 3.5, SKIN)
			ci.draw_arc(Vector2(0, -11), 4.5, PI, TAU, 8, STEEL, 2.0)
			ci.draw_line(Vector2(9, 13), Vector2(9, -22), WOOD, 1.8)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(9, -20), Vector2(15, -17), Vector2(15, -12), Vector2(9, -14)]), STEEL)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(8, -22), Vector2(9, -27), Vector2(10, -22)]), STEEL)
		"kusznicy":
			ci.draw_line(Vector2(-3, 12), Vector2(-3, 4), DARK, 2.5)
			ci.draw_line(Vector2(3, 12), Vector2(3, 4), DARK, 2.5)
			ci.draw_rect(Rect2(-5, -6, 10, 11), col)
			ci.draw_circle(Vector2(0, -9), 3.5, SKIN)
			ci.draw_arc(Vector2(0, -10), 4.0, PI, TAU, 8, STEEL, 2.0)
			ci.draw_line(Vector2(-1, -1), Vector2(15, -3), WOOD, 2.2)
			ci.draw_line(Vector2(12, -9), Vector2(12, 3), DARK, 1.6)
			ci.draw_rect(Rect2(-9, -6, 3, 8), WOOD)
		"lisowczycy":
			_horse(ci, Color(0.25, 0.2, 0.15))
			_rider(ci, col, -1)
			_ellipse(ci, Vector2(0, -15), 3.5, 2.0, Color(0.3, 0.2, 0.1)) # kołpak
			ci.draw_line(Vector2(1, -16), Vector2(4, -21), Color(0.9, 0.9, 0.9), 1.2) # pióro
			ci.draw_arc(Vector2(10, -6), 6.0, -2.4, -0.4, 8, STEEL, 1.6) # szabla
			ci.draw_rect(Rect2(-4, -2, 8, 3), trim)
		"jazda":
			_horse(ci, Color(0.5, 0.33, 0.18))
			_rider(ci, col, -1)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-3, -15), Vector2(0, -18), Vector2(3, -15)]), STEEL)
			ci.draw_line(Vector2(-6, -4), Vector2(18, -14), WOOD, 1.5)
			ci.draw_rect(Rect2(-4, -2, 8, 3), trim)
		"dragonia":
			_horse(ci, Color(0.3, 0.22, 0.15))
			_rider(ci, col, -1)
			ci.draw_rect(Rect2(-6, -16, 12, 2), DARK)
			ci.draw_rect(Rect2(-3, -19, 6, 3), DARK)
			ci.draw_line(Vector2(-6, -6), Vector2(14, -10), DARK, 1.8)
			ci.draw_rect(Rect2(-4, -2, 8, 3), trim)
		"husaria":
			# skrzydła za plecami
			for i in 5:
				var y := -24.0 + i * 3.5
				ci.draw_line(Vector2(-5, -2), Vector2(-9 - i * 0.6, y), Color(0.95, 0.95, 0.95), 2.2)
			ci.draw_line(Vector2(-5, -2), Vector2(-9, -24), WOOD, 1.0)
			_horse(ci, Color(0.92, 0.9, 0.85))
			_rider(ci, col, -1)
			ci.draw_rect(Rect2(-3, -10, 6, 5), STEEL) # pancerz
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-3.5, -14), Vector2(0, -18), Vector2(3.5, -14)]), STEEL)
			ci.draw_line(Vector2(-8, -2), Vector2(22, -16), Color(0.9, 0.85, 0.6), 1.5)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(18, -14.2), Vector2(22, -16), Vector2(15, -18)]), trim)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Mała kontrolka-ikona (np. na przycisku rekrutacji).
class Icon extends Control:
	var unit_id := "piechota"
	var color := Color(0.2, 0.45, 0.9)
	func _draw() -> void:
		var a := 0.45 if (get_parent() is BaseButton and (get_parent() as BaseButton).disabled) else 1.0
		modulate.a = a
		UnitArt.draw_unit(self, unit_id, size * 0.5 + Vector2(0, 2), minf(size.x, size.y) * 0.55, color)
