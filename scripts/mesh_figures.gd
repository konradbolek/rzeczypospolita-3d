class_name MeshFigures
extends RefCounted
## Niskopoligonowe figurki i zamki z brył (Box/Cylinder/Sphere).
## Kolory i sylwetki nawiązują do assets/units/*.png oraz assets/map/castle_*.png.
## To geometria 3D, nie Sprite3D.

const SKIN := Color(0.93, 0.76, 0.58)
const STEEL := Color(0.78, 0.82, 0.88)
const GOLD := Color(0.86, 0.68, 0.22)
const WOOD := Color(0.42, 0.26, 0.13)
const BOOT := Color(0.16, 0.10, 0.07)
const BLACK := Color(0.10, 0.09, 0.08)
const WING := Color(0.96, 0.95, 0.92)
const STRING := Color(0.93, 0.90, 0.82)
const WOOD_DK := Color(0.28, 0.16, 0.08)
const STONE := Color(0.62, 0.6, 0.55)
const STONE_DK := Color(0.42, 0.4, 0.37)
const ROOF := Color(0.62, 0.18, 0.13)
const CLOTH := Color(0.93, 0.9, 0.82)
const PINE := Color(0.13, 0.36, 0.16)
const OAK := Color(0.2, 0.45, 0.16)
const DARK := Color(0.1, 0.08, 0.06)
const Surf := preload("res://scripts/surface_tex.gd")

static var _box: BoxMesh
static var _sphere: SphereMesh
static var _cyl: CylinderMesh
static var _hex: CylinderMesh
static var _cone: CylinderMesh


static func _ensure() -> void:
	if _box != null:
		return
	_box = BoxMesh.new()
	_box.size = Vector3.ONE
	_sphere = SphereMesh.new()
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 12
	_sphere.rings = 6
	_cyl = CylinderMesh.new()
	_cyl.top_radius = 1.0
	_cyl.bottom_radius = 1.0
	_cyl.height = 1.0
	_cyl.radial_segments = 8
	_cyl.rings = 1
	_hex = CylinderMesh.new()
	_hex.top_radius = 1.0
	_hex.bottom_radius = 1.0
	_hex.height = 1.0
	_hex.radial_segments = 6
	_hex.rings = 1
	_cone = CylinderMesh.new()
	_cone.top_radius = 0.0
	_cone.bottom_radius = 1.0
	_cone.height = 1.0
	_cone.radial_segments = 8
	_cone.rings = 1


static func _mat(col: Color, rough: float = 0.84, metal: float = 0.0, emit: float = 0.0, surf: String = "") -> StandardMaterial3D:
	return Surf.material(col, rough, metal, emit, surf)


static func _basis_y(dir: Vector3, z_hint: Vector3) -> Basis:
	var y := dir.normalized()
	if y.length_squared() < 0.5:
		return Basis.IDENTITY
	var z := z_hint - y * y.dot(z_hint)
	if z.length_squared() < 0.0000001:
		var alt := Vector3(0, 0, 1) if absf(y.y) < 0.9 else Vector3(1, 0, 0)
		z = alt - y * y.dot(alt)
	z = z.normalized()
	var x := y.cross(z).normalized()
	z = x.cross(y)
	return Basis(x, y, z)


static func _place(parent: Node3D, mesh: Mesh, pos: Vector3, col: Color, basis: Basis, scl: Vector3, rough: float = 0.84, metal: float = 0.0, emit: float = 0.0) -> MeshInstance3D:
	_ensure()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col, rough, metal, emit)
	mi.position = pos
	mi.basis = basis
	mi.scale = scl
	if Surf.battle_safe:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _box_at(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rot_y: float = 0.0, rough: float = 0.84, metal: float = 0.0) -> MeshInstance3D:
	_ensure()
	return _place(parent, _box, pos, col, Basis(Vector3.UP, rot_y), size, rough, metal)


static func _cyl_at(parent: Node3D, pos: Vector3, radius: float, height: float, col: Color, rough: float = 0.84, metal: float = 0.0, hex: bool = false) -> MeshInstance3D:
	_ensure()
	return _place(parent, _hex if hex else _cyl, pos, col, Basis.IDENTITY, Vector3(radius, height, radius), rough, metal)


static func _cone_at(parent: Node3D, pos: Vector3, radius: float, height: float, col: Color, rough: float = 0.78, metal: float = 0.0) -> MeshInstance3D:
	_ensure()
	return _place(parent, _cone, pos, col, Basis.IDENTITY, Vector3(radius, height, radius), rough, metal)


static func _ell(parent: Node3D, pos: Vector3, radii: Vector3, col: Color, rough: float = 0.86, metal: float = 0.0, emit: float = 0.0) -> MeshInstance3D:
	_ensure()
	return _place(parent, _sphere, pos, col, Basis.IDENTITY, radii, rough, metal, emit)


static func _span(parent: Node3D, a: Vector3, b: Vector3, radius: float, col: Color, rough: float = 0.84, metal: float = 0.0) -> void:
	_ensure()
	var d := b - a
	var h := d.length()
	if h < 0.001:
		return
	_place(parent, _cyl, (a + b) * 0.5, col, _basis_y(d, Vector3(0, 0, 1)), Vector3(radius, h, radius), rough, metal)


static func _cone_dir(parent: Node3D, base: Vector3, tip: Vector3, radius: float, col: Color, rough: float = 0.8) -> void:
	_ensure()
	var d := tip - base
	var h := d.length()
	if h < 0.001:
		return
	_place(parent, _cone, (base + tip) * 0.5, col, _basis_y(d, Vector3(0, 0, 1)), Vector3(radius, h, radius), rough, 0.0)


static func _slab(parent: Node3D, a: Vector3, b: Vector3, width: float, thick: float, col: Color, z_hint: Vector3, rough: float = 0.84, metal: float = 0.0) -> void:
	_ensure()
	var d := b - a
	var h := d.length()
	if h < 0.001:
		return
	_place(parent, _box, (a + b) * 0.5, col, _basis_y(d, z_hint), Vector3(width, h, thick), rough, metal)


## Buduje model jednostki. Stopy w y = feet_y. Zwraca wysokość czubka (pod portret).
static func add_unit(parent: Node3D, kind: String, feet_y: float, hero: bool = false) -> float:
	var holder := Node3D.new()
	holder.name = "Model3D"
	holder.position = Vector3(0, feet_y, 0)
	var sc := 1.08 if hero else 1.0
	holder.scale = Vector3(sc, sc, sc)
	parent.add_child(holder)
	var id: String = UnitArt.kind_of(kind)
	var top := 0.0
	match id:
		"wilk":
			top = _wolf(holder)
		"niedzwiedz":
			top = _bear(holder)
		"husaria", "jazda", "dragonia", "lisowczycy":
			top = _cavalry(holder, id)
		_:
			top = _infantry(holder, id)
	return feet_y + top * sc


static func _infantry(parent: Node3D, kind: String) -> float:
	var cloth := Color(0.16, 0.30, 0.58)
	var trim := Color(0.72, 0.12, 0.13)
	var hat := "morion"
	var weapon := "pike"
	var armor := false
	match kind:
		"lucznicy":
			cloth = Color(0.18, 0.42, 0.20)
			trim = Color(0.42, 0.26, 0.13)
			hat = "hood"
			weapon = "bow"
		"arkebuzerzy":
			cloth = Color(0.14, 0.28, 0.55)
			trim = Color(0.70, 0.12, 0.12)
			hat = "wide"
			weapon = "musket"
		"halabardnicy":
			cloth = Color(0.62, 0.12, 0.12)
			trim = STEEL
			hat = "morion"
			weapon = "halberd"
			armor = true
		"kusznicy":
			cloth = Color(0.64, 0.12, 0.13)
			trim = GOLD
			hat = "sallet"
			weapon = "crossbow"
	return _soldier(parent, Vector3.ZERO, cloth, trim, hat, weapon, armor, 1.0, true)


## Piechur albo jeździec (skala < 1). origin to poziom stóp; przy mounted biodra są przy origin.y + 0.38*scale.
static func _soldier(parent: Node3D, origin: Vector3, cloth: Color, trim: Color, hat: String, weapon: String, armor: bool, scale: float, with_legs: bool) -> float:
	var s := scale
	var o := origin
	if with_legs:
		_box_at(parent, Vector3(0.10, 0.34, 0.09) * s, o + Vector3(0.01, 0.17, 0.055) * s, cloth.darkened(0.12))
		_box_at(parent, Vector3(0.10, 0.34, 0.09) * s, o + Vector3(0.01, 0.17, -0.055) * s, cloth.darkened(0.12))
		_box_at(parent, Vector3(0.12, 0.08, 0.11) * s, o + Vector3(0.03, 0.04, 0.055) * s, BOOT)
		_box_at(parent, Vector3(0.12, 0.08, 0.11) * s, o + Vector3(0.03, 0.04, -0.055) * s, BOOT)
	else:
		# uda na siodle
		_box_at(parent, Vector3(0.16, 0.08, 0.10) * s, o + Vector3(0.06, 0.34, 0.09) * s, cloth.darkened(0.15))
		_box_at(parent, Vector3(0.16, 0.08, 0.10) * s, o + Vector3(0.06, 0.34, -0.09) * s, cloth.darkened(0.15))
	# tułów
	var torso := o + Vector3(0, 0.52, 0) * s
	_box_at(parent, Vector3(0.24, 0.36, 0.16) * s, torso, cloth)
	var shiny := trim == STEEL or trim == GOLD
	_box_at(parent, Vector3(0.25, 0.05, 0.17) * s, o + Vector3(0, 0.38, 0) * s, trim, 0.0, 0.45 if shiny else 0.7, 0.5 if shiny else 0.0)
	# mankiety / pas naramienny
	_box_at(parent, Vector3(0.08, 0.06, 0.08) * s, o + Vector3(0.06, 0.46, 0.14) * s, trim)
	_box_at(parent, Vector3(0.08, 0.06, 0.08) * s, o + Vector3(0.02, 0.46, -0.14) * s, trim)
	if armor:
		_box_at(parent, Vector3(0.20, 0.22, 0.10) * s, torso + Vector3(0.06, 0.02, 0) * s, STEEL, 0.0, 0.32, 0.62)
		_box_at(parent, Vector3(0.22, 0.08, 0.17) * s, o + Vector3(0, 0.34, 0) * s, cloth)
	# głowa
	var head := o + Vector3(0, 0.80, 0) * s
	_ell(parent, head, Vector3(0.105, 0.11, 0.10) * s, SKIN)
	var apex := _hat(parent, head, hat, s)
	# ramiona
	_span(parent, o + Vector3(0.02, 0.64, 0.12) * s, o + Vector3(0.10, 0.48, 0.16) * s, 0.035 * s, cloth)
	_span(parent, o + Vector3(0.10, 0.48, 0.16) * s, o + Vector3(0.08, 0.36, 0.14) * s, 0.03 * s, cloth.darkened(0.1))
	_span(parent, o + Vector3(-0.02, 0.64, -0.12) * s, o + Vector3(-0.06, 0.46, -0.16) * s, 0.035 * s, cloth)
	_span(parent, o + Vector3(-0.06, 0.46, -0.16) * s, o + Vector3(0.02, 0.36, -0.12) * s, 0.03 * s, cloth.darkened(0.1))
	if hat == "wide":
		# bandolier arkebuzera
		_slab(parent, o + Vector3(-0.06, 0.66, -0.06) * s, o + Vector3(0.08, 0.40, 0.08) * s, 0.04 * s, 0.025 * s, WOOD, Vector3(0, 0, 1))
	var wtop := _weapon(parent, o, s, weapon)
	return maxf(apex, wtop)


static func _hat(parent: Node3D, head: Vector3, kind: String, s: float) -> float:
	match kind:
		"wide":
			_cyl_at(parent, head + Vector3(0, 0.02, 0) * s, 0.18 * s, 0.028 * s, BLACK, 0.7)
			_cyl_at(parent, head + Vector3(0, 0.09, 0) * s, 0.075 * s, 0.10 * s, BLACK, 0.7)
			return head.y + 0.15 * s
		"hood":
			_cone_at(parent, head + Vector3(0, 0.10, 0) * s, 0.13 * s, 0.18 * s, Color(0.38, 0.24, 0.13))
			_box_at(parent, Vector3(0.12, 0.18, 0.18) * s, head + Vector3(-0.08, -0.02, 0) * s, Color(0.34, 0.22, 0.12))
			return head.y + 0.20 * s
		"fur":
			_cyl_at(parent, head + Vector3(0, 0.09, 0) * s, 0.095 * s, 0.16 * s, Color(0.30, 0.18, 0.10), 0.9)
			_ell(parent, head + Vector3(0, 0.18, 0) * s, Vector3(0.075, 0.05, 0.075) * s, Color(0.22, 0.13, 0.08))
			_span(parent, head + Vector3(0.02, 0.16, 0) * s, head + Vector3(0.12, 0.36, 0.05) * s, 0.014 * s, WING)
			return head.y + 0.36 * s
		"sallet":
			_ell(parent, head + Vector3(0.03, 0.03, 0) * s, Vector3(0.12, 0.075, 0.10) * s, STEEL, 0.34, 0.6)
			_box_at(parent, Vector3(0.04, 0.04, 0.12) * s, head + Vector3(0.12, 0.0, 0) * s, STEEL, 0.0, 0.34, 0.6)
			return head.y + 0.12 * s
		"hussar":
			_ell(parent, head + Vector3(0, 0.04, 0) * s, Vector3(0.10, 0.10, 0.095) * s, STEEL, 0.32, 0.66)
			_cyl_at(parent, head + Vector3(0, -0.01, 0) * s, 0.12 * s, 0.028 * s, GOLD, 0.4, 0.55)
			_span(parent, head + Vector3(-0.02, 0.10, 0) * s, head + Vector3(-0.10, 0.32, 0.02) * s, 0.016 * s, WING)
			return head.y + 0.32 * s
		_:
			_ell(parent, head + Vector3(0, 0.045, 0) * s, Vector3(0.11, 0.09, 0.105) * s, STEEL, 0.32, 0.62)
			_cyl_at(parent, head + Vector3(0, -0.005, 0) * s, 0.155 * s, 0.028 * s, STEEL, 0.32, 0.62)
			_box_at(parent, Vector3(0.025, 0.11, 0.09) * s, head + Vector3(0, 0.13, 0) * s, STEEL, 0.0, 0.32, 0.62)
			return head.y + 0.20 * s


static func _weapon(parent: Node3D, o: Vector3, s: float, weapon: String) -> float:
	match weapon:
		"bow":
			return _bow(parent, o + Vector3(0.18, 0.52, 0.10) * s, s, 0.16, 0.26)
		"musket":
			_span(parent, o + Vector3(-0.02, 0.58, 0.12) * s, o + Vector3(0.12, 0.60, 0.12) * s, 0.03 * s, WOOD)
			_span(parent, o + Vector3(0.12, 0.60, 0.12) * s, o + Vector3(0.52, 0.70, 0.12) * s, 0.016 * s, Color(0.18, 0.18, 0.2), 0.4, 0.45)
			_ell(parent, o + Vector3(0.50, 0.69, 0.12) * s, Vector3(0.02, 0.02, 0.02) * s, Color(0.95, 0.55, 0.15), 0.4, 0.0, 0.35)
			return o.y + 0.74 * s
		"halberd":
			var foot := o + Vector3(0.12, 0.02, 0.14) * s
			var top := o + Vector3(0.20, 1.28, 0.14) * s
			_span(parent, foot, top, 0.018 * s, WOOD)
			_cone_dir(parent, top, top + Vector3(0.02, 0.10, 0) * s, 0.03 * s, STEEL)
			_slab(parent, o + Vector3(0.18, 1.08, 0.14) * s, o + Vector3(0.40, 0.98, 0.14) * s, 0.10 * s, 0.02 * s, STEEL, Vector3(0, 0, 1), 0.32, 0.55)
			_slab(parent, o + Vector3(0.16, 0.98, 0.14) * s, o + Vector3(0.30, 0.90, 0.14) * s, 0.06 * s, 0.018 * s, STEEL, Vector3(0, 0, 1), 0.32, 0.55)
			return top.y + 0.10 * s
		"crossbow":
			_box_at(parent, Vector3(0.40, 0.05, 0.05) * s, o + Vector3(0.22, 0.56, 0.10) * s, WOOD)
			_bow(parent, o + Vector3(0.36, 0.56, 0.10) * s, s, 0.10, 0.16)
			_span(parent, o + Vector3(0.20, 0.58, 0.10) * s, o + Vector3(0.46, 0.60, 0.10) * s, 0.008 * s, WOOD.darkened(0.2))
			return o.y + 0.78 * s
		"saber":
			var hilt := o + Vector3(0.14, 0.46, 0.12) * s
			_span(parent, hilt, hilt + Vector3(0.16, 0.16, 0.02) * s, 0.012 * s, STEEL, 0.3, 0.7)
			_span(parent, hilt + Vector3(0.16, 0.16, 0.02) * s, hilt + Vector3(0.30, 0.04, 0.04) * s, 0.01 * s, STEEL, 0.3, 0.7)
			_span(parent, hilt + Vector3(0, -0.02, -0.05) * s, hilt + Vector3(0, -0.02, 0.05) * s, 0.012 * s, GOLD, 0.4, 0.6)
			return hilt.y + 0.20 * s
		"lance":
			var grip := o + Vector3(0.12, 0.62, 0.08) * s
			var tip := o + Vector3(0.78, 1.15, 0.08) * s
			_span(parent, grip, tip, 0.014 * s, WOOD)
			_cone_dir(parent, tip, tip + (tip - grip).normalized() * 0.08 * s, 0.028 * s, STEEL)
			var penn := tip - (tip - grip).normalized() * 0.16 * s
			_slab(parent, penn, penn + Vector3(-0.02, -0.12, 0.08) * s, 0.09 * s, 0.012 * s, Color(0.92, 0.92, 0.90), Vector3(0, 0, 1))
			_slab(parent, penn + Vector3(-0.02, -0.12, 0.08) * s, penn + Vector3(-0.04, -0.24, 0.12) * s, 0.08 * s, 0.012 * s, Color(0.75, 0.10, 0.12), Vector3(0, 0, 1))
			return tip.y + 0.06 * s
		_:
			# pika
			var a := o + Vector3(0.10, 0.20, 0.12) * s
			var b := o + Vector3(0.22, 1.22, 0.12) * s
			_span(parent, a, b, 0.016 * s, WOOD)
			_cone_dir(parent, b, b + Vector3(0.03, 0.10, 0) * s, 0.03 * s, STEEL)
			return b.y + 0.10 * s


static func _bow(parent: Node3D, origin: Vector3, s: float, bulge: float, half_h: float) -> float:
	var pts: Array[Vector3] = []
	for i in 6:
		var t := float(i) / 5.0
		var y := half_h - t * half_h * 2.0
		var x := sin(t * PI) * bulge
		pts.append(origin + Vector3(x, y, 0) * s)
	for i in pts.size() - 1:
		_span(parent, pts[i], pts[i + 1], 0.012 * s, WOOD)
	_span(parent, pts[0], pts[pts.size() - 1], 0.005 * s, STRING, 0.5)
	# strzała
	_span(parent, origin + Vector3(-0.02, 0, 0) * s, origin + Vector3(0.22, 0.02, 0) * s, 0.006 * s, WOOD.darkened(0.15))
	return pts[0].y


static func _cavalry(parent: Node3D, kind: String) -> float:
	var coat := Color(0.50, 0.30, 0.16)
	var cloth := Color(0.18, 0.32, 0.62)
	var trim := STEEL
	var hat := "morion"
	var weapon := "lance"
	var armor := false
	match kind:
		"husaria":
			coat = Color(0.94, 0.91, 0.84)
			cloth = Color(0.72, 0.08, 0.10)
			trim = STEEL
			hat = "hussar"
			weapon = "lance"
			armor = true
		"lisowczycy":
			coat = Color(0.12, 0.09, 0.08)
			cloth = Color(0.70, 0.12, 0.12)
			trim = Color(0.55, 0.08, 0.08)
			hat = "fur"
			weapon = "saber"
		"dragonia":
			coat = Color(0.26, 0.16, 0.11)
			cloth = Color(0.15, 0.28, 0.52)
			trim = Color(0.75, 0.14, 0.12)
			hat = "wide"
			weapon = "musket"
		_:
			coat = Color(0.48, 0.28, 0.14)
			cloth = Color(0.18, 0.34, 0.66)
			trim = Color(0.85, 0.72, 0.30)
			hat = "morion"
			weapon = "lance"
	var seat := _horse(parent, coat, kind == "husaria")
	# biodra jeźdźca (0.38 * skala) siedzą w siodle
	var rider_s := 0.82
	var rider_origin := seat - Vector3(0, 0.38 * rider_s, 0)
	var top := _soldier(parent, rider_origin, cloth, trim, hat, weapon, armor, rider_s, false)
	if kind == "husaria":
		var shoulder := seat + Vector3(-0.04, 0.30, 0)
		top = maxf(top, _wings(parent, shoulder))
	return top


static func _horse(parent: Node3D, coat: Color, hussar: bool) -> Vector3:
	var mane := coat.darkened(0.48)
	_ell(parent, Vector3(-0.02, 0.36, 0), Vector3(0.34, 0.15, 0.16), coat)
	_ell(parent, Vector3(0.20, 0.38, 0), Vector3(0.13, 0.13, 0.14), coat)
	_span(parent, Vector3(0.24, 0.44, 0), Vector3(0.38, 0.64, 0), 0.06, coat)
	_span(parent, Vector3(0.20, 0.50, 0), Vector3(0.34, 0.72, 0), 0.022, mane)
	_ell(parent, Vector3(0.44, 0.66, 0), Vector3(0.12, 0.075, 0.06), coat)
	_ell(parent, Vector3(0.54, 0.62, 0), Vector3(0.07, 0.045, 0.042), coat.lightened(0.06))
	_ell(parent, Vector3(0.58, 0.61, 0), Vector3(0.018, 0.015, 0.015), BLACK)
	_ell(parent, Vector3(0.46, 0.70, 0.035), Vector3(0.016, 0.016, 0.012), BLACK)
	_ell(parent, Vector3(0.46, 0.70, -0.035), Vector3(0.016, 0.016, 0.012), BLACK)
	_cone_dir(parent, Vector3(0.40, 0.72, 0.03), Vector3(0.38, 0.84, 0.045), 0.028, mane)
	_cone_dir(parent, Vector3(0.40, 0.72, -0.03), Vector3(0.38, 0.84, -0.045), 0.028, mane)
	var leg_x: Array[float] = [-0.18, 0.16]
	var leg_z: Array[float] = [-0.11, 0.11]
	for sx in leg_x:
		for sz in leg_z:
			var hoof_x: float = sx + (0.04 if sx > 0.0 else -0.03)
			_span(parent, Vector3(sx, 0.30, sz), Vector3(hoof_x, 0.05, sz), 0.032, coat.darkened(0.18))
			_box_at(parent, Vector3(0.07, 0.05, 0.055), Vector3(hoof_x, 0.025, sz), BLACK)
	_span(parent, Vector3(-0.32, 0.42, 0), Vector3(-0.50, 0.20, 0.05), 0.02, mane)
	_span(parent, Vector3(-0.44, 0.28, 0.03), Vector3(-0.52, 0.08, 0.08), 0.014, mane)
	# czaprak
	var cloth := Color(0.72, 0.10, 0.12) if hussar else coat.darkened(0.25)
	_box_at(parent, Vector3(0.28, 0.04, 0.20), Vector3(0.0, 0.50, 0), cloth)
	_box_at(parent, Vector3(0.16, 0.12, 0.03), Vector3(-0.02, 0.42, 0.13), cloth)
	_box_at(parent, Vector3(0.16, 0.12, 0.03), Vector3(-0.02, 0.42, -0.13), cloth)
	if hussar:
		# lamparci czaprak: kilka ciemnych plam
		var spots: Array[Vector3] = [Vector3(0.08, 0.53, 0.04), Vector3(-0.06, 0.53, -0.05), Vector3(0.02, 0.53, 0.08), Vector3(-0.02, 0.44, 0.145)]
		for spot in spots:
			_ell(parent, spot, Vector3(0.025, 0.012, 0.02), Color(0.15, 0.10, 0.06))
	# siodło
	_box_at(parent, Vector3(0.12, 0.05, 0.12), Vector3(0.02, 0.53, 0), Color(0.36, 0.20, 0.10))
	return Vector3(0.02, 0.56, 0)


static func _wings(parent: Node3D, origin: Vector3) -> float:
	var apex := origin.y
	var sides: Array[float] = [-1.0, 1.0]
	for side in sides:
		var base := origin + Vector3(-0.04, 0.0, 0.05 * side)
		var frame_tip := base + Vector3(-0.10, 0.52, 0.22 * side)
		_span(parent, base, frame_tip, 0.012, WOOD)
		_box_at(parent, Vector3(0.06, 0.10, 0.04), base, WOOD)
		for i in 6:
			var t := float(i) / 5.0
			var p: Vector3 = base.lerp(frame_tip, t)
			var tip := p + Vector3(-0.16 - t * 0.05, 0.05, 0.12 * side)
			_slab(parent, p, tip, 0.055, 0.012, WING.darkened(0.04 * t), Vector3(0, 0, side))
			apex = maxf(apex, tip.y)
	return apex


static func _wolf(parent: Node3D) -> float:
	var fur := Color(0.62, 0.64, 0.66)
	var dark := Color(0.40, 0.42, 0.46)
	var belly := Color(0.78, 0.76, 0.70)
	_ell(parent, Vector3(-0.02, 0.36, 0), Vector3(0.40, 0.16, 0.18), fur)
	_ell(parent, Vector3(-0.02, 0.44, 0), Vector3(0.30, 0.07, 0.12), dark)
	_ell(parent, Vector3(-0.02, 0.28, 0), Vector3(0.26, 0.06, 0.12), belly)
	_span(parent, Vector3(0.28, 0.40, 0), Vector3(0.42, 0.50, 0), 0.07, fur)
	var head := Vector3(0.52, 0.54, 0)
	_ell(parent, head, Vector3(0.13, 0.11, 0.11), fur)
	_ell(parent, head + Vector3(0.12, -0.02, 0), Vector3(0.10, 0.055, 0.06), fur.lightened(0.05))
	_ell(parent, head + Vector3(0.20, -0.02, 0), Vector3(0.025, 0.02, 0.02), BLACK)
	_ell(parent, head + Vector3(0.06, 0.04, 0.06), Vector3(0.018, 0.018, 0.018), Color(0.95, 0.78, 0.2), 0.4, 0.0, 0.6)
	_ell(parent, head + Vector3(0.06, 0.04, -0.06), Vector3(0.018, 0.018, 0.018), Color(0.95, 0.78, 0.2), 0.4, 0.0, 0.6)
	_cone_dir(parent, head + Vector3(-0.02, 0.08, 0.05), head + Vector3(-0.04, 0.20, 0.08), 0.035, dark)
	_cone_dir(parent, head + Vector3(-0.02, 0.08, -0.05), head + Vector3(-0.04, 0.20, -0.08), 0.035, dark)
	var wx: Array[float] = [-0.20, 0.16]
	var wz: Array[float] = [-0.09, 0.09]
	for sx in wx:
		for sz in wz:
			_span(parent, Vector3(sx, 0.28, sz), Vector3(sx, 0.02, sz * 1.15), 0.03, fur.darkened(0.1))
			_box_at(parent, Vector3(0.06, 0.035, 0.05), Vector3(sx + 0.02, 0.015, sz * 1.15), BOOT)
	# ogon do góry
	_span(parent, Vector3(-0.36, 0.40, 0), Vector3(-0.52, 0.58, 0.04), 0.025, dark)
	_span(parent, Vector3(-0.50, 0.56, 0.03), Vector3(-0.58, 0.72, 0.06), 0.018, fur.lightened(0.08))
	return head.y + 0.22


static func _bear(parent: Node3D) -> float:
	var fur := Color(0.48, 0.30, 0.16)
	var dark := Color(0.30, 0.17, 0.09)
	var snout := Color(0.66, 0.48, 0.32)
	# garby i brzuch
	_ell(parent, Vector3(-0.04, 0.40, 0), Vector3(0.42, 0.24, 0.22), fur)
	_ell(parent, Vector3(0.10, 0.52, 0), Vector3(0.22, 0.14, 0.16), fur.darkened(0.08))
	_ell(parent, Vector3(-0.04, 0.30, 0), Vector3(0.28, 0.10, 0.16), fur.lightened(0.08))
	var head := Vector3(0.40, 0.58, 0)
	_ell(parent, head, Vector3(0.16, 0.15, 0.15), fur)
	_ell(parent, head + Vector3(0.14, -0.02, 0), Vector3(0.10, 0.07, 0.08), snout)
	_ell(parent, head + Vector3(0.22, -0.01, 0), Vector3(0.03, 0.025, 0.03), BLACK)
	_ell(parent, head + Vector3(0.06, 0.05, 0.07), Vector3(0.02, 0.02, 0.016), BLACK)
	_ell(parent, head + Vector3(0.06, 0.05, -0.07), Vector3(0.02, 0.02, 0.016), BLACK)
	_ell(parent, head + Vector3(-0.02, 0.14, 0.08), Vector3(0.045, 0.04, 0.035), dark)
	_ell(parent, head + Vector3(-0.02, 0.14, -0.08), Vector3(0.045, 0.04, 0.035), dark)
	var bx: Array[float] = [-0.18, 0.16]
	var bz: Array[float] = [-0.14, 0.14]
	for sx in bx:
		for sz in bz:
			_span(parent, Vector3(sx, 0.32, sz), Vector3(sx, 0.04, sz * 1.05), 0.055, dark)
			_box_at(parent, Vector3(0.09, 0.05, 0.08), Vector3(sx + 0.03, 0.02, sz * 1.05), BLACK)
	# krótki ogon
	_ell(parent, Vector3(-0.42, 0.42, 0), Vector3(0.06, 0.05, 0.05), dark)
	return head.y + 0.20


## Zamek na heksie. style: polska | szwecja | osmanowie. accent = kolor właściciela (wieżyczki).
static func add_castle(parent: Node3D, style: String, accent: Color) -> void:
	var wall := Color(0.86, 0.84, 0.78)
	var keep := Color(0.90, 0.88, 0.82)
	var roof := Color(0.70, 0.14, 0.12)
	var trim := Color(0.55, 0.52, 0.48)
	var shape := "polish"
	match style:
		"szwecja":
			wall = Color(0.58, 0.26, 0.18)
			keep = Color(0.52, 0.22, 0.16)
			roof = Color(0.20, 0.18, 0.17)
			trim = Color(0.38, 0.36, 0.34)
			shape = "spire"
		"osmanowie":
			wall = Color(0.78, 0.62, 0.40)
			keep = Color(0.82, 0.68, 0.42)
			roof = Color(0.86, 0.72, 0.40)
			trim = Color(0.55, 0.40, 0.24)
			shape = "dome"
	_castle(parent, accent, wall, keep, roof, trim, shape)


static func _castle(parent: Node3D, accent: Color, wall: Color, keep: Color, roof: Color, trim: Color, shape: String) -> void:
	# cokół heksowy + obwódka właściciela
	_cyl_at(parent, Vector3(0, 0.07, 0), 0.94, 0.14, trim.lightened(0.08), 0.92, 0.0, true)
	_cyl_at(parent, Vector3(0, 0.15, 0), 0.90, 0.045, accent, 0.55, 0.05, true)
	_cyl_at(parent, Vector3(0, 0.175, 0), 0.72, 0.04, trim.darkened(0.08), 0.9, 0.0, true)
	var base_y := 0.18
	var wall_h := 0.42
	var ring := 0.76
	for i in 6:
		var a := TAU * float(i) / 6.0
		var mid := a + TAU / 12.0
		var radial := Vector3(cos(mid), 0, sin(mid))
		var wall_r := ring * cos(PI / 6.0)
		var wc := wall if i % 2 == 0 else wall.darkened(0.07)
		var wpos := Vector3(radial.x * wall_r, base_y + wall_h * 0.5, radial.z * wall_r)
		var gate := i == 1
		_box_at(parent, Vector3(0.14, wall_h if not gate else wall_h * 0.55, 0.50), wpos - Vector3(0, 0.09 if gate else 0.0, 0), wc, -mid)
		# blanki
		if not gate:
			var tangent := Vector3(-sin(mid), 0, cos(mid))
			var signs: Array[float] = [-1.0, 1.0]
			for sgn in signs:
				var mp: Vector3 = Vector3(radial.x * wall_r, base_y + wall_h + 0.045, radial.z * wall_r) + tangent * sgn * 0.16
				_box_at(parent, Vector3(0.12, 0.09, 0.12), mp, wc, -mid)
			var slit := wpos + radial * 0.08 + Vector3(0, 0.04, 0)
			_box_at(parent, Vector3(0.05, 0.14, 0.07), slit, Color(0.06, 0.05, 0.05), -mid)
		else:
			var door := wpos + radial * 0.06 + Vector3(0, -0.06, 0)
			_box_at(parent, Vector3(0.10, 0.28, 0.22), door, Color(0.28, 0.16, 0.08), -mid)
			_box_at(parent, Vector3(0.04, 0.22, 0.10), door + radial * 0.04, Color(0.08, 0.06, 0.05), -mid)
			# schodki
			_box_at(parent, Vector3(0.28, 0.04, 0.16), door + radial * 0.16 + Vector3(0, -0.16, 0), trim, -mid)
		# wieżyczka właściciela
		var tp := Vector3(cos(a) * ring, 0, sin(a) * ring)
		var shaft_h := 0.66
		_cyl_at(parent, tp + Vector3(0, base_y + shaft_h * 0.5, 0), 0.115, shaft_h, accent.darkened(0.18), 0.62, 0.08)
		_cyl_at(parent, tp + Vector3(0, base_y + shaft_h - 0.02, 0), 0.14, 0.06, accent, 0.5, 0.1)
		_cone_at(parent, tp + Vector3(0, base_y + shaft_h + 0.16, 0), 0.16, 0.34, accent.lightened(0.12), 0.55, 0.08)
	# donżon
	var keep_h := 0.78
	var keep_pos := Vector3(0, base_y + keep_h * 0.5, 0)
	if shape == "dome":
		keep_h = 0.48
		keep_pos = Vector3(0, base_y + keep_h * 0.5, 0)
		_box_at(parent, Vector3(0.50, keep_h, 0.50), keep_pos, keep)
		var drum_y := base_y + keep_h
		_cyl_at(parent, Vector3(0, drum_y + 0.10, 0), 0.20, 0.20, keep.lightened(0.05))
		_ell(parent, Vector3(0, drum_y + 0.28, 0), Vector3(0.26, 0.30, 0.26), roof, 0.45, 0.22)
		_cone_at(parent, Vector3(0, drum_y + 0.58, 0), 0.05, 0.16, accent)
		_ell(parent, Vector3(0, drum_y + 0.68, 0), Vector3(0.035, 0.035, 0.035), GOLD, 0.4, 0.5)
		# minaret
		var mp := Vector3(0.30, 0, -0.18)
		_cyl_at(parent, mp + Vector3(0, base_y + 0.55, 0), 0.055, 1.10, wall.lightened(0.06))
		_cyl_at(parent, mp + Vector3(0, base_y + 1.05, 0), 0.10, 0.05, accent)
		_cone_at(parent, mp + Vector3(0, base_y + 1.22, 0), 0.07, 0.28, accent.lightened(0.1))
		_ell(parent, mp + Vector3(0, base_y + 1.38, 0), Vector3(0.03, 0.03, 0.03), GOLD, 0.4, 0.45)
	elif shape == "spire":
		keep_h = 0.95
		keep_pos = Vector3(0, base_y + keep_h * 0.5, 0)
		_box_at(parent, Vector3(0.42, keep_h, 0.42), keep_pos, keep)
		_windows(parent, keep_pos, 0.22, keep_h)
		var top := base_y + keep_h
		_cone_at(parent, Vector3(0, top + 0.22, 0), 0.30, 0.46, roof, 0.7)
		_cyl_at(parent, Vector3(0, top + 0.52, 0), 0.035, 0.40, trim.darkened(0.2))
		_cone_at(parent, Vector3(0, top + 0.82, 0), 0.06, 0.22, accent)
	else:
		_box_at(parent, Vector3(0.48, keep_h, 0.48), keep_pos, keep)
		_windows(parent, keep_pos, 0.25, keep_h)
		# krenelaż donżonu
		var merlons: Array[Vector3] = [Vector3(0.18, 0, 0.18), Vector3(-0.18, 0, 0.18), Vector3(0.18, 0, -0.18), Vector3(-0.18, 0, -0.18)]
		for c in merlons:
			_box_at(parent, Vector3(0.10, 0.08, 0.10), keep_pos + Vector3(c.x, keep_h * 0.5 + 0.04, c.z), keep)
		var roof_y := base_y + keep_h
		_cone_at(parent, Vector3(0, roof_y + 0.20, 0), 0.32, 0.42, roof, 0.62)
		_cyl_at(parent, Vector3(0, roof_y + 0.46, 0), 0.03, 0.22, trim)
		_cone_at(parent, Vector3(0, roof_y + 0.64, 0), 0.055, 0.16, roof)
		# narożne hełmy
		var pinnacles: Array[Vector3] = [Vector3(0.18, 0, 0.18), Vector3(-0.18, 0, 0.18), Vector3(0.18, 0, -0.18), Vector3(-0.18, 0, -0.18)]
		for c2 in pinnacles:
			_cone_at(parent, Vector3(c2.x, roof_y + 0.10, c2.z), 0.07, 0.18, roof)


static func _windows(parent: Node3D, keep_pos: Vector3, half: float, keep_h: float) -> void:
	var dark := Color(0.07, 0.08, 0.12)
	var glass := Color(0.45, 0.62, 0.78)
	var faces: Array[Vector3] = [Vector3(0, 0.08, half + 0.01), Vector3(half + 0.01, 0.08, 0), Vector3(0, 0.08, -(half + 0.01))]
	for face in faces:
		var sz := Vector3(0.10, 0.16, 0.04) if absf(face.z) > absf(face.x) else Vector3(0.04, 0.16, 0.10)
		_box_at(parent, sz, keep_pos + face, dark)
		var gz := Vector3(0.06, 0.08, 0.02) if absf(face.z) > absf(face.x) else Vector3(0.02, 0.08, 0.06)
		_box_at(parent, gz, keep_pos + face + face.normalized() * 0.02, glass, 0.0, 0.25, 0.15)
	# drugie piętro, węższe
	var up := Vector3(0, keep_h * 0.28, 0)
	_box_at(parent, Vector3(0.08, 0.12, 0.03), keep_pos + Vector3(0, 0, half + 0.01) + up, dark)


## Kopalnie, artefakty, porty, sceneria i przeszkody bitwy (bryły, nie billboardy).

static func M(c: Color, surf: String = "") -> StandardMaterial3D:
	return _mat(c, 0.84, 0.0, 0.0, surf)


static func disk(parent: Node3D, radius: float, height: float, pos: Vector3, surf: String) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 6
	m.material = Surf.terrain_material(surf)
	return _mi(parent, m, pos)


static func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	if Surf.battle_safe:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO, surf := "") -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	b.material = M(col, surf)
	return _mi(parent, b, pos, rot)


static func cyl(parent: Node3D, r: float, h: float, pos: Vector3, col: Color, seg := 8, r2 := -1.0, rot := Vector3.ZERO, surf := "") -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r if r2 < 0.0 else r2
	m.bottom_radius = r
	m.height = h
	m.radial_segments = seg
	m.material = M(col, surf)
	return _mi(parent, m, pos, rot)


static func cone(parent: Node3D, r: float, h: float, pos: Vector3, col: Color, seg := 7, surf := "") -> MeshInstance3D:
	return cyl(parent, r, h, pos, col, seg, 0.0, Vector3.ZERO, surf)


static func sph(parent: Node3D, r: float, pos: Vector3, col: Color, surf := "") -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 6
	m.material = M(col, surf)
	return _mi(parent, m, pos)


static func banner(parent: Node3D, col: Color, at: Vector3, h := 1.05) -> void:
	cyl(parent, 0.02, h, at + Vector3(0, h * 0.5, 0), WOOD_DK, 6)
	box(parent, Vector3(0.26, 0.16, 0.02), at + Vector3(0.13, h - 0.1, 0), col)


static func resource(kind: String, owned: bool) -> Node3D:
	var root := Node3D.new()
	var flag := Color(0.2, 0.55, 1.0) if owned else Color(0.92, 0.92, 0.92)
	match kind:
		"tartak":
			_shed(root, WOOD, ROOF.darkened(0.1))
			_logs(root, Vector3(0.35, 0.12, 0.15))
			cyl(root, 0.12, 0.04, Vector3(-0.28, 0.28, 0.2), STEEL, 10)
			banner(root, flag, Vector3(0.42, 0.45, 0), 0.7)
		"kopalnia":
			_mine_frame(root, STONE_DK)
			_rocks(root, Color(0.55, 0.5, 0.48), Color(0.72, 0.4, 0.22))
			banner(root, flag, Vector3(0.4, 0.55, 0), 0.65)
		"kopalnia_zlota":
			_mine_frame(root, Color(0.4, 0.32, 0.16))
			_rocks(root, Color(0.55, 0.42, 0.18), GOLD)
			cone(root, 0.06, 0.16, Vector3(0.22, 0.2, 0.12), GOLD, 4)
			cone(root, 0.05, 0.12, Vector3(0.08, 0.16, -0.1), GOLD, 4)
			banner(root, flag, Vector3(0.4, 0.55, 0), 0.65)
		"kopalnia_wegla":
			_mine_frame(root, Color(0.22, 0.2, 0.18))
			sph(root, 0.22, Vector3(0.05, 0.16, 0.05), Color(0.12, 0.12, 0.12))
			sph(root, 0.14, Vector3(0.22, 0.12, -0.08), Color(0.16, 0.16, 0.16))
			banner(root, flag, Vector3(0.42, 0.5, 0), 0.6)
		"drewno":
			_logs(root, Vector3(0, 0.1, 0))
			_logs(root, Vector3(0.05, 0.22, 0.05))
		"ruda":
			_rocks(root, Color(0.5, 0.52, 0.55), Color(0.85, 0.45, 0.18))
		_:
			box(root, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.15, 0), GOLD if kind == "zloto" else WOOD)
	return root


static func _shed(parent: Node3D, wall: Color, roof: Color) -> void:
	box(parent, Vector3(0.55, 0.32, 0.4), Vector3(0, 0.24, 0), wall)
	box(parent, Vector3(0.64, 0.08, 0.48), Vector3(0, 0.44, 0), roof, Vector3(0, 0, 0.15))
	box(parent, Vector3(0.16, 0.2, 0.04), Vector3(0, 0.16, 0.2), DARK)


static func _logs(parent: Node3D, at: Vector3) -> void:
	var lay := Vector3(0, 0, PI * 0.5)
	for i in 3:
		var y := float(i) * 0.09
		cyl(parent, 0.045, 0.42, at + Vector3(0, 0.05 + y, 0), WOOD, 6, -1.0, lay)
		cyl(parent, 0.05, 0.02, at + Vector3(0.21, 0.05 + y, 0), Color(0.82, 0.68, 0.4), 6, -1.0, lay)


static func _mine_frame(parent: Node3D, col: Color) -> void:
	box(parent, Vector3(0.5, 0.28, 0.36), Vector3(0, 0.2, 0), col)
	box(parent, Vector3(0.22, 0.2, 0.08), Vector3(0, 0.16, 0.16), DARK)
	cyl(parent, 0.03, 0.55, Vector3(-0.16, 0.5, 0), WOOD_DK, 5)
	cyl(parent, 0.03, 0.55, Vector3(0.16, 0.5, 0), WOOD_DK, 5)
	cyl(parent, 0.025, 0.36, Vector3(0, 0.74, 0), WOOD_DK, 5, -1.0, Vector3(0, 0, PI * 0.5))
	box(parent, Vector3(0.36, 0.04, 0.06), Vector3(0, 0.74, 0), WOOD)


static func _rocks(parent: Node3D, base: Color, glint: Color) -> void:
	box(parent, Vector3(0.22, 0.16, 0.18), Vector3(-0.1, 0.1, 0.05), base, Vector3(0.2, 0.4, 0.1))
	box(parent, Vector3(0.18, 0.14, 0.16), Vector3(0.12, 0.09, -0.06), base.lightened(0.08), Vector3(-0.2, 0.2, 0.3))
	sph(parent, 0.045, Vector3(0.02, 0.16, 0.02), glint)


static func artifact(aid: String) -> Node3D:
	var root := Node3D.new()
	cyl(root, 0.2, 0.08, Vector3(0, 0.04, 0), STONE_DK, 8)
	cyl(root, 0.14, 0.1, Vector3(0, 0.12, 0), STONE, 8)
	match aid:
		"sakiewka":
			sph(root, 0.1, Vector3(0, 0.28, 0), Color(0.55, 0.32, 0.14))
			cyl(root, 0.04, 0.04, Vector3(0, 0.38, 0), GOLD, 8)
			cyl(root, 0.035, 0.02, Vector3(0.08, 0.24, 0.04), GOLD, 8)
		"szabla":
			box(root, Vector3(0.28, 0.025, 0.04), Vector3(0.02, 0.32, 0), STEEL, Vector3(0, 0, -0.7))
			box(root, Vector3(0.08, 0.04, 0.04), Vector3(-0.08, 0.24, 0), GOLD)
		"buty_kuriera":
			box(root, Vector3(0.16, 0.08, 0.07), Vector3(-0.05, 0.22, 0.02), Color(0.35, 0.2, 0.1), Vector3(0, 0.3, 0.2))
			box(root, Vector3(0.16, 0.08, 0.07), Vector3(0.06, 0.22, -0.02), Color(0.4, 0.24, 0.12), Vector3(0, -0.2, -0.15))
		"pierscien_sily":
			cyl(root, 0.07, 0.025, Vector3(0, 0.24, 0), GOLD, 12)
			sph(root, 0.035, Vector3(0, 0.28, 0), Color(0.75, 0.15, 0.12))
		"tarcza_hetmana":
			box(root, Vector3(0.16, 0.22, 0.03), Vector3(0, 0.3, 0), Color(0.7, 0.12, 0.12))
			box(root, Vector3(0.06, 0.22, 0.035), Vector3(0, 0.3, 0), CLOTH)
			sph(root, 0.03, Vector3(0, 0.3, 0.03), GOLD)
		"helm_husarski":
			sph(root, 0.08, Vector3(0, 0.28, 0), STEEL)
			cone(root, 0.05, 0.1, Vector3(0, 0.38, 0), STEEL, 5)
			box(root, Vector3(0.14, 0.04, 0.08), Vector3(-0.08, 0.32, 0), CLOTH, Vector3(0, 0, 0.4))
		"luneta":
			cyl(root, 0.035, 0.22, Vector3(0.02, 0.28, 0), Color(0.72, 0.55, 0.22), 8)
			cyl(root, 0.05, 0.06, Vector3(0.12, 0.28, 0), Color(0.55, 0.4, 0.16), 8)
			sph(root, 0.03, Vector3(-0.1, 0.28, 0), Color(0.3, 0.45, 0.55))
		"ksiega_run":
			box(root, Vector3(0.16, 0.06, 0.2), Vector3(0, 0.24, 0), Color(0.35, 0.15, 0.12))
			box(root, Vector3(0.14, 0.02, 0.18), Vector3(0, 0.28, 0), Color(0.9, 0.86, 0.7))
			sph(root, 0.03, Vector3(0, 0.31, 0), Color(0.35, 0.55, 0.85))
		"pieczec_krola":
			cyl(root, 0.07, 0.04, Vector3(0, 0.22, 0), Color(0.7, 0.12, 0.14), 10)
			cone(root, 0.05, 0.08, Vector3(0, 0.3, 0), GOLD, 5)
		_:
			sph(root, 0.08, Vector3(0, 0.28, 0), GOLD)
	return root


static func ship() -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(0.7, 0.12, 0.24), Vector3(0, 0.1, 0), WOOD)
	box(root, Vector3(0.18, 0.1, 0.16), Vector3(0.4, 0.12, 0), WOOD.darkened(0.1))
	cyl(root, 0.025, 0.55, Vector3(-0.05, 0.4, 0), WOOD_DK, 5)
	box(root, Vector3(0.28, 0.32, 0.02), Vector3(0.1, 0.42, 0), CLOTH)
	box(root, Vector3(0.12, 0.08, 0.02), Vector3(-0.02, 0.7, 0), Color(0.75, 0.15, 0.12))
	return root


static func port() -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(0.55, 0.06, 0.28), Vector3(-0.15, 0.08, 0), WOOD.lightened(0.05))
	for x in [-0.32, -0.05]:
		cyl(root, 0.03, 0.22, Vector3(x, 0.06, 0.12), WOOD_DK, 5)
		cyl(root, 0.03, 0.22, Vector3(x, 0.06, -0.12), WOOD_DK, 5)
	var s := ship()
	s.position = Vector3(0.35, 0, 0.05)
	s.scale = Vector3(0.85, 0.85, 0.85)
	root.add_child(s)
	return root


static func scenery(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"village":
			_house(root, Vector3(-0.16, 0, 0.05), Color(0.78, 0.7, 0.55), ROOF)
			_house(root, Vector3(0.22, 0, -0.08), Color(0.72, 0.62, 0.48), Color(0.4, 0.28, 0.18))
			cyl(root, 0.06, 0.1, Vector3(0.02, 0.06, 0.18), STONE, 8)
		"windmill":
			cyl(root, 0.14, 0.55, Vector3(0, 0.32, 0), STONE, 8)
			cone(root, 0.2, 0.22, Vector3(0, 0.68, 0), ROOF.darkened(0.05), 8)
			box(root, Vector3(0.46, 0.06, 0.04), Vector3(0, 0.48, 0.12), WOOD)
			box(root, Vector3(0.06, 0.46, 0.04), Vector3(0, 0.48, 0.12), WOOD)
			box(root, Vector3(0.08, 0.14, 0.04), Vector3(0, 0.16, 0.12), WOOD_DK)
		"wheat":
			for i in 5:
				var x := float(i - 2) * 0.08
				box(root, Vector3(0.02, 0.22 + float(i % 3) * 0.04, 0.02), Vector3(x, 0.12, float(i % 2) * 0.06), Color(0.82, 0.68, 0.22))
				sph(root, 0.025, Vector3(x, 0.26, float(i % 2) * 0.06), Color(0.9, 0.78, 0.3))
		"ruins":
			box(root, Vector3(0.1, 0.4, 0.28), Vector3(-0.12, 0.2, 0), STONE_DK)
			box(root, Vector3(0.28, 0.22, 0.1), Vector3(0.08, 0.11, 0.08), STONE)
			box(root, Vector3(0.26, 0.08, 0.1), Vector3(0.1, 0.06, -0.12), STONE.darkened(0.1), Vector3(0, 0, 0.6))
		"oak":
			cyl(root, 0.05, 0.28, Vector3(0, 0.14, 0), WOOD, 6)
			sph(root, 0.2, Vector3(0, 0.4, 0), OAK, "foliage")
			sph(root, 0.12, Vector3(0.12, 0.46, 0.05), OAK.darkened(0.08), "foliage")
		"pine":
			cyl(root, 0.04, 0.2, Vector3(0, 0.1, 0), WOOD, 5)
			cone(root, 0.16, 0.28, Vector3(0, 0.32, 0), PINE, 6, "foliage")
			cone(root, 0.12, 0.22, Vector3(0, 0.5, 0), PINE.lightened(0.08), 6, "foliage")
		"rock":
			box(root, Vector3(0.28, 0.16, 0.22), Vector3(0, 0.08, 0), Color(0.5, 0.5, 0.52), Vector3(0.1, 0.3, 0), "rock")
			box(root, Vector3(0.16, 0.14, 0.14), Vector3(0.12, 0.12, 0.06), Color(0.62, 0.62, 0.64), Vector3.ZERO, "rock")
		"bush":
			sph(root, 0.12, Vector3(0, 0.1, 0), OAK.darkened(0.1), "foliage")
		"ship":
			var s := ship()
			s.scale = Vector3(0.8, 0.8, 0.8)
			root.add_child(s)
		_:
			box(root, Vector3(0.2, 0.2, 0.2), Vector3(0, 0.1, 0), STONE)
	return root


static func _house(parent: Node3D, at: Vector3, wall: Color, roof: Color) -> void:
	box(parent, Vector3(0.28, 0.2, 0.22), at + Vector3(0, 0.1, 0), wall)
	box(parent, Vector3(0.34, 0.08, 0.28), at + Vector3(0, 0.24, 0), roof)
	box(parent, Vector3(0.08, 0.1, 0.03), at + Vector3(0, 0.06, 0.11), WOOD_DK)


static func battle_prop(kind: String, damaged: bool) -> Node3D:
	var root := Node3D.new()
	match kind:
		"hill":
			sph(root, 0.55, Vector3(0, 0.05, 0), Color(0.48, 0.4, 0.24), "dirt")
			root.scale = Vector3(1.15, 0.45, 0.9)
			sph(root, 0.28, Vector3(-0.1, 0.22, 0.05), Color(0.58, 0.5, 0.3), "grass")
		"rock":
			box(root, Vector3(0.7, 0.4, 0.55), Vector3(0, 0.22, 0), Color(0.48, 0.48, 0.5), Vector3(0.05, 0.2, 0.1), "rock")
			box(root, Vector3(0.4, 0.35, 0.35), Vector3(0.2, 0.4, 0.05), Color(0.35, 0.35, 0.38), Vector3.ZERO, "rock")
			box(root, Vector3(0.3, 0.22, 0.28), Vector3(-0.25, 0.18, -0.05), Color(0.58, 0.58, 0.6), Vector3.ZERO, "rock")
		"tree":
			var t := scenery("pine")
			t.scale = Vector3(1.4, 1.4, 1.4)
			root.add_child(t)
		"wall":
			_wall(root, damaged, false, false)
		"gate":
			_wall(root, damaged, true, false)
		"tower":
			_wall(root, damaged, false, true)
		_:
			box(root, Vector3(0.4, 0.4, 0.4), Vector3(0, 0.2, 0), STONE)
	return root


static func _wall(parent: Node3D, damaged: bool, gate: bool, tower: bool) -> void:
	var h := 0.85 if not damaged else 0.5
	var col := STONE if not damaged else STONE_DK.darkened(0.05)
	if tower:
		var th := 1.35 if not damaged else 0.8
		box(parent, Vector3(0.7, th, 0.7), Vector3(0, th * 0.5, 0), col)
		if not damaged:
			cone(parent, 0.48, 0.35, Vector3(0, th + 0.12, 0), ROOF, 4)
			box(parent, Vector3(0.16, 0.16, 0.04), Vector3(0, th * 0.55, 0.36), DARK)
		else:
			box(parent, Vector3(0.35, 0.12, 0.3), Vector3(0.35, 0.08, 0.2), STONE_DK, Vector3(0.2, 0.4, 0.5))
		return
	var length := 1.55
	box(parent, Vector3(0.28, h, length), Vector3(0, h * 0.5, 0), col)
	if gate:
		box(parent, Vector3(0.3, h * 0.72, 0.46), Vector3(0.02, h * 0.32, 0), WOOD.darkened(0.15))
		cyl(parent, 0.06, h + 0.15, Vector3(0, (h + 0.15) * 0.5, 0.32), STONE.lightened(0.05), 6)
		cyl(parent, 0.06, h + 0.15, Vector3(0, (h + 0.15) * 0.5, -0.32), STONE.lightened(0.05), 6)
	if not damaged:
		for i in 4:
			var z := -0.55 + float(i) * 0.36
			if gate and absf(z) < 0.28:
				continue
			box(parent, Vector3(0.3, 0.16, 0.18), Vector3(0, h + 0.08, z), col.lightened(0.04))
	else:
		box(parent, Vector3(0.4, 0.14, 0.35), Vector3(0.25, 0.08, 0.4), STONE_DK, Vector3(0.4, 0.2, 0.3))
		box(parent, Vector3(0.22, 0.28, 0.2), Vector3(-0.05, h * 0.35, -0.45), col.darkened(0.08))
