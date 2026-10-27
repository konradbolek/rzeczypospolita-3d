extends Node3D
## Prosty widok 3D mapy: czyta stan z WorldMap (2D logika) i renderuje hexy, obiekty i kamerę.

const HEIGHTS := {"morze": 0.05, "rzeka": 0.1, "bagno": 0.18, "równina": 0.25, "step": 0.25,
	"wybrzeze": 0.22, "las": 0.3, "wzgórze": 0.5, "gory": 0.85}
const FAC_COL := {"neutral": Color(0.5, 0.45, 0.4), "sweden": Color(0.2, 0.4, 0.9), "moscow": Color(0.7, 0.2, 0.15),
	"horde": Color(0.8, 0.6, 0.2), "beast": Color(0.35, 0.25, 0.15)}
const Fig := preload("res://scripts/mesh_figures.gd")

var wm: Node2D
var cam2d: Camera2D
var cam: Camera3D
var S := 1.0
var yaw := 0.0
var pitch := deg_to_rad(55.0)
var _hex_mm: MultiMesh
var _cells: Array = []
var _cell_idx: Dictionary = {}
var _tree_mm: MultiMesh
var _peak_mm: MultiMesh
var _path_mm: MultiMesh
var _hover_ring: MeshInstance3D
var _sel_ring: MeshInstance3D
var _dyn: Node3D
var _hero: Node3D
var _scenery: Node3D
var _scenery_nodes: Array = []
var _sig_tiles := ""
var _sig_obj := ""
var _built_seed := -999999
var _dragging := false


func setup(world_map: Node2D, camera2d: Camera2D) -> void:
	wm = world_map
	cam2d = camera2d
	S = 1.0 / float(wm.hex_size)


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.03, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.65)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	_dyn = Node3D.new()
	add_child(_dyn)
	_hover_ring = _ring(Color(1, 1, 1, 0.5))
	_sel_ring = _ring(Color(1, 0.85, 0.15, 0.6))


func _mat(col: Color = Color.WHITE, vc := false, transp := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.vertex_color_use_as_albedo = vc
	m.vertex_color_is_srgb = true
	m.roughness = 0.9
	if transp:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _ring(col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.radial_segments = 6
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.03
	cm.material = _mat(col, false, true)
	mi.mesh = cm
	mi.visible = false
	add_child(mi)
	return mi


func _p3(px: Vector2, y := 0.0) -> Vector3:
	return Vector3(px.x * S, y, px.y * S)


func cell_h(c: Vector2i) -> float:
	if not wm._cells.has(c):
		return 0.0
	var d: Dictionary = wm._cells[c]
	var t := str(d["terrain"])
	if str(d["region_id"]) == "morze":
		t = "morze"
	if wm._bridges.has(c):
		return 0.2
	return float(HEIGHTS.get(t, 0.25))


func _terrain(c: Vector2i) -> String:
	var d: Dictionary = wm._cells[c]
	return "morze" if str(d["region_id"]) == "morze" else str(d["terrain"])


func _build_tiles() -> void:
	_cells = wm._cells.keys()
	_cell_idx.clear()
	var cm := CylinderMesh.new()
	cm.radial_segments = 6
	cm.rings = 0
	cm.top_radius = 0.97
	cm.bottom_radius = 0.97
	cm.height = 1.0
	cm.material = _mat(Color.WHITE, true)
	_hex_mm = _new_mm(cm, _cells.size(), true)
	var trees: Array = []
	var peaks: Array = []
	for i in _cells.size():
		var c: Vector2i = _cells[i]
		_cell_idx[c] = i
		var h := cell_h(c)
		var p := _p3(HexMath.axial_to_pixel(c.x, c.y, wm.hex_size), h * 0.5)
		_hex_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(1, h, 1)), p))
		var t := _terrain(c)
		var hh: int = wm._cell_hash(c)
		if t == "las":
			for k in 3:
				var a := float((hh >> (k * 3)) % 360) + k * 120.0
				trees.append(p + Vector3(cos(deg_to_rad(a)) * 0.45, h * 0.5, sin(deg_to_rad(a)) * 0.45))
		elif t == "gory":
			peaks.append(p + Vector3(0, h * 0.5, 0))
	var tm := CylinderMesh.new()
	tm.top_radius = 0.0
	tm.bottom_radius = 0.28
	tm.height = 0.8
	tm.radial_segments = 8
	tm.material = _mat(Color.WHITE, true)
	_tree_mm = _new_mm(tm, trees.size(), true)
	for i in trees.size():
		_tree_mm.set_instance_transform(i, Transform3D(Basis(), trees[i] + Vector3(0, 0.4, 0)))
	var pm := CylinderMesh.new()
	pm.top_radius = 0.0
	pm.bottom_radius = 0.75
	pm.height = 1.1
	pm.radial_segments = 5
	pm.material = _mat(Color.WHITE, true)
	_peak_mm = _new_mm(pm, peaks.size(), true)
	for i in peaks.size():
		_peak_mm.set_instance_transform(i, Transform3D(Basis(), peaks[i] + Vector3(0, 0.55, 0)))
	_tree_pos = trees
	_peak_pos = peaks
	_build_scenery()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sm.material = _mat(Color(1, 0.85, 0.2))
	_path_mm = _new_mm(sm, 64, false)
	_path_mm.visible_instance_count = 0

var _tree_pos: Array = []
var _peak_pos: Array = []


func _new_mm(mesh: Mesh, n: int, colors: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = n
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	add_child(mi)
	return mm


func _px_cell(p: Vector3) -> Vector2i:
	return HexMath.pixel_to_axial(Vector2(p.x, p.z) / S, wm.hex_size)


func _update_colors() -> void:
	for i in _cells.size():
		var c: Vector2i = _cells[i]
		var col: Color
		if not wm._explored.has(c):
			var n := float(wm._cell_hash(c) % 7) * 0.006
			col = Color(0.04 + n, 0.04 + n, 0.05 + n)
		else:
			col = wm.TERRAIN_COLORS.get(_terrain(c), Color(0.6, 0.6, 0.4))
			var reg: Dictionary = wm._region_by_id.get(wm._cells[c]["region_id"], {})
			col = col.lerp(Color.html(str(reg.get("color", "#888888"))), 0.12)
			if wm.is_road(c):
				col = col.lerp(Color(0.6, 0.5, 0.35), 0.45)
			if wm._bridges.has(c):
				col = Color(0.45, 0.32, 0.2)
			if wm._reachable.has(c) and c != wm.hero_pos:
				col = col.lerp(Color(0.55, 0.8, 1.0), 0.18)
		_hex_mm.set_instance_color(i, col)
	for i in _tree_pos.size():
		_tree_mm.set_instance_color(i, Color(0.13, 0.35, 0.15) if wm._explored.has(_px_cell(_tree_pos[i])) else Color(0.05, 0.05, 0.06))
	for i in _peak_pos.size():
		_peak_mm.set_instance_color(i, Color(0.6, 0.58, 0.56) if wm._explored.has(_px_cell(_peak_pos[i])) else Color(0.05, 0.05, 0.06))
	for n in _scenery_nodes:
		if is_instance_valid(n):
			n.visible = wm._explored.has(n.get_meta("cell"))


func _label(txt: String, pos: Vector3, col := Color(1, 0.95, 0.8)) -> void:
	var l := Label3D.new()
	l.text = txt
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 48
	l.pixel_size = 0.008
	l.outline_size = 12
	l.modulate = col
	l.position = pos
	l.no_depth_test = true
	_dyn.add_child(l)


const FAC_UNIT := {"sweden": "arkebuzerzy", "moscow": "jazda", "horde": "lucznicy", "neutral": "piechota",
	"kozacy": "lisowczycy", "brandenburgia": "halabardnicy", "polska": "husaria"}


## Jednostka / bohater: bryła low-poly, podstawka i chorągiew. Portret zostaje w UI.
func _figure(col: Color, pos: Vector3, unit_id: String, is_hero := false) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	Fig.cyl(root, 0.42, 0.06, Vector3(0, 0.03, 0), col.darkened(0.45), 16)
	var body: Node3D = Fig.unit(unit_id, col)
	body.position.y = 0.06
	if is_hero:
		body.scale = Vector3(1.15, 1.15, 1.15)
	root.add_child(body)
	Fig.banner(root, col.lightened(0.12), Vector3(-0.38, 0.08, -0.12), 1.35 if is_hero else 1.05)
	_dyn.add_child(root)
	return root


func _army_unit_id(a: Dictionary, fac: String) -> String:
	var units: Array = a.get("units", [])
	if units.size() > 0:
		return str(units[0])
	if fac.begins_with("beast_"):
		return fac.substr(6)
	if fac.begins_with("myhero_"):
		return "husaria"
	return str(FAC_UNIT.get(fac, "piechota"))


func _place(node: Node3D, pos: Vector3) -> void:
	node.position = pos
	_dyn.add_child(node)


func _cpos(c: Vector2i) -> Vector3:
	return _p3(HexMath.axial_to_pixel(c.x, c.y, wm.hex_size), cell_h(c))


func _build_objects() -> void:
	for ch in _dyn.get_children():
		ch.queue_free()
	for pos in wm._castles.keys():
		var reg: Dictionary = wm._castles[pos]
		var owned: bool = str(reg.get("id", "")) in wm.owned_region_ids
		var p := _cpos(pos)
		var acc := Color(0.2, 0.55, 1.0) if owned else Color(0.85, 0.15, 0.15)
		if wm._explored.has(pos):
			_place(Fig.castle(acc), p)
			_label(str(reg.get("capital", "")), p + Vector3(0, 2.15, 0))
	for pos in wm._resources.keys():
		if not wm._explored.has(pos):
			continue
		var r: Dictionary = wm._resources[pos]
		_place(Fig.resource(str(r.get("type", "")), bool(r.get("owned", false))), _cpos(pos))
	for pos in wm._artifacts.keys():
		if not wm._explored.has(pos):
			continue
		_place(Fig.artifact(str(wm._artifacts[pos])), _cpos(pos))
	for pos in wm._ports.keys():
		if not wm._explored.has(pos):
			continue
		var port_pos := _cpos(pos)
		_place(Fig.port(), port_pos)
		_label(str(wm._ports[pos].get("name", "")), port_pos + Vector3(0, 1.15, 0), Color(0.75, 0.88, 1.0))
	for pos in wm._armies.keys():
		if not wm._explored.has(pos):
			continue
		var a: Dictionary = wm._armies[pos]
		var fac := str(a.get("faction", "neutral"))
		var col: Color = FAC_COL.get("beast" if fac.begins_with("beast_") else fac, Color(0.5, 0.3, 0.6))
		if str(a.get("id", "")) == wm.RIVAL_ID:
			col = Color(0.55, 0.15, 0.7)
		var heroish: bool = fac.begins_with("myhero_") or str(a.get("id", "")) == wm.RIVAL_ID
		_figure(col, _cpos(pos), _army_unit_id(a, fac), heroish)
	_hero = _figure(Color(0.85, 0.1, 0.12), _cpos(wm.hero_pos), "husaria", true)


func _scenery_kind(terrain: String, h2: int) -> String:
	match terrain:
		"wzgórze":
			if h2 % 11 == 3:
				return "ruins"
			if h2 % 3 == 0:
				return "oak"
			if h2 % 3 == 1:
				return "rock"
		"równina":
			if h2 % 9 == 2:
				return "village"
			if h2 % 9 == 5:
				return "windmill"
			if h2 % 9 == 7:
				return "wheat"
			if h2 % 4 == 0:
				return "oak"
		"step":
			if h2 % 13 == 4:
				return "windmill"
			if h2 % 6 == 3:
				return "rock"
			if h2 % 6 == 0:
				return "bush"
		"bagno":
			if h2 % 2 == 0:
				return "bush"
		"wybrzeze":
			if h2 % 5 == 0:
				return "bush"
		"morze":
			if h2 % 19 == 4:
				return "ship"
	return ""


func _build_scenery() -> void:
	if _scenery and is_instance_valid(_scenery):
		_scenery.free()
	_scenery_nodes.clear()
	_scenery = Node3D.new()
	_scenery.name = "Scenery"
	add_child(_scenery)
	for c in _cells:
		var cell: Vector2i = c
		if wm._castles.has(cell) or wm._resources.has(cell) or wm._ports.has(cell) or wm._artifacts.has(cell):
			continue
		var h2: int = wm._cell_hash(Vector2i(cell.y * 7 + 3, cell.x * 11 + 5))
		var kind := _scenery_kind(_terrain(cell), h2)
		if kind == "":
			continue
		var n := Fig.scenery(kind)
		n.position = _cpos(cell) + Vector3(0.12, 0, 0.18)
		n.set_meta("cell", cell)
		n.visible = false
		_scenery.add_child(n)
		_scenery_nodes.append(n)


func _process(_d: float) -> void:
	if wm == null:
		return
	if _hex_mm == null or _cells.size() != wm._cells.size() or _built_seed != wm.map_seed:
		_built_seed = wm.map_seed
		for ch in get_children():
			if ch is MultiMeshInstance3D:
				ch.queue_free()
		_build_tiles()
		_sig_tiles = ""
	var st := "%d|%d|%s|%d" % [wm._explored.size(), wm._reachable.size(), str(wm.hero_pos), wm.map_seed]
	if st != _sig_tiles:
		_sig_tiles = st
		_update_colors()
	var owned_n := 0
	for rp in wm._resources.keys():
		if bool(wm._resources[rp].get("owned", false)):
			owned_n += 1
	var so := "%d|%s|%s|%d|%d|%d|%s|%d" % [wm._explored.size(), str(wm._armies.keys()), str(wm.hero_pos), wm._artifacts.size(),
		wm._resources.size(), owned_n, str(wm.owned_region_ids), wm.map_seed]
	if so != _sig_obj and not wm.is_animating:
		_sig_obj = so
		_build_objects()
	# bohater w trakcie animacji
	if _hero and is_instance_valid(_hero):
		var hp: Vector2 = wm._hero_px if wm.is_animating else HexMath.axial_to_pixel(wm.hero_pos.x, wm.hero_pos.y, wm.hex_size)
		_hero.position = _p3(hp, cell_h(HexMath.pixel_to_axial(hp, wm.hex_size)))
	# ścieżka
	var pp: Array = wm._path_preview
	_path_mm.visible_instance_count = mini(pp.size(), 64)
	for i in _path_mm.visible_instance_count:
		_path_mm.set_instance_transform(i, Transform3D(Basis(), _cpos(pp[i]) + Vector3(0, 0.15, 0)))
	_place_ring(_hover_ring, wm._hover)
	_place_ring(_sel_ring, wm._selected)
	# kamera śledzi Camera2D (pan/zoom/centrowanie z logiki 2D)
	var target := _p3(cam2d.position, 0.3)
	var dist := 16.0 / maxf(0.15, cam2d.zoom.x)
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.position = target + off
	cam.look_at(target, Vector3.UP)
	for ch in wm.get_children():
		if ch is CanvasItem:
			ch.visible = false


func _place_ring(r: MeshInstance3D, c: Vector2i) -> void:
	r.visible = wm._cells.has(c)
	if r.visible:
		r.position = _cpos(c) + Vector3(0, 0.02, 0)


## Ekran -> współrzędne pikselowe mapy 2D (dla logiki WorldMap).
func screen_to_map(sp: Vector2) -> Vector2:
	var o := cam.project_ray_origin(sp)
	var n := cam.project_ray_normal(sp)
	var h := 0.25
	var px := Vector2.ZERO
	for _i in 3:
		if absf(n.y) < 0.0001:
			break
		var t := (h - o.y) / n.y
		var hit := o + n * t
		px = Vector2(hit.x, hit.z) / S
		h = cell_h(HexMath.pixel_to_axial(px, wm.hex_size))
	return px


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE):
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch + event.relative.y * 0.006, deg_to_rad(25), deg_to_rad(85))
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			yaw += 0.15
		elif event.keycode == KEY_R:
			yaw -= 0.15
