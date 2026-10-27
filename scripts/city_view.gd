extends Node3D
## Widok miasta w 3D. Mapa jest wtedy poza drzewem; tu nie ma cieni, Label3D ani triplanaru.
## Rekrutacja zostaje nakładką 2D — ta scena to tylko sceneria.

signal building_picked(bid: String)

const Surf := preload("res://scripts/surface_tex.gd")
const ORDER := ["ratusz", "koszary", "kuznia", "wieza", "targ", "stajnia", "mur"]
const STYLES := {
	"polska": {
		"wall": "stone_brick", "roof": "roof_tile", "wood": "wood_plank", "log": "wood_log",
		"trim": "stone_block", "ground": "grass_lush", "path": "dirt_path", "accent": "cloth",
		"foliage": "foliage", "dome": false, "ground_tint": Color(1, 1, 1),
		"sky": Color(0.55, 0.73, 0.92), "flag": Color(0.78, 0.12, 0.14),
	},
	"szwecja": {
		"wall": "wood_plank", "roof": "wood", "wood": "wood", "log": "wood_log",
		"trim": "stone", "ground": "grass_moss", "path": "dirt", "accent": "cloth_wool",
		"foliage": "foliage_dark", "dome": false, "ground_tint": Color(0.82, 0.88, 0.9),
		"sky": Color(0.68, 0.76, 0.84), "flag": Color(0.12, 0.32, 0.7),
	},
	"osmanowie": {
		"wall": "stone_block", "roof": "roof", "wood": "wood", "log": "wood_log",
		"trim": "stone", "ground": "sand", "path": "sand_ripples", "accent": "cloth_linen",
		"foliage": "foliage", "dome": true, "ground_tint": Color(1, 0.97, 0.9),
		"sky": Color(0.45, 0.72, 0.95), "flag": Color(0.1, 0.48, 0.28),
	},
	"moskwa": {
		"wall": "wood_log", "roof": "wood_plank", "wood": "wood", "log": "wood_log",
		"trim": "stone_rough", "ground": "grass_dry", "path": "dirt_dark", "accent": "cloth",
		"foliage": "foliage_dark", "dome": false, "ground_tint": Color(0.95, 0.93, 0.88),
		"sky": Color(0.62, 0.7, 0.82), "flag": Color(0.55, 0.12, 0.12),
	},
	"kozacy": {
		"wall": "wood", "roof": "wheat_field", "wood": "wood", "log": "wood_log",
		"trim": "mud", "ground": "grass_dry", "path": "dirt_path", "accent": "cloth_wool",
		"foliage": "foliage", "dome": false, "ground_tint": Color(1, 0.98, 0.9),
		"sky": Color(0.62, 0.78, 0.92), "flag": Color(0.15, 0.38, 0.62),
	},
	"brandenburgia": {
		"wall": "stone", "roof": "stone_brick", "wood": "wood_plank", "log": "wood_log",
		"trim": "stone_block", "ground": "grass", "path": "dirt", "accent": "cloth_linen",
		"foliage": "foliage", "dome": false, "ground_tint": Color(0.94, 0.95, 0.96),
		"sky": Color(0.58, 0.68, 0.78), "flag": Color(0.22, 0.26, 0.32),
	},
}

var _faction := "polska"
var _owned := true
var _buildings: Dictionary = {}
var _sig := ""
var _token := 0
var _shown := false
var _trace := false
var _root: Node3D
var _rig: Node3D
var _cam: Camera3D
var _sun: DirectionalLight3D
var _env: WorldEnvironment
var _hi: MeshInstance3D
var _focus := "ratusz"
var _pick: Array = []
var _anchors: Dictionary = {}


func _ready() -> void:
	visible = false
	_trace = "--city" in OS.get_cmdline_user_args()


func present(faction: String, owned: bool, buildings: Dictionary) -> void:
	var sig := _sig_of(faction, owned, buildings)
	if sig == _sig and _shown:
		highlight(_focus)
		return
	_sig = sig
	_token += 1
	var token := _token
	_faction = faction if STYLES.has(faction) else "polska"
	_owned = owned
	_buildings = buildings.duplicate()
	visible = true
	if _shown and _rig and is_instance_valid(_rig):
		_rebuild()
		_log_ready()
		return
	_drop_content()
	# Klatka przerwy po zdjęciu mapy — atlas cieni ma spaść zanim staną budynki.
	await get_tree().process_frame
	if token != _token or not is_inside_tree():
		return
	_ensure_rig()
	_rebuild()
	_shown = true
	_log_ready()


func dismiss() -> void:
	_token += 1
	_shown = false
	_sig = ""
	visible = false
	_drop_content()
	_drop_rig()


func highlight(bid: String) -> void:
	_focus = bid
	if _hi == null or not is_instance_valid(_hi):
		return
	if not _anchors.has(bid):
		_hi.visible = false
		return
	var a: Dictionary = _anchors[bid]
	var p: Vector3 = a["pos"]
	_hi.visible = true
	_hi.position = Vector3(p.x, 0.08, p.z)
	var r := float(a["r"])
	_hi.scale = Vector3(r, 1.0, r)


func debug_ready() -> bool:
	return _shown


func debug_mesh_count() -> int:
	return _mesh_count(self)


func debug_shadow() -> bool:
	return _sun != null and _sun.shadow_enabled


func debug_pick(bid: String) -> void:
	highlight(bid)
	building_picked.emit(bid)


## Rzut punktu budynku na ekran i ten sam test AABB co klik myszą.
func debug_ray(bid: String) -> String:
	if _cam == null or not _anchors.has(bid):
		return ""
	var p: Vector3 = (_anchors[bid]["pos"] as Vector3) + Vector3(0, 0.9, 0)
	return _pick_at(_cam.unproject_position(p))


func _sig_of(faction: String, owned: bool, buildings: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in ORDER:
		parts.append("%s=%d" % [k, int(buildings.get(k, 0))])
	return "%s|%s|%s" % [faction, str(owned), "|".join(parts)]


func _lv(bid: String) -> int:
	if not _owned:
		return 1
	return int(_buildings.get(bid, 0))


func _st() -> Dictionary:
	return STYLES[_faction]


func _log_ready() -> void:
	if not _trace:
		return
	print("CITY_READY meshes=%d shadows=%s label3d=%d triplanar=%d" % [
		_mesh_count(self),
		str(_sun.shadow_enabled) if _sun else "nil",
		_count_label(self),
		_count_tri(self),
	])


func _ensure_rig() -> void:
	if _rig and is_instance_valid(_rig):
		_apply_sky()
		if _cam:
			_cam.current = true
		return
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.82, 0.84)
	e.ambient_light_energy = 0.62
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env = WorldEnvironment.new()
	_env.environment = e
	_rig.add_child(_env)
	_apply_sky()
	_sun = DirectionalLight3D.new()
	_sun.name = "CitySun"
	_sun.shadow_enabled = false
	_sun.light_energy = 1.25
	_sun.rotation_degrees = Vector3(-46, 32, 0)
	_rig.add_child(_sun)
	_cam = Camera3D.new()
	_cam.name = "CityCam"
	_cam.fov = 34.0
	_cam.near = 0.08
	_cam.far = 80.0
	_cam.position = Vector3(11.2, 8.4, 12.6)
	_rig.add_child(_cam)
	_cam.look_at(Vector3(0.2, 1.05, 0.0), Vector3.UP)
	_cam.current = true


func _apply_sky() -> void:
	if _env and _env.environment:
		_env.environment.background_color = _st()["sky"]


func _rebuild() -> void:
	_drop_content()
	_root = Node3D.new()
	_root.name = "Town"
	add_child(_root)
	_pick.clear()
	_anchors.clear()
	var st := _st()
	_ground(st)
	_walls(st, _lv("mur"))
	_add_built("ratusz", Vector3(0.0, 0, -2.35), _ratusz(st, _lv("ratusz")))
	_add_built("wieza", Vector3(-4.7, 0, -3.55), _wieza(st, _lv("wieza")))
	_add_built("targ", Vector3(3.7, 0, -1.35), _targ(st, _lv("targ")))
	_add_built("koszary", Vector3(-3.15, 0, 1.55), _koszary(st, _lv("koszary")))
	_add_built("stajnia", Vector3(0.35, 0, 2.45), _stajnia(st, _lv("stajnia")))
	_add_built("kuznia", Vector3(3.85, 0, 1.7), _kuznia(st, _lv("kuznia")))
	_dress(st)
	_make_highlight()
	_no_shadows(_root)
	highlight(_focus)


func _add_built(bid: String, pos: Vector3, built: Dictionary) -> void:
	var n: Node3D = built["node"]
	n.position = pos
	n.name = bid
	_root.add_child(n)
	var box: AABB = built["aabb"]
	_pick.append({"bid": bid, "aabb": AABB(box.position + pos, box.size)})
	_anchors[bid] = {"pos": pos, "r": float(built["r"])}


func _ground(st: Dictionary) -> void:
	var tint: Color = st["ground_tint"]
	_plane(Vector2(20.0, 16.0), Vector3(0, -0.02, 0.2), str(st["ground"]), tint, 5.0)
	_box(_root, Vector3(2.4, 0.04, 11.2), Vector3(0, 0.02, 0.2), str(st["path"]), 3.0, Color.WHITE)
	_box(_root, Vector3(12.4, 0.045, 2.2), Vector3(0, 0.03, 0.4), str(st["path"]), 3.0, Color.WHITE)
	# podwórze z ubitej ziemi
	_box(_root, Vector3(10.6, 0.03, 7.6), Vector3(0.1, 0.015, 0.15), "dirt", 3.5, Color(0.96, 0.94, 0.9))


func _walls(st: Dictionary, lvl: int) -> void:
	var stone := lvl >= 1
	var id := str(st["wall"]) if stone else str(st["log"])
	var h := 0.7 + float(mini(lvl, 3)) * 0.38
	var y := h * 0.5
	var x0 := -6.5
	var x1 := 6.5
	var z0 := -5.15
	var z1 := 5.05
	var t := 0.42
	# północ i boki — pełne
	_wall_run(Vector3(0, y, z0), Vector3(x1 - x0 + t, h, t), id, "mur", h)
	_wall_run(Vector3(x0, y, 0), Vector3(t, h, z1 - z0), id, "mur", h)
	_wall_run(Vector3(x1, y, 0), Vector3(t, h, z1 - z0), id, "mur", h)
	# południe z bramą (w stronę kamery)
	var gap := 1.7
	var side := (x1 - x0 - gap) * 0.5
	_wall_run(Vector3(x0 + side * 0.5, y, z1), Vector3(side, h, t), id, "mur", h)
	_wall_run(Vector3(x1 - side * 0.5, y, z1), Vector3(side, h, t), id, "mur", h)
	if stone and lvl >= 2:
		for i in 7:
			var x := -5.4 + float(i) * 1.8
			if absf(x) < 1.15:
				continue
			_box(_root, Vector3(0.34, 0.28, 0.46), Vector3(x, h + 0.12, z1), id, 1.4)
			_box(_root, Vector3(0.34, 0.28, 0.46), Vector3(x, h + 0.12, z0), id, 1.4)
	# brama
	var gate_h := h * 0.92
	_box(_root, Vector3(0.18, gate_h, 0.5), Vector3(-0.78, gate_h * 0.5, z1), str(st["trim"]), 1.6)
	_box(_root, Vector3(0.18, gate_h, 0.5), Vector3(0.78, gate_h * 0.5, z1), str(st["trim"]), 1.6)
	_box(_root, Vector3(1.9, 0.22, 0.55), Vector3(0, gate_h + 0.05, z1), str(st["trim"]), 1.8)
	_box(_root, Vector3(1.35, gate_h * 0.72, 0.08), Vector3(0, gate_h * 0.38, z1 + 0.16), str(st["wood"]), 2.0, Color(0.85, 0.8, 0.72))
	_banner(_root, Vector3(-1.15, 0, z1 + 0.15), st["flag"], 1.7 + float(lvl) * 0.15)
	_banner(_root, Vector3(1.15, 0, z1 + 0.15), st["flag"], 1.7 + float(lvl) * 0.15)
	if lvl >= 3:
		for c in [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x0, 0, z1), Vector3(x1, 0, z1)]:
			_corner_tower(_root, c, h + 0.9, str(st["trim"]), str(st["roof"]))
	_anchors["mur"] = {"pos": Vector3(0, 0, z1), "r": 2.4}
	_pick.append({"bid": "mur", "aabb": AABB(Vector3(-1.3, 0, z1 - 0.5), Vector3(2.6, h + 0.6, 1.3))})


func _wall_run(pos: Vector3, size: Vector3, id: String, bid: String, h: float) -> void:
	_box(_root, size, pos, id, 2.2)
	_pick.append({"bid": bid, "aabb": AABB(pos - size * 0.5, size)})
	if h > 0.8:
		# blanki co kawałek na długich murach — tylko gdy to nie brama
		pass


func _ratusz(st: Dictionary, lvl: int) -> Dictionary:
	var n := Node3D.new()
	var w := 3.3
	var d := 2.35
	if lvl <= 0:
		_timber_hut(n, Vector3(2.2, 1.15, 1.6), st, false)
		return _pack(n, Vector3(-1.2, 0, -0.9), Vector3(2.4, 1.5, 1.8), 1.5)
	var h := 1.35 + float(mini(lvl, 2) - 1) * 0.55
	_box(n, Vector3(w, h, d), Vector3(0, h * 0.5, 0), str(st["wall"]), 2.4)
	_windows(n, Vector3(w, h, d), 0.15)
	_box(n, Vector3(0.7, 0.95, 0.08), Vector3(0, 0.5, d * 0.5 + 0.02), str(st["wood"]), 1.5, Color(0.75, 0.62, 0.45))
	if bool(st["dome"]):
		_sph(n, 1.15, Vector3(0, h + 0.55, 0), str(st["trim"]), Color(0.96, 0.93, 0.86))
		_cyl(n, 0.08, 0.45, Vector3(0, h + 1.7, 0), "gold", Color(0.9, 0.75, 0.3))
	else:
		_gable(n, Vector3(0, h, 0), w + 0.35, d + 0.25, 0.7 + float(lvl) * 0.12, str(st["roof"]))
		if lvl >= 2:
			_box(n, Vector3(0.7, 0.9, 0.7), Vector3(0, h + 0.45, -0.15), str(st["trim"]), 1.6)
			_cone(n, 0.5, 0.55, Vector3(0, h + 1.15, -0.15), str(st["roof"]))
	_chimney(n, Vector3(w * 0.32, h + 0.15, -d * 0.2), str(st["trim"]))
	return _pack(n, Vector3(-w * 0.5, 0, -d * 0.5), Vector3(w, h + 1.5, d), 2.1)


func _wieza(st: Dictionary, lvl: int) -> Dictionary:
	var n := Node3D.new()
	if lvl <= 0:
		_cyl(n, 0.35, 1.1, Vector3(0, 0.55, 0), str(st["log"]))
		_cone(n, 0.5, 0.4, Vector3(0, 1.25, 0), str(st["roof"]))
		return _pack(n, Vector3(-0.5, 0, -0.5), Vector3(1.0, 1.8, 1.0), 0.9)
	var h := 2.3
	_cyl(n, 0.72, h, Vector3(0, h * 0.5, 0), str(st["wall"]), Color.WHITE, 10)
	_box(n, Vector3(0.28, 0.4, 0.06), Vector3(0, h * 0.55, 0.74), "stone_rough", 1.0, Color(0.15, 0.16, 0.2))
	_cone(n, 0.95, 0.7, Vector3(0, h + 0.25, 0), str(st["roof"]), 10)
	_cyl(n, 0.04, 0.55, Vector3(0, h + 0.85, 0), str(st["log"]))
	_box(n, Vector3(0.38, 0.22, 0.03), Vector3(0.16, h + 0.95, 0), str(st["accent"]), 1.0, st["flag"])
	return _pack(n, Vector3(-0.9, 0, -0.9), Vector3(1.8, h + 1.3, 1.8), 1.15)


func _targ(st: Dictionary, lvl: int) -> Dictionary:
	var n := Node3D.new()
	var stalls := 1 + mini(lvl, 3)
	if lvl <= 0:
		stalls = 1
	for i in stalls:
		var x := float(i - 1) * 1.15
		_stall(n, Vector3(x, 0, 0), st, i)
	var span := 1.2 + float(stalls) * 1.05
	return _pack(n, Vector3(-span * 0.5, 0, -0.7), Vector3(span, 1.5, 1.5), span * 0.45)


func _stall(parent: Node3D, at: Vector3, st: Dictionary, i: int) -> void:
	_box(parent, Vector3(0.95, 0.55, 0.7), at + Vector3(0, 0.32, 0), str(st["wood"]), 1.8)
	var cloth := "cloth_linen" if i % 2 == 0 else "cloth_wool"
	var col: Color = st["flag"] if i == 0 else Color.WHITE
	_box(parent, Vector3(1.15, 0.06, 0.95), at + Vector3(0, 0.78, 0), cloth, 1.2, col, Vector3(0, 0, 0.12))
	_box(parent, Vector3(0.08, 0.85, 0.08), at + Vector3(-0.4, 0.42, 0.32), str(st["log"]), 1.0)
	_box(parent, Vector3(0.08, 0.85, 0.08), at + Vector3(0.4, 0.42, 0.32), str(st["log"]), 1.0)
	_box(parent, Vector3(0.35, 0.28, 0.35), at + Vector3(0.15, 0.16, 0.45), "wood", 1.2, Color(0.8, 0.7, 0.5))


func _koszary(st: Dictionary, lvl: int) -> Dictionary:
	var n := Node3D.new()
	var len := 2.6 + float(mini(lvl, 5)) * 0.28
	if lvl <= 0:
		_timber_hut(n, Vector3(2.4, 1.05, 1.35), st, true)
		return _pack(n, Vector3(-1.3, 0, -0.75), Vector3(2.6, 1.4, 1.5), 1.5)
	var h := 1.05 + (0.35 if lvl >= 3 else 0.0)
	_box(n, Vector3(len, h, 1.45), Vector3(0, h * 0.5, 0), str(st["wood"]), 2.2)
	_gable(n, Vector3(0, h, 0), len + 0.2, 1.7, 0.48, str(st["roof"]))
	_windows(n, Vector3(len, h, 1.45), 0.12)
	_box(n, Vector3(0.55, 0.8, 0.06), Vector3(0, 0.42, 0.76), str(st["log"]), 1.2, Color(0.55, 0.38, 0.22))
	if lvl >= 4:
		_box(n, Vector3(0.9, 0.7, 0.9), Vector3(len * 0.5 - 0.2, 0.4, 1.0), str(st["log"]), 1.4)
		_box(n, Vector3(1.05, 0.08, 1.05), Vector3(len * 0.5 - 0.2, 0.78, 1.0), str(st["roof"]), 1.2)
	return _pack(n, Vector3(-len * 0.5, 0, -0.85), Vector3(len, h + 0.8, 2.2), len * 0.45)


func _stajnia(st: Dictionary, lvl: int) -> Dictionary:
	var n := Node3D.new()
	var len := 2.5 + (0.7 if lvl >= 2 else 0.0)
	if lvl <= 0:
		_timber_hut(n, Vector3(2.2, 0.95, 1.4), st, true)
		return _pack(n, Vector3(-1.2, 0, -0.8), Vector3(2.4, 1.3, 1.6), 1.4)
	var h := 1.0
	_box(n, Vector3(len, h, 1.55), Vector3(0, h * 0.5, 0), str(st["wood"]), 2.0)
	_gable(n, Vector3(0, h, 0), len + 0.15, 1.8, 0.42, "wood")
	# otwarte stanowiska
	var bays := 3 if lvl >= 2 else 2
	for i in bays:
		var x := -len * 0.28 + float(i) * (len * 0.28)
		_box(n, Vector3(0.55, 0.7, 0.06), Vector3(x, 0.4, 0.8), "stone_rough", 1.0, Color(0.12, 0.1, 0.08))
		_box(n, Vector3(0.5, 0.22, 0.4), Vector3(x, 0.14, 1.15), "wheat_field", 1.4, Color(0.95, 0.85, 0.45))
	_box(n, Vector3(0.08, h, 0.08), Vector3(-len * 0.5 + 0.05, h * 0.5, 0.78), str(st["log"]), 1.0)
	_box(n, Vector3(0.08, h, 0.08), Vector3(len * 0.5 - 0.05, h * 0.5, 0.78), str(st["log"]), 1.0)
	return _pack(n, Vector3(-len * 0.5, 0, -0.85), Vector3(len, h + 0.7, 2.2), len * 0.42)


func _kuznia(st: Dictionary, lvl: int) -> Dictionary:
	var n := Node3D.new()
	if lvl <= 0:
		_timber_hut(n, Vector3(1.7, 1.0, 1.4), st, false)
		_chimney(n, Vector3(0.45, 1.0, -0.2), str(st["trim"]))
		return _pack(n, Vector3(-0.95, 0, -0.8), Vector3(1.9, 1.8, 1.6), 1.15)
	var h := 1.15
	_box(n, Vector3(2.05, h, 1.6), Vector3(0, h * 0.5, 0), "stone_rough", 2.0)
	_gable(n, Vector3(0, h, 0), 2.3, 1.85, 0.45, str(st["roof"]))
	_box(n, Vector3(0.7, 0.75, 0.08), Vector3(0, 0.42, 0.84), "stone_rough", 1.0, Color(0.1, 0.08, 0.07))
	# palenisko — unshaded, bez emisji w shaderze światła
	var glow := _box(n, Vector3(0.35, 0.22, 0.28), Vector3(0.15, 0.2, 0.55), "", 1.0, Color(0.95, 0.45, 0.12))
	var gm := glow.mesh as BoxMesh
	if gm and gm.material is StandardMaterial3D:
		(gm.material as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box(n, Vector3(0.38, 0.16, 0.22), Vector3(-0.55, 0.4, 0.7), "metal_plate", 1.5, Color(0.75, 0.78, 0.82))
	_chimney(n, Vector3(0.55, h + 0.05, -0.25), "stone_brick")
	return _pack(n, Vector3(-1.15, 0, -0.9), Vector3(2.3, h + 1.3, 1.9), 1.35)


func _timber_hut(parent: Node3D, size: Vector3, st: Dictionary, long_roof: bool) -> void:
	_box(parent, size, Vector3(0, size.y * 0.5, 0), str(st["log"]), 1.6, Color(0.92, 0.86, 0.76))
	_gable(parent, Vector3(0, size.y, 0), size.x + 0.15, size.z + 0.2, 0.38 if not long_roof else 0.32, str(st["roof"]))
	_box(parent, Vector3(0.4, size.y * 0.55, 0.05), Vector3(0, size.y * 0.3, size.z * 0.5 + 0.02), str(st["wood"]), 1.0, Color(0.45, 0.3, 0.16))


func _dress(st: Dictionary) -> void:
	# studnia
	_cyl(_root, 0.42, 0.38, Vector3(-1.55, 0.2, 0.15), "stone", Color.WHITE, 10)
	_cyl(_root, 0.28, 0.08, Vector3(-1.55, 0.4, 0.15), "water", Color(0.75, 0.88, 0.95), 10)
	_box(_root, Vector3(0.08, 0.7, 0.08), Vector3(-1.85, 0.7, 0.15), str(st["log"]), 1.0)
	_box(_root, Vector3(0.08, 0.7, 0.08), Vector3(-1.25, 0.7, 0.15), str(st["log"]), 1.0)
	_box(_root, Vector3(0.75, 0.06, 0.08), Vector3(-1.55, 1.05, 0.15), str(st["log"]), 1.0)
	# drzewa za murami
	_pine(_root, Vector3(-8.2, 0, -2.4), st, 1.15)
	_pine(_root, Vector3(-7.6, 0, 2.8), st, 0.85)
	_pine(_root, Vector3(8.0, 0, -3.2), st, 1.0)
	_pine(_root, Vector3(7.4, 0, 3.4), st, 1.25)
	# łan i krzak
	_box(_root, Vector3(2.2, 0.35, 1.4), Vector3(-8.0, 0.18, 0.2), "wheat_field", 2.0, Color(0.95, 0.86, 0.45))
	_sph(_root, 0.35, Vector3(7.8, 0.28, 0.4), str(st["foliage"]))
	# beczki przy kuźni
	_cyl(_root, 0.18, 0.32, Vector3(2.7, 0.16, 2.55), str(st["log"]), Color.WHITE, 8)
	_cyl(_root, 0.16, 0.28, Vector3(3.05, 0.14, 2.4), str(st["wood"]), Color.WHITE, 8)


func _pine(parent: Node3D, at: Vector3, st: Dictionary, sc: float) -> void:
	var n := Node3D.new()
	n.position = at
	n.scale = Vector3(sc, sc, sc)
	_cyl(n, 0.12, 0.55, Vector3(0, 0.28, 0), str(st["log"]))
	_cone(n, 0.55, 0.7, Vector3(0, 0.75, 0), str(st["foliage"]))
	_cone(n, 0.38, 0.55, Vector3(0, 1.15, 0), str(st["foliage"]), 7)
	parent.add_child(n)


func _banner(parent: Node3D, at: Vector3, col: Color, h: float) -> void:
	_cyl(parent, 0.045, h, at + Vector3(0, h * 0.5, 0), "wood_log")
	_box(parent, Vector3(0.55, 0.32, 0.03), at + Vector3(0.28, h - 0.22, 0), "cloth", 1.2, col)


func _corner_tower(parent: Node3D, at: Vector3, h: float, wall: String, roof: String) -> void:
	_cyl(parent, 0.55, h, at + Vector3(0, h * 0.5, 0), wall, Color.WHITE, 8)
	_cone(parent, 0.7, 0.5, at + Vector3(0, h + 0.18, 0), roof, 8)
	_pick.append({"bid": "mur", "aabb": AABB(at + Vector3(-0.6, 0, -0.6), Vector3(1.2, h + 0.7, 1.2))})


func _gable(parent: Node3D, base: Vector3, w: float, d: float, rise: float, id: String) -> void:
	# Pryzmat: kalenica wzdłuż X, trójkątne szczyty na krótszych bokach. UV siatki, bez triplanaru.
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(w, rise, d)
	pm.material = Surf.shaded(id, Color.WHITE, 2.2)
	mi.mesh = pm
	mi.position = base + Vector3(0, rise * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _windows(parent: Node3D, size: Vector3, inset: float) -> void:
	var dark := Color(0.16, 0.18, 0.22)
	var z := size.z * 0.5 + 0.03
	var y := size.y * 0.62
	var cols := 2 if size.x < 2.4 else 3
	for i in cols:
		var x := (float(i) - float(cols - 1) * 0.5) * (size.x * 0.28)
		if absf(x) < inset:
			continue
		_box(parent, Vector3(0.22, 0.28, 0.05), Vector3(x, y, z), "stone_rough", 1.0, dark)


func _chimney(parent: Node3D, at: Vector3, id: String) -> void:
	_box(parent, Vector3(0.28, 0.7, 0.28), at + Vector3(0, 0.35, 0), id, 1.4)


func _make_highlight() -> void:
	_hi = MeshInstance3D.new()
	_hi.name = "Hi"
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.05
	cm.radial_segments = 18
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 0.84, 0.25, 0.5)
	mat.uv1_triplanar = false
	cm.material = mat
	_hi.mesh = cm
	_hi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hi.visible = false
	_root.add_child(_hi)


func _pack(n: Node3D, origin: Vector3, size: Vector3, radius: float) -> Dictionary:
	return {"node": n, "aabb": AABB(origin, size), "r": radius}


func _plane(size: Vector2, pos: Vector3, id: String, tint: Color, repeats: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	pm.material = Surf.shaded(id, tint, repeats)
	mi.mesh = pm
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mi)


func _box(parent: Node3D, size: Vector3, pos: Vector3, id: String, repeats: float, tint: Color = Color.WHITE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = Surf.shaded(id, tint, repeats)
	mi.mesh = b
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, id: String, tint: Color = Color.WHITE, seg := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = seg
	m.material = Surf.shaded(id, tint, 1.4)
	mi.mesh = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cone(parent: Node3D, r: float, h: float, pos: Vector3, id: String, seg := 7) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	m.radial_segments = seg
	m.material = Surf.shaded(id, Color.WHITE, 1.3)
	mi.mesh = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _sph(parent: Node3D, r: float, pos: Vector3, id: String, tint: Color = Color.WHITE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 8
	m.material = Surf.shaded(id, tint, 1.2)
	mi.mesh = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for ch in n.get_children():
		_no_shadows(ch)


func _unhandled_input(event: InputEvent) -> void:
	if not _shown or _cam == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var bid := _pick_at(event.position)
		if bid != "":
			building_picked.emit(bid)


func _pick_at(screen: Vector2) -> String:
	var origin := _cam.project_ray_origin(screen)
	var dir := _cam.project_ray_normal(screen)
	var best := ""
	var best_t := 1.0e9
	for item in _pick:
		var box: AABB = item["aabb"]
		var t := _ray_aabb(origin, dir, box)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = str(item["bid"])
	return best


func _ray_aabb(o: Vector3, d: Vector3, box: AABB) -> float:
	var tmin := 0.0
	var tmax := 1.0e9
	var bmin := box.position
	var bmax := box.position + box.size
	for axis in 3:
		var origin := o[axis]
		var dir := d[axis]
		var mn := bmin[axis]
		var mx := bmax[axis]
		if absf(dir) < 0.000001:
			if origin < mn or origin > mx:
				return -1.0
			continue
		var t1 := (mn - origin) / dir
		var t2 := (mx - origin) / dir
		if t1 > t2:
			var tmp := t1
			t1 = t2
			t2 = tmp
		tmin = maxf(tmin, t1)
		tmax = minf(tmax, t2)
		if tmin > tmax:
			return -1.0
	if tmax < 0.0:
		return -1.0
	return tmin


func _drop_content() -> void:
	_hi = null
	_pick.clear()
	if _root and is_instance_valid(_root):
		var old := _root
		_root = null
		old.free()


func _drop_rig() -> void:
	_cam = null
	_sun = null
	_env = null
	if _rig and is_instance_valid(_rig):
		var old := _rig
		_rig = null
		old.free()


func _mesh_count(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for ch in n.get_children():
		c += _mesh_count(ch)
	return c


func _count_label(n: Node) -> int:
	var c := 1 if n is Label3D else 0
	for ch in n.get_children():
		c += _count_label(ch)
	return c


func _count_tri(n: Node) -> int:
	var c := 0
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mats: Array = []
		if mi.material_override:
			mats.append(mi.material_override)
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var sm := mi.mesh.surface_get_material(s)
				if sm:
					mats.append(sm)
		for mat in mats:
			if mat is BaseMaterial3D and (mat as BaseMaterial3D).uv1_triplanar:
				c += 1
	for ch in n.get_children():
		c += _count_tri(ch)
	return c
