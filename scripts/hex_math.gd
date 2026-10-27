class_name HexMath
extends RefCounted
## Matematyka hexów pointy-top (oś axial: q, r).

const AXIAL_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


static func axial_to_pixel(q: int, r: int, size: float) -> Vector2:
	var x := size * (sqrt(3.0) * float(q) + sqrt(3.0) / 2.0 * float(r))
	var y := size * (3.0 / 2.0 * float(r))
	return Vector2(x, y)


static func pixel_to_axial(pos: Vector2, size: float) -> Vector2i:
	var q := (sqrt(3.0) / 3.0 * pos.x - 1.0 / 3.0 * pos.y) / size
	var r := (2.0 / 3.0 * pos.y) / size
	return axial_round(q, r)


static func axial_round(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundi(q)
	var rr := roundi(r)
	var rs := roundi(s)
	var q_diff := absf(rq - q)
	var r_diff := absf(rr - r)
	var s_diff := absf(rs - s)
	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs
	return Vector2i(rq, rr)


static func hex_corners(center: Vector2, size: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * float(i) - 30.0)
		corners.append(center + Vector2(cos(angle), sin(angle)) * size)
	return corners


static func distance(a: Vector2i, b: Vector2i) -> int:
	return int((absi(a.x - b.x) + absi(a.x + a.y - b.x - b.y) + absi(a.y - b.y)) / 2)


static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in AXIAL_DIRS:
		out.append(cell + d)
	return out
