extends Node3D
## Walka na hexach w 3D (low-poly). Logika tur zostaje, rysowanie jest sceną Node3D.

signal battle_over(player_won: bool)
signal status(text: String)
signal spell_cast(spell_id: String, cost: int)

var mana: int = 0
var spell_power: int = 0
var _pending_spell: String = ""
var _pending_cost: int = 0
var _cast_this_turn: bool = false
const SPELL_TARGET_ENEMY := {"blyskawica": true}

@export var hex_size: float = 1.08
const GROUND_Y := 0.12
const Fig := preload("res://scripts/mesh_figures.gd")
const Surf := preload("res://scripts/surface_tex.gd")
@export var map_w: int = 11
@export var map_h: int = 8

var _hover: Vector2i = Vector2i(9999, 9999)
var _selected: int = -1 # index in _units
var _reachable: Dictionary = {}
var _units: Array[Dictionary] = []
var _player_turn: bool = true
var _busy: bool = false
var _obstacles: Dictionary = {} # Vector2i -> "hill"/"rock"/"wall"
var _trees: Array = [] # [Vector2, scale]
var _is_siege: bool = false
## Oblężenie: struktury (brama, wieże) — Vector2i -> {kind, hp, max_hp}
var _structs: Dictionary = {}
const TOWER_DMG := 5
const TOWER_RANGE := 5
## Efekty: pociski, szarże, błyski trafień, liczby obrażeń
var _fx_proj: Array = [] # [from, to, t, kind]
var _fx_lunge: Dictionary = {} # idx -> Vector2 offset
var _fx_flash: Dictionary = {} # idx -> float
var _fx_text: Array = [] # [pos, text, t]
## Płynny ruch jednostek
const STEP_TIME := 0.12
var _came: Dictionary = {} # Vector2i -> Vector2i (ścieżka BFS)
var _anim_px: Dictionary = {} # idx -> Vector2 (pozycja rysowania w trakcie animacji)
var animating: bool = false
var _view: Node3D
var _cam: Camera3D
var _props: Node3D
var _fx_root: Node3D
var _tile_nodes: Array = []
var _unit_nodes: Array = []
var _prop_nodes: Dictionary = {}
var _prop_keys: Dictionary = {}
var _proj_pool: Array = []
var _txt_pool: Array = []
var _mat_move: StandardMaterial3D
var _mat_atk: StandardMaterial3D
var _mat_hover: StandardMaterial3D
var _mat_dim: StandardMaterial3D
var _mat_flash: StandardMaterial3D
var _mounted := false
## Pusta bitwa nie może co klatkę brudzić materiałów — na Metalu drugi frame się zawiesza.
var _visual_dirty := false
var _ai_steps := 0


func start_battle(player_units: Array = [], is_siege: bool = false, enemy_units: Array = []) -> void:
	_units.clear()
	_selected = -1
	_player_turn = true
	_busy = false
	_pending_spell = ""
	_cast_this_turn = false
	_is_siege = is_siege
	_build_terrain()
	if player_units.is_empty():
		_units.append(_mk("Piechota", "piechota", true, Vector2i(1, 3), 40, 8, 3, Color(0.2, 0.45, 0.9)))
		_units.append(_mk("Łucznicy", "lucznicy", true, Vector2i(1, 5), 25, 10, 3, Color(0.3, 0.7, 1.0)))
		_units[-1]["range"] = 3
	else:
		for u in player_units:
			var d: Dictionary = u
			_units.append(_mk(
				str(d.get("name", "Jednostka")),
				str(d.get("unit_id", "")),
				true,
				d.get("pos", Vector2i(1, 3)),
				int(d.get("hp", 30)),
				int(d.get("dmg", 8)),
				int(d.get("speed", 3)),
				d.get("color", Color(0.2, 0.45, 0.9))
			))
			_units[-1]["range"] = int(d.get("range", 1))
	# Wróg — prawa (garnizon zamku mocniejszy przy oblężeniu)
	if not enemy_units.is_empty():
		for u in enemy_units:
			var e: Dictionary = u
			_units.append(_mk(str(e.get("name", "Wróg")), str(e.get("unit_id", "")), false, e.get("pos", Vector2i(9, 3)),
				int(e.get("hp", 30)), int(e.get("dmg", 8)), int(e.get("speed", 3)), e.get("color", Color(0.75, 0.2, 0.15))))
			_units[-1]["range"] = int(e.get("range", 1))
		_add_siege_structures()
		status.emit("Twoja tura — wybierz jednostkę")
		_mount_3d()
		return
	_add_siege_structures()
	var hp_bonus := 10 if is_siege else 0
	var dmg_bonus := 2 if is_siege else 0
	_units.append(_mk("Garnizon" if is_siege else "Piechota wroga", "enemy_p", false, Vector2i(9, 3), 35 + hp_bonus, 7 + dmg_bonus, 3, Color(0.75, 0.2, 0.15)))
	_units.append(_mk("Łucznicy murów" if is_siege else "Łucznicy wroga", "enemy_l", false, Vector2i(9, 5), 22 + hp_bonus, 9 + dmg_bonus, 3, Color(0.9, 0.35, 0.25)))
	if is_siege or player_units.size() >= 3:
		_units.append(_mk("Straż zamkowa" if is_siege else "Jazda wroga", "enemy_j", false, Vector2i(8, 4), 32 + hp_bonus, 11 + dmg_bonus, 5, Color(0.6, 0.1, 0.1)))
	status.emit("Twoja tura — wybierz jednostkę")
	_mount_3d()


## Zwraca "" gdy OK, inaczej powód odmowy.
func begin_spell(spell_id: String, cost: int) -> String:
	if _busy or animating or not _player_turn:
		return "Czary tylko w twojej turze."
	if _cast_this_turn:
		return "Już rzucono czar w tej turze."
	if mana < cost:
		return "Za mało many (%d/%d)." % [mana, cost]
	_pending_spell = spell_id
	_pending_cost = cost
	_selected = -1
	_reachable.clear()
	queue_redraw()
	if SPELL_TARGET_ENEMY.has(spell_id):
		status.emit("Czar: kliknij WROGĄ jednostkę (PPM/Esc = anuluj)")
	else:
		status.emit("Czar: kliknij SWOJĄ jednostkę (PPM/Esc = anuluj)")
	return ""


func is_player_turn() -> bool:
	return _player_turn and not _busy and not animating


func _apply_spell(hit: int) -> void:
	var u: Dictionary = _units[hit]
	var wants_enemy: bool = SPELL_TARGET_ENEMY.has(_pending_spell)
	if hit < 0 or bool(u["player"]) == wants_enemy:
		status.emit("Zły cel czaru")
		return
	match _pending_spell:
		"blyskawica":
			u["hp"] = maxi(0, int(u["hp"]) - (15 + spell_power))
			status.emit("Błyskawica trafia %s (−%d%s)" % [str(u["name"]), 15 + spell_power, ", ginie" if int(u["hp"]) <= 0 else ", zostało %d" % int(u["hp"])])
		"leczenie":
			var before := int(u["hp"])
			u["hp"] = mini(int(u["max_hp"]), int(u["hp"]) + 20 + spell_power)
			status.emit("Leczenie: %s +%d HP (%d)" % [str(u["name"]), int(u["hp"]) - before, int(u["hp"])])
		"przyspieszenie":
			u["speed"] = int(u["speed"]) + 2
			status.emit("Przyspieszenie: %s szybkość %d" % [str(u["name"]), int(u["speed"])])
	mana -= _pending_cost
	_cast_this_turn = true
	spell_cast.emit(_pending_spell, _pending_cost)
	_pending_spell = ""
	queue_redraw()
	_check_end()


func get_survivor_unit_ids() -> Array:
	var out: Array = []
	for u in _units:
		if bool(u["player"]) and int(u["hp"]) > 0:
			var uid := str(u.get("unit_id", ""))
			if uid != "":
				out.append(uid)
	return out


func get_enemy_survivor_unit_ids() -> Array:
	var out: Array = []
	for u in _units:
		if not bool(u["player"]) and int(u["hp"]) > 0:
			var uid := str(u.get("unit_id", ""))
			if uid != "":
				out.append(uid)
	return out


func _mk(name: String, unit_id: String, player: bool, pos: Vector2i, hp: int, dmg: int, speed: int, color: Color) -> Dictionary:
	return {
		"name": name,
		"unit_id": unit_id,
		"player": player,
		"pos": pos,
		"hp": hp,
		"max_hp": hp,
		"dmg": dmg,
		"speed": speed,
		"color": color,
		"acted": false,
	}


func _build_terrain() -> void:
	_obstacles.clear()
	_trees.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Pagórki/skały tylko w środkowych kolumnach (3..6) — nigdy na pozycjach startowych.
	var candidates: Array[Vector2i] = []
	for q in range(3, 7):
		for r in map_h:
			candidates.append(Vector2i(q, r))
	candidates.shuffle()
	var n := rng.randi_range(4, 6)
	for i in n:
		_obstacles[candidates[i]] = "hill" if rng.randf() < 0.6 else "rock"
	if _is_siege:
		# Pełna linia murów po stronie wroga (kolumna 7) — bez wyłomów; brama dodawana w _add_siege_structures.
		for r in map_h:
			_obstacles[Vector2i(7, r)] = "wall"
		for q in range(8, map_w):
			for r in map_h:
				if _obstacles.get(Vector2i(q, r), "") in ["hill", "rock"]:
					_obstacles.erase(Vector2i(q, r))
	# Dekoracyjne drzewa na krawędziach pola (bez wpływu na grę)
	var tl := HexMath.axial_to_pixel(0, 0, hex_size)
	var br := HexMath.axial_to_pixel(map_w - 1, map_h - 1, hex_size)
	for i in 14:
		var top := rng.randf() < 0.5
		var pos := Vector2(rng.randf_range(tl.x - hex_size * 3, br.x + hex_size * 3), tl.y - hex_size * rng.randf_range(1.6, 2.6)) if top else Vector2(rng.randf_range(tl.x - hex_size * 3, br.x + hex_size * 3), br.y + hex_size * rng.randf_range(1.6, 2.6))
		_trees.append([pos, rng.randf_range(0.7, 1.2)])


func _add_siege_structures() -> void:
	_structs.clear()
	if not _is_siege:
		return
	# Każdy odcinek muru ma HP — atakujący mogą go przebić.
	for r in map_h:
		var wc := Vector2i(7, r)
		if str(_obstacles.get(wc, "")) == "wall":
			_structs[wc] = {"kind": "wall", "hp": 30, "max_hp": 30}
	var gate := Vector2i(7, 4)
	_obstacles[gate] = "gate"
	_structs[gate] = {"kind": "gate", "hp": 40, "max_hp": 40}
	for t in [Vector2i(7, 0), Vector2i(7, map_h - 1)]:
		_obstacles[t] = "tower"
		_structs[t] = {"kind": "tower", "hp": 30, "max_hp": 30}
	# jednostki wroga nie mogą stać na murach
	for u in _units:
		if not bool(u["player"]) and _obstacles.has(u["pos"]):
			for q in range(8, map_w):
				var c := Vector2i(q, int(u["pos"].y))
				if _cell_free(c):
					u["pos"] = c
					break


func _attack_struct(attacker_i: int, cell: Vector2i) -> void:
	var st: Dictionary = _structs[cell]
	var a: Dictionary = _units[attacker_i]
	var dmg := int(a["dmg"])
	_play_attack_fx(attacker_i, HexMath.axial_to_pixel(cell.x, cell.y, hex_size), -1)
	st["hp"] = maxi(0, int(st["hp"]) - dmg)
	var nm: String = {"gate": "Brama", "tower": "Wieża", "wall": "Mur"}.get(str(st["kind"]), "Mur")
	if int(st["hp"]) <= 0:
		_structs.erase(cell)
		_obstacles.erase(cell)
		status.emit("%s %s przez %s — przejście otwarte!" % [nm, "zburzony" if str(st["kind"]) == "wall" else "zburzona", str(a["name"])])
	else:
		status.emit("%s: −%d (zostało %d)" % [nm, dmg, int(st["hp"])])
	queue_redraw()


func _towers_fire() -> void:
	for cell in _structs.keys():
		var st: Dictionary = _structs[cell]
		if st["kind"] != "tower":
			continue
		var best := -1
		var bd := 999
		for i in _units.size():
			var u: Dictionary = _units[i]
			if bool(u["player"]) and int(u["hp"]) > 0:
				var d := HexMath.distance(cell, u["pos"])
				if d < bd:
					bd = d
					best = i
		if best >= 0 and bd <= TOWER_RANGE:
			var tp: Vector2 = HexMath.axial_to_pixel(cell.x, cell.y, hex_size) + Vector2(0, -hex_size * 0.6)
			_spawn_projectile(tp, _unit_px(best), "arrow")
			_units[best]["hp"] = maxi(0, int(_units[best]["hp"]) - TOWER_DMG)
			_hit_fx(best, TOWER_DMG)
			status.emit("Wieża strzela w %s (−%d)" % [str(_units[best]["name"]), TOWER_DMG])
			await get_tree().create_timer(0.35).timeout
			if not _mounted:
				return


## ---------- Animacje ataku ----------
func _unit_px(i: int) -> Vector2:
	var p: Vector2i = _units[i]["pos"]
	return _anim_px.get(i, HexMath.axial_to_pixel(p.x, p.y, hex_size))


func _spawn_projectile(from: Vector2, to: Vector2, kind: String) -> void:
	var pr := [from, to, 0.0, kind]
	_fx_proj.append(pr)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		pr[2] = v
		queue_redraw(), 0.0, 1.0, 0.28)
	tw.tween_callback(func() -> void:
		_fx_proj.erase(pr)
		queue_redraw())


func _hit_fx(i: int, dmg: int) -> void:
	_fx_flash[i] = 1.0
	var tx := [_unit_px(i) + Vector2(0, -hex_size * 0.6), "-%d" % dmg, 0.0]
	_fx_text.append(tx)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_fx_flash[i] = 1.0 - v
		tx[2] = v
		queue_redraw(), 0.0, 1.0, 0.6)
	tw.tween_callback(func() -> void:
		_fx_flash.erase(i)
		_fx_text.erase(tx)
		queue_redraw())


func _play_attack_fx(ai: int, target_px: Vector2, di: int) -> void:
	var from := _unit_px(ai)
	var ranged := int(_units[ai].get("range", 1)) > 1 and from.distance_to(target_px) > hex_size * 2.2
	_attack_sound(str(_units[ai].get("unit_id", "")), ranged)
	if ranged:
		var uid := str(_units[ai].get("unit_id", ""))
		var kind := "ball" if uid in ["arkebuzerzy", "dragonia", "janczarzy", "rajtarzy", "strzelcy", "muszkieterowie", "kozacy"] else "arrow"
		_spawn_projectile(from + Vector2(0, -hex_size * 0.3), target_px, kind)
	else:
		var dir := (target_px - from).normalized()
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void:
			_fx_lunge[ai] = dir * hex_size * 0.55 * sin(v * PI)
			queue_redraw(), 0.0, 1.0, 0.3)
		tw.tween_callback(func() -> void:
			_fx_lunge.erase(ai)
			queue_redraw())
	if di >= 0:
		_hit_fx(di, int(_units[ai]["dmg"]))


func is_blocked(cell: Vector2i) -> bool:
	return _obstacles.has(cell)


func _cell_free(cell: Vector2i, ignore_idx: int = -1) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_w or cell.y >= map_h:
		return false
	if _obstacles.has(cell):
		# Brama: przechodzą tylko obrońcy (wróg w oblężeniu); atakujący muszą ją rozbić.
		var defender := ignore_idx >= 0 and ignore_idx < _units.size() and not bool(_units[ignore_idx]["player"])
		if not (str(_obstacles[cell]) == "gate" and _structs.has(cell) and defender):
			return false
	for i in _units.size():
		if i == ignore_idx:
			continue
		if int(_units[i]["hp"]) <= 0:
			continue
		if _units[i]["pos"] == cell:
			return false
	return true


func _unit_at(cell: Vector2i) -> int:
	for i in _units.size():
		if int(_units[i]["hp"]) <= 0:
			continue
		if _units[i]["pos"] == cell:
			return i
	return -1


func _recompute_reach(idx: int) -> void:
	_reachable.clear()
	_came.clear()
	if idx < 0 or idx >= _units.size():
		return
	var u: Dictionary = _units[idx]
	var speed: int = int(u["speed"])
	var start: Vector2i = u["pos"]
	_reachable[start] = 0
	var frontier: Array[Vector2i] = [start]
	var guard := 0
	while not frontier.is_empty() and guard < 512:
		guard += 1
		var cur: Vector2i = frontier.pop_front()
		var cost: int = int(_reachable[cur])
		if cost >= speed:
			continue
		for nxt in HexMath.neighbors(cur):
			if not _cell_free(nxt, idx) and nxt != start:
				continue
			if nxt.x < 0 or nxt.y < 0 or nxt.x >= map_w or nxt.y >= map_h:
				continue
			var nc := cost + 1
			if nc > speed:
				continue
			if _reachable.has(nxt) and int(_reachable[nxt]) <= nc:
				continue
			_reachable[nxt] = nc
			_came[nxt] = cur
			frontier.append(nxt)


func _path_px(idx: int, goal: Vector2i) -> PackedVector2Array:
	var start: Vector2i = _units[idx]["pos"]
	var cells: Array[Vector2i] = []
	var cur := goal
	var guard := 0
	while cur != start and _came.has(cur) and guard < 64:
		cells.push_front(cur)
		cur = _came[cur]
		guard += 1
	if cur != start:
		cells = [goal]
	var pts := PackedVector2Array([HexMath.axial_to_pixel(start.x, start.y, hex_size)])
	for c in cells:
		pts.append(HexMath.axial_to_pixel(c.x, c.y, hex_size))
	return pts


func _animate_unit(idx: int, goal: Vector2i) -> void:
	var pts := _path_px(idx, goal)
	animating = true
	_anim_px[idx] = pts[0]
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_anim_px[idx] = _pp(pts, v)
		queue_redraw(), 0.0, 1.0, STEP_TIME * float(pts.size() - 1))
	await tw.finished
	if not _mounted:
		return
	_anim_px.erase(idx)
	_units[idx]["pos"] = goal
	animating = false
	queue_redraw()


static func _pp(pts: PackedVector2Array, t: float) -> Vector2:
	if pts.size() == 1 or t <= 0.0:
		return pts[0]
	if t >= 1.0:
		return pts[pts.size() - 1]
	var f := t * float(pts.size() - 1)
	var i := int(floor(f))
	return pts[i].lerp(pts[i + 1], f - float(i))


func _alive_side(player: bool) -> bool:
	for u in _units:
		if bool(u["player"]) == player and int(u["hp"]) > 0:
			return true
	return false


func _check_end() -> bool:
	if not _alive_side(true):
		_busy = true
		status.emit("Porażka!")
		battle_over.emit(false)
		return true
	if not _alive_side(false):
		_busy = true
		status.emit("Zwycięstwo!")
		battle_over.emit(true)
		return true
	return false


func _all_player_acted() -> bool:
	for u in _units:
		if bool(u["player"]) and int(u["hp"]) > 0 and not bool(u["acted"]):
			return false
	return true


func _reset_acted(player: bool) -> void:
	for u in _units:
		if bool(u["player"]) == player:
			u["acted"] = false


func _finish_player_unit(idx: int) -> void:
	_units[idx]["acted"] = true
	_selected = -1
	_reachable.clear()
	queue_redraw()
	if _check_end():
		return
	if _all_player_acted():
		_start_enemy_turn()
	else:
		status.emit("Wybierz kolejną jednostkę")


func _start_enemy_turn() -> void:
	_player_turn = false
	_ai_steps = 0
	_reset_acted(false)
	status.emit("Tura wroga…")
	if not _structs.is_empty():
		_busy = true
		await _towers_fire()
		_busy = false
		if not _mounted or _check_end():
			return
	_enemy_ai_step()


func _end_enemy_turn() -> void:
	_player_turn = true
	_cast_this_turn = false
	_reset_acted(true)
	_selected = -1
	status.emit("Twoja tura — wybierz jednostkę")
	queue_redraw()


func _enemy_ai_step() -> void:
	if not _mounted or not is_visible_in_tree():
		return
	if _check_end():
		return
	_ai_steps += 1
	if _ai_steps > 24:
		_end_enemy_turn()
		return
	var idx := -1
	for i in _units.size():
		var u: Dictionary = _units[i]
		if not bool(u["player"]) and int(u["hp"]) > 0 and not bool(u["acted"]):
			idx = i
			break
	if idx < 0:
		_end_enemy_turn()
		return
	var enemy: Dictionary = _units[idx]
	# Znajdź najbliższego gracza
	var target_i := -1
	var best_d := 999
	for i in _units.size():
		var u: Dictionary = _units[i]
		if bool(u["player"]) and int(u["hp"]) > 0:
			var d: int = HexMath.distance(enemy["pos"], u["pos"])
			if d < best_d:
				best_d = d
				target_i = i
	if target_i < 0:
		_units[idx]["acted"] = true
		# deferred, nie rekurencja — synchroniczna pętla po oddziałach zatyka klatkę
		call_deferred("_enemy_ai_step")
		return
	var target: Dictionary = _units[target_i]
	if best_d <= int(enemy.get("range", 1)):
		_resolve_attack(idx, target_i)
		_units[idx]["acted"] = true
		queue_redraw()
		if _check_end():
			return
		await get_tree().create_timer(0.25).timeout
		if not _mounted:
			return
		_enemy_ai_step()
		return
	# Ruch w stronę celu
	_recompute_reach(idx)
	var best_cell: Vector2i = enemy["pos"]
	var best_score := best_d
	for cell in _reachable.keys():
		var c: Vector2i = cell
		if c == enemy["pos"]:
			continue
		var score: int = HexMath.distance(c, target["pos"])
		if score < best_score:
			best_score = score
			best_cell = c
	if best_cell != enemy["pos"]:
		await _animate_unit(idx, best_cell)
	if not _mounted:
		return
	if HexMath.distance(best_cell, target["pos"]) <= int(enemy.get("range", 1)):
		_resolve_attack(idx, target_i)
	_units[idx]["acted"] = true
	queue_redraw()
	if _check_end():
		return
	await get_tree().create_timer(0.15).timeout
	if not _mounted:
		return
	_enemy_ai_step()


func _resolve_attack(attacker_i: int, defender_i: int) -> void:
	var a: Dictionary = _units[attacker_i]
	var d: Dictionary = _units[defender_i]
	var dmg: int = int(a["dmg"])
	_play_attack_fx(attacker_i, _unit_px(defender_i), defender_i)
	d["hp"] = maxi(0, int(d["hp"]) - dmg)
	var who := str(a["name"])
	var whom := str(d["name"])
	if int(d["hp"]) <= 0:
		_sfx("sfx_shout")
		status.emit("%s zabija %s (−%d)" % [who, whom, dmg])
	else:
		status.emit("%s atakuje %s (−%d HP, zostało %d)" % [who, whom, dmg, int(d["hp"])])


func queue_redraw() -> void:
	_visual_dirty = true


func _process(_dt: float) -> void:
	if not _mounted or not is_visible_in_tree():
		return
	var live_fx := animating or not _fx_proj.is_empty() or not _fx_lunge.is_empty() or not _fx_flash.is_empty()
	if not _visual_dirty and not live_fx:
		return
	_sync_visuals()
	if not live_fx:
		_visual_dirty = false


func deactivate() -> void:
	_mounted = false
	_visual_dirty = false
	visible = false
	# Kamera należy do mapy — nie wyłączać jej stąd i nie zwalniać.
	_cam = null
	_drop_view()


func _cell_pos(cell: Vector2i) -> Vector3:
	var p := HexMath.axial_to_pixel(cell.x, cell.y, hex_size)
	return Vector3(p.x, GROUND_Y, p.y)


func _trans(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _world() -> Node:
	var p := get_parent()
	return p.get_node_or_null("World3D") if p else null


func _drop_view() -> void:
	_tile_nodes.clear()
	_unit_nodes.clear()
	_prop_nodes.clear()
	_prop_keys.clear()
	_proj_pool.clear()
	_txt_pool.clear()
	_fx_proj.clear()
	_fx_lunge.clear()
	_fx_flash.clear()
	_fx_text.clear()
	if _view and is_instance_valid(_view):
		var old := _view
		_view = null
		old.free()


func _ensure_mats() -> void:
	if _mat_move != null:
		return
	_mat_move = _trans(Color(0.3, 0.55, 1.0, 0.4))
	_mat_atk = _trans(Color(1.0, 0.25, 0.15, 0.48))
	_mat_hover = _trans(Color(1, 1, 1, 0.22))
	_mat_dim = _trans(Color(0, 0, 0, 0.45))
	_mat_flash = _trans(Color(1, 0.2, 0.1, 0.6))


## Jedno światło mapy ma wyłączone cienie. Te siatki i tak nie wchodzą w shadow pass.
func _no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for ch in n.get_children():
		_no_shadows(ch)


func _mount_3d() -> void:
	visible = true
	_ensure_mats()
	_drop_view()
	_view = Node3D.new()
	_view.name = "View"
	add_child(_view)
	var mid := HexMath.axial_to_pixel(int(map_w / 2), int(map_h / 2), hex_size)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(hex_size * float(map_w) * 3.2, hex_size * float(map_h) * 3.4)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.92, 0.96, 0.88)
	gm.albedo_texture = Surf.tex("grass")
	gm.uv1_scale = Vector3(8.0, 8.0, 8.0)
	gm.roughness = 0.95
	pm.material = gm
	ground.mesh = pm
	ground.position = Vector3(mid.x, -0.01, mid.y)
	_view.add_child(ground)
	for r in map_h:
		for q in map_w:
			var cell := Vector2i(q, r)
			var tile := Node3D.new()
			var center := HexMath.axial_to_pixel(q, r, hex_size)
			tile.position = Vector3(center.x, 0, center.y)
			tile.set_meta("cell", cell)
			var hsh := absi(hash(cell)) % 100
			var surf := Surf.pick("grass", hsh)
			if hsh % 7 == 0:
				surf = Surf.pick("dirt", hsh)
			if _is_siege and q >= 8:
				surf = Surf.pick("sand", hsh)
			elif _is_siege and q == 7:
				surf = Surf.pick("stone", hsh)
			Fig.disk(tile, hex_size * 0.98, 0.14, Vector3(0, 0.07, 0), surf)
			var hi := MeshInstance3D.new()
			hi.name = "Hi"
			var hm := CylinderMesh.new()
			hm.top_radius = hex_size * 0.9
			hm.bottom_radius = hex_size * 0.9
			hm.height = 0.04
			hm.radial_segments = 6
			hm.material = _mat_hover
			hi.mesh = hm
			hi.position.y = 0.16
			hi.visible = false
			tile.add_child(hi)
			_view.add_child(tile)
			_tile_nodes.append(tile)
	for t in _trees:
		var tp: Vector2 = t[0]
		var sc := float(t[1])
		var tree := Fig.battle_prop("tree", false)
		tree.position = Vector3(tp.x, GROUND_Y, tp.y)
		tree.scale = Vector3(sc, sc, sc)
		_view.add_child(tree)
	_props = Node3D.new()
	_props.name = "Props"
	_view.add_child(_props)
	_fx_root = Node3D.new()
	_fx_root.name = "Fx"
	_view.add_child(_fx_root)
	_build_unit_nodes()
	var target := Vector3(mid.x, 0.3, mid.y)
	var eye := target + Vector3(0.2, hex_size * 8.2, hex_size * 7.4)
	var world := _world()
	if world and world.has_method("aim_for_battle"):
		# Ta sama kamera co mapa. Własna Camera3D + Environment robiły drugi pass.
		_cam = world.aim_for_battle(eye, target)
	elif _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 42.0
		_cam.far = 120.0
		add_child(_cam)
		_cam.position = eye
		_cam.look_at(target, Vector3.UP)
		_cam.current = true
	_mounted = true
	_visual_dirty = true
	_sync_visuals()
	_no_shadows(_view)
	_visual_dirty = false


func _build_unit_nodes() -> void:
	for i in _units.size():
		var u: Dictionary = _units[i]
		var n := Node3D.new()
		Fig.cyl(n, 0.36, 0.045, Vector3(0, 0.03, 0), u["color"], 14)
		var body := Node3D.new()
		body.name = "Body"
		body.scale = Vector3(0.82, 0.82, 0.82)
		if not bool(u["player"]):
			body.rotation.y = PI
		n.add_child(body)
		MeshFigures.add_unit(body, str(u.get("unit_id", "piechota")), 0.0, false)
		var sel := MeshInstance3D.new()
		sel.name = "Sel"
		var sm := CylinderMesh.new()
		sm.top_radius = 0.46
		sm.bottom_radius = 0.46
		sm.height = 0.035
		sm.radial_segments = 18
		sm.material = _trans(Color(1, 0.9, 0.25, 0.9))
		sel.mesh = sm
		sel.position.y = 0.03
		sel.visible = false
		n.add_child(sel)
		_add_hp_bar(n, 1.08)
		_view.add_child(n)
		_unit_nodes.append(n)


func _add_hp_bar(n: Node3D, y: float) -> void:
	var bg := _bar(Color(0.05, 0.05, 0.05), 0.62)
	bg.name = "HpBg"
	bg.position = Vector3(0, y, 0)
	n.add_child(bg)
	var fg := _bar(Color(0.25, 0.8, 0.28), 0.62)
	fg.name = "HpFg"
	fg.position = Vector3(0, y + 0.02, 0)
	n.add_child(fg)


func _bar(col: Color, w: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(w, 0.055, 0.05)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b.material = m
	mi.mesh = b
	mi.set_meta("bar_mat", m)
	return mi


func _set_hp(n: Node3D, frac: float) -> void:
	var fg := n.get_node_or_null("HpFg") as MeshInstance3D
	if fg == null:
		return
	frac = clampf(frac, 0.0, 1.0)
	if is_equal_approx(float(n.get_meta("hp_frac", -1.0)), frac):
		return
	n.set_meta("hp_frac", frac)
	fg.scale = Vector3(maxf(0.04, frac), 1, 1)
	fg.position.x = (frac - 1.0) * 0.31
	var mat: StandardMaterial3D = fg.get_meta("bar_mat")
	mat.albedo_color = Color(0.85, 0.2, 0.15).lerp(Color(0.3, 0.82, 0.28), frac)


func _prop_key(cell: Vector2i) -> String:
	var kind := str(_obstacles.get(cell, ""))
	var dmg := false
	if _structs.has(cell):
		var st: Dictionary = _structs[cell]
		dmg = int(st["hp"]) * 2 <= int(st["max_hp"])
	return kind + ("*" if dmg else "")


func _sync_visuals() -> void:
	_sync_tiles()
	_sync_props()
	_sync_units()
	_sync_fx()


func _sync_tiles() -> void:
	var sel := Vector2i(-99, -99)
	if _selected >= 0 and _selected < _units.size():
		sel = _units[_selected]["pos"]
	for tile in _tile_nodes:
		var cell: Vector2i = tile.get_meta("cell")
		var hi: MeshInstance3D = tile.get_node("Hi")
		hi.visible = false
		if _selected >= 0 and _selected < _units.size():
			var ti := _unit_at(cell)
			if ti >= 0 and not bool(_units[ti]["player"]) and HexMath.distance(sel, cell) <= int(_units[_selected].get("range", 1)):
				hi.visible = true
				hi.material_override = _mat_atk
				continue
			if _structs.has(cell) and HexMath.distance(sel, cell) <= int(_units[_selected].get("range", 1)):
				hi.visible = true
				hi.material_override = _mat_atk
				continue
		if _reachable.has(cell) and cell != sel:
			hi.visible = true
			hi.material_override = _mat_move
		elif cell == _hover and cell.x >= 0 and cell.y >= 0 and cell.x < map_w and cell.y < map_h:
			hi.visible = true
			hi.material_override = _mat_hover


func _sync_props() -> void:
	var live := {}
	for cell in _obstacles.keys():
		var c: Vector2i = cell
		live[c] = true
		var key := _prop_key(c)
		if str(_prop_keys.get(c, "")) != key:
			if _prop_nodes.has(c) and is_instance_valid(_prop_nodes[c]):
				_prop_nodes[c].queue_free()
			var kind := key.trim_suffix("*")
			var n := Fig.battle_prop(kind, key.ends_with("*"))
			n.position = _cell_pos(c)
			if _structs.has(c):
				var top := 1.15 if kind == "tower" else 1.0
				_add_hp_bar(n, top)
			_no_shadows(n)
			_props.add_child(n)
			_prop_nodes[c] = n
			_prop_keys[c] = key
	var stale: Array = []
	for c in _prop_nodes.keys():
		if not live.has(c):
			stale.append(c)
	for c in stale:
		if is_instance_valid(_prop_nodes[c]):
			_prop_nodes[c].queue_free()
		_prop_nodes.erase(c)
		_prop_keys.erase(c)
	for c in _structs.keys():
		if _prop_nodes.has(c) and is_instance_valid(_prop_nodes[c]):
			var st: Dictionary = _structs[c]
			_set_hp(_prop_nodes[c], float(st["hp"]) / maxf(1.0, float(st["max_hp"])))


func _sync_units() -> void:
	for i in _units.size():
		if i >= _unit_nodes.size():
			break
		var n: Node3D = _unit_nodes[i]
		var u: Dictionary = _units[i]
		if int(u["hp"]) <= 0:
			n.visible = false
			continue
		n.visible = true
		var px: Vector2 = _unit_px(i) + _fx_lunge.get(i, Vector2.ZERO)
		n.position = Vector3(px.x, GROUND_Y, px.y)
		_set_hp(n, float(u["hp"]) / maxf(1.0, float(u["max_hp"])))
		var sel := n.get_node_or_null("Sel")
		if sel:
			sel.visible = i == _selected
		var acted := bool(u["acted"]) and bool(u["player"]) == _player_turn
		var ov: Material = null
		if _fx_flash.has(i):
			_mat_flash.albedo_color = Color(1, 0.2, 0.1, clampf(float(_fx_flash[i]), 0.0, 1.0) * 0.7)
			ov = _mat_flash
		elif acted:
			ov = _mat_dim
		_apply_overlay(n, ov)


func _apply_overlay(n: Node, mat: Material) -> void:
	if n is GeometryInstance3D and str(n.name) not in ["HpBg", "HpFg", "Sel", "Tag"]:
		var gi := n as GeometryInstance3D
		var mid := 0
		if mat != null:
			mid = mat.get_instance_id()
		if int(gi.get_meta("ov_id", -1)) != mid:
			gi.set_meta("ov_id", mid)
			gi.material_overlay = mat
	for ch in n.get_children():
		_apply_overlay(ch, mat)


func _sync_fx() -> void:
	while _proj_pool.size() < _fx_proj.size():
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.05
		s.height = 0.1
		s.radial_segments = 8
		s.rings = 4
		s.material = Fig.M(Color(0.25, 0.18, 0.1))
		mi.mesh = s
		_fx_root.add_child(mi)
		_proj_pool.append(mi)
	for i in _proj_pool.size():
		var mi: MeshInstance3D = _proj_pool[i]
		mi.visible = i < _fx_proj.size()
		if not mi.visible:
			continue
		var pr: Array = _fx_proj[i]
		var a: Vector2 = pr[0]
		var b: Vector2 = pr[1]
		var t: float = float(pr[2])
		var p := a.lerp(b, t)
		var arc := sin(t * PI) * a.distance_to(b) * 0.25
		mi.position = Vector3(p.x, GROUND_Y + 0.55 + arc, p.y)
	# Liczby obrażeń są w belce 2D. Label3D (no_depth_test + outline) na Metal/Vulkan
	# potrafił zakleszczyć Forward+ w klatce po pokazaniu armii.


func _pick_cell(local: Vector2) -> Vector2i:
	if _cam == null:
		return _hover
	var origin := _cam.project_ray_origin(local)
	var normal := _cam.project_ray_normal(local)
	if absf(normal.y) < 0.0001:
		return _hover
	var dist := (GROUND_Y - origin.y) / normal.y
	if dist < 0.0:
		return _hover
	var hit := origin + normal * dist
	return HexMath.pixel_to_axial(Vector2(hit.x, hit.z), hex_size)


func _handle_click(axial: Vector2i) -> void:
	var hit := _unit_at(axial)
	if _pending_spell != "":
		if hit < 0:
			status.emit("Kliknij jednostkę (PPM/Esc = anuluj)")
			return
		_apply_spell(hit)
		return
	if _selected < 0:
		if hit >= 0 and bool(_units[hit]["player"]) and not bool(_units[hit]["acted"]):
			_selected = hit
			_recompute_reach(hit)
			status.emit("Wybrano: %s — kliknij hex (ruch) lub wroga obok (atak)" % str(_units[hit]["name"]))
			queue_redraw()
		return
	if hit < 0 and _structs.has(axial):
		var sd: int = HexMath.distance(_units[_selected]["pos"], axial)
		if sd <= int(_units[_selected].get("range", 1)):
			_attack_struct(_selected, axial)
			_finish_player_unit(_selected)
		else:
			status.emit("Podejdź do murów (zasięg %d)" % int(_units[_selected].get("range", 1)))
		return
	if hit >= 0 and not bool(_units[hit]["player"]):
		var dist: int = HexMath.distance(_units[_selected]["pos"], axial)
		if dist <= int(_units[_selected].get("range", 1)):
			_resolve_attack(_selected, hit)
			_finish_player_unit(_selected)
		else:
			status.emit("Wróg poza zasięgiem (%d) — podejdź bliżej" % int(_units[_selected].get("range", 1)))
		return
	if _reachable.has(axial) and _cell_free(axial, _selected):
		var mi := _selected
		_reachable.clear()
		status.emit("%s maszeruje…" % str(_units[mi]["name"]))
		await _animate_unit(mi, axial)
		_finish_player_unit(mi)
		return
	if hit >= 0 and bool(_units[hit]["player"]) and not bool(_units[hit]["acted"]):
		_selected = hit
		_recompute_reach(hit)
		queue_redraw()
		return
	status.emit("Nieprawidłowy cel")


## Klik / hover w układzie pikseli SubViewport (wywołuje nakładka).
func handle_pointer(event: InputEvent, local: Vector2) -> void:
	if not _mounted or not is_visible_in_tree():
		return
	if _busy or animating or not _player_turn:
		return
	if event is InputEventMouseMotion:
		var axial := _pick_cell(local)
		if axial != _hover:
			_hover = axial
			_visual_dirty = true
	elif _pending_spell != "" and ((event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT) or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE)):
		_pending_spell = ""
		status.emit("Czar anulowany")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(_pick_cell(local))


# --- Dźwięki bitwy ---
func _sfx(n: String) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play(n)


func _attack_sound(uid: String, ranged: bool) -> void:
	var snd := "sfx_sword"
	if uid == "wilk":
		snd = "sfx_howl"
	elif uid == "niedzwiedz":
		snd = "sfx_roar"
	elif ranged:
		snd = "sfx_musket" if uid in ["arkebuzerzy", "dragonia", "janczarzy", "rajtarzy", "karolinska_piechota", "strzelcy", "muszkieterowie", "kozacy"] else "sfx_arrow"
	elif uid in ["jazda", "dragonia", "husaria", "lisowczycy", "rajtarzy", "sipahi", "enemy_j", "bojarzy", "molojcy", "kirasjerzy"]:
		snd = "sfx_charge"
	_sfx(snd)
