extends Node2D
## Dekoracja mgły wojny: ciemna, ale z dryfującą teksturą dymu i złotawą krawędzią (nic nie odkrywa).

var map: Node2D = null
var _tex: Texture2D = null
var _t: float = 0.0
var _acc: float = 0.0
const TILE := 512.0


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = 1
	if ResourceLoader.exists("res://assets/ui/fog_smoke.png"):
		_tex = load("res://assets/ui/fog_smoke.png")


func _process(d: float) -> void:
	_t += d
	_acc += d
	if _acc > 0.07:
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	if map == null or _tex == null:
		return
	var vr: Rect2 = map._view_rect()
	var hs: float = map.hex_size
	var off := Vector2(_t * 9.0, _t * 4.0)
	var off2 := Vector2(-_t * 6.0, _t * 7.0)
	for key in map._cells.keys():
		var cell: Vector2i = key
		if map._explored.has(cell):
			continue
		var c: Vector2 = HexMath.axial_to_pixel(cell.x, cell.y, hs)
		if not vr.has_point(c):
			continue
		var edge := false
		for nb in HexMath.neighbors(cell):
			if map._explored.has(nb):
				edge = true
				break
		var pts: PackedVector2Array = HexMath.hex_corners(c, hs * (0.72 if edge else 1.04))
		var uv := PackedVector2Array()
		var uv2 := PackedVector2Array()
		for p in pts:
			uv.append((p + off) / TILE)
			uv2.append((p + off2) / (TILE * 1.7))
		draw_colored_polygon(pts, Color(0.55, 0.6, 0.75, 0.16), uv, _tex)
		draw_colored_polygon(pts, Color(0.45, 0.38, 0.3, 0.12), uv2, _tex)
		if edge:
			# złotawy, ledwie widoczny rąbek na granicy odkrytego terenu
			var e: PackedVector2Array = HexMath.hex_corners(c, hs * 0.74)
			e.append(e[0])
			draw_polyline(e, Color(0.85, 0.68, 0.32, 0.18), 1.5, true)
