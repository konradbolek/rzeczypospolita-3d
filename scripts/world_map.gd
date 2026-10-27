extends Node2D
## Mapa hex + ruch bohatera + zamki w stolicach.

@export var hex_size: float = 28.0
@export var map_width: int = 48
@export var map_height: int = 34
@export var max_movement: int = 15

signal hex_selected(q: int, r: int, region_id: String, region_name: String, terrain: String)
signal hero_moved(q: int, r: int, mp_left: int)
signal turn_ended(mp: int)
signal city_entered(region_id: String, region_name: String, capital: String, owned_by_player: bool)
signal castle_presence(on_castle: bool, region_name: String)
signal castle_siege(region_id: String, region_name: String, capital: String)
signal army_encountered(army_id: String, army_name: String)
signal armies_moved(moved_count: int)
signal artifact_picked(artifact_id: String)
signal resource_picked(res_type: String, kind: String, amount: int)

## Katalog artefaktów (bonusy liczone w main.gd).
const ARTIFACT_DEFS: Dictionary = {
	"pierscien_sily": {"name": "Pierścień siły", "desc": "Atak: +2 obrażeń w bitwie", "fx": {"dmg": 2}},
	"szabla": {"name": "Karabela", "desc": "Atak: +1 obrażeń w bitwie", "fx": {"dmg": 1}},
	"tarcza_hetmana": {"name": "Tarcza hetmana", "desc": "Obrona: +10 HP jednostek", "fx": {"hp": 10}},
	"helm_husarski": {"name": "Hełm husarski", "desc": "Obrona +5 HP, Atak +1", "fx": {"hp": 5, "dmg": 1}},
	"buty_kuriera": {"name": "Buty kuriera", "desc": "Ruch: +2 max PR", "fx": {"mp": 2}},
	"luneta": {"name": "Luneta żeglarska", "desc": "Zasięg widzenia +2, +1 PR", "fx": {"sight": 2, "mp": 1}},
	"ksiega_run": {"name": "Księga run", "desc": "Magia: +6 max many, +1 regeneracji", "fx": {"mana": 6, "regen": 1}},
	"pieczec_krola": {"name": "Pieczęć królewska", "desc": "Dochód: +150 zł/turę", "fx": {"income": 150}},
	"sakiewka": {"name": "Sakiewka", "desc": "+100 zł (jednorazowo)", "fx": {"gold_once": 100}},
}
const ARTIFACT_SPOTS: Array = [
	["sakiewka", Vector2i(18, 17)], ["szabla", Vector2i(13, 20)],
	["buty_kuriera", Vector2i(20, 21)], ["pierscien_sily", Vector2i(25, 13)],
	["tarcza_hetmana", Vector2i(9, 14)], ["sakiewka", Vector2i(30, 22)],
	["helm_husarski", Vector2i(36, 16)], ["luneta", Vector2i(14, 7)],
	["ksiega_run", Vector2i(29, 28)], ["pieczec_krola", Vector2i(40, 20)],
	["sakiewka", Vector2i(6, 24)], ["szabla", Vector2i(42, 8)],
]
## Mapa jest powiększona względem danych w regions.json (współrzędne × MAP_SCALE).
const MAP_SCALE := 1.5
var _explored: Dictionary = {} # Vector2i -> true (mgła wojny)
var sight_bonus: int = 0
const SIGHT_HERO := 4
var _ports: Dictionary = {} # Vector2i -> {"name": String, "body": int}
var _water_body: Dictionary = {} # Vector2i -> id akwenu
var _port_links: Dictionary = {} # port -> Array[{"to", "path", "cost"}]
var _sea_link: Dictionary = {} # cel (port) -> Array[Vector2i] wody na trasie
var _bridges: Dictionary = {}
const PORT_NAMES := ["Puck", "Elbląg", "Królewiec", "Kłajpeda", "Windawa", "Parnawa", "Kołobrzeg", "Toruń", "Płock",
	"Grodno", "Czerkasy", "Oczaków", "Akerman", "Chocim", "Kazimierz", "Sandomierz", "Pińsk", "Kijów-Podół"]
var _last_xf := Transform2D()
var _artifacts: Dictionary = {} # Vector2i -> artifact_id

## Zasoby: "tartak"/"kopalnia" = przejmowane (+2/turę), "drewno"/"ruda" = stos jednorazowy +5
const RESOURCE_SPOTS: Array = [
	["tartak", Vector2i(15, 18)], ["kopalnia", Vector2i(22, 16)],
	["tartak", Vector2i(11, 22)], ["kopalnia", Vector2i(27, 20)],
	["drewno", Vector2i(17, 19)], ["drewno", Vector2i(12, 16)], ["drewno", Vector2i(24, 22)],
	["ruda", Vector2i(20, 15)], ["ruda", Vector2i(26, 17)], ["ruda", Vector2i(10, 19)],
	["kopalnia_zlota", Vector2i(19, 22)], ["kopalnia_zlota", Vector2i(30, 14)], ["kopalnia_zlota", Vector2i(9, 13)],
	["kopalnia_wegla", Vector2i(13, 20)], ["kopalnia_wegla", Vector2i(24, 12)], ["kopalnia_wegla", Vector2i(32, 22)],
	["tartak", Vector2i(20, 9)], ["tartak", Vector2i(34, 9)], ["tartak", Vector2i(26, 26)],
	["kopalnia", Vector2i(14, 10)], ["kopalnia", Vector2i(36, 18)],
]
## Dochód z przejętych budowli (na turę).
const MINE_INCOME: Dictionary = {
	"tartak": {"wood": 2}, "kopalnia": {"ore": 2},
	"kopalnia_wegla": {"ore": 3}, "kopalnia_zlota": {"gold": 100},
}
const MINE_NAMES: Dictionary = {
	"tartak": "tartak", "kopalnia": "kopalnię rudy",
	"kopalnia_wegla": "kopalnię węgla", "kopalnia_zlota": "kopalnię złota",
}
## Hexy z drogą — ruch po drodze kosztuje połowę (min. 1).
var _road_cells: Dictionary = {}
var _resources: Dictionary = {} # Vector2i -> {"type": String, "owned": bool}

const TERRAIN_COST: Dictionary = {
	"równina": 2,
	"step": 2,
	"wybrzeze": 2,
	"las": 3,
	"wzgórze": 3,
	"bagno": 4,
	"gory": 5,
	"rzeka": 4,
	"morze": 99,
}

## Na start gracz „posiada” Małopolskę (Kraków).
var owned_region_ids: Array[String] = ["malopolska"]

var _cells: Dictionary = {}
var _regions: Array = []
var _region_by_id: Dictionary = {}
var _castles: Dictionary = {} # Vector2i -> region Dictionary
var _armies: Dictionary = {} # Vector2i -> {id, name, faction}
var _pending_army_id: String = ""
## Rywal AI: regiony i cel ruchu ustawiane przez main.gd.
var rival_region_ids: Array[String] = []
var rival_target: Vector2i = Vector2i(-1, -1)
## AI rywala: omijaj bohatera gracza (gdy rywal dużo słabszy).
var rival_avoid_hero: bool = false
## Hot-seat: drugi bohater należy do gracza 2 — nie rusza się sam.
var rival_frozen: bool = false
var _stepping_rival: bool = false
const RIVAL_ID := "rival_hero"
var _pre_battle_pos: Vector2i = Vector2i(16, 18)
var _hover: Vector2i = Vector2i(9999, 9999)
var _selected: Vector2i = Vector2i(9999, 9999)

var hero_pos: Vector2i = Vector2i(16, 18)
var movement_left: int = 15
var _reachable: Dictionary = {}
var _came_from: Dictionary = {}
var _path_preview: Array[Vector2i] = []
## Płynny ruch (animacja) — logika nadal hexowa.
const HERO_STEP_TIME := 0.13
const ARMY_STEP_TIME := 0.3
var is_animating: bool = false
var _hero_px: Vector2 = Vector2.ZERO
var _army_paths: Dictionary = {} # Vector2i (cel) -> PackedVector2Array
var _army_t: float = 1.0


var _terrain_tex: Dictionary = {}

func _terrain_texture(terrain: String) -> Texture2D:
	if not _terrain_tex.has(terrain):
		var fname := terrain.replace("ó", "o")
		var path := "res://assets/terrain/%s.png" % fname
		_terrain_tex[terrain] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _terrain_tex[terrain]


## Ziarno mapy: 0 = stara, stała mapa (stare zapisy). Nowa gra losuje ziarno.
var map_seed: int = 0
var _noise: FastNoiseLite = null
var _rng := RandomNumberGenerator.new()
var _carp_shift := 0
var _poles_shift := Vector2i.ZERO


func _setup_seed(sd: int) -> void:
	map_seed = sd
	_rng.seed = sd if sd != 0 else 1
	_noise = null
	_carp_shift = 0
	_poles_shift = Vector2i.ZERO
	if sd != 0:
		_noise = FastNoiseLite.new()
		_noise.seed = sd
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_noise.frequency = 0.09
		_noise.fractal_octaves = 2
		_carp_shift = _rng.randi_range(-2, 2)
		_poles_shift = Vector2i(_rng.randi_range(-3, 3), _rng.randi_range(-2, 2))


func _generate_world(sd: int) -> void:
	_setup_seed(sd)
	_generate_cells()
	_build_castles()
	_build_map_details()
	_build_bridges()


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_load_regions()
	var rs := RandomNumberGenerator.new()
	rs.randomize()
	_generate_world(rs.randi_range(1, 2000000000))
	_spawn_resources()
	_spawn_ports()
	_spawn_armies()
	_spawn_artifacts()
	_ensure_corridors()
	_build_port_links()
	_explored.clear()
	movement_left = max_movement
	_recompute_reach()
	queue_redraw()
	_emit_castle_presence()


func end_turn() -> void:
	if is_animating:
		return
	movement_left = max_movement
	var moved := _move_enemy_armies()
	_recompute_reach()
	queue_redraw()
	turn_ended.emit(movement_left)
	if moved > 0:
		var max_len := 1
		for k in _army_paths.keys():
			max_len = maxi(max_len, (_army_paths[k] as PackedVector2Array).size() - 1)
		is_animating = true
		_army_t = 0.0
		# Kamera śledzi bohatera rywala (jeśli się rusza).
		var cam := get_viewport().get_camera_2d()
		var rpts := PackedVector2Array()
		for k in _army_paths.keys():
			if _armies.has(k) and str(_armies[k].get("id", "")) == RIVAL_ID:
				rpts = _army_paths[k]
		# Rywal widoczny tylko na odkrytych polach (mgła wojny).
		var vis_i0 := -1
		var vis_i1 := -1
		for i in rpts.size():
			if _explored.has(HexMath.pixel_to_axial(rpts[i], hex_size)):
				if vis_i0 < 0:
					vis_i0 = i
				vis_i1 = i
		if rpts.size() > 1 and vis_i0 >= 0:
			var seg := float(rpts.size() - 1)
			var t0 := maxf(0.0, (float(vis_i0) - 1.0) / seg)
			var t1 := minf(1.0, (float(vis_i1) + 1.0) / seg)
			_army_t = t0
			queue_redraw()
			if cam != null:
				var ct := create_tween()
				ct.tween_property(cam, "position", to_global(path_point(rpts, t0)), 0.45).set_trans(Tween.TRANS_SINE)
				await ct.finished
			var tw := create_tween()
			tw.tween_method(func(v: float) -> void:
				_army_t = v
				if cam != null and _explored.has(HexMath.pixel_to_axial(path_point(rpts, v), hex_size)):
					cam.position = to_global(path_point(rpts, v))
				queue_redraw(), t0, t1, maxf(0.2, ARMY_STEP_TIME * seg * (t1 - t0)))
			await tw.finished
			if cam != null:
				var bt := create_tween()
				bt.tween_interval(0.5)
				bt.tween_property(cam, "position", to_global(HexMath.axial_to_pixel(hero_pos.x, hero_pos.y, hex_size)), 0.5).set_trans(Tween.TRANS_SINE)
				await bt.finished
		# Cały ruch w mgle — bez kamery i animacji.
		_army_t = 1.0
		_army_paths.clear()
		is_animating = false
		queue_redraw()
	if moved > 0:
		armies_moved.emit(moved)
	# Wróg wszedł na bohatera → walka
	if _armies.has(hero_pos):
		var army: Dictionary = _armies[hero_pos]
		_pending_army_id = str(army.get("id", ""))
		_pre_battle_pos = hero_pos # już na tym hexie — odwrót: sąsiad
		army_encountered.emit(_pending_army_id, str(army.get("name", "Wroga armia")))


func is_on_castle() -> bool:
	return _castles.has(hero_pos)


func owned_castle_count() -> int:
	var n := 0
	for pos in _castles.keys():
		var reg: Dictionary = _castles[pos]
		if str(reg.get("id", "")) in owned_region_ids:
			n += 1
	return n


func try_enter_city() -> bool:
	if is_animating:
		return false
	if not _castles.has(hero_pos):
		return false
	var reg: Dictionary = _castles[hero_pos]
	var rid := str(reg.get("id", ""))
	var rname := str(reg.get("name", rid))
	var capital := str(reg.get("capital", ""))
	if rid in owned_region_ids:
		city_entered.emit(rid, rname, capital, true)
	else:
		# Obcy zamek — oblężenie (walka o garnizon).
		castle_siege.emit(rid, rname, capital)
	return true


func is_region_owned(region_id: String) -> bool:
	return region_id in owned_region_ids


func capture_castle(region_id: String) -> bool:
	if region_id == "" or region_id in owned_region_ids:
		return false
	rival_region_ids.erase(region_id)
	owned_region_ids.append(region_id)
	_reveal_sources()
	queue_redraw()
	_emit_castle_presence()
	return true


func _load_regions() -> void:
	var path := "res://data/regions.json"
	if not FileAccess.file_exists(path):
		push_error("Brak data/regions.json")
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("regions.json: zły format")
		return
	_regions = parsed.get("regions", [])
	if parsed.has("map_width"):
		map_width = int(parsed["map_width"])
	if parsed.has("map_height"):
		map_height = int(parsed["map_height"])
	map_width = roundi(map_width * MAP_SCALE)
	map_height = roundi(map_height * MAP_SCALE)
	for reg in _regions:
		reg["capital_q"] = roundi(float(reg.get("capital_q", 0)) * MAP_SCALE)
		reg["capital_r"] = roundi(float(reg.get("capital_r", 0)) * MAP_SCALE)
		_region_by_id[reg["id"]] = reg
	if _region_by_id.has("malopolska"):
		hero_pos = Vector2i(int(_region_by_id["malopolska"]["capital_q"]), int(_region_by_id["malopolska"]["capital_r"]))
		_pre_battle_pos = hero_pos


func _build_castles() -> void:
	_castles.clear()
	for reg in _regions:
		var pos := Vector2i(int(reg.get("capital_q", 0)), int(reg.get("capital_r", 0)))
		_castles[pos] = reg


const BLOCKING_TERRAIN := ["morze", "gory", "las", "rzeka"]
const MINE_TYPES := ["tartak", "kopalnia", "kopalnia_zlota", "kopalnia_wegla"]


## Woda / góry / las są nieprzechodnie (zamki, kopalnie i drogi zawsze przechodnie, poza morzem).
func is_blocked(cell: Vector2i) -> bool:
	if not _cells.has(cell):
		return true
	var t := str(_cells[cell]["terrain"])
	if t == "morze" or str(_cells[cell]["region_id"]) == "morze":
		return true
	if _castles.has(cell) or _resources.has(cell) or _road_cells.has(cell) or _ports.has(cell) or _bridges.has(cell):
		return false
	return t in BLOCKING_TERRAIN


## Gwarantuje, że zamki, kopalnie, armie i artefakty są osiągalne: przecina korytarz
## (las/góry -> równina) najkrótszą drogą do już dostępnego obszaru.
func _ensure_corridors() -> void:
	var start := hero_pos
	if is_blocked(start) and _cells.has(start) and str(_cells[start]["terrain"]) != "morze":
		_cells[start]["terrain"] = "równina"
	var targets: Array = []
	targets.append_array(_castles.keys())
	targets.append_array(_resources.keys())
	targets.append_array(_armies.keys())
	targets.append_array(_artifacts.keys())
	targets.append_array(_ports.keys())
	for _iter in 300:
		var reach := _flood(start)
		var missing: Array = targets.filter(func(t): return not reach.has(t))
		if missing.is_empty():
			return
		var tgt: Vector2i = missing[0]
		# 0-1 BFS od celu: zablokowany ląd kosztuje 1, morze nieprzechodnie.
		var dist := {tgt: 0}
		var prev := {}
		var dq: Array = [tgt]
		var found := Vector2i(-9999, -9999)
		while not dq.is_empty():
			var cur: Vector2i = dq.pop_front()
			if reach.has(cur):
				found = cur
				break
			for n in HexMath.neighbors(cur):
				if not _cells.has(n) or str(_cells[n]["terrain"]) == "morze" or str(_cells[n]["region_id"]) == "morze":
					continue
				var w := 1 if is_blocked(n) else 0
				var nd: int = int(dist[cur]) + w
				if dist.has(n) and int(dist[n]) <= nd:
					continue
				dist[n] = nd
				prev[n] = cur
				if w == 0:
					dq.push_front(n)
				else:
					dq.push_back(n)
		if found.x == -9999:
			targets.erase(tgt)
			continue
		var c: Vector2i = found
		while true:
			if is_blocked(c) or (c == tgt and str(_cells[c]["terrain"]) in BLOCKING_TERRAIN):
				if str(_cells[c]["terrain"]) == "rzeka":
					_bridges[c] = true # bród/most — rzeka zostaje spławna
				else:
					_cells[c]["terrain"] = "równina"
			if c == tgt:
				break
			c = prev[c]


func _flood(start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var fr: Array = [start]
	while not fr.is_empty():
		var cur: Vector2i = fr.pop_back()
		for n in HexMath.neighbors(cur):
			if seen.has(n) or is_blocked(n):
				continue
			seen[n] = true
			fr.append(n)
	return seen


func _spawn_armies() -> void:
	_armies.clear()
	# Blisko nowych stolic / szlaków.
	_armies[_sc(Vector2i(18, 18))] = {"id": "bandyci_1", "name": "Wataha bandytów", "faction": "neutral"}
	_armies[_sc(Vector2i(17, 7))] = {"id": "szwedzi_1", "name": "Oddział szwedzki", "faction": "sweden"}
	_armies[_sc(Vector2i(36, 12))] = {"id": "moskwa_1", "name": "Straż moskiewska", "faction": "moscow"}
	_armies[_sc(Vector2i(28, 25))] = {"id": "tatarzy_1", "name": "Czambuł tatarski", "faction": "horde"}
	# Strażnicy kopalń: przenieś wolne armie na najbliższe kopalnie, a resztę kopalń obsadź nowymi.
	var mines: Array = []
	for p in _resources.keys():
		if str(_resources[p]["type"]) in MINE_TYPES:
			mines.append(p)
	var old := _armies.duplicate()
	_armies.clear()
	for pos in old.keys():
		var best := Vector2i(-1, -1)
		for m in mines:
			if not _armies.has(m) and (best.x < 0 or HexMath.distance(pos, m) < HexMath.distance(pos, best)):
				best = m
		_armies[best if best.x >= 0 else pos] = old[pos]
	var i := 0
	for m in mines:
		if _armies.has(m):
			continue
		i += 1
		_armies[m] = {"id": "straz_kopalni_%d" % i, "name": "Straż kopalni", "faction": "neutral"}
	_spawn_beasts()



func _spawn_artifacts() -> void:
	_artifacts.clear()
	for spot in ARTIFACT_SPOTS:
		var want: Vector2i = _sc(spot[1])
		if map_seed != 0:
			want += Vector2i(_rng.randi_range(-5, 5), _rng.randi_range(-5, 5))
		var best := Vector2i(-1, -1)
		var best_d := 999
		for c in _cells.keys():
			var cell: Vector2i = c
			if str(_cells[cell]["terrain"]) in BLOCKING_TERRAIN or _castles.has(cell) or _armies.has(cell) \
					or _artifacts.has(cell) or _ports.has(cell) or _resources.has(cell) or cell == hero_pos:
				continue
			var d: int = HexMath.distance(cell, want)
			if d < best_d:
				best_d = d
				best = cell
		if best.x >= 0:
			_artifacts[best] = str(spot[0])


func _spawn_resources() -> void:
	_resources.clear()
	var spots: Array = RESOURCE_SPOTS.duplicate()
	# Większa mapa = więcej złóż w dziczy.
	var extra := ["tartak", "kopalnia", "kopalnia_zlota", "kopalnia_wegla", "drewno", "ruda", "drewno", "ruda", "tartak", "kopalnia"]
	for k in extra.size():
		spots.append([extra[k], Vector2i(_rng.randi_range(3, 45), _rng.randi_range(4, 31))])
	for spot in spots:
		var want: Vector2i = _sc(spot[1])
		if map_seed != 0:
			want += Vector2i(_rng.randi_range(-4, 4), _rng.randi_range(-4, 4))
		var best := Vector2i(-1, -1)
		var best_d := 999
		for c in _cells.keys():
			var cell: Vector2i = c
			if str(_cells[cell]["terrain"]) in BLOCKING_TERRAIN or _castles.has(cell) or _armies.has(cell) \
					or _artifacts.has(cell) or _resources.has(cell) or cell == hero_pos:
				continue
			var d: int = HexMath.distance(cell, want)
			if d < best_d:
				best_d = d
				best = cell
		if best.x >= 0:
			_resources[best] = {"type": str(spot[0]), "owned": false}


func resource_at(cell: Vector2i) -> Dictionary:
	return _resources.get(cell, {})


## Dochód z przejętych tartaków/kopalń: {"wood": n, "ore": n}
func owned_mine_income() -> Dictionary:
	var inc := {"wood": 0, "ore": 0, "gold": 0}
	for p in _resources:
		var r: Dictionary = _resources[p]
		if bool(r.get("owned", false)):
			var m: Dictionary = MINE_INCOME.get(str(r["type"]), {})
			for k in m:
				inc[k] += int(m[k])
	return inc


var _mine_tex: Dictionary = {}
func _mine_png(t: String) -> Texture2D:
	if not _mine_tex.has(t):
		var p := "res://assets/map/mines/%s.png" % t
		_mine_tex[t] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	return _mine_tex[t]


func _draw_resource(center: Vector2, r: Dictionary) -> void:
	var t: String = str(r["type"])
	var s := hex_size * 0.3
	var wood := t == "tartak" or t == "drewno"
	var col := Color(0.6, 0.36, 0.14) if wood else Color(0.62, 0.66, 0.74)
	var dark := Color(0.12, 0.08, 0.04)
	if t == "drewno" or t == "ruda":
		var pt := _mine_png(t)
		if pt != null:
			var pd := hex_size * 0.95
			draw_circle(center + Vector2(0, hex_size * 0.28), hex_size * 0.4, Color(0, 0, 0, 0.22))
			draw_texture_rect(pt, Rect2(center - Vector2(pd * 0.5, pd * 0.62), Vector2(pd, pd)), false)
			return
	if MINE_INCOME.has(t):
		var mt := _mine_png(t)
		if mt != null:
			var owned2 := bool(r.get("owned", false))
			var d := hex_size * 1.45
			draw_circle(center + Vector2(0, hex_size * 0.3), hex_size * 0.55, Color(0, 0, 0, 0.22))
			draw_texture_rect(mt, Rect2(center - Vector2(d * 0.5, d * 0.68), Vector2(d, d)), false)
			var fp := center + Vector2(hex_size * 0.45, -hex_size * 0.55)
			var flag2 := Color(0.85, 0.12, 0.12) if owned2 else Color(0.92, 0.92, 0.92)
			draw_line(fp, fp + Vector2(0, -hex_size * 0.45), Color.BLACK, 2.0)
			draw_colored_polygon(PackedVector2Array([fp + Vector2(0, -hex_size * 0.45),
				fp + Vector2(hex_size * 0.32, -hex_size * 0.36), fp + Vector2(0, -hex_size * 0.27)]), flag2)
			return
	if MINE_INCOME.has(t):
		var owned := bool(r.get("owned", false))
		var flag := Color(0.2, 0.55, 1.0) if owned else Color(0.92, 0.92, 0.92)
		draw_circle(center + Vector2(0, s * 0.9), s * 1.1, Color(0, 0, 0, 0.25))
		# budynek z dachem
		var rect := Rect2(center - Vector2(s, s * 0.3), Vector2(s * 2, s * 1.1))
		draw_rect(rect, col)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 1.2, -s * 0.3),
			center + Vector2(0, -s * 1.1), center + Vector2(s * 1.2, -s * 0.3)]), col.darkened(0.35))
		draw_rect(rect, dark, false, 1.5)
		if wood:
			draw_line(center + Vector2(-s * 0.6, s * 0.2), center + Vector2(s * 0.6, s * 0.2), dark, 2.0)
			draw_circle(center + Vector2(-s * 0.6, s * 0.2), s * 0.18, Color(0.85, 0.65, 0.35))
		else:
			draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 0.4, s * 0.8),
				center + Vector2(-s * 0.4, s * 0.1), center + Vector2(0, -s * 0.2),
				center + Vector2(s * 0.4, s * 0.1), center + Vector2(s * 0.4, s * 0.8)]), Color(0.08, 0.08, 0.1))
		draw_line(center + Vector2(s, -s * 0.3), center + Vector2(s, -s * 1.9), Color.BLACK, 2.0)
		draw_colored_polygon(PackedVector2Array([center + Vector2(s, -s * 1.9),
			center + Vector2(s * 1.9, -s * 1.6), center + Vector2(s, -s * 1.3)]), flag)
	else:
		draw_circle(center + Vector2(0, s * 0.7), s * 0.95, Color(0, 0, 0, 0.25))
		if wood:
			for i in 3:
				var y := s * (0.45 - 0.42 * i)
				var w := s * (0.95 - 0.25 * i)
				draw_line(center + Vector2(-w, y), center + Vector2(w, y), dark, s * 0.42)
				draw_line(center + Vector2(-w, y), center + Vector2(w, y), col, s * 0.3)
				draw_circle(center + Vector2(w, y), s * 0.17, Color(0.9, 0.72, 0.42))
		else:
			for off in [Vector2(-0.45, 0.25), Vector2(0.45, 0.25), Vector2(0, -0.3)]:
				var c: Vector2 = center + off * s
				var rock := PackedVector2Array([c + Vector2(-s * 0.45, s * 0.3), c + Vector2(-s * 0.3, -s * 0.3),
					c + Vector2(s * 0.2, -s * 0.4), c + Vector2(s * 0.45, s * 0.3)])
				draw_colored_polygon(rock, col)
				rock.append(rock[0])
				draw_polyline(rock, Color(0.15, 0.15, 0.2), 1.5)
				draw_circle(c + Vector2(-s * 0.05, -s * 0.05), s * 0.08, Color(0.95, 0.5, 0.2))


func artifact_at(cell: Vector2i) -> String:
	return str(_artifacts.get(cell, ""))


var _art_tex: Dictionary = {}
func artifact_texture(aid: String) -> Texture2D:
	if not _art_tex.has(aid):
		var p := "res://assets/artifacts/%s.png" % aid
		_art_tex[aid] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	return _art_tex[aid]


func _draw_artifact(center: Vector2, aid: String = "") -> void:
	var s := hex_size * 0.34
	var at := artifact_texture(aid)
	if at != null:
		draw_circle(center, hex_size * 0.55, Color(1.0, 0.9, 0.3, 0.22))
		draw_arc(center, hex_size * 0.55, 0.0, TAU, 28, Color(1.0, 0.85, 0.3, 0.8), 1.5)
		var d := hex_size * 0.95
		draw_texture_rect(at, Rect2(center - Vector2(d * 0.5, d * 0.55), Vector2(d, d)), false)
		return
	# poświata
	draw_circle(center, s * 1.25, Color(1.0, 0.9, 0.3, 0.22))
	draw_circle(center, s * 0.95, Color(1.0, 0.9, 0.3, 0.25))
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2 + i * PI / 5
		var rad := s if i % 2 == 0 else s * 0.45
		pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, Color(1.0, 0.82, 0.1))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.35, 0.2, 0.0), 2.0)
	draw_circle(center, s * 0.2, Color(1, 1, 0.85))


func _move_enemy_armies() -> int:
	if _armies.is_empty():
		return 0
	var entries: Array = []
	for pos in _armies.keys():
		entries.append({"pos": pos, "army": _armies[pos]})
	# Losowa kolejność, żeby nie faworyzować jednego kierunku.
	entries.shuffle()
	var occupied: Dictionary = {}
	var moved_count := 0
	var next_map: Dictionary = {}
	_army_paths.clear()
	for e in entries:
		var pos: Vector2i = e["pos"]
		var army: Dictionary = e["army"]
		# Zwykłe (stacjonarne) armie stoją w miejscu — rusza się tylko bohater rywala.
		if str(army.get("id", "")) != RIVAL_ID or rival_frozen:
			occupied[pos] = true
			next_map[pos] = army
			continue
		var steps := 2
		# Szwedzi / Moskwa trochę szybsi
		var faction := str(army.get("faction", ""))
		if faction in ["sweden", "moscow"]:
			steps = 3
		var tgt: Vector2i = hero_pos
		if str(army.get("id", "")) == RIVAL_ID:
			steps = 4
			if rival_target.x >= 0:
				tgt = rival_target
		var cur: Vector2i = pos
		var pts := PackedVector2Array([HexMath.axial_to_pixel(pos.x, pos.y, hex_size)])
		_stepping_rival = str(army.get("id", "")) == RIVAL_ID
		for _i in steps:
			if cur == tgt:
				break
			var nxt := _army_step_toward(cur, tgt, occupied, next_map)
			if nxt == cur:
				break
			cur = nxt
			pts.append(HexMath.axial_to_pixel(cur.x, cur.y, hex_size))
		if pts.size() > 1:
			_army_paths[cur] = pts
		if cur != pos:
			moved_count += 1
		occupied[cur] = true
		next_map[cur] = army
	_armies = next_map
	return moved_count


func _army_step_toward(from: Vector2i, target: Vector2i, reserved: Dictionary, next_map: Dictionary) -> Vector2i:
	if from == target:
		return from
	var best: Vector2i = from
	var best_d: int = HexMath.distance(from, target)
	for n in HexMath.neighbors(from):
		if not _cells.has(n):
			continue
		if is_blocked(n):
			continue
		# Nie wchodź na zajęte docelowe hexy innych armii w tej turze.
		if reserved.has(n) or next_map.has(n):
			continue
		if _stepping_rival and rival_avoid_hero and HexMath.distance(n, hero_pos) <= 1:
			continue
		# Wolno wejść na bohatera (walka).
		var d: int = HexMath.distance(n, target)
		if d < best_d:
			best_d = d
			best = n
	return best


func remove_army(army_id: String) -> void:
	var to_del: Array[Vector2i] = []
	for pos in _armies.keys():
		if str(_armies[pos].get("id", "")) == army_id:
			to_del.append(pos)
	for pos in to_del:
		_armies.erase(pos)
	_pending_army_id = ""
	_recompute_reach()
	queue_redraw()


## Zapisuje ocalałe jednostki (unit_id) zwykłej armii po walce.
func set_army_units(army_id: String, units: Array) -> void:
	for pos in _armies.keys():
		if str(_armies[pos].get("id", "")) == army_id:
			_armies[pos]["units"] = units.duplicate()


func get_army_units(army_id: String) -> Array:
	for pos in _armies.keys():
		if str(_armies[pos].get("id", "")) == army_id:
			return _armies[pos].get("units", [])
	return []


func retreat_from_battle() -> void:
	var dest: Vector2i = _pre_battle_pos
	if dest == hero_pos or (_armies.has(dest) and dest != hero_pos):
		# Szukaj wolnego sąsiada (np. gdy wróg wszedł na nas).
		for n in HexMath.neighbors(hero_pos):
			if not _cells.has(n):
				continue
			if is_blocked(n):
				continue
			if _armies.has(n):
				continue
			dest = n
			break
	hero_pos = dest
	_pending_army_id = ""
	_recompute_reach()
	queue_redraw()
	_emit_castle_presence()
	hero_moved.emit(hero_pos.x, hero_pos.y, movement_left)


func army_pos(army_id: String) -> Vector2i:
	for pos in _armies.keys():
		if str(_armies[pos].get("id", "")) == army_id:
			return pos
	return Vector2i(-1, -1)


func castle_pos(region_id: String) -> Vector2i:
	for pos in _castles.keys():
		if str(_castles[pos].get("id", "")) == region_id:
			return pos
	return Vector2i(-1, -1)


func castle_region_at(cell: Vector2i) -> String:
	if _castles.has(cell):
		return str(_castles[cell].get("id", ""))
	return ""


func place_army(cell: Vector2i, data: Dictionary) -> void:
	_armies[cell] = data
	_recompute_reach()
	queue_redraw()


func army_at(cell: Vector2i) -> Dictionary:
	return _armies.get(cell, {})


func _sc(v: Vector2i) -> Vector2i:
	return Vector2i(roundi(v.x * MAP_SCALE), roundi(v.y * MAP_SCALE))


func _generate_cells() -> void:
	_cells.clear()
	for r in map_height:
		for q in map_width:
			if _is_sea(q, r) and not _near_capital(q, r):
				_cells[Vector2i(q, r)] = {"region_id": "morze", "terrain": "morze"}
				continue
			var id := _region_for_qr(q, r)
			var terrain := _terrain_for_region(id, q, r)
			_cells[Vector2i(q, r)] = {"region_id": id, "terrain": terrain}
	_carve_lakes()
	_carve_rivers()


func _near_capital(q: int, r: int, rad: int = 2) -> bool:
	for reg in _regions:
		if HexMath.distance(Vector2i(q, r), Vector2i(int(reg.get("capital_q", 0)), int(reg.get("capital_r", 0)))) <= rad:
			return true
	return false


func _nz(q: float, r: float) -> float:
	if _noise == null:
		return sin(q * 0.37) * 0.5 + cos(r * 0.29 + q * 0.11) * 0.5
	return _noise.get_noise_2d(q * 0.55 + 400.0, r * 0.55 - 200.0)


## Bałtyk (z Zatoką Gdańską i Ryską) na północy, Morze Czarne na SE. u,v = współrzędne „historyczne”.
func _is_sea(q: int, r: int) -> bool:
	var u := q / MAP_SCALE
	var v := r / MAP_SCALE
	var nz := _nz(q, r)
	var coast := 2.2 + nz * 1.3
	if u >= 12.0 and u <= 23.0:
		coast += 1.7 * (1.0 - absf(u - 17.5) / 5.5)
	if u >= 27.0 and u <= 35.0:
		coast += 1.3 * (1.0 - absf(u - 31.0) / 4.0)
	if u < 4.0:
		coast += 1.2
	if v < coast:
		return true
	var e := (u - 48.0) * (u - 48.0) / 110.0 + (v - 34.5) * (v - 34.5) / 20.0
	return e < 1.0 + nz * 0.3


func _set_water(c: Vector2i, t: String) -> void:
	if not _cells.has(c) or _near_capital(c.x, c.y, 1):
		return
	if str(_cells[c]["terrain"]) == "morze":
		return
	_cells[c]["terrain"] = t


## Jeziora: Pojezierze Mazurskie + kilka losowych w głębi lądu.
func _carve_lakes() -> void:
	var centers: Array = []
	for k in _rng.randi_range(4, 6):
		centers.append(Vector2(_rng.randf_range(20.0, 29.0), _rng.randf_range(6.0, 10.0)))
	for k in _rng.randi_range(3, 5):
		centers.append(Vector2(_rng.randf_range(4.0, 44.0), _rng.randf_range(8.0, 30.0)))
	for cv in centers:
		var c := Vector2i(roundi(cv.x * MAP_SCALE), roundi(cv.y * MAP_SCALE))
		if _near_capital(c.x, c.y, 4):
			continue
		var rad := _rng.randi_range(1, 3)
		for dq in range(-rad - 1, rad + 2):
			for dr in range(-rad - 1, rad + 2):
				var cell := c + Vector2i(dq, dr)
				var d := HexMath.distance(c, cell)
				if d <= rad or (d == rad + 1 and _nz(cell.x * 3.0, cell.y * 3.0) > 0.25):
					_set_water(cell, "morze")


## Rzeki (Wisła, Odra, Niemen, Dniepr, Dniestr) — spławne, przekraczane mostami.
func _carve_rivers() -> void:
	var rivers := [
		[Vector2(17.5, 20.5), Vector2(18.2, 16.0), Vector2(20.6, 13.2), Vector2(19.6, 9.0), Vector2(20.0, 6.5), Vector2(20.0, 1.0)],
		[Vector2(9.5, 20.0), Vector2(8.2, 15.0), Vector2(7.8, 11.0), Vector2(7.3, 8.0), Vector2(4.8, 7.0), Vector2(4.0, 1.0)],
		[Vector2(36.0, 13.5), Vector2(31.5, 9.6), Vector2(27.6, 7.4), Vector2(25.5, 4.5), Vector2(25.0, 0.5)],
		[Vector2(41.0, 5.0), Vector2(39.5, 13.0), Vector2(38.3, 20.0), Vector2(40.5, 26.0), Vector2(44.0, 31.0), Vector2(46.0, 33.5)],
		[Vector2(23.0, 23.0), Vector2(29.0, 27.5), Vector2(36.0, 30.0), Vector2(42.0, 32.5)],
	]
	for rv in rivers:
		var pts: Array = []
		for k in rv.size():
			var p: Vector2 = rv[k]
			if k > 0 and k < rv.size() - 1:
				p += Vector2(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.8, 0.8))
			pts.append(p * MAP_SCALE)
		for k in pts.size() - 1:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[k + 1]
			var ca := HexMath.axial_round(a.x, a.y)
			var cb := HexMath.axial_round(b.x, b.y)
			var n := maxi(1, HexMath.distance(ca, cb))
			var prev := ca
			for s in n + 1:
				var t := float(s) / float(n)
				# lekki meander
				var off := sin(t * PI * 2.0 + k) * 0.6
				var cell := HexMath.axial_round(lerpf(a.x, b.x, t) + off * 0.5 + 1e-4, lerpf(a.y, b.y, t) - off * 0.3 + 1e-4)
				if HexMath.distance(prev, cell) > 1:
					# dopełnij lukę, żeby rzeka była ciągła (statki)
					var mid := HexMath.axial_round((prev.x + cell.x) * 0.5 + 1e-4, (prev.y + cell.y) * 0.5 + 1e-4)
					_set_water(mid, "rzeka")
				_set_water(cell, "rzeka")
				prev = cell


## Mosty na rzekach co kilka pól (poza drogami, które same są mostami).
func _build_bridges() -> void:
	_bridges.clear()
	var k := 0
	var keys: Array = _cells.keys()
	keys.sort()
	for c in keys:
		if str(_cells[c]["terrain"]) != "rzeka" or _road_cells.has(c):
			continue
		k += 1
		if (_cell_hash(c) + k) % 9 == 0:
			_bridges[c] = true


func is_water(c: Vector2i) -> bool:
	if not _cells.has(c):
		return false
	var t := str(_cells[c]["terrain"])
	return t == "morze" or t == "rzeka" or str(_cells[c]["region_id"]) == "morze"


func _compute_water_bodies() -> Dictionary:
	_water_body.clear()
	var sizes := {}
	var id := 0
	for c in _cells.keys():
		if _water_body.has(c) or not is_water(c):
			continue
		id += 1
		var st: Array = [c]
		_water_body[c] = id
		var n := 0
		while not st.is_empty():
			var cur: Vector2i = st.pop_back()
			n += 1
			for nb in HexMath.neighbors(cur):
				if not _water_body.has(nb) and is_water(nb):
					_water_body[nb] = id
					st.append(nb)
		sizes[id] = n
	return sizes


func _port_body(c: Vector2i) -> int:
	for nb in HexMath.neighbors(c):
		if _water_body.has(nb):
			return int(_water_body[nb])
	return 0


## Porty: przy zamkach nad wodą + dodatkowe na wybrzeżach dużych akwenów.
func _spawn_ports() -> void:
	_ports.clear()
	var sizes := _compute_water_bodies()
	var cands: Array = []
	var keys: Array = _cells.keys()
	keys.sort()
	for c in keys:
		if is_water(c) or str(_cells[c]["terrain"]) in BLOCKING_TERRAIN or _castles.has(c) or _resources.has(c):
			continue
		var b := _port_body(c)
		if b > 0 and int(sizes.get(b, 0)) >= 20:
			cands.append(c)
	var ni := 0
	for cp in _castles.keys():
		var best := Vector2i(-1, -1)
		for c in cands:
			if HexMath.distance(c, cp) <= 4 and (best.x < 0 or HexMath.distance(c, cp) < HexMath.distance(best, cp)):
				best = c
		if best.x >= 0:
			_ports[best] = {"name": "Port " + str(_castles[cp].get("capital", "")), "body": _port_body(best)}
	var shuffled := cands.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	var per_body := {}
	for p in _ports.keys():
		per_body[_ports[p]["body"]] = int(per_body.get(_ports[p]["body"], 0)) + 1
	for c in shuffled:
		var b := _port_body(c)
		var want := 2 + int(sizes[b]) / 110
		if int(per_body.get(b, 0)) >= want:
			continue
		var ok := true
		for p in _ports.keys():
			if HexMath.distance(p, c) < 9:
				ok = false
				break
		if not ok or _near_capital(c.x, c.y, 2):
			continue
		_ports[c] = {"name": "Przystań " + str(PORT_NAMES[ni % PORT_NAMES.size()]), "body": b}
		ni += 1
		per_body[b] = int(per_body.get(b, 0)) + 1


## Trasy morskie/rzeczne między portami tego samego akwenu. Koszt: 2 PR za zaokrętowanie + 1 PR / 4 pola wody.
func _build_port_links() -> void:
	_compute_water_bodies()
	_port_links.clear()
	for p in _ports.keys():
		_ports[p]["body"] = _port_body(p)
	for p in _ports.keys():
		var links: Array = []
		var prev := {}
		var fr: Array = []
		for nb in HexMath.neighbors(p):
			if _water_body.has(nb):
				prev[nb] = p
				fr.append(nb)
		var qi := 0
		while qi < fr.size():
			var cur: Vector2i = fr[qi]
			qi += 1
			for nb in HexMath.neighbors(cur):
				if prev.has(nb):
					continue
				if _water_body.has(nb):
					prev[nb] = cur
					fr.append(nb)
				elif _ports.has(nb) and nb != p:
					prev[nb] = cur
					var path: Array = []
					var c: Vector2i = cur
					while c != p:
						path.push_front(c)
						c = prev[c]
					links.append({"to": nb, "path": path, "cost": 2 + ceili(path.size() / 4.0)})
		_port_links[p] = links
	# Port bez połączeń nie ma sensu — usuń.
	for p in _port_links.keys():
		if (_port_links[p] as Array).is_empty():
			_ports.erase(p)
			_port_links.erase(p)
	for p in _port_links.keys():
		_port_links[p] = (_port_links[p] as Array).filter(func(l): return _ports.has(l["to"]))


func port_at(c: Vector2i) -> Dictionary:
	return _ports.get(c, {})


func reveal_around(c: Vector2i, rad: int) -> void:
	for dq in range(-rad, rad + 1):
		for dr in range(maxi(-rad, -dq - rad), mini(rad, -dq + rad) + 1):
			_explored[c + Vector2i(dq, dr)] = true


func _reveal_sources() -> void:
	# Jak w Heroes: mgłę rozwiewa wyłącznie bohater; odkryte zostaje na stałe.
	reveal_around(hero_pos, SIGHT_HERO + sight_bonus)
	for pos in _armies.keys():
		if str(_armies[pos].get("id", "")).begins_with("my_hero_"):
			reveal_around(pos, SIGHT_HERO)


func is_explored(c: Vector2i) -> bool:
	return _explored.has(c)


func _region_for_qr(q: int, r: int) -> String:
	# Voronoi od stolic = organiczne prowincje.
	var best_id := "mazowsze"
	var best_d := 999999
	for reg in _regions:
		var cq := int(reg.get("capital_q", 0))
		var cr := int(reg.get("capital_r", 0))
		var d: int = HexMath.distance(Vector2i(q, r), Vector2i(cq, cr))
		# Lekkie wagi, żeby Litwa/Ukraina nie zjadały centrum.
		var rid := str(reg.get("id", ""))
		if rid in ["litwa", "ukraina"]:
			d += 1
		if rid == "pomorze_zach" or rid == "slask":
			d += 0
		if d < best_d:
			best_d = d
			best_id = rid
	return best_id


func _terrain_for_region(region_id: String, q: int, r: int) -> String:
	var n := absi((q * 73856093) ^ (r * 19349663) ^ hash(region_id)) % 100
	if _noise != null:
		# Szum spójny (plamy lasów/gór zamiast pojedynczych pól) + odrobina ziarna.
		var v := (_noise.get_noise_2d(q * 1.0, r * 1.0) + 1.0) * 0.5
		n = clampi(int(v * 100.0) + (absi((q * 92821) ^ (r * 68917) ^ map_seed) % 11) - 5, 0, 99)
	var cs := _carp_shift
	var pq := _poles_shift.x
	var pr := _poles_shift.y
	var q0 := q
	var r0 := r
	q = roundi(q0 / MAP_SCALE)
	r = roundi(r0 / MAP_SCALE)
	# Karpaty — łuk na południu centrum
	if r >= 21 + cs and r <= 28 and q >= 10 + cs and q <= 28 + cs:
		if n < 55:
			return "gory"
		if n < 80:
			return "wzgórze"
	# Polesie — bagna między Litwą a Ukrainą
	if r >= 14 + pr and r <= 20 + pr and q >= 24 + pq and q <= 34 + pq and n < 40:
		return "bagno"
	# Wybrzeże bałtyckie
	if r <= 6 and region_id in ["prusy", "inflanty", "pomorze_zach"]:
		return "wybrzeze" if n < 60 else "równina"
	match region_id:
		"litwa", "zmudz":
			return "las" if n < 55 else ("bagno" if n < 70 else "równina")
		"ukraina", "wolyn":
			return "step" if n < 65 else "równina"
		"slask":
			return "gory" if n < 45 else "wzgórze"
		"malopolska", "rus_czerwona":
			return "wzgórze" if n < 45 else ("las" if n < 70 else "równina")
		"inflanty", "prusy", "pomorze_zach":
			return "las" if n < 30 else "równina"
		_:
			return "równina" if n < 75 else "las"


func _terrain_cost(cell: Vector2i) -> int:
	if not _cells.has(cell):
		return 999
	var t: String = str(_cells[cell]["terrain"])
	var c: int = int(TERRAIN_COST.get(t, 3))
	if _road_cells.has(cell):
		return maxi(1, c / 2)
	return c


func is_road(cell: Vector2i) -> bool:
	return _road_cells.has(cell)


func _recompute_reach() -> void:
	_reachable.clear()
	_came_from.clear()
	_sea_link.clear()
	_reveal_sources()
	_reachable[hero_pos] = 0
	var frontier: Array[Vector2i] = [hero_pos]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var cost_here: int = int(_reachable[current])
		for nxt in HexMath.neighbors(current):
			if not _cells.has(nxt):
				continue
			if is_blocked(nxt):
				continue
			var step := _terrain_cost(nxt)
			var new_cost := cost_here + step
			if new_cost > movement_left:
				continue
			if _reachable.has(nxt) and int(_reachable[nxt]) <= new_cost:
				continue
			_reachable[nxt] = new_cost
			_came_from[nxt] = current
			_sea_link.erase(nxt)
			# Hex z armią (wróg/strażnik/rywal) = cel (walka), ale nie da się przez niego przejść.
			if _armies.has(nxt):
				continue
			frontier.append(nxt)
		# Port: rejs do innych portów tego samego akwenu.
		if _ports.has(current) and (current == hero_pos or not _armies.has(current)):
			for link in _port_links.get(current, []):
				var to: Vector2i = link["to"]
				var nc: int = cost_here + int(link["cost"])
				if nc > movement_left or not _explored.has(to):
					continue
				if _reachable.has(to) and int(_reachable[to]) <= nc:
					continue
				_reachable[to] = nc
				_came_from[to] = current
				_sea_link[to] = link["path"]
				if not _armies.has(to):
					frontier.append(to)
	# Mgła: nie można wskazać nieodkrytego pola.
	for k in _reachable.keys():
		if not _explored.has(k):
			_reachable.erase(k)


func _build_path_to(goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not _reachable.has(goal) or goal == hero_pos:
		return path
	var cur: Vector2i = goal
	while cur != hero_pos:
		path.push_front(cur)
		if _sea_link.has(cur):
			var sp: Array = _sea_link[cur]
			for k in range(sp.size() - 1, -1, -1):
				path.push_front(sp[k])
		if not _came_from.has(cur):
			return [] as Array[Vector2i]
		cur = _came_from[cur]
	return path


static func path_point(pts: PackedVector2Array, t: float) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	if pts.size() == 1 or t <= 0.0:
		return pts[0]
	if t >= 1.0:
		return pts[pts.size() - 1]
	var f := t * float(pts.size() - 1)
	var i := int(floor(f))
	return pts[i].lerp(pts[i + 1], f - float(i))


func try_move_to(goal: Vector2i) -> bool:
	if is_animating or not _reachable.has(goal) or goal == hero_pos:
		return false
	var cost: int = int(_reachable[goal])
	var path := _build_path_to(goal)
	var pts := PackedVector2Array([HexMath.axial_to_pixel(hero_pos.x, hero_pos.y, hex_size)])
	for c in path:
		pts.append(HexMath.axial_to_pixel(c.x, c.y, hex_size))
	if pts.size() < 2:
		pts.append(HexMath.axial_to_pixel(goal.x, goal.y, hex_size))
	is_animating = true
	_path_preview.clear()
	_reachable.clear()
	_sea_link.clear()
	_hero_px = pts[0]
	var tw := create_tween()
	var cam := get_viewport().get_camera_2d()
	tw.tween_method(func(v: float) -> void:
		_hero_px = path_point(pts, v)
		reveal_around(HexMath.pixel_to_axial(_hero_px, hex_size), SIGHT_HERO + sight_bonus)
		if cam:
			# kamera łagodnie podąża za bohaterem, gdy zbliża się do krawędzi ekranu
			var hp := to_global(_hero_px)
			var half := get_viewport_rect().size * 0.5 / cam.zoom
			var off := hp - cam.position
			if absf(off.x) > half.x * 0.55 or absf(off.y) > half.y * 0.55:
				cam.position = cam.position.lerp(hp, 0.08)
		queue_redraw(), 0.0, 1.0, HERO_STEP_TIME * float(pts.size() - 1)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	is_animating = false
	_commit_move(goal, cost)
	return true


func _commit_move(goal: Vector2i, cost: int) -> void:
	_pre_battle_pos = hero_pos
	hero_pos = goal
	movement_left = maxi(0, movement_left - cost)
	_path_preview.clear()
	_recompute_reach()
	queue_redraw()
	hero_moved.emit(hero_pos.x, hero_pos.y, movement_left)
	_emit_castle_presence()
	if _artifacts.has(hero_pos):
		var aid: String = str(_artifacts[hero_pos])
		_artifacts.erase(hero_pos)
		queue_redraw()
		artifact_picked.emit(aid)
	if _armies.has(hero_pos):
		var army: Dictionary = _armies[hero_pos]
		_pending_army_id = str(army.get("id", ""))
		army_encountered.emit(_pending_army_id, str(army.get("name", "Wroga armia")))
		return
	collect_resource_here()
	if _castles.has(hero_pos):
		try_enter_city()


## Zbiera stos / przejmuje kopalnię na polu bohatera (też po wygranej ze strażą).
func collect_resource_here() -> void:
	if _resources.has(hero_pos):
		var res: Dictionary = _resources[hero_pos]
		var rt: String = str(res["type"])
		if rt == "drewno" or rt == "ruda":
			_resources.erase(hero_pos)
			queue_redraw()
			resource_picked.emit("wood" if rt == "drewno" else "ore", "pile", 5)
		elif not bool(res.get("owned", false)):
			res["owned"] = true
			queue_redraw()
			var m: Dictionary = MINE_INCOME.get(rt, {"ore": 2})
			var k: String = str(m.keys()[0])
			resource_picked.emit(k, "mine:" + str(MINE_NAMES.get(rt, rt)), int(m[k]))


func _emit_castle_presence() -> void:
	if _castles.has(hero_pos):
		var reg: Dictionary = _castles[hero_pos]
		var rid := str(reg.get("id", ""))
		var label := str(reg.get("name", ""))
		if rid not in owned_region_ids:
			label = "%s (obcy)" % label
		castle_presence.emit(true, label)
	else:
		castle_presence.emit(false, "")


const TERRAIN_COLORS: Dictionary = {
	"równina": Color(0.62, 0.74, 0.36),
	"step": Color(0.80, 0.74, 0.42),
	"wybrzeze": Color(0.86, 0.80, 0.56),
	"las": Color(0.20, 0.45, 0.22),
	"wzgórze": Color(0.58, 0.56, 0.36),
	"bagno": Color(0.33, 0.42, 0.30),
	"gory": Color(0.52, 0.50, 0.50),
	"rzeka": Color(0.25, 0.50, 0.75),
	"morze": Color(0.10, 0.26, 0.50),
}


func _cell_hash(cell: Vector2i) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663)) % 1000


func _draw_terrain_hex(cell: Vector2i, center: Vector2, terrain: String, region_col: Color) -> void:
	var base: Color = TERRAIN_COLORS.get(terrain, Color(0.6, 0.6, 0.5))
	if terrain != "morze":
		base = base.lerp(region_col, 0.22)
	var h := _cell_hash(cell)
	base = base.lightened(float(h % 7) * 0.008)
	var corners := HexMath.hex_corners(center, hex_size * 0.97)
	# gradient: góra jaśniejsza, dół ciemniejszy
	var cols := PackedColorArray()
	for c in corners:
		var t := clampf((c.y - center.y) / hex_size, -1.0, 1.0)
		cols.append(base.lightened(0.12 * -t) if t < 0 else base.darkened(0.14 * t))
	var ttex := _terrain_texture(terrain)
	if ttex:
		var uvs := PackedVector2Array()
		var tcols := PackedColorArray()
		for i in corners.size():
			uvs.append(corners[i] / 320.0)
			var cc: Color = cols[i]
			var tint := Color(1, 1, 1).lerp(region_col, 0.07 if terrain != "morze" else 0.0)
			tcols.append(Color(tint.r * (0.9 + cc.v * 0.2), tint.g * (0.9 + cc.v * 0.2), tint.b * (0.9 + cc.v * 0.2)))
		draw_polygon(corners, tcols, uvs, ttex)
	else:
		draw_polygon(corners, cols)
	var ring := corners + PackedVector2Array([corners[0]])
	draw_polyline(ring, base.darkened(0.45), 1.2, true)
	var inner := HexMath.hex_corners(center, hex_size * 0.86)
	draw_polyline(inner + PackedVector2Array([inner[0]]), Color(1, 1, 1, 0.07), 1.0, true)
	var s := hex_size
	var ox := float(h % 5 - 2) * s * 0.05
	if ttex:
		return # realistyczna tekstura PNG — bez kreskówkowych nakładek
	match terrain:
		"las":
			var offs := [Vector2(-0.35, 0.25), Vector2(0.3, 0.3), Vector2(0.0, -0.3), Vector2(-0.4, -0.12), Vector2(0.38, -0.08), Vector2(0.02, 0.08)]
			for k in offs.size():
				var off: Vector2 = offs[k]
				var sc := 0.8 + float((h + k * 37) % 5) * 0.08
				var p: Vector2 = center + off * s + Vector2(ox, 0)
				draw_line(p + Vector2(0, s * 0.1 * sc), p + Vector2(0, s * 0.2 * sc), Color(0.3, 0.18, 0.08), 1.8)
				var tc := Color(0.06, 0.27 + float(k % 3) * 0.04, 0.11)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.14 * sc, s * 0.12 * sc),
					p + Vector2(0, -s * 0.2 * sc), p + Vector2(s * 0.14 * sc, s * 0.12 * sc)]), tc)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.1 * sc, -s * 0.02 * sc),
					p + Vector2(0, -s * 0.28 * sc), p + Vector2(s * 0.1 * sc, -s * 0.02 * sc)]), tc.lightened(0.12))
		"gory":
			# tylny grzbiet
			var back := PackedVector2Array([center + Vector2(-s * 0.6, s * 0.1), center + Vector2(-s * 0.3, -s * 0.35),
				center + Vector2(s * 0.05, -s * 0.15), center + Vector2(s * 0.35, -s * 0.5), center + Vector2(s * 0.65, s * 0.1)])
			draw_colored_polygon(back, Color(0.33, 0.32, 0.36))
			draw_colored_polygon(PackedVector2Array([center + Vector2(s * 0.24, -s * 0.36),
				center + Vector2(s * 0.35, -s * 0.5), center + Vector2(s * 0.46, -s * 0.36)]), Color(0.9, 0.92, 0.98))
			var m := PackedVector2Array([center + Vector2(-s * 0.55, s * 0.4), center + Vector2(-s * 0.1, -s * 0.3),
				center + Vector2(s * 0.2, s * 0.05), center + Vector2(s * 0.35, -s * 0.1), center + Vector2(s * 0.6, s * 0.4)])
			draw_colored_polygon(m, Color(0.45, 0.42, 0.40))
			# cień na prawym zboczu
			draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 0.1, -s * 0.3), center + Vector2(s * 0.2, s * 0.05),
				center + Vector2(s * 0.05, s * 0.4)]), Color(0, 0, 0, 0.18))
			draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 0.22, -s * 0.12),
				center + Vector2(-s * 0.1, -s * 0.3), center + Vector2(s * 0.02, -s * 0.12)]), Color(0.95, 0.95, 1.0))
			draw_polyline(m, Color(0.2, 0.18, 0.18), 1.5)
		"wzgórze":
			draw_arc(center + Vector2(-s * 0.15 + ox, s * 0.2), s * 0.3, PI, TAU, 10, Color(0.38, 0.35, 0.2), 2.0)
			draw_arc(center + Vector2(s * 0.25 + ox, s * 0.25), s * 0.22, PI, TAU, 10, Color(0.38, 0.35, 0.2), 2.0)
		"bagno":
			for i in 3:
				var y := s * (-0.2 + 0.2 * i)
				draw_line(center + Vector2(-s * 0.3 + ox, y), center + Vector2(s * 0.3 + ox, y), Color(0.15, 0.3, 0.3, 0.8), 1.5)
			draw_line(center + Vector2(s * 0.1, s * 0.1), center + Vector2(s * 0.05, -s * 0.25), Color(0.25, 0.35, 0.12), 1.5)
			draw_line(center + Vector2(-s * 0.15, s * 0.1), center + Vector2(-s * 0.2, -s * 0.2), Color(0.25, 0.35, 0.12), 1.5)
		"step":
			if h % 2 == 0:
				for i in 3:
					var p := center + Vector2(s * (-0.25 + 0.25 * i) + ox, s * 0.15)
					draw_line(p, p + Vector2(-s * 0.06, -s * 0.15), Color(0.6, 0.52, 0.25), 1.2)
					draw_line(p, p + Vector2(s * 0.06, -s * 0.15), Color(0.6, 0.52, 0.25), 1.2)
		"równina":
			if h % 3 == 0:
				# pola uprawne: pasy
				var fc := Color(0.78, 0.68, 0.3, 0.55) if h % 2 == 0 else Color(0.45, 0.6, 0.22, 0.55)
				var fr := Rect2(center + Vector2(-s * 0.38 + ox, -s * 0.18), Vector2(s * 0.5, s * 0.36))
				draw_rect(fr, fc)
				for i in 4:
					var fy := fr.position.y + fr.size.y * (0.2 + 0.2 * i)
					draw_line(Vector2(fr.position.x, fy), Vector2(fr.end.x, fy), fc.darkened(0.35), 1.0)
				draw_rect(Rect2(fr.end + Vector2(s * 0.04, -fr.size.y), Vector2(s * 0.22, fr.size.y * 0.6)), Color(0.8, 0.72, 0.35, 0.45))
			elif h % 3 == 1:
				for i in 3:
					var p := center + Vector2(s * (-0.25 + 0.25 * i) + ox, s * (0.1 if i % 2 == 0 else -0.05))
					draw_line(p, p + Vector2(0, -s * 0.12), Color(0.38, 0.55, 0.2), 1.2)
		"wybrzeze":
			for i in 4:
				var p := center + Vector2(s * (-0.3 + 0.2 * i) + ox, s * (0.15 if i % 2 == 0 else -0.1))
				draw_circle(p, s * 0.035, Color(0.6, 0.55, 0.4, 0.7))
		"morze", "rzeka":
			var wc := Color(0.6, 0.8, 1.0, 0.45)
			var rows := 3 if terrain == "morze" else 2
			for i in rows:
				var wy := s * (-0.3 + 0.3 * i)
				var wx := ox + float((h + i * 13) % 5 - 2) * s * 0.06
				draw_arc(center + Vector2(-s * 0.13 + wx, wy), s * 0.12, PI * 1.1, PI * 1.9, 5, wc, 1.3)
				draw_arc(center + Vector2(s * 0.11 + wx, wy), s * 0.12, PI * 1.1, PI * 1.9, 5, wc, 1.3)

	_draw_extra_detail(cell, center, terrain, h)


## Dodatkowe drobne detale (kępy trawy, kamienie, kwiaty, wioski, wiatraki, trzciny, łodzie).
var _tree_tex: Texture2D = null
var _tree_tried := false
func _detail_tree() -> Texture2D:
	if not _tree_tried:
		_tree_tried = true
		if ResourceLoader.exists("res://assets/map/tree.png"):
			_tree_tex = load("res://assets/map/tree.png") as Texture2D
	return _tree_tex

var _hero_texs: Dictionary = {}
func _hero_tex(fac: String) -> Texture2D:
	if not _hero_texs.has(fac):
		var p := fac if fac.begins_with("res://") else "res://assets/heroes/hero_%s.png" % fac
		_hero_texs[fac] = RoundTex.circle(load(p) as Texture2D) if ResourceLoader.exists(p) else null
	return _hero_texs[fac]

var _deco_tex: Dictionary = {}
func _deco(n: String) -> Texture2D:
	if not _deco_tex.has(n):
		var p := "res://assets/map/deco/%s.png" % n
		_deco_tex[n] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	return _deco_tex[n]

func _deco_at(n: String, pos: Vector2, size: float) -> bool:
	var t := _deco(n)
	if t == null:
		return false
	draw_texture_rect(t, Rect2(pos - Vector2(size * 0.5, size * 0.85), Vector2(size, size)), false)
	return true

func _draw_extra_detail(cell: Vector2i, center: Vector2, terrain: String, h: int) -> void:
	var s := hex_size
	var h2 := _cell_hash(Vector2i(cell.y * 7 + 3, cell.x * 11 + 5))
	if _deco("oak") != null and _draw_png_detail(cell, center, terrain, h2):
		return
	var grass := Color(0.22, 0.42, 0.14, 0.75)
	if (terrain == "las" and h2 % 3 == 0) or (terrain in ["równina", "wzgórze"] and h2 % 13 == 0):
		var tt := _detail_tree()
		if tt:
			var d := s * (0.75 if terrain == "las" else 0.55)
			var tp := center + Vector2(float(h2 % 7 - 3) * s * 0.08, float(h2 % 5 - 2) * s * 0.08)
			draw_texture_rect(tt, Rect2(tp - Vector2(d * 0.5, d * 0.8), Vector2(d, d)), false)
	if terrain in ["równina", "step", "wzgórze", "wybrzeze"]:
		# kępki trawy
		for k in 3:
			var p := center + Vector2(float((h2 + k * 29) % 9 - 4) * s * 0.09, float((h2 + k * 17) % 7 - 3) * s * 0.1)
			draw_line(p, p + Vector2(-s * 0.04, -s * 0.08), grass, 1.0)
			draw_line(p, p + Vector2(0, -s * 0.1), grass, 1.0)
			draw_line(p, p + Vector2(s * 0.04, -s * 0.08), grass, 1.0)
		# kamienie
		if h2 % 4 == 0:
			var rp := center + Vector2(s * 0.3, s * 0.32)
			draw_circle(rp, s * 0.055, Color(0.45, 0.43, 0.4))
			draw_circle(rp + Vector2(-s * 0.015, -s * 0.015), s * 0.03, Color(0.65, 0.63, 0.6))
		# kwiaty
		if h2 % 5 == 1:
			var fcol: Color = [Color(0.9, 0.2, 0.2), Color(0.95, 0.85, 0.2), Color(0.7, 0.4, 0.9)][h2 % 3]
			for k in 4:
				draw_circle(center + Vector2(-s * 0.3 + k * s * 0.07, s * 0.35 - (k % 2) * s * 0.05), s * 0.025, fcol)
	if terrain == "równina" and h2 % 13 == 2:
		# wioska: dwa domki z dachami
		for k in 2:
			var b := center + Vector2(s * (0.1 + 0.2 * k), -s * 0.3 + k * s * 0.08)
			draw_rect(Rect2(b + Vector2(-s * 0.08, 0), Vector2(s * 0.16, s * 0.12)), Color(0.85, 0.78, 0.62))
			draw_colored_polygon(PackedVector2Array([b + Vector2(-s * 0.11, 0), b + Vector2(0, -s * 0.1), b + Vector2(s * 0.11, 0)]), Color(0.6, 0.22, 0.12))
			draw_rect(Rect2(b + Vector2(-s * 0.02, s * 0.05), Vector2(s * 0.04, s * 0.07)), Color(0.3, 0.18, 0.1))
	elif terrain in ["równina", "step"] and h2 % 17 == 5:
		# wiatrak
		var w := center + Vector2(-s * 0.25, -s * 0.1)
		draw_colored_polygon(PackedVector2Array([w + Vector2(-s * 0.07, s * 0.2), w + Vector2(-s * 0.04, -s * 0.05),
			w + Vector2(s * 0.04, -s * 0.05), w + Vector2(s * 0.07, s * 0.2)]), Color(0.75, 0.65, 0.5))
		for k in 4:
			var ang := PI * 0.25 + k * PI * 0.5
			draw_line(w, w + Vector2(cos(ang), sin(ang)) * s * 0.2, Color(0.35, 0.25, 0.15), 2.0)
		draw_circle(w, s * 0.03, Color(0.2, 0.15, 0.1))
	if terrain == "las" and h2 % 3 == 0:
		# polana/grzyby i pnie
		draw_circle(center + Vector2(s * 0.2, s * 0.38), s * 0.04, Color(0.4, 0.26, 0.12))
		draw_circle(center + Vector2(-s * 0.2, s * 0.4), s * 0.03, Color(0.85, 0.15, 0.1))
	if terrain == "bagno":
		for k in 3:
			var p := center + Vector2(s * (-0.3 + 0.3 * k), s * 0.32)
			draw_line(p, p + Vector2(-s * 0.03, -s * 0.18), Color(0.35, 0.4, 0.15), 1.2)
			draw_circle(p + Vector2(-s * 0.03, -s * 0.2), s * 0.025, Color(0.4, 0.25, 0.1))
	if terrain == "gory" and h2 % 2 == 0:
		draw_circle(center + Vector2(-s * 0.4, s * 0.38), s * 0.05, Color(0.4, 0.38, 0.38))
		draw_circle(center + Vector2(-s * 0.32, s * 0.42), s * 0.035, Color(0.5, 0.48, 0.48))
	if terrain == "morze" and h2 % 23 == 4:
		# łódź z żaglem
		var bp := center + Vector2(0, s * 0.15)
		draw_colored_polygon(PackedVector2Array([bp + Vector2(-s * 0.22, 0), bp + Vector2(s * 0.22, 0),
			bp + Vector2(s * 0.14, s * 0.1), bp + Vector2(-s * 0.14, s * 0.1)]), Color(0.4, 0.25, 0.12))
		draw_line(bp, bp + Vector2(0, -s * 0.35), Color(0.3, 0.2, 0.1), 1.5)
		draw_colored_polygon(PackedVector2Array([bp + Vector2(0, -s * 0.33), bp + Vector2(s * 0.18, -s * 0.05), bp + Vector2(0, -s * 0.05)]), Color(0.95, 0.93, 0.85))
	elif terrain == "morze" and h2 % 7 == 1:
		draw_circle(center + Vector2(s * 0.2, -s * 0.1), s * 0.03, Color(1, 1, 1, 0.5))
		draw_circle(center + Vector2(-s * 0.15, s * 0.2), s * 0.025, Color(1, 1, 1, 0.4))

## Detale PNG (drzewa, skały, wioski, wiatraki, ruiny, łodzie). Zwraca true gdy narysowano.
func _draw_png_detail(cell: Vector2i, c: Vector2, terrain: String, h2: int) -> bool:
	if _castles.has(cell) or _armies.has(cell) or cell == hero_pos:
		return false
	var s := hex_size
	var o := Vector2(float(h2 % 7 - 3) * s * 0.07, float(h2 % 5 - 2) * s * 0.06)
	match terrain:
		"las":
			var kinds := ["pine", "oak"] if h2 % 2 == 0 else ["oak", "pine"]
			_deco_at(kinds[0], c + Vector2(-s * 0.3, -s * 0.05) + o, s * 0.75)
			_deco_at(kinds[1], c + Vector2(s * 0.3, s * 0.05) + o, s * 0.7)
			_deco_at("pine", c + Vector2(0, s * 0.35), s * 0.8)
			if h2 % 4 == 0:
				_deco_at("bush", c + Vector2(s * 0.4, s * 0.45), s * 0.4)
		"gory":
			_deco_at("rock", c + Vector2(-s * 0.35, s * 0.45) + o, s * 0.45)
			if h2 % 3 == 0:
				_deco_at("pine", c + Vector2(s * 0.4, s * 0.45), s * 0.45)
		"wzgórze":
			if h2 % 3 == 0:
				_deco_at("oak", c + o, s * 0.65)
			elif h2 % 3 == 1:
				_deco_at("rock", c + Vector2(s * 0.25, s * 0.35), s * 0.4)
			if h2 % 11 == 3:
				_deco_at("ruins", c + Vector2(-s * 0.2, s * 0.2), s * 0.7)
		"równina":
			if h2 % 9 == 2:
				_deco_at("village", c + Vector2(0, s * 0.3), s * 0.95)
			elif h2 % 9 == 5:
				_deco_at("windmill", c + Vector2(-s * 0.15, s * 0.3), s * 0.8)
				_deco_at("wheat", c + Vector2(s * 0.3, s * 0.5), s * 0.5)
			elif h2 % 9 == 7:
				_deco_at("wheat", c + Vector2(0, s * 0.45), s * 0.7)
			elif h2 % 4 == 0:
				_deco_at("oak", c + o, s * 0.6)
				_deco_at("bush", c + Vector2(s * 0.35, s * 0.45), s * 0.35)
			elif h2 % 4 == 1:
				_deco_at("bush", c + o + Vector2(0, s * 0.3), s * 0.4)
		"step":
			if h2 % 6 == 0:
				_deco_at("bush", c + o + Vector2(0, s * 0.3), s * 0.4)
			elif h2 % 6 == 3:
				_deco_at("rock", c + Vector2(s * 0.2, s * 0.4), s * 0.35)
			elif h2 % 13 == 4:
				_deco_at("windmill", c + Vector2(0, s * 0.3), s * 0.75)
		"bagno":
			if h2 % 2 == 0:
				_deco_at("bush", c + Vector2(-s * 0.25, s * 0.4), s * 0.4)
			return false
		"wybrzeze":
			if h2 % 5 == 0:
				_deco_at("bush", c + Vector2(0, s * 0.4), s * 0.35)
		"morze":
			if h2 % 19 == 4:
				_deco_at("ship", c + Vector2(0, s * 0.3), s * 0.8)
			return false
		_:
			return false
	return true

func _draw_army(center: Vector2, faction: String, portrait: String = "") -> void:
	if faction.begins_with("myhero_"):
		var ht: Texture2D = _hero_tex(portrait if portrait != "" else faction.substr(7))
		var hs := hex_size
		draw_set_transform(center + Vector2(0, hs * 0.42), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, hs * 0.5, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(center + Vector2(0, hs * 0.42), hs * 0.5, 0.0, TAU, 32, Color(0.35, 0.7, 1.0, 0.9), 2.5)
		if ht:
			var hd := hs * 1.25
			draw_texture_rect(ht, Rect2(center - Vector2(hd * 0.5, hd * 0.8), Vector2(hd, hd)), false)
		else:
			draw_circle(center, hs * 0.35, Color(0.2, 0.45, 0.9))
		return
	if faction.begins_with("beast_"):
		var bt := UnitArt.texture_for(faction.substr(6))
		if bt:
			var bs := hex_size
			draw_set_transform(center + Vector2(0, bs * 0.42), 0.0, Vector2(1.0, 0.35))
			draw_circle(Vector2.ZERO, bs * 0.55, Color(0, 0, 0, 0.35))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_arc(center + Vector2(0, bs * 0.42), bs * 0.55, 0.0, TAU, 32, Color(0.95, 0.65, 0.2, 0.8), 2.0)
			var bd := bs * 1.5
			draw_texture_rect(bt, Rect2(center - Vector2(bd * 0.5, bd * 0.72), Vector2(bd, bd)), false)
			return
	var col := Color(0.7, 0.15, 0.15)
	match faction:
		"sweden":
			col = Color(0.2, 0.4, 0.85)
		"moscow":
			col = Color(0.7, 0.1, 0.1)
		"horde":
			col = Color(0.75, 0.55, 0.1)
		_:
			col = Color(0.5, 0.25, 0.25)
	var s := hex_size
	var etex := _deco("enemy")
	if etex:
		draw_set_transform(center + Vector2(0, s * 0.42), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, s * 0.5, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(center + Vector2(0, s * 0.42), s * 0.5, 0.0, TAU, 32, col.lerp(Color(1, 0.2, 0.15), 0.5), 2.0)
		var ed := s * 1.4
		draw_texture_rect(etex, Rect2(center - Vector2(ed * 0.5, ed * 0.8), Vector2(ed, ed)), false)
		return
	draw_circle(center + Vector2(0, s * 0.42), s * 0.36, Color(0, 0, 0, 0.3))
	# tarcza
	var shield := PackedVector2Array([center + Vector2(-s * 0.3, -s * 0.1), center + Vector2(s * 0.3, -s * 0.1),
		center + Vector2(s * 0.28, s * 0.2), center + Vector2(0, s * 0.45), center + Vector2(-s * 0.28, s * 0.2)])
	draw_colored_polygon(shield, col)
	var sr := shield + PackedVector2Array([shield[0]])
	draw_polyline(sr, Color(0.05, 0.02, 0.02), 2.5)
	draw_polyline(sr, Color(1, 1, 1, 0.5), 1.0)
	# skrzyżowane miecze
	draw_line(center + Vector2(-s * 0.15, 0), center + Vector2(s * 0.15, s * 0.3), Color(0.95, 0.95, 0.95), 2.0)
	draw_line(center + Vector2(s * 0.15, 0), center + Vector2(-s * 0.15, s * 0.3), Color(0.95, 0.95, 0.95), 2.0)
	# chorągiew
	draw_line(center + Vector2(-s * 0.3, -s * 0.1), center + Vector2(-s * 0.3, -s * 0.7), Color(0.15, 0.1, 0.05), 2.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 0.3, -s * 0.7),
		center + Vector2(s * 0.2, -s * 0.58), center + Vector2(-s * 0.3, -s * 0.45)]), col.lightened(0.15))
	# ostrzegawcza obwódka
	draw_arc(center, s * 0.82, 0.0, TAU, 32, Color(1.0, 0.2, 0.15, 0.55), 2.0)


const CASTLE_FACTION := {"Ryga": "szwecja", "Kamieniec": "osmanowie", "Kowno": "szwecja", "Kijów": "kozacy", "Wilno": "moskwa", "Szczecin": "brandenburgia"}
var _castle_tex: Dictionary = {}
func _castle_png(cap: String) -> Texture2D:
	var f: String = CASTLE_FACTION.get(cap, "polska")
	if not _castle_tex.has(f):
		var p := "res://assets/map/castle_%s.png" % f
		if not ResourceLoader.exists(p):
			p = "res://assets/map/castle_%s.png" % {"moskwa": "szwecja", "kozacy": "polska", "brandenburgia": "szwecja"}.get(f, "polska")
		_castle_tex[f] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	return _castle_tex[f]

func _draw_castle_png(center: Vector2, owned: bool, cap: String) -> bool:
	var t := _castle_png(cap)
	if t == null:
		return false
	var accent := Color(0.2, 0.55, 1.0) if owned else Color(0.85, 0.15, 0.15)
	var hc := HexMath.hex_corners(center, hex_size * 0.95)
	draw_colored_polygon(hc, Color(accent.r, accent.g, accent.b, 0.25))
	draw_polyline(hc + PackedVector2Array([hc[0]]), accent, 2.5)
	draw_circle(center + Vector2(0, hex_size * 0.35), hex_size * 0.7, Color(0, 0, 0, 0.3))
	var d := hex_size * 2.3
	draw_texture_rect(t, Rect2(center - Vector2(d * 0.5, d * 0.62), Vector2(d, d)), false)
	# chorągiew właściciela
	var fp := center + Vector2(0, -d * 0.55)
	draw_line(fp, fp + Vector2(0, -hex_size * 0.45), Color(0.1, 0.08, 0.05), 1.5)
	draw_colored_polygon(PackedVector2Array([fp + Vector2(0, -hex_size * 0.45), fp + Vector2(hex_size * 0.4, -hex_size * 0.35), fp + Vector2(0, -hex_size * 0.25)]), accent)
	return true

func _draw_castle(center: Vector2, owned: bool) -> void:
	var base := Color(0.9, 0.78, 0.4) if owned else Color(0.62, 0.6, 0.66)
	var accent := Color(0.2, 0.55, 1.0) if owned else Color(0.85, 0.15, 0.15)
	var dark := Color(0.12, 0.1, 0.08)
	var s := hex_size * 0.6
	# podstawa w kolorze właściciela
	draw_colored_polygon(HexMath.hex_corners(center, hex_size * 0.9), Color(accent.r, accent.g, accent.b, 0.28))
	draw_polyline(HexMath.hex_corners(center, hex_size * 0.9) + PackedVector2Array([HexMath.hex_corners(center, hex_size * 0.9)[0]]), accent, 2.5)
	draw_circle(center + Vector2(0, s * 0.65), s * 0.85, Color(0, 0, 0, 0.25))
	# mury
	var wall := Rect2(center + Vector2(-s * 0.75, -s * 0.05), Vector2(s * 1.5, s * 0.7))
	draw_rect(wall, base)
	for i in 4:
		var bx := center.x - s * 0.75 + float(i) * s * 0.42
		draw_rect(Rect2(Vector2(bx, center.y - s * 0.22), Vector2(s * 0.24, s * 0.2)), base)
	draw_rect(wall, dark, false, 1.5)
	# wieża centralna
	var tower := Rect2(center + Vector2(-s * 0.25, -s * 0.65), Vector2(s * 0.5, s * 0.75))
	draw_rect(tower, base.lightened(0.1))
	draw_rect(tower, dark, false, 1.5)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 0.33, -s * 0.65),
		center + Vector2(0, -s * 1.05), center + Vector2(s * 0.33, -s * 0.65)]), accent)
	# brama
	draw_rect(Rect2(center + Vector2(-s * 0.15, s * 0.3), Vector2(s * 0.3, s * 0.35)), dark)
	# chorągiew
	draw_line(center + Vector2(0, -s * 1.05), center + Vector2(0, -s * 1.45), dark, 1.5)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -s * 1.45),
		center + Vector2(s * 0.45, -s * 1.33), center + Vector2(0, -s * 1.2)]), accent)
	if owned:
		# korona
		var cy := center.y - s * 0.4
		var crown := PackedVector2Array([Vector2(center.x - s * 0.18, cy + s * 0.1), Vector2(center.x - s * 0.18, cy - s * 0.08),
			Vector2(center.x - s * 0.09, cy), Vector2(center.x, cy - s * 0.12), Vector2(center.x + s * 0.09, cy),
			Vector2(center.x + s * 0.18, cy - s * 0.08), Vector2(center.x + s * 0.18, cy + s * 0.1)])
		draw_colored_polygon(crown, Color(1.0, 0.85, 0.15))


func _draw_hex_outline(cell: Vector2i, col: Color, width: float, scale: float = 0.93) -> void:
	var c := HexMath.axial_to_pixel(cell.x, cell.y, hex_size)
	var pts := HexMath.hex_corners(c, hex_size * scale)
	pts.append(pts[0])
	draw_polyline(pts, col, width, true)


func _process(_d: float) -> void:
	var xf := get_global_transform_with_canvas()
	if xf != _last_xf:
		_last_xf = xf
		queue_redraw()


func _view_rect() -> Rect2:
	var inv := get_global_transform_with_canvas().affine_inverse()
	var sz := get_viewport_rect().size
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * sz
	return Rect2(a, b - a).abs().grow(hex_size * 3.0)


var view3d: Node = null # widok 3D (World3D); gdy ustawiony, 2D nie rysuje mapy

func _mouse_local(sp: Vector2) -> Vector2:
	if view3d:
		return view3d.screen_to_map(sp)
	return get_global_transform_with_canvas().affine_inverse() * sp


func _draw() -> void:
	if view3d:
		return
	var vr := _view_rect()
	for key in _cells.keys():
		var cell: Vector2i = key
		var data: Dictionary = _cells[cell]
		var center := HexMath.axial_to_pixel(cell.x, cell.y, hex_size)
		if not vr.has_point(center):
			continue
		var terrain := str(data["terrain"])
		if str(data["region_id"]) == "morze":
			terrain = "morze"
		var reg: Dictionary = _region_by_id.get(data["region_id"], {})
		var rcol := Color.html(str(reg.get("color", "#888888")))
		_draw_terrain_hex(cell, center, terrain, rcol)

	_draw_map_details()
	for bp in _bridges.keys():
		var bc := HexMath.axial_to_pixel(bp.x, bp.y, hex_size)
		if vr.has_point(bc):
			_draw_bridge(bc)
	for pp in _ports.keys():
		var pc := HexMath.axial_to_pixel(pp.x, pp.y, hex_size)
		if vr.has_point(pc) and _explored.has(pp):
			_draw_port(pc)

	# zasięg ruchu
	for key in _reachable.keys():
		var rc: Vector2i = key
		if rc == hero_pos or not _cells.has(rc):
			continue
		var c2 := HexMath.axial_to_pixel(rc.x, rc.y, hex_size)
		draw_colored_polygon(HexMath.hex_corners(c2, hex_size * 0.9), Color(0.35, 0.75, 1.0, 0.22))
		_draw_hex_outline(rc, Color(0.55, 0.85, 1.0, 0.7), 1.5, 0.85)

	# ścieżka
	if not _path_preview.is_empty():
		var prev := HexMath.axial_to_pixel(hero_pos.x, hero_pos.y, hex_size)
		for cell in _path_preview:
			var nx := HexMath.axial_to_pixel(cell.x, cell.y, hex_size)
			draw_line(prev, nx, Color(0.1, 0.05, 0.0, 0.7), 6.0, true)
			draw_line(prev, nx, Color(1.0, 0.85, 0.2, 0.85), 3.0, true)
			prev = nx
	for i in _path_preview.size():
		var cell: Vector2i = _path_preview[i]
		var cpath := HexMath.axial_to_pixel(cell.x, cell.y, hex_size)
		var last := i == _path_preview.size() - 1
		if not last and i + 1 < _path_preview.size():
			var nxp := HexMath.axial_to_pixel(_path_preview[i + 1].x, _path_preview[i + 1].y, hex_size)
			var dir := (nxp - cpath).normalized()
			var side := Vector2(-dir.y, dir.x)
			var tip := cpath + dir * hex_size * 0.22
			draw_colored_polygon(PackedVector2Array([tip, cpath - dir * hex_size * 0.08 + side * hex_size * 0.16, cpath - dir * hex_size * 0.08 - side * hex_size * 0.16]), Color(1.0, 0.85, 0.2))
		else:
			draw_circle(cpath, hex_size * 0.3, Color(0.1, 0.05, 0.0, 0.85))
			draw_circle(cpath, hex_size * 0.24, Color(0.35, 0.8, 0.3) if movement_left - int(_reachable.get(cell, 0)) > 0 else Color(1.0, 0.75, 0.2))
			var left := maxi(0, movement_left - int(_reachable.get(cell, 0)))
			var font := ThemeDB.fallback_font
			var txt := str(left)
			var fs := int(hex_size * 0.32)
			var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
			draw_string_outline(font, cpath + Vector2(-sz.x * 0.5, sz.y * 0.32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0))
			draw_string(font, cpath + Vector2(-sz.x * 0.5, sz.y * 0.32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))

	if _cells.has(_hover):
		var hcol := Color(1, 1, 1, 0.95) if _reachable.has(_hover) else Color(1.0, 0.5, 0.4, 0.8)
		_draw_hex_outline(_hover, Color(0, 0, 0, 0.6), 4.5)
		_draw_hex_outline(_hover, hcol, 2.5)
	if _cells.has(_selected):
		_draw_hex_outline(_selected, Color(0, 0, 0, 0.7), 5.0)
		_draw_hex_outline(_selected, Color(1.0, 0.85, 0.15), 3.0)

	for pos in _castles.keys():
		var cpos: Vector2i = pos
		var reg2: Dictionary = _castles[cpos]
		var owned: bool = str(reg2.get("id", "")) in owned_region_ids
		var cc := HexMath.axial_to_pixel(cpos.x, cpos.y, hex_size)
		if not _draw_castle_png(cc, owned, str(reg2.get("capital", ""))):
			_draw_castle(cc, owned)

	_draw_capital_labels()

	for pos in _resources.keys():
		var rp: Vector2i = pos
		if _explored.has(rp):
			_draw_resource(HexMath.axial_to_pixel(rp.x, rp.y, hex_size), _resources[rp])

	for pos in _artifacts.keys():
		var tp: Vector2i = pos
		if _explored.has(tp):
			_draw_artifact(HexMath.axial_to_pixel(tp.x, tp.y, hex_size), str(_artifacts[tp]))

	for pos in _armies.keys():
		var apos: Vector2i = pos
		var army: Dictionary = _armies[apos]
		var ac := HexMath.axial_to_pixel(apos.x, apos.y, hex_size)
		if _army_t < 1.0 and _army_paths.has(apos):
			ac = path_point(_army_paths[apos], _army_t)
		if not _explored.has(HexMath.pixel_to_axial(ac, hex_size)):
			continue
		_draw_army(ac, str(army.get("faction", "neutral")), str(army.get("portrait", "")))
		if str(army.get("id", "")) == RIVAL_ID:
			draw_circle(ac + Vector2(0, -hex_size * 0.75), hex_size * 0.18, Color(0.55, 0.15, 0.7))
			draw_string(ThemeDB.fallback_font, ac + Vector2(-hex_size * 0.6, hex_size * 0.95), "Rywal", HORIZONTAL_ALIGNMENT_CENTER, hex_size * 1.2, 12, Color(1, 0.85, 1))
	for rrid in rival_region_ids:
		var rc := castle_pos(rrid)
		if rc.x >= 0:
			_draw_hex_outline(rc, Color(0.6, 0.2, 0.8), 3.0)

	_draw_fog(vr)
	# bohater: rycerz na tarczy z pierścieniem
	if not is_animating:
		_hero_px = HexMath.axial_to_pixel(hero_pos.x, hero_pos.y, hex_size)
	var hc := _hero_px
	var s := hex_size
	if is_animating and is_water(HexMath.pixel_to_axial(hc, hex_size)) and _deco("ship") != null:
		draw_circle(hc + Vector2(0, s * 0.3), s * 0.5, Color(0.8, 0.9, 1.0, 0.25))
		_deco_at("ship", hc + Vector2(0, s * 0.45), s * 1.5)
		return
	var htex := _deco("hero")
	if htex:
		draw_set_transform(hc + Vector2(0, s * 0.42), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, s * 0.55, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(hc + Vector2(0, s * 0.42), s * 0.55, 0.0, TAU, 40, Color(1.0, 0.85, 0.3, 0.9), 2.5)
		var hd := s * 1.5
		draw_texture_rect(htex, Rect2(hc - Vector2(hd * 0.5, hd * 0.78), Vector2(hd, hd)), false)
		_draw_portrait_badge(hc + Vector2(s * 0.55, -s * 0.75), s * 0.32)
		return
	draw_circle(hc + Vector2(0, s * 0.4), s * 0.42, Color(0, 0, 0, 0.35))
	draw_arc(hc, s * 0.62, 0.0, TAU, 40, Color(1.0, 0.9, 0.3, 0.9), 3.0)
	draw_circle(hc, s * 0.48, Color(0.85, 0.1, 0.12))
	draw_arc(hc, s * 0.48, 0.0, TAU, 32, Color(0.15, 0.0, 0.0), 2.0)
	# biały orzeł (stylizowany)
	draw_colored_polygon(PackedVector2Array([hc + Vector2(0, -s * 0.3), hc + Vector2(s * 0.3, -s * 0.12),
		hc + Vector2(s * 0.12, s * 0.02), hc + Vector2(s * 0.1, s * 0.3), hc + Vector2(-s * 0.1, s * 0.3),
		hc + Vector2(-s * 0.12, s * 0.02), hc + Vector2(-s * 0.3, -s * 0.12)]), Color(1, 1, 1))
	draw_colored_polygon(PackedVector2Array([hc + Vector2(-s * 0.1, -s * 0.4), hc + Vector2(-s * 0.05, -s * 0.48),
		hc + Vector2(0, -s * 0.42), hc + Vector2(s * 0.05, -s * 0.48), hc + Vector2(s * 0.1, -s * 0.4),
		hc + Vector2(s * 0.1, -s * 0.32), hc + Vector2(-s * 0.1, -s * 0.32)]), Color(1.0, 0.85, 0.15))


func _unhandled_input(event: InputEvent) -> void:
	if is_animating:
		return
	if event is InputEventMouseMotion:
		var local: Vector2 = _mouse_local(event.position)
		var axial := HexMath.pixel_to_axial(local, hex_size)
		if axial != _hover:
			_hover = axial
			if _reachable.has(axial):
				_path_preview = _build_path_to(axial)
			else:
				_path_preview.clear()
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = _mouse_local(event.position)
		var axial := HexMath.pixel_to_axial(local, hex_size)
		if not _cells.has(axial):
			return
		if not _explored.has(axial):
			hex_selected.emit(axial.x, axial.y, "", "Nieodkryty teren", "mgła")
			return
		_selected = axial
		var data: Dictionary = _cells[axial]
		var reg: Dictionary = _region_by_id.get(data["region_id"], {})
		hex_selected.emit(
			axial.x, axial.y,
			data["region_id"],
			str(reg.get("name", data["region_id"])),
			str(data["terrain"])
		)
		if _reachable.has(axial) and axial != hero_pos:
			try_move_to(axial)
		elif axial == hero_pos and _castles.has(axial):
			try_enter_city()
		else:
			queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			end_turn()
		elif event.keycode == KEY_E:
			try_enter_city()


# --- Zapis / wczytywanie ---
func _explored_string() -> String:
	var sb := PackedStringArray()
	for r in map_height:
		for q in map_width:
			sb.append("1" if _explored.has(Vector2i(q, r)) else "0")
	return "".join(sb)


func get_save_data() -> Dictionary:
	var armies: Array = []
	for pos in _armies.keys():
		var a: Dictionary = _armies[pos]
		armies.append({"q": pos.x, "r": pos.y, "id": str(a.get("id", "")),
			"name": str(a.get("name", "")), "faction": str(a.get("faction", "neutral")),
			"units": Array(a.get("units", [])).duplicate()})
	var terr := PackedStringArray()
	for r in map_height:
		for q in map_width:
			terr.append(str(_cells.get(Vector2i(q, r), {}).get("terrain", "morze")))
	return {
		"map_seed": map_seed,
		"map_w": map_width,
		"explored": _explored_string(),
		"ports": _ports.keys().map(func(p): return {"q": p.x, "r": p.y, "name": str(_ports[p]["name"])}),
		"terrain": ",".join(terr),
		"hero_pos": [hero_pos.x, hero_pos.y],
		"pre_battle_pos": [_pre_battle_pos.x, _pre_battle_pos.y],
		"movement_left": movement_left,
		"max_movement": max_movement,
		"owned_region_ids": owned_region_ids.duplicate(),
		"armies": armies,
		"rival_region_ids": rival_region_ids.duplicate(),
		"artifacts": _artifacts.keys().map(func(p): return {"q": p.x, "r": p.y, "id": str(_artifacts[p])}),
		"resources": _resources.keys().map(func(p): return {"q": p.x, "r": p.y,
			"type": str(_resources[p]["type"]), "owned": bool(_resources[p].get("owned", false))}),
	}


func apply_save_data(d: Dictionary) -> void:
	# Odtwórz ten sam teren: ziarno (0 = stary zapis -> stara mapa) + dokładny zapis pól.
	_generate_world(int(d.get("map_seed", 0)))
	if d.has("terrain"):
		var terr: PackedStringArray = str(d["terrain"]).split(",")
		if terr.size() == map_width * map_height:
			for r in map_height:
				for q in map_width:
					var c := Vector2i(q, r)
					if _cells.has(c):
						_cells[c]["terrain"] = terr[r * map_width + q]
	var hp: Array = d.get("hero_pos", [hero_pos.x, hero_pos.y])
	hero_pos = Vector2i(int(hp[0]), int(hp[1]))
	var pb: Array = d.get("pre_battle_pos", hp)
	_pre_battle_pos = Vector2i(int(pb[0]), int(pb[1]))
	max_movement = int(d.get("max_movement", max_movement))
	movement_left = int(d.get("movement_left", max_movement))
	owned_region_ids.clear()
	for rid in d.get("owned_region_ids", []):
		owned_region_ids.append(str(rid))
	rival_region_ids.clear()
	for rid in d.get("rival_region_ids", []):
		rival_region_ids.append(str(rid))
	_armies.clear()
	for a in d.get("armies", []):
		_armies[Vector2i(int(a["q"]), int(a["r"]))] = {
			"id": str(a.get("id", "")), "name": str(a.get("name", "")),
			"faction": str(a.get("faction", "neutral"))}
		if a.has("units"):
			_armies[Vector2i(int(a["q"]), int(a["r"]))]["units"] = Array(a["units"]).map(func(x): return str(x))
	if d.has("artifacts"):
		_artifacts.clear()
		for t in d["artifacts"]:
			_artifacts[Vector2i(int(t["q"]), int(t["r"]))] = str(t.get("id", ""))
	else:
		_spawn_artifacts()
	if d.has("resources"):
		_resources.clear()
		for t in d["resources"]:
			_resources[Vector2i(int(t["q"]), int(t["r"]))] = {"type": str(t.get("type", "")), "owned": bool(t.get("owned", false))}
	else:
		_spawn_resources()
	_ports.clear()
	if d.has("ports"):
		for t in d["ports"]:
			_ports[Vector2i(int(t["q"]), int(t["r"]))] = {"name": str(t.get("name", "Port")), "body": 0}
	else:
		_spawn_ports()
	_ensure_corridors()
	_build_port_links()
	_explored.clear()
	var ex := str(d.get("explored", ""))
	if ex.length() == map_width * map_height:
		for r in map_height:
			for q in map_width:
				if ex[r * map_width + q] == "1":
					_explored[Vector2i(q, r)] = true
	_pending_army_id = ""
	_path_preview.clear()
	_selected = Vector2i(9999, 9999)
	_recompute_reach()
	queue_redraw()
	_emit_castle_presence()


# --- Detale mapy (tylko grafika, cache liczony raz) ---
var _border_segs: PackedVector2Array = PackedVector2Array() # pary punktów
var _coast_segs: PackedVector2Array = PackedVector2Array()
var _roads: Array = [] # Array[PackedVector2Array]


func _is_water_cell(c: Vector2i) -> bool:
	if not _cells.has(c):
		return true
	return str(_cells[c]["region_id"]) == "morze" or str(_cells[c]["terrain"]) == "morze"


func _build_map_details() -> void:
	_border_segs = PackedVector2Array()
	_coast_segs = PackedVector2Array()
	_roads.clear()
	_road_cells.clear()
	for key in _cells.keys():
		var cell: Vector2i = key
		var rid := str(_cells[cell]["region_id"])
		var water := _is_water_cell(cell)
		if water:
			continue
		var c := HexMath.axial_to_pixel(cell.x, cell.y, hex_size)
		var corners := HexMath.hex_corners(c, hex_size * 0.97)
		for d in HexMath.AXIAL_DIRS:
			var n: Vector2i = cell + d
			var nc := HexMath.axial_to_pixel(n.x, n.y, hex_size)
			var ang := rad_to_deg((nc - c).angle())
			var j := posmod(roundi(ang / 60.0), 6)
			var a := corners[j]
			var b := corners[(j + 1) % 6]
			if _is_water_cell(n):
				_coast_segs.append(a)
				_coast_segs.append(b)
			elif str(_cells[n]["region_id"]) != rid and (n.x > cell.x or (n.x == cell.x and n.y > cell.y)):
				_border_segs.append(a)
				_border_segs.append(b)
	# drogi: każda stolica do 2 najbliższych
	var caps: Array = _castles.keys()
	var done: Dictionary = {}
	for a_v in caps:
		var a: Vector2i = a_v
		var sorted := caps.duplicate()
		sorted.erase(a)
		sorted.sort_custom(func(x, y): return HexMath.distance(a, x) < HexMath.distance(a, y))
		for k in mini(3, sorted.size()):
			var b: Vector2i = sorted[k]
			var dist := HexMath.distance(a, b)
			if dist > 20:
				continue
			var pair_key := "%d,%d-%d,%d" % ([a.x, a.y, b.x, b.y] if a < b else [b.x, b.y, a.x, a.y])
			if done.has(pair_key):
				continue
			done[pair_key] = true
			var pts := PackedVector2Array()
			var ok := true
			var rc: Array[Vector2i] = []
			for i in dist + 1:
				var t := float(i) / float(dist)
				var hc := HexMath.axial_round(lerpf(a.x, b.x, t) + 1e-4, lerpf(a.y, b.y, t) + 1e-4)
				if _is_water_cell(hc):
					ok = false
					break
				rc.append(hc)
				var p := HexMath.axial_to_pixel(hc.x, hc.y, hex_size)
				var jit := float(_cell_hash(hc) % 7 - 3) * hex_size * 0.05
				if i > 0 and i < dist:
					p += Vector2(jit, -jit * 0.5)
				pts.append(p)
			if ok and pts.size() >= 2:
				_roads.append(pts)
				for c in rc:
					_road_cells[c] = true


func _draw_map_details() -> void:
	# wybrzeże: piana + ciemna linia
	if _coast_segs.size() > 0:
		draw_multiline(_coast_segs, Color(0.85, 0.92, 1.0, 0.55), 4.0)
		draw_multiline(_coast_segs, Color(0.25, 0.2, 0.12, 0.85), 1.6)
	# granice regionów: cień + jasny kontur
	if _border_segs.size() > 0:
		draw_multiline(_border_segs, Color(0, 0, 0, 0.35), 4.5)
		draw_multiline(_border_segs, Color(0.95, 0.9, 0.7, 0.75), 1.6)
	# drogi
	for pts_v in _roads:
		var pts: PackedVector2Array = pts_v
		draw_polyline(pts, Color(0.22, 0.15, 0.08, 0.75), hex_size * 0.32, true)
		draw_polyline(pts, Color(0.66, 0.54, 0.36, 0.95), hex_size * 0.22, true)
		draw_polyline(pts, Color(0.80, 0.70, 0.50, 0.6), hex_size * 0.08, true)


func _draw_capital_labels() -> void:
	var font: Font = ThemeDB.fallback_font
	var fs := int(clampf(hex_size * 0.42, 9.0, 16.0))
	for pos in _castles.keys():
		var cp: Vector2i = pos
		var reg: Dictionary = _castles[cp]
		var cap_name := str(reg.get("capital", reg.get("name", "")))
		if cap_name == "":
			continue
		var c := HexMath.axial_to_pixel(cp.x, cp.y, hex_size) + Vector2(0, hex_size * 1.05)
		var w := font.get_string_size(cap_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tl := c + Vector2(-w * 0.5, 0)
		draw_rect(Rect2(tl + Vector2(-3, -fs + 1), Vector2(w + 6, fs + 4)), Color(0.1, 0.07, 0.04, 0.6))
		draw_string_outline(font, tl, cap_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.8))
		draw_string(font, tl, cap_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.93, 0.7))


## Neutralne bestie (wilki, niedźwiedzie) w dziczy, z dala od zamków.
func _spawn_beasts() -> void:
	var placed := 0
	var tries := 0
	while placed < 12 and tries < 3000:
		tries += 1
		var c := Vector2i(_rng.randi_range(0, map_width - 1), _rng.randi_range(0, map_height - 1))
		if not _cells.has(c) or is_blocked(c) or _armies.has(c) or _resources.has(c) or _castles.has(c) or _road_cells.has(c) or _ports.has(c) or _bridges.has(c) or c == hero_pos:
			continue
		var near := false
		for cp in _castles.keys():
			if HexMath.distance(c, cp) < 4:
				near = true
				break
		if near:
			continue
		var kind := "wilk" if placed % 2 == 0 else "niedzwiedz"
		placed += 1
		_armies[c] = {"id": "bestia_%d" % placed, "name": "Wataha wilków" if kind == "wilk" else "Niedźwiedzie", "faction": "beast_" + kind}



var _fog_fx: Node2D = null
func _ensure_fog_fx() -> void:
	if _fog_fx == null:
		_fog_fx = preload("res://scripts/fog_fx.gd").new()
		_fog_fx.map = self
		add_child(_fog_fx)
	_fog_fx.queue_redraw()


func _draw_fog(vr: Rect2) -> void:
	_ensure_fog_fx()
	var dark := Color(0.04, 0.04, 0.06, 1.0)
	for key in _cells.keys():
		var cell: Vector2i = key
		if _explored.has(cell):
			continue
		var c := HexMath.axial_to_pixel(cell.x, cell.y, hex_size)
		if not vr.has_point(c):
			continue
		var edge := false
		for nb in HexMath.neighbors(cell):
			if _explored.has(nb):
				edge = true
				break
		if edge:
			draw_colored_polygon(HexMath.hex_corners(c, hex_size * 1.02), Color(0.04, 0.04, 0.06, 0.82))
			draw_colored_polygon(HexMath.hex_corners(c, hex_size * 0.7), dark)
		else:
			draw_colored_polygon(HexMath.hex_corners(c, hex_size * 1.04), dark)


func _draw_bridge(c: Vector2) -> void:
	var s := hex_size
	var wood := Color(0.45, 0.3, 0.15)
	draw_line(c + Vector2(-s * 0.7, -s * 0.12), c + Vector2(s * 0.7, -s * 0.12), Color(0.15, 0.1, 0.05), 3.0)
	draw_line(c + Vector2(-s * 0.7, s * 0.12), c + Vector2(s * 0.7, s * 0.12), Color(0.15, 0.1, 0.05), 3.0)
	for i in 8:
		var x := -s * 0.65 + i * s * 0.185
		draw_line(c + Vector2(x, -s * 0.12), c + Vector2(x, s * 0.12), wood.lightened(float(i % 2) * 0.12), s * 0.13)


func _draw_port(c: Vector2) -> void:
	var t := _deco("port")
	if t != null:
		draw_circle(c + Vector2(0, hex_size * 0.3), hex_size * 0.55, Color(0, 0, 0, 0.2))
		var d := hex_size * 1.6
		draw_texture_rect(t, Rect2(c - Vector2(d * 0.5, d * 0.62), Vector2(d, d)), false)
	else:
		draw_circle(c, hex_size * 0.4, Color(0.4, 0.25, 0.1))
	draw_circle(c + Vector2(-hex_size * 0.55, -hex_size * 0.55), hex_size * 0.17, Color(0.1, 0.25, 0.5))
	draw_string(ThemeDB.fallback_font, c + Vector2(-hex_size * 0.66, -hex_size * 0.48), "⚓", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1))


## Portret aktywnego bohatera (plakietka nad figurką) — żeby bohaterowie się nie mylili.
var active_portrait: String = ""
func _draw_portrait_badge(c: Vector2, r: float) -> void:
	if active_portrait == "":
		return
	var t := _hero_tex(active_portrait)
	if t == null:
		return
	draw_circle(c, r + 2.5, Color(1.0, 0.85, 0.3))
	draw_texture_rect(t, Rect2(c - Vector2(r, r), Vector2(r * 2, r * 2)), false)
	draw_arc(c, r + 1.0, 0.0, TAU, 32, Color(0.2, 0.1, 0.0), 1.5)
