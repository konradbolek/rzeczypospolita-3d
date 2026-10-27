class_name MeshFigures
extends RefCounted
## Bryły low-poly (Box/Cylinder/Sphere) w kolorach zbliżonych do PNG mapy i sylwetek jednostek.
## Wspólne dla mapy świata i pola bitwy. Skala: stopy w (0,0,0), postać patrzy w +X, wysokość ~1.

const SKIN := Color(0.93, 0.76, 0.6)
const STEEL := Color(0.78, 0.8, 0.84)
const WOOD := Color(0.45, 0.28, 0.12)
const WOOD_DK := Color(0.28, 0.16, 0.08)
const STONE := Color(0.62, 0.6, 0.55)
const STONE_DK := Color(0.42, 0.4, 0.37)
const ROOF := Color(0.62, 0.18, 0.13)
const GOLD := Color(0.95, 0.78, 0.22)
const CLOTH := Color(0.93, 0.9, 0.82)
const PINE := Color(0.13, 0.36, 0.16)
const OAK := Color(0.2, 0.45, 0.16)
const DARK := Color(0.1, 0.08, 0.06)

static var _mats: Dictionary = {}


static func M(c: Color) -> StandardMaterial3D:
	var key := (int(c.r8) << 16) | (int(c.g8) << 8) | int(c.b8)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c.r, c.g, c.b)
		m.roughness = 0.84
		_mats[key] = m
	return _mats[key]


static func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	b.material = M(col)
	return _mi(parent, b, pos, rot)


static func cyl(parent: Node3D, r: float, h: float, pos: Vector3, col: Color, seg := 8, r2 := -1.0, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r if r2 < 0.0 else r2
	m.bottom_radius = r
	m.height = h
	m.radial_segments = seg
	m.material = M(col)
	return _mi(parent, m, pos, rot)


static func cone(parent: Node3D, r: float, h: float, pos: Vector3, col: Color, seg := 7) -> MeshInstance3D:
	return cyl(parent, r, h, pos, col, seg, 0.0)


static func sph(parent: Node3D, r: float, pos: Vector3, col: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 6
	m.material = M(col)
	return _mi(parent, m, pos)


static func banner(parent: Node3D, col: Color, at: Vector3, h := 1.05) -> void:
	cyl(parent, 0.02, h, at + Vector3(0, h * 0.5, 0), WOOD_DK, 6)
	box(parent, Vector3(0.26, 0.16, 0.02), at + Vector3(0.13, h - 0.1, 0), col)


## ---------- Jednostki ----------

static func unit(unit_id: String, col: Color) -> Node3D:
	var root := Node3D.new()
	var kind := UnitArt.kind_of(unit_id) if unit_id != "" else "piechota"
	match kind:
		"jazda", "lisowczycy", "dragonia", "husaria":
			_cavalry(root, kind, col)
		"wilk":
			_beast(root, false, col)
		"niedzwiedz":
			_beast(root, true, col)
		_:
			_infantry(root, kind, col)
	return root


static func _legs(parent: Node3D, col: Color) -> void:
	box(parent, Vector3(0.07, 0.28, 0.07), Vector3(-0.06, 0.14, 0), col.darkened(0.35))
	box(parent, Vector3(0.07, 0.28, 0.07), Vector3(0.06, 0.14, 0), col.darkened(0.35))


static func _head(parent: Node3D, y: float) -> void:
	sph(parent, 0.09, Vector3(0, y, 0), SKIN)


static func _infantry(parent: Node3D, kind: String, col: Color) -> void:
	_legs(parent, DARK)
	var torso := col
	if kind == "halabardnicy":
		torso = STEEL
	box(parent, Vector3(0.26, 0.32, 0.16), Vector3(0, 0.44, 0), torso)
	box(parent, Vector3(0.27, 0.05, 0.17), Vector3(0, 0.36, 0), col.lightened(0.25))
	_head(parent, 0.7)
	match kind:
		"lucznicy":
			cone(parent, 0.1, 0.12, Vector3(0, 0.82, 0), col.darkened(0.25), 5)
			box(parent, Vector3(0.05, 0.22, 0.05), Vector3(-0.14, 0.48, 0), WOOD)
			_bow(parent, Vector3(0.16, 0.5, 0))
		"arkebuzerzy":
			box(parent, Vector3(0.22, 0.04, 0.22), Vector3(0, 0.8, 0), DARK)
			box(parent, Vector3(0.1, 0.08, 0.1), Vector3(0, 0.86, 0), DARK)
			box(parent, Vector3(0.42, 0.04, 0.04), Vector3(0.22, 0.5, 0.06), WOOD_DK)
			sph(parent, 0.03, Vector3(0.44, 0.5, 0.06), Color(0.15, 0.15, 0.15))
		"halabardnicy":
			cyl(parent, 0.1, 0.06, Vector3(0, 0.78, 0), STEEL, 8, 0.08)
			box(parent, Vector3(0.04, 0.7, 0.04), Vector3(0.2, 0.4, 0), WOOD)
			box(parent, Vector3(0.14, 0.1, 0.04), Vector3(0.26, 0.72, 0), STEEL)
			cone(parent, 0.04, 0.12, Vector3(0.2, 0.8, 0), STEEL, 4)
		"kusznicy":
			cyl(parent, 0.1, 0.05, Vector3(0, 0.78, 0), STEEL, 8)
			box(parent, Vector3(0.28, 0.04, 0.05), Vector3(0.16, 0.5, 0), WOOD)
			box(parent, Vector3(0.04, 0.16, 0.04), Vector3(0.28, 0.5, 0), DARK)
			box(parent, Vector3(0.05, 0.16, 0.05), Vector3(-0.16, 0.46, 0), WOOD)
		_:
			cone(parent, 0.11, 0.14, Vector3(0, 0.84, 0), STEEL, 6)
			box(parent, Vector3(0.04, 0.62, 0.04), Vector3(0.18, 0.42, 0), WOOD)
			cone(parent, 0.045, 0.12, Vector3(0.18, 0.78, 0), STEEL, 4)
			box(parent, Vector3(0.04, 0.22, 0.16), Vector3(-0.16, 0.46, 0), col.lightened(0.3))


static func _bow(parent: Node3D, at: Vector3) -> void:
	box(parent, Vector3(0.03, 0.28, 0.03), at + Vector3(0, 0.06, 0), WOOD, Vector3(0, 0, 0.5))
	box(parent, Vector3(0.03, 0.28, 0.03), at + Vector3(0, -0.06, 0), WOOD, Vector3(0, 0, -0.5))
	box(parent, Vector3(0.01, 0.22, 0.01), at + Vector3(0.06, 0, 0), CLOTH)


static func _horse(parent: Node3D, coat: Color) -> void:
	box(parent, Vector3(0.62, 0.2, 0.18), Vector3(-0.02, 0.38, 0), coat)
	box(parent, Vector3(0.16, 0.16, 0.12), Vector3(0.36, 0.52, 0), coat)
	sph(parent, 0.08, Vector3(0.46, 0.58, 0), coat.darkened(0.1))
	box(parent, Vector3(0.04, 0.16, 0.03), Vector3(-0.34, 0.42, 0), coat.darkened(0.35), Vector3(0, 0, 0.8))
	for x in [-0.2, -0.05, 0.12, 0.24]:
		box(parent, Vector3(0.05, 0.28, 0.05), Vector3(x, 0.14, 0.07), coat.darkened(0.45))
		box(parent, Vector3(0.05, 0.28, 0.05), Vector3(x, 0.14, -0.07), coat.darkened(0.45))


static func _rider(parent: Node3D, col: Color, y: float) -> void:
	box(parent, Vector3(0.18, 0.2, 0.14), Vector3(0.02, y, 0), col)
	_head(parent, y + 0.2)


static func _cavalry(parent: Node3D, kind: String, col: Color) -> void:
	var coat := Color(0.5, 0.32, 0.16)
	match kind:
		"lisowczycy":
			coat = Color(0.22, 0.16, 0.12)
		"dragonia":
			coat = Color(0.32, 0.22, 0.14)
		"husaria":
			coat = Color(0.9, 0.88, 0.82)
	_horse(parent, coat)
	_rider(parent, col, 0.66)
	match kind:
		"lisowczycy":
			box(parent, Vector3(0.12, 0.06, 0.12), Vector3(0.02, 0.92, 0), Color(0.35, 0.22, 0.12))
			box(parent, Vector3(0.02, 0.12, 0.04), Vector3(0.08, 1.0, 0), CLOTH)
			box(parent, Vector3(0.22, 0.03, 0.03), Vector3(0.18, 0.7, 0.1), STEEL, Vector3(0, 0.4, -0.6))
		"dragonia":
			box(parent, Vector3(0.2, 0.035, 0.2), Vector3(0.02, 0.92, 0), DARK)
			box(parent, Vector3(0.28, 0.035, 0.035), Vector3(0.16, 0.72, 0.08), DARK)
		"husaria":
			box(parent, Vector3(0.16, 0.12, 0.12), Vector3(0.02, 0.66, 0), STEEL)
			cone(parent, 0.09, 0.1, Vector3(0.02, 0.96, 0), STEEL, 5)
			box(parent, Vector3(0.5, 0.03, 0.03), Vector3(0.22, 0.78, 0), Color(0.85, 0.78, 0.45))
			for i in 4:
				var yy := 0.55 + float(i) * 0.1
				box(parent, Vector3(0.22, 0.025, 0.05), Vector3(-0.16, yy, -0.02), CLOTH, Vector3(0, 0, 0.9))
		_:
			cone(parent, 0.09, 0.1, Vector3(0.02, 0.96, 0), STEEL, 5)
			box(parent, Vector3(0.55, 0.03, 0.03), Vector3(0.28, 0.8, 0), WOOD)


static func _beast(parent: Node3D, bear: bool, col: Color) -> void:
	var coat := Color(0.35, 0.28, 0.22) if bear else Color(0.45, 0.45, 0.47)
	coat = coat.lerp(col, 0.25)
	if bear:
		box(parent, Vector3(0.55, 0.32, 0.32), Vector3(0, 0.36, 0), coat)
		sph(parent, 0.16, Vector3(0.32, 0.46, 0), coat.darkened(0.05))
		sph(parent, 0.06, Vector3(0.3, 0.6, 0.1), coat.darkened(0.15))
		sph(parent, 0.06, Vector3(0.3, 0.6, -0.1), coat.darkened(0.15))
		box(parent, Vector3(0.08, 0.22, 0.1), Vector3(0.16, 0.14, 0.12), coat.darkened(0.3))
		box(parent, Vector3(0.08, 0.22, 0.1), Vector3(0.16, 0.14, -0.12), coat.darkened(0.3))
		box(parent, Vector3(0.08, 0.22, 0.1), Vector3(-0.18, 0.14, 0.12), coat.darkened(0.3))
		box(parent, Vector3(0.08, 0.22, 0.1), Vector3(-0.18, 0.14, -0.12), coat.darkened(0.3))
	else:
		box(parent, Vector3(0.5, 0.18, 0.16), Vector3(0, 0.28, 0), coat)
		box(parent, Vector3(0.16, 0.14, 0.12), Vector3(0.3, 0.38, 0), coat.lightened(0.05))
		cone(parent, 0.04, 0.1, Vector3(0.28, 0.5, 0.06), coat.darkened(0.2), 4)
		cone(parent, 0.04, 0.1, Vector3(0.28, 0.5, -0.06), coat.darkened(0.2), 4)
		box(parent, Vector3(0.16, 0.03, 0.03), Vector3(-0.32, 0.32, 0), coat.darkened(0.15), Vector3(0, 0, 0.6))
		for x in [-0.14, 0.12]:
			box(parent, Vector3(0.04, 0.2, 0.04), Vector3(x, 0.12, 0.06), coat.darkened(0.3))
			box(parent, Vector3(0.04, 0.2, 0.04), Vector3(x, 0.12, -0.06), coat.darkened(0.3))


## ---------- Zamek ----------

static func castle(accent: Color) -> Node3D:
	var root := Node3D.new()
	cyl(root, 0.92, 0.16, Vector3(0, 0.08, 0), STONE, 6)
	for i in 6:
		var a := TAU * float(i) / 6.0 + PI / 6.0
		var p := Vector3(cos(a) * 0.72, 0.42, sin(a) * 0.72)
		cyl(root, 0.13, 0.52, p, STONE_DK, 6)
		box(root, Vector3(0.1, 0.08, 0.1), p + Vector3(0, 0.32, 0), accent)
	box(root, Vector3(0.7, 0.38, 0.16), Vector3(0, 0.36, 0.15), STONE)
	box(root, Vector3(0.16, 0.38, 0.7), Vector3(0, 0.36, -0.05), STONE)
	box(root, Vector3(0.34, 0.7, 0.34), Vector3(0, 0.58, 0), STONE.lightened(0.06))
	cone(root, 0.28, 0.38, Vector3(0, 1.08, 0), ROOF, 4)
	box(root, Vector3(0.16, 0.22, 0.06), Vector3(0, 0.28, 0.48), DARK)
	box(root, Vector3(0.08, 0.1, 0.04), Vector3(0.1, 0.7, 0.18), Color(0.15, 0.18, 0.22))
	box(root, Vector3(0.08, 0.1, 0.04), Vector3(-0.1, 0.7, 0.18), Color(0.15, 0.18, 0.22))
	banner(root, accent, Vector3(0, 1.2, 0), 0.7)
	return root


## ---------- Surowce i kopalnie ----------

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


## ---------- Artefakty ----------

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


## ---------- Port, statek, sceneria mapy ----------

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
			sph(root, 0.2, Vector3(0, 0.4, 0), OAK)
			sph(root, 0.12, Vector3(0.12, 0.46, 0.05), OAK.darkened(0.08))
		"pine":
			cyl(root, 0.04, 0.2, Vector3(0, 0.1, 0), WOOD, 5)
			cone(root, 0.16, 0.28, Vector3(0, 0.32, 0), PINE, 6)
			cone(root, 0.12, 0.22, Vector3(0, 0.5, 0), PINE.lightened(0.08), 6)
		"rock":
			box(root, Vector3(0.28, 0.16, 0.22), Vector3(0, 0.08, 0), Color(0.5, 0.5, 0.52), Vector3(0.1, 0.3, 0))
			box(root, Vector3(0.16, 0.14, 0.14), Vector3(0.12, 0.12, 0.06), Color(0.62, 0.62, 0.64))
		"bush":
			sph(root, 0.12, Vector3(0, 0.1, 0), OAK.darkened(0.1))
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


## ---------- Pole bitwy ----------

static func battle_prop(kind: String, damaged: bool) -> Node3D:
	var root := Node3D.new()
	match kind:
		"hill":
			sph(root, 0.55, Vector3(0, 0.05, 0), Color(0.48, 0.4, 0.24))
			root.scale = Vector3(1.15, 0.45, 0.9)
			sph(root, 0.28, Vector3(-0.1, 0.22, 0.05), Color(0.58, 0.5, 0.3))
		"rock":
			box(root, Vector3(0.7, 0.4, 0.55), Vector3(0, 0.22, 0), Color(0.48, 0.48, 0.5), Vector3(0.05, 0.2, 0.1))
			box(root, Vector3(0.4, 0.35, 0.35), Vector3(0.2, 0.4, 0.05), Color(0.35, 0.35, 0.38))
			box(root, Vector3(0.3, 0.22, 0.28), Vector3(-0.25, 0.18, -0.05), Color(0.58, 0.58, 0.6))
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
