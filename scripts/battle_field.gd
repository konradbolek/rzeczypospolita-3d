extends Node2D
## Prosta walka na hexach (styl Heroes — szkic).

signal battle_over(player_won: bool)
signal status(text: String)
signal spell_cast(spell_id: String, cost: int)

var mana: int = 0
var spell_power: int = 0
var _pending_spell: String = ""
var _pending_cost: int = 0
var _cast_this_turn: bool = false
const SPELL_TARGET_ENEMY := {"blyskawica": true}

@export var hex_size: float = 32.0
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
## Assety PNG pola bitwy (fallback: rysowanie proceduralne)
var _btex: Dictionary = {}
func _tex(n: String) -> Texture2D:
	if not _btex.has(n):
		var p := "res://assets/battle/%s.png" % n
		_btex[n] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	return _btex[n]


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
		queue_redraw()
		return
	_add_siege_structures()
	var hp_bonus := 10 if is_siege else 0
	var dmg_bonus := 2 if is_siege else 0
	_units.append(_mk("Garnizon" if is_siege else "Piechota wroga", "enemy_p", false, Vector2i(9, 3), 35 + hp_bonus, 7 + dmg_bonus, 3, Color(0.75, 0.2, 0.15)))
	_units.append(_mk("Łucznicy murów" if is_siege else "Łucznicy wroga", "enemy_l", false, Vector2i(9, 5), 22 + hp_bonus, 9 + dmg_bonus, 3, Color(0.9, 0.35, 0.25)))
	if is_siege or player_units.size() >= 3:
		_units.append(_mk("Straż zamkowa" if is_siege else "Jazda wroga", "enemy_j", false, Vector2i(8, 4), 32 + hp_bonus, 11 + dmg_bonus, 5, Color(0.6, 0.1, 0.1)))
	status.emit("Twoja tura — wybierz jednostkę")
	queue_redraw()


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
	while not frontier.is_empty():
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
	_reset_acted(false)
	status.emit("Tura wroga…")
	if not _structs.is_empty():
		_busy = true
		await _towers_fire()
		_busy = false
		if _check_end():
			return
	_enemy_ai_step()


func _enemy_ai_step() -> void:
	if _check_end():
		return
	var idx := -1
	for i in _units.size():
		var u: Dictionary = _units[i]
		if not bool(u["player"]) and int(u["hp"]) > 0 and not bool(u["acted"]):
			idx = i
			break
	if idx < 0:
		_player_turn = true
		_cast_this_turn = false
		_reset_acted(true)
		_selected = -1
		status.emit("Twoja tura — wybierz jednostkę")
		queue_redraw()
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
		_enemy_ai_step()
		return
	var target: Dictionary = _units[target_i]
	if best_d <= int(enemy.get("range", 1)):
		_resolve_attack(idx, target_i)
		_units[idx]["acted"] = true
		queue_redraw()
		if _check_end():
			return
		await get_tree().create_timer(0.25).timeout
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
	if HexMath.distance(best_cell, target["pos"]) <= int(enemy.get("range", 1)):
		_resolve_attack(idx, target_i)
	_units[idx]["acted"] = true
	queue_redraw()
	if _check_end():
		return
	await get_tree().create_timer(0.15).timeout
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


func _draw() -> void:
	# tło: łąka pod polem bitwy
	var tl := HexMath.axial_to_pixel(0, 0, hex_size)
	var br_px := HexMath.axial_to_pixel(map_w - 1, map_h - 1, hex_size)
	var bg := Rect2(Vector2(minf(tl.x, HexMath.axial_to_pixel(0, map_h - 1, hex_size).x), tl.y), Vector2.ZERO).expand(br_px).expand(HexMath.axial_to_pixel(map_w - 1, 0, hex_size)).grow(hex_size * 3.5)
	var bgt := _tex("battle_bg")
	if bgt:
		var ts := bgt.get_size()
		var sc := maxf(bg.size.x / ts.x, bg.size.y / ts.y)
		draw_texture_rect(bgt, Rect2(bg.get_center() - ts * sc * 0.5, ts * sc), false)
	else:
		draw_rect(bg, Color(0.17, 0.27, 0.14))
	for k in (0 if bgt else 6):
		draw_rect(Rect2(bg.position + Vector2(0, bg.size.y * k / 6.0), Vector2(bg.size.x, bg.size.y / 12.0)), Color(0.2, 0.31, 0.16, 0.35))
	for t in _trees:
		_draw_tree(t[0], hex_size * float(t[1]))
	var sel_pos := Vector2i(-1, -1)
	if _selected >= 0:
		sel_pos = _units[_selected]["pos"]
	for r in map_h:
		for q in map_w:
			var cell := Vector2i(q, r)
			var center := HexMath.axial_to_pixel(q, r, hex_size)
			var h := absi(hash(cell)) % 100
			var col := Color(0.30, 0.46, 0.22).lerp(Color(0.40, 0.52, 0.25), h / 100.0)
			if h % 7 == 0:
				col = Color(0.45, 0.38, 0.24) # ubita ziemia
			var corners := HexMath.hex_corners(center, hex_size * 0.97)
			# cień pod hexem
			var sh := PackedVector2Array()
			for p in corners:
				sh.append(p + Vector2(2, 3))
			draw_colored_polygon(sh, Color(0, 0, 0, 0.25))
			if bgt:
				draw_colored_polygon(corners, Color(col.r, col.g, col.b, 0.18))
			else:
				draw_colored_polygon(corners, col)
			# jaśniejszy środek (wypukłość)
			draw_colored_polygon(HexMath.hex_corners(center + Vector2(-1, -2), hex_size * 0.6), Color(1, 1, 0.8, 0.05))
			# kępki trawy
			for g in 3:
				var off := Vector2(((h * (g + 3)) % 31) - 15, ((h * (g + 5)) % 23) - 11) * hex_size / 32.0
				var gp := center + off
				draw_line(gp, gp + Vector2(-2, -4), Color(0.2, 0.36, 0.14), 1.0)
				draw_line(gp, gp + Vector2(1, -5), Color(0.24, 0.42, 0.16), 1.0)
			if _reachable.has(cell) and cell != sel_pos:
				draw_colored_polygon(corners, Color(0.3, 0.55, 1.0, 0.35))
			if _selected >= 0:
				var ti := _unit_at(cell)
				if ti >= 0 and not bool(_units[ti]["player"]) and HexMath.distance(sel_pos, cell) <= int(_units[_selected].get("range", 1)):
					draw_colored_polygon(corners, Color(1.0, 0.25, 0.15, 0.45))
			if cell == _hover:
				draw_colored_polygon(corners, Color(1, 1, 1, 0.12))
			draw_polyline(corners + PackedVector2Array([corners[0]]), Color(0.05, 0.1, 0.03, 0.55), 1.0)
			if _obstacles.has(cell):
				_draw_obstacle(center, str(_obstacles[cell]), cell)
	# jednostki
	for i in _units.size():
		var u: Dictionary = _units[i]
		if int(u["hp"]) <= 0:
			continue
		var pos: Vector2i = u["pos"]
		var c: Vector2 = _anim_px.get(i, HexMath.axial_to_pixel(pos.x, pos.y, hex_size)) + _fx_lunge.get(i, Vector2.ZERO)
		var col: Color = u["color"]
		var is_player := bool(u["player"])
		var acted := bool(u["acted"]) and is_player == _player_turn
		# podstawa w kolorze frakcji
		var base := HexMath.hex_corners(c, hex_size * 0.8)
		draw_colored_polygon(base, Color(col.r, col.g, col.b, 0.28))
		if i == _selected:
			draw_polyline(base + PackedVector2Array([base[0]]), Color(1, 0.9, 0.2), 3.0)
			draw_polyline(HexMath.hex_corners(c, hex_size * 0.92) + PackedVector2Array([HexMath.hex_corners(c, hex_size * 0.92)[0]]), Color(1, 0.95, 0.5, 0.6), 1.5)
		else:
			draw_polyline(base + PackedVector2Array([base[0]]), col.darkened(0.2), 1.5)
		var body := col.darkened(0.45) if acted else col
		if _fx_flash.has(i):
			body = body.lerp(Color(1, 0.2, 0.1), clampf(float(_fx_flash[i]), 0.0, 1.0) * 0.8)
		UnitArt.draw_unit(self, str(u.get("unit_id", "")), c + Vector2(0, -2), hex_size * 0.75, body, not is_player)
		if acted:
			draw_circle(c + Vector2(hex_size * 0.5, -hex_size * 0.5), 6.0, Color(0.15, 0.15, 0.15, 0.85))
			draw_string(ThemeDB.fallback_font, c + Vector2(hex_size * 0.5 - 4, -hex_size * 0.5 + 4), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.8))
		# pasek HP
		var frac := clampf(float(u["hp"]) / maxf(1.0, float(u["max_hp"])), 0.0, 1.0)
		var bw := hex_size * 1.1
		var br := Rect2(c + Vector2(-bw * 0.5, hex_size * 0.55), Vector2(bw, 5))
		draw_rect(br.grow(1), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(br.position, Vector2(bw * frac, 5)), Color(0.9, 0.2, 0.15).lerp(Color(0.3, 0.85, 0.3), frac))
		var hp_txt := "%d" % int(u["hp"])
		var tp := c + Vector2(-bw * 0.5 - 1, hex_size * 0.55 - 2)
		draw_string_outline(ThemeDB.fallback_font, tp, hp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
		draw_string(ThemeDB.fallback_font, tp, hp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	# HP struktur oblężniczych
	for cell in _structs.keys():
		var st: Dictionary = _structs[cell]
		var sc := HexMath.axial_to_pixel(cell.x, cell.y, hex_size)
		var f := float(st["hp"]) / float(st["max_hp"])
		var r := Rect2(sc + Vector2(-hex_size * 0.5, hex_size * 0.6), Vector2(hex_size, 4))
		draw_rect(r.grow(1), Color.BLACK)
		draw_rect(Rect2(r.position, Vector2(r.size.x * f, 4)), Color(0.85, 0.7, 0.2))
	# pociski
	for pr in _fx_proj:
		var a: Vector2 = pr[0]
		var b: Vector2 = pr[1]
		var t: float = pr[2]
		var p := a.lerp(b, t) + Vector2(0, -sin(t * PI) * a.distance_to(b) * 0.18)
		var p2 := a.lerp(b, maxf(0.0, t - 0.08)) + Vector2(0, -sin(maxf(0.0, t - 0.08) * PI) * a.distance_to(b) * 0.18)
		if pr[3] == "ball":
			draw_circle(p, 3.0, Color(0.1, 0.1, 0.1))
			draw_circle(p2, 5.0, Color(0.9, 0.9, 0.85, 0.35))
		else:
			draw_line(p2, p, Color(0.35, 0.22, 0.1), 2.0)
			draw_circle(p, 1.8, Color(0.8, 0.8, 0.8))
	for tx in _fx_text:
		var tp2: Vector2 = tx[0] + Vector2(0, -20.0 * float(tx[2]))
		draw_string_outline(ThemeDB.fallback_font, tp2, tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
		draw_string(ThemeDB.fallback_font, tp2, tx[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.3, 0.2, 1.0 - float(tx[2]) * 0.6))


func _input(event: InputEvent) -> void:
	var overlay := get_parent().get_parent() as Control
	if overlay == null or not overlay.visible:
		return
	if _busy or animating or not _player_turn:
		return
	if event is InputEventMouseMotion:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var axial := HexMath.pixel_to_axial(local, hex_size)
		if axial != _hover:
			_hover = axial
			queue_redraw()
	elif _pending_spell != "" and ((event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT) or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE)):
		_pending_spell = ""
		status.emit("Czar anulowany")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var axial := HexMath.pixel_to_axial(local, hex_size)
		_handle_click(axial)
		get_viewport().set_input_as_handled()


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
	# Atak na bramę/wieżę
	if hit < 0 and _structs.has(axial):
		var sd: int = HexMath.distance(_units[_selected]["pos"], axial)
		if sd <= int(_units[_selected].get("range", 1)):
			_attack_struct(_selected, axial)
			_finish_player_unit(_selected)
		else:
			status.emit("Podejdź do murów (zasięg %d)" % int(_units[_selected].get("range", 1)))
		return
	# Atak
	if hit >= 0 and not bool(_units[hit]["player"]):
		var dist: int = HexMath.distance(_units[_selected]["pos"], axial)
		if dist <= int(_units[_selected].get("range", 1)):
			_resolve_attack(_selected, hit)
			_finish_player_unit(_selected)
		else:
			status.emit("Wróg poza zasięgiem (%d) — podejdź bliżej" % int(_units[_selected].get("range", 1)))
		return
	# Ruch
	if _reachable.has(axial) and _cell_free(axial, _selected):
		var mi := _selected
		_reachable.clear()
		status.emit("%s maszeruje…" % str(_units[mi]["name"]))
		await _animate_unit(mi, axial)
		_finish_player_unit(mi)
		return
	# Reselect własnej
	if hit >= 0 and bool(_units[hit]["player"]) and not bool(_units[hit]["acted"]):
		_selected = hit
		_recompute_reach(hit)
		queue_redraw()
		return
	status.emit("Nieprawidłowy cel")


func _draw_tree(p: Vector2, sz: float) -> void:
	var tt := _tex("tree")
	if tt:
		var d := sz * 2.0
		draw_circle(p + Vector2(4, sz * 0.4), sz * 0.5, Color(0, 0, 0, 0.25))
		draw_texture_rect(tt, Rect2(p - Vector2(d * 0.5, d * 0.75), Vector2(d, d)), false)
		return
	draw_circle(p + Vector2(4, 4), sz * 0.45, Color(0, 0, 0, 0.25))
	draw_rect(Rect2(p + Vector2(-2, 0), Vector2(4, sz * 0.4)), Color(0.35, 0.22, 0.1))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -sz * 0.9), p + Vector2(-sz * 0.45, sz * 0.1), p + Vector2(sz * 0.45, sz * 0.1)]), Color(0.1, 0.3, 0.12))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -sz * 1.2), p + Vector2(-sz * 0.35, -sz * 0.3), p + Vector2(sz * 0.35, -sz * 0.3)]), Color(0.14, 0.38, 0.15))


func _draw_obstacle(c: Vector2, kind: String, cell: Vector2i = Vector2i(-99, -99)) -> void:
	var s := hex_size
	if kind in ["wall", "gate", "tower"]:
		var nm := kind
		if _structs.has(cell):
			var st: Dictionary = _structs[cell]
			if int(st["hp"]) * 2 <= int(st["max_hp"]):
				nm += "_damaged"
		var stx := _tex("siege/" + nm)
		if stx == null:
			stx = _tex("siege/" + kind)
		if stx:
			draw_colored_polygon(HexMath.hex_corners(c, s * 0.95), Color(0.22, 0.18, 0.12, 0.55))
			var tsz := stx.get_size()
			var hgt := {"wall": 1.5, "gate": 2.1, "tower": 2.6}[kind] as float
			var hh := s * hgt
			var ww := minf(hh * tsz.x / tsz.y, s * 2.2)
			hh = ww * tsz.y / tsz.x
			draw_texture_rect(stx, Rect2(c + Vector2(-ww * 0.5, s * 0.75 - hh), Vector2(ww, hh)), false)
			return
	if kind in ["hill", "rock"]:
		var ot := _tex(kind)
		if ot:
			var d := s * 1.9
			draw_texture_rect(ot, Rect2(c - Vector2(d * 0.5, d * 0.6), Vector2(d, d)), false)
			return
	match kind:
		"hill":
			var pts := PackedVector2Array()
			for k in 13:
				var a := PI + PI * k / 12.0
				pts.append(c + Vector2(cos(a) * s * 0.85, sin(a) * s * 0.65 + s * 0.3))
			draw_colored_polygon(pts, Color(0.42, 0.36, 0.2))
			var top := PackedVector2Array()
			for k in 13:
				var a := PI + PI * k / 12.0
				top.append(c + Vector2(cos(a) * s * 0.55 - 3, sin(a) * s * 0.45 + s * 0.15))
			draw_colored_polygon(top, Color(0.55, 0.48, 0.28))
			draw_polyline(pts, Color(0.2, 0.15, 0.08), 2.0)
			draw_line(c + Vector2(s * 0.15, -s * 0.05), c + Vector2(s * 0.45, s * 0.2), Color(0.25, 0.2, 0.1), 1.5)
		"rock":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.6, s * 0.35), c + Vector2(-s * 0.4, -s * 0.3), c + Vector2(-s * 0.05, -s * 0.55), c + Vector2(s * 0.35, -s * 0.35), c + Vector2(s * 0.6, s * 0.35)]), Color(0.45, 0.45, 0.47))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.05, -s * 0.55), c + Vector2(s * 0.35, -s * 0.35), c + Vector2(s * 0.6, s * 0.35), c + Vector2(s * 0.1, s * 0.35)]), Color(0.32, 0.32, 0.35))
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.6, s * 0.35), c + Vector2(-s * 0.4, -s * 0.3), c + Vector2(-s * 0.05, -s * 0.55), c + Vector2(s * 0.35, -s * 0.35), c + Vector2(s * 0.6, s * 0.35), c + Vector2(-s * 0.6, s * 0.35)]), Color(0.12, 0.12, 0.14), 2.0)
		"gate":
			draw_colored_polygon(HexMath.hex_corners(c, s * 0.97), Color(0.25, 0.2, 0.15))
			var g := Rect2(c + Vector2(-s * 0.5, -s * 0.65), Vector2(s * 1.0, s * 1.05))
			draw_rect(g, Color(0.55, 0.52, 0.46))
			var door := Rect2(c + Vector2(-s * 0.3, -s * 0.3), Vector2(s * 0.6, s * 0.7))
			draw_rect(door, Color(0.4, 0.25, 0.1))
			for k in 4:
				draw_line(door.position + Vector2(k * door.size.x / 3.0, 0), door.position + Vector2(k * door.size.x / 3.0, door.size.y), Color(0.2, 0.12, 0.05), 1.5)
			draw_rect(g, Color(0.15, 0.13, 0.1), false, 2.0)
		"tower":
			draw_colored_polygon(HexMath.hex_corners(c, s * 0.97), Color(0.25, 0.2, 0.15))
			var tw := Rect2(c + Vector2(-s * 0.4, -s * 1.0), Vector2(s * 0.8, s * 1.4))
			draw_rect(tw, Color(0.62, 0.58, 0.5))
			draw_colored_polygon(PackedVector2Array([tw.position + Vector2(-4, 0), tw.position + Vector2(tw.size.x + 4, 0), tw.position + Vector2(tw.size.x * 0.5, -s * 0.5)]), Color(0.55, 0.15, 0.1))
			draw_rect(Rect2(c + Vector2(-3, -s * 0.6), Vector2(6, 10)), Color(0.1, 0.08, 0.06))
			draw_rect(tw, Color(0.15, 0.13, 0.1), false, 2.0)
		"wall":
			var corners := HexMath.hex_corners(c, s * 0.97)
			draw_colored_polygon(corners, Color(0.25, 0.2, 0.15)) # rów
			var w := Rect2(c + Vector2(-s * 0.55, -s * 0.6), Vector2(s * 1.1, s * 1.0))
			draw_rect(w, Color(0.6, 0.57, 0.5))
			for row in 4:
				var y := w.position.y + row * w.size.y / 4.0
				draw_line(Vector2(w.position.x, y), Vector2(w.end.x, y), Color(0.35, 0.33, 0.3), 1.0)
			for k in 3:
				draw_rect(Rect2(w.position + Vector2(k * s * 0.4, -s * 0.2), Vector2(s * 0.28, s * 0.2)), Color(0.6, 0.57, 0.5))
			draw_rect(w, Color(0.15, 0.13, 0.1), false, 2.0)


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
