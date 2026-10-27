extends Control
## Ekran miasta: widok zamku (budynki rysowane kodem) + budowa + rekrutacja.

signal left_city
signal recruit_requested(unit_id: String)
signal build_requested(building_id: String)

@onready var panel: PanelContainer = $Center/Panel
@onready var vbox: VBoxContainer = $Center/Panel/Margin/VBox
@onready var title_label: Label = $Center/Panel/Margin/VBox/TitleLabel
@onready var capital_label: Label = $Center/Panel/Margin/VBox/CapitalLabel
@onready var flavor_label: Label = $Center/Panel/Margin/VBox/FlavorLabel
@onready var gold_label: Label = $Center/Panel/Margin/VBox/GoldLabel
@onready var army_label: Label = $Center/Panel/Margin/VBox/ArmyLabel
@onready var buildings_list: ItemList = $Center/Panel/Margin/VBox/BuildingsList
@onready var recruit_row: HBoxContainer = $Center/Panel/Margin/VBox/RecruitRow
@onready var leave_button: Button = $Center/Panel/Margin/VBox/LeaveButton

const GOLD := Color(0.95, 0.78, 0.35)
const PARCH := Color(0.93, 0.87, 0.72)

var _owned: bool = false
var _defs: Dictionary = {}
var _buildings: Dictionary = {}
var _gold: int = 0
var _selected: String = "ratusz"
var res_wood: int = 0
var res_ore: int = 0

var _town_view: TownView = null
var _detail_box: PanelContainer = null
var _detail_name: Label = null
var _detail_desc: Label = null
var _detail_cost: Label = null
var _detail_btn: Button = null
var _owner_banner: Label = null
var _recruit_title: Label = null


## Widok miasta: niebo, mury, budynki jako ikony rysowane w _draw.
class TownView extends Control:
	signal building_clicked(bid: String)
	const ORDER := ["ratusz", "koszary", "kuznia", "wieza", "targ", "stajnia", "mur"]
	var buildings: Dictionary = {}
	var defs: Dictionary = {}
	var owned: bool = true
	var hovered: String = ""
	var selected: String = ""
	var faction: String = "polska"
	var herb: Texture2D = null
	var bg: Texture2D = null
	const THEMES := {
		"polska": {"sky_t": Color(0.22, 0.40, 0.72), "sky_b": Color(0.98, 0.82, 0.58), "hill": Color(0.30, 0.44, 0.30),
			"grass_t": Color(0.36, 0.50, 0.26), "grass_b": Color(0.24, 0.36, 0.17), "stone": Color(0.80, 0.52, 0.40),
			"wall": Color(0.62, 0.38, 0.30), "roof": Color(0.70, 0.18, 0.14), "road": Color(0.62, 0.52, 0.36),
			"flag1": Color(1, 1, 1), "flag2": Color(0.85, 0.12, 0.15), "style": "gotyk", "snow": false},
		"szwecja": {"sky_t": Color(0.30, 0.45, 0.62), "sky_b": Color(0.82, 0.88, 0.92), "hill": Color(0.22, 0.34, 0.30),
			"grass_t": Color(0.42, 0.52, 0.40), "grass_b": Color(0.28, 0.36, 0.30), "stone": Color(0.70, 0.30, 0.24),
			"wall": Color(0.52, 0.54, 0.56), "roof": Color(0.22, 0.30, 0.36), "road": Color(0.55, 0.52, 0.48),
			"flag1": Color(0.10, 0.32, 0.65), "flag2": Color(0.98, 0.80, 0.10), "style": "nordyk", "snow": true},
		"osmanowie": {"sky_t": Color(0.20, 0.50, 0.78), "sky_b": Color(1.0, 0.86, 0.55), "hill": Color(0.70, 0.58, 0.38),
			"grass_t": Color(0.72, 0.62, 0.40), "grass_b": Color(0.55, 0.45, 0.28), "stone": Color(0.94, 0.88, 0.74),
			"wall": Color(0.86, 0.74, 0.54), "roof": Color(0.22, 0.55, 0.52), "road": Color(0.80, 0.68, 0.46),
			"flag1": Color(0.12, 0.50, 0.25), "flag2": Color(1, 1, 1), "style": "orient", "snow": false},
	}

	func T(k: String):
		return THEMES.get(faction, THEMES["polska"])[k]

	func set_faction(f: String) -> void:
		faction = f if THEMES.has(f) else "polska"
		var path := "res://assets/city/herb_%s.svg" % faction
		herb = load(path) if ResourceLoader.exists(path) else null
		var bp := "res://assets/city/bg_%s.png" % faction
		bg = null
		if ResourceLoader.exists(bp):
			bg = load(bp) as Texture2D
		if bg == null and FileAccess.file_exists(bp):
			var img := Image.load_from_file(ProjectSettings.globalize_path(bp))
			if img:
				bg = ImageTexture.create_from_image(img)
		queue_redraw()

	func _dome(c: Vector2, rw: float, rh: float, col: Color) -> void:
		var pts: Array = [c + Vector2(-rw, 0)]
		for i in 13:
			var a := PI + PI * float(i) / 12.0
			pts.append(c + Vector2(cos(a) * rw, sin(a) * rh))
		pts.append(c + Vector2(rw, 0))
		_poly(pts, col)
		draw_line(c + Vector2(0, -rh), c + Vector2(0, -rh - 14), Color(0.9, 0.75, 0.3, col.a), 2)
		draw_circle(c + Vector2(0, -rh - 16), 3, Color(0.95, 0.8, 0.3, col.a))

	func _roof(l: Vector2, r: Vector2, top: Vector2, col: Color) -> void:
		var st: String = T("style")
		if st == "orient":
			_dome(Vector2((l.x + r.x) / 2, l.y), (r.x - l.x) / 2 * 0.8, (l.y - top.y) * 0.9, col)
		elif st == "nordyk":
			_poly([l, Vector2(top.x, top.y - (l.y - top.y) * 0.4), r], col)
			draw_line(Vector2(top.x, top.y - (l.y - top.y) * 0.4), Vector2(top.x, top.y - (l.y - top.y) * 0.4 - 10), Color(0.15, 0.15, 0.15, col.a), 2)
		else:
			_poly([l, top, r], col)
			for k in 3:
				var t := float(k + 1) / 4.0
				draw_line(l.lerp(top, t), r.lerp(top, t), col.darkened(0.25), 1)

	# Sloty z głębią: (x, y podstawy jako ułamek, skala). Tył -> przód.
	const SLOTS := {
		"wieza": Vector3(0.12, 0.58, 0.72),
		"mur": Vector3(0.88, 0.58, 0.72),
		"ratusz": Vector3(0.38, 0.56, 0.74),
		"targ": Vector3(0.64, 0.58, 0.70),
		"koszary": Vector3(0.18, 0.92, 0.92),
		"stajnia": Vector3(0.50, 0.94, 0.88),
		"kuznia": Vector3(0.82, 0.90, 0.90),
	}
	const LOCAL := Rect2(-90, -200, 180, 226)

	func _init() -> void:
		clip_contents = true
		custom_minimum_size = Vector2(400, 200)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _anchor(bid: String) -> Vector2:
		var v: Vector3 = SLOTS[bid]
		return Vector2(size.x * v.x, size.y * v.y)

	func _scale(bid: String) -> float:
		return float(SLOTS[bid].z) * clampf(minf(size.y / 340.0, size.x / 1180.0), 0.5, 1.6)

	func _slot_rect_of(bid: String) -> Rect2:
		var sc := _scale(bid)
		return Rect2(_anchor(bid) + LOCAL.position * sc, LOCAL.size * sc)

	func _sorted() -> Array:
		var arr: Array = SLOTS.keys()
		arr.sort_custom(func(x, y): return SLOTS[x].y < SLOTS[y].y)
		return arr

	func _bid_at(p: Vector2) -> String:
		var arr := _sorted()
		arr.reverse()
		for bid in arr:
			if _slot_rect_of(bid).has_point(p):
				return bid
		return ""

	func _poly(pts: Array, c: Color) -> void:
		draw_colored_polygon(PackedVector2Array(pts), c)

	func _draw() -> void:
		var W := size.x
		var H := size.y
		var hz := H * 0.42
		if bg and owned:
			# Panorama PNG (cover)
			var ts := bg.get_size()
			var sc0 := maxf(W / ts.x, H / ts.y)
			var ds := ts * sc0
			draw_texture_rect(bg, Rect2((Vector2(W, H) - ds) * 0.5, ds), false)
			draw_rect(Rect2(0, H * 0.55, W, H * 0.45), Color(0, 0, 0, 0.12))
		else:
			# Niebo
			var top: Color = T("sky_t") if owned else Color(0.25, 0.22, 0.30)
			var bot: Color = T("sky_b") if owned else Color(0.62, 0.40, 0.35)
			for i in 24:
				var t := float(i) / 24.0
				draw_rect(Rect2(0, hz * t, W, hz / 24.0 + 1), top.lerp(bot, t))
			# Słońce i chmury
			var sun := Vector2(W * 0.82, hz * 0.45)
			for k in 4:
				draw_circle(sun, 40 - k * 8, Color(1, 0.92, 0.65, 0.12 + k * 0.18))
			for cl in [Vector3(0.15, 0.18, 1.0), Vector3(0.45, 0.10, 0.8), Vector3(0.66, 0.25, 1.2)]:
				var cp := Vector2(W * cl.x, hz * cl.y + 20)
				for j in 5:
					draw_circle(cp + Vector2(j * 18 * cl.z - 36, -sin(j * 1.2) * 8), 16 * cl.z, Color(1, 1, 1, 0.55))
			# Góry daleko (mgiełka)
			var m1: Array = [Vector2(0, hz + 10)]
			for x in range(0, int(W) + 60, 60):
				m1.append(Vector2(x, hz - 40 - abs(sin(x * 0.011)) * 70 - sin(x * 0.037) * 15))
			m1.append(Vector2(W, hz + 10)); 
			_poly(m1, Color(0.52, 0.58, 0.72).lerp(bot, 0.35))
			for x in range(0, int(W), 60):
				var pk := Vector2(x, hz - 40 - abs(sin(x * 0.011)) * 70 - sin(x * 0.037) * 15)
				if pk.y < (hz - 60 if T("snow") else hz - 85):
					_poly([pk, pk + Vector2(-14, 16), pk + Vector2(14, 16)], Color(0.95, 0.96, 1.0, 0.8))
			# Wzgórza średnie
			var m2: Array = [Vector2(0, H)]
			for x in range(0, int(W) + 40, 40):
				m2.append(Vector2(x, hz - 8 - sin(x * 0.008 + 1.0) * 22))
			m2.append(Vector2(W, H))
			_poly(m2, (T("hill") as Color).lerp(bot, 0.2))
			# Drzewa na horyzoncie
			for x in range(10, int(W), 23):
				var ty := hz - 4 - sin(x * 0.008 + 1.0) * 22
				if T("style") == "orient":
					if x % 3 == 0:
						draw_line(Vector2(x, ty), Vector2(x, ty - 22), Color(0.4, 0.3, 0.2), 2)
						for k in 5:
							var a2 := -PI + PI * k / 4.0
							draw_line(Vector2(x, ty - 22), Vector2(x, ty - 22) + Vector2(cos(a2), sin(a2) * 0.5 + 0.3) * 12, Color(0.25, 0.45, 0.2), 3)
				elif T("style") == "nordyk":
					_poly([Vector2(x - 7, ty + 2), Vector2(x, ty - 22 - (x % 7)), Vector2(x + 7, ty + 2)], Color(0.12, 0.25, 0.20))
			# Dalekie mury z wieżami (mniejsze = dalej)
			var wy := hz + H * 0.06
			var wc: Color = T("wall")
			draw_rect(Rect2(W * 0.05, wy - 22, W * 0.9, 22), wc)
			for x in range(int(W * 0.05), int(W * 0.95), 16):
				draw_rect(Rect2(x, wy - 28, 9, 6), wc)
			for tx in [0.05, 0.35, 0.65, 0.95]:
				var px: float = W * float(tx)
				draw_rect(Rect2(px - 14, wy - 52, 28, 52), wc.lightened(0.08))
				_roof(Vector2(px - 18, wy - 52), Vector2(px + 18, wy - 52), Vector2(px, wy - 80), T("roof"))
				draw_line(Vector2(px, wy - 82), Vector2(px, wy - 104), Color(0.2, 0.15, 0.1), 2)
				draw_rect(Rect2(px + 1, wy - 104, 16, 5), T("flag1"))
				draw_rect(Rect2(px + 1, wy - 99, 16, 5), T("flag2"))
			draw_rect(Rect2(W * 0.05, wy - 2, W * 0.9, 3), Color(0, 0, 0, 0.18))
			# Dziedziniec (trawa) z gradientem głębi
			for i in 16:
				var t := float(i) / 16.0
				var yy := wy + (H - wy) * t
				draw_rect(Rect2(0, yy, W, (H - wy) / 16.0 + 1), (T("grass_t") as Color).lerp(T("grass_b"), t))
			# Droga w perspektywie
			var vp := Vector2(W * 0.5, wy)
			_poly([vp + Vector2(-20, 0), vp + Vector2(20, 0), Vector2(W * 0.62, H), Vector2(W * 0.38, H)], T("road"))
			for k in 7:
				var t := pow(float(k + 1) / 8.0, 1.6)
				var y := wy + (H - wy) * t
				var hw := 20 + (W * 0.12 - 20) * t
				draw_line(Vector2(W * 0.5 - hw, y), Vector2(W * 0.5 + hw, y), Color(0.50, 0.42, 0.28, 0.6), 1.0 + 2 * t)
			# Brama w murze
			draw_rect(Rect2(vp.x - 16, wy - 22, 32, 22), Color(0.2, 0.15, 0.1))
		# Budynki (od tyłu do przodu) ze skalą
		for bid in _sorted():
			var sc := _scale(bid)
			var an := _anchor(bid)
			# cień
			draw_set_transform(an + Vector2(10 * sc, 0), 0, Vector2(sc * 1.6, sc * 0.35))
			draw_circle(Vector2.ZERO, 60, Color(0, 0, 0, 0.28))
			draw_set_transform(an, 0, Vector2(sc, sc))
			_draw_building(bid, LOCAL)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		# Krzewy na pierwszym planie i winieta
		for i in 6:
			var a := 0.10 - i * 0.015
			draw_rect(Rect2(i * 6, i * 6, W - i * 12, H - i * 12), Color(0, 0, 0, a), false, 6)
		if herb:
			var hs := clampf(H * 0.22, 48.0, 110.0)
			draw_texture_rect(herb, Rect2(14, 14, hs * 0.865, hs), false)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.46, 0.20), false, 4)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			var h := _bid_at(ev.position)
			if h != hovered:
				hovered = h
				tooltip_text = ""
				if h != "" and defs.has(h):
					tooltip_text = "%s — %s" % [defs[h]["name"], defs[h]["desc"]]
				queue_redraw()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var b := _bid_at(ev.position)
			if b != "":
				building_clicked.emit(b)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and hovered != "":
			hovered = ""
			queue_redraw()

	var _btex_cache: Dictionary = {}
	func _btex(bid: String) -> Texture2D:
		if not _btex_cache.has(bid):
			var path := "res://assets/city/buildings/%s.png" % bid
			_btex_cache[bid] = load(path) as Texture2D if ResourceLoader.exists(path) else null
		return _btex_cache[bid]

	func _draw_building(bid: String, r: Rect2) -> void:
		var lvl: int = int(buildings.get(bid, 0))
		var mx: int = int(defs.get(bid, {}).get("max", 1))
		var built := lvl > 0
		var cx := r.position.x + r.size.x / 2
		var base := r.position.y + r.size.y - 26
		var a := 1.0 if built else 0.35
		# Podświetlenie
		if bid == selected:
			draw_rect(r, Color(1, 0.85, 0.3, 0.22))
			draw_rect(r, GOLD, false, 2)
		elif bid == hovered:
			draw_rect(r, Color(1, 1, 1, 0.12))
			draw_rect(r, Color(1, 1, 1, 0.6), false, 1)
		var stone := Color(T("stone"), a)
		var dark := Color(0.25, 0.20, 0.16, a)
		var roof := Color(T("roof"), a)
		var btex: Texture2D = _btex(bid)
		if btex:
			var gs := 0.82 + 0.09 * float(maxi(lvl, 1))
			var bw := r.size.x * gs
			var bh := r.size.y * gs
			var by := base + 26.0 * gs
			draw_texture_rect(btex, Rect2(cx - bw / 2, by - bh, bw, bh), false, Color(1, 1, 1, a))
		if btex == null:
			match bid:
				"ratusz":
					draw_rect(Rect2(cx - 50, base - 60, 100, 60), stone)
					_roof(Vector2(cx - 58, base - 60), Vector2(cx + 58, base - 60), Vector2(cx, base - 95), roof)
					draw_rect(Rect2(cx - 14, base - 130, 28, 40), stone)
					_roof(Vector2(cx - 18, base - 130), Vector2(cx + 18, base - 130), Vector2(cx, base - 155), roof)
					draw_circle(Vector2(cx, base - 112), 8, Color(0.95, 0.95, 0.85, a))
					draw_line(Vector2(cx, base - 112), Vector2(cx, base - 118), dark, 2)
					draw_line(Vector2(cx, base - 112), Vector2(cx + 5, base - 112), dark, 2)
					draw_rect(Rect2(cx - 10, base - 28, 20, 28), dark)
					for dx in [-36, 24]:
						draw_rect(Rect2(cx + dx, base - 48, 12, 14), Color(0.95, 0.85, 0.45, a))
				"koszary":
					draw_rect(Rect2(cx - 60, base - 50, 120, 50), stone)
					draw_colored_polygon(PackedVector2Array([Vector2(cx - 66, base - 50), Vector2(cx - 50, base - 75), Vector2(cx + 50, base - 75), Vector2(cx + 66, base - 50)]), Color(0.45, 0.30, 0.18, a))
					draw_rect(Rect2(cx - 16, base - 34, 32, 34), dark)
					draw_line(Vector2(cx + 40, base - 75), Vector2(cx + 40, base - 125), dark, 3)
					draw_colored_polygon(PackedVector2Array([Vector2(cx + 41, base - 125), Vector2(cx + 75, base - 117), Vector2(cx + 41, base - 108)]), Color(T("flag2"), a))
					draw_colored_polygon(PackedVector2Array([Vector2(cx + 41, base - 125), Vector2(cx + 75, base - 117), Vector2(cx + 41, base - 117)]), Color(T("flag1"), a))
					# włócznie
					for dx in [-50, -40]:
						draw_line(Vector2(cx + dx, base), Vector2(cx + dx, base - 70), dark, 2)
				"kuznia":
					draw_rect(Rect2(cx - 48, base - 55, 96, 55), Color(0.50, 0.42, 0.36, a))
					draw_colored_polygon(PackedVector2Array([Vector2(cx - 54, base - 55), Vector2(cx, base - 85), Vector2(cx + 54, base - 55)]), Color(0.30, 0.28, 0.30, a))
					draw_rect(Rect2(cx + 22, base - 110, 16, 40), Color(0.40, 0.30, 0.26, a))
					if built:
						for k in 3:
							draw_circle(Vector2(cx + 30 + k * 8, base - 120 - k * 14), 7 + k * 2, Color(0.6, 0.6, 0.6, 0.55 - k * 0.12))
					draw_rect(Rect2(cx - 22, base - 34, 44, 34), Color(0.95, 0.45, 0.10, a) if built else dark)
					draw_rect(Rect2(cx - 14, base - 18, 28, 8), dark)
					draw_rect(Rect2(cx - 4, base - 10, 8, 10), dark)
				"wieza":
					draw_rect(Rect2(cx - 22, base - 130, 44, 130), Color(0.70, 0.68, 0.78, a))
					if T("style") == "orient":
						draw_rect(Rect2(cx - 28, base - 136, 56, 6), Color(T("stone"), a))
						_dome(Vector2(cx, base - 136), 18, 26, Color(T("roof"), a))
					else:
						_roof(Vector2(cx - 30, base - 130), Vector2(cx + 30, base - 130), Vector2(cx, base - 185), Color(0.35, 0.20, 0.60, a))
					draw_circle(Vector2(cx, base - 190), 5, Color(0.6, 0.9, 1.0, a))
					for wy in [-105, -70]:
						draw_rect(Rect2(cx - 6, base + wy, 12, 18), Color(0.6, 0.85, 1.0, a))
					draw_rect(Rect2(cx - 10, base - 28, 20, 28), dark)
				"targ":
					var cols := [Color(0.85, 0.20, 0.20, a), Color(0.95, 0.85, 0.30, a), Color(0.25, 0.45, 0.85, a)]
					for i in 3:
						var x0 := cx - 66 + i * 46
						draw_line(Vector2(x0 + 4, base), Vector2(x0 + 4, base - 50), dark, 3)
						draw_line(Vector2(x0 + 38, base), Vector2(x0 + 38, base - 50), dark, 3)
						draw_colored_polygon(PackedVector2Array([Vector2(x0, base - 50), Vector2(x0 + 21, base - 72), Vector2(x0 + 42, base - 50)]), cols[i])
						draw_rect(Rect2(x0 + 4, base - 22, 34, 10), Color(0.55, 0.38, 0.20, a))
						if lvl >= i + 1:
							draw_circle(Vector2(x0 + 14, base - 26), 5, Color(0.9, 0.5, 0.1, a))
							draw_circle(Vector2(x0 + 28, base - 26), 5, Color(0.4, 0.8, 0.3, a))
				"stajnia":
					draw_rect(Rect2(cx - 70, base - 48, 140, 48), Color(0.58, 0.40, 0.22, a))
					draw_colored_polygon(PackedVector2Array([Vector2(cx - 78, base - 48), Vector2(cx, base - 82), Vector2(cx + 78, base - 48)]), Color(0.80, 0.68, 0.30, a))
					for dx in [-50, -16, 18]:
						draw_rect(Rect2(cx + dx, base - 34, 28, 34), dark)
						draw_line(Vector2(cx + dx, base - 34), Vector2(cx + dx + 28, base), Color(0.75, 0.55, 0.3, a), 2)
					if lvl >= 2:
						draw_rect(Rect2(cx + 50, base - 30, 10, 30), Color(0.4, 0.28, 0.16, a))
						draw_circle(Vector2(cx + 55, base - 36), 9, Color(0.35, 0.22, 0.12, a))
				"mur":
					var hgt := 50 + lvl * 15
					draw_rect(Rect2(cx - 60, base - hgt, 120, hgt), stone)
					for k in 6:
						draw_rect(Rect2(cx - 60 + k * 21, base - hgt - 12, 14, 12), stone)
					for k in 4:
						draw_line(Vector2(cx - 60, base - hgt + 14 + k * 14), Vector2(cx + 60, base - hgt + 14 + k * 14), Color(0.55, 0.5, 0.42, a), 1)
					if lvl >= 3:
						draw_rect(Rect2(cx - 20, base - hgt - 50, 40, 40), stone)
						_roof(Vector2(cx - 26, base - hgt - 50), Vector2(cx + 26, base - hgt - 50), Vector2(cx, base - hgt - 80), roof)
					draw_rect(Rect2(cx - 14, base - 30, 28, 30), dark)
		if not built:
			# Plac budowy
			draw_rect(Rect2(cx - 55, base - 8, 110, 8), Color(0.55, 0.40, 0.22))
			for dx in [-45, 45]:
				draw_line(Vector2(cx + dx, base), Vector2(cx + dx, base - 60), Color(0.55, 0.40, 0.22), 3)
			draw_line(Vector2(cx - 45, base - 60), Vector2(cx + 45, base - 60), Color(0.55, 0.40, 0.22), 3)
		# Nazwa + poziom
		var font := get_theme_default_font()
		var nm: String = str(defs.get(bid, {}).get("name", bid))
		var ty := r.position.y + r.size.y - 6
		draw_rect(Rect2(r.position.x + 4, ty - 18, r.size.x - 8, 22), Color(0.12, 0.09, 0.06, 0.8))
		draw_string(font, Vector2(r.position.x + 4, ty - 2), nm, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 15, PARCH)
		var badge := Vector2(r.position.x + r.size.x - 18, r.position.y + 18)
		draw_circle(badge, 15, Color(0.15, 0.10, 0.05))
		draw_circle(badge, 13, GOLD if lvl >= mx else (Color(0.7, 0.7, 0.75) if built else Color(0.4, 0.4, 0.4)))
		draw_string(font, badge + Vector2(-15, 5), "%d/%d" % [lvl, mx], HORIZONTAL_ALIGNMENT_CENTER, 30, 12, Color(0.1, 0.08, 0.05))


func _ready() -> void:
	visible = false
	leave_button.pressed.connect(_on_leave)
	$Center/Panel/Margin/VBox/RecruitRow/RecruitPiechota.pressed.connect(_on_recruit.bind("piechota"))
	$Center/Panel/Margin/VBox/RecruitRow/RecruitLucznicy.pressed.connect(_on_recruit.bind("lucznicy"))
	$Center/Panel/Margin/VBox/RecruitRow/RecruitJazda.pressed.connect(_on_recruit.bind("jazda"))
	var M = preload("res://scripts/main.gd")
	var fac: String = str(get_tree().current_scene.get("player_faction")) if get_tree().current_scene and get_tree().current_scene.get("player_faction") != null else "polska"
	for uid in M.FACTIONS.get(fac, M.FACTIONS["polska"])["units"]:
		if uid in ["piechota", "lucznicy", "jazda"]:
			continue
		var b := Button.new()
		b.name = "Recruit_" + uid
		b.text = "%s (%d zł)" % [M.UNIT_CATALOG[uid]["name"], int(M.UNIT_CATALOG[uid]["cost"])]
		recruit_row.add_child(b)
		b.pressed.connect(_on_recruit.bind(uid))
	_build_ui()


func _style(bg: Color, border: Color, bw: int = 2, rad: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(rad)
	s.content_margin_left = 8; s.content_margin_right = 8
	s.content_margin_top = 4; s.content_margin_bottom = 4
	return s


func _style_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _style(Color(0.30, 0.20, 0.10), Color(0.65, 0.50, 0.25)))
	b.add_theme_stylebox_override("hover", _style(Color(0.42, 0.29, 0.13), GOLD))
	b.add_theme_stylebox_override("pressed", _style(Color(0.22, 0.14, 0.07), GOLD))
	b.add_theme_stylebox_override("disabled", _style(Color(0.18, 0.16, 0.14), Color(0.32, 0.30, 0.27)))
	b.add_theme_color_override("font_color", PARCH)
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.48, 0.44))


const _ICON_IDS := {"RecruitPiechota": "piechota", "RecruitLucznicy": "lucznicy", "RecruitJazda": "jazda"}

func _add_unit_icon(b: Button) -> void:
	var uid := str(_ICON_IDS.get(str(b.name), str(b.name).trim_prefix("Recruit_")))
	var ic := UnitArt.Icon.new()
	ic.unit_id = uid
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.set_anchors_preset(Control.PRESET_CENTER_TOP)
	ic.offset_left = -18; ic.offset_right = 18; ic.offset_top = 2; ic.offset_bottom = 38
	b.add_child(ic)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := b.get_theme_stylebox(st) as StyleBoxFlat
		if sb:
			sb.content_margin_top = 40
	b.draw.connect(ic.queue_redraw)


func _fit_to_viewport() -> void:
	# Panel zawsze w granicach okna (12px marginesu), widok miasta się skaluje
	var vp := get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(maxf(vp.x - 24.0, 400.0), maxf(vp.y - 24.0, 300.0))
	panel.size = panel.custom_minimum_size
	if _town_view:
		_town_view.queue_redraw()


func _build_ui() -> void:
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	$Center/Panel/Margin.add_theme_constant_override("margin_top", 8)
	$Center/Panel/Margin.add_theme_constant_override("margin_bottom", 8)
	$Center/Panel/Margin.add_theme_constant_override("margin_left", 12)
	$Center/Panel/Margin.add_theme_constant_override("margin_right", 12)
	panel.add_theme_stylebox_override("panel", _style(Color(0.16, 0.11, 0.07, 0.97), Color(0.70, 0.52, 0.22), 4, 10))
	vbox.add_theme_constant_override("separation", 4)
	title_label.add_theme_color_override("font_color", GOLD)
	title_label.add_theme_font_size_override("font_size", 22)
	capital_label.visible = false
	for l in [capital_label, flavor_label, gold_label, army_label]:
		l.add_theme_color_override("font_color", PARCH)
	buildings_list.visible = false
	# Baner właściciela
	_owner_banner = Label.new()
	_owner_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_owner_banner.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_owner_banner)
	vbox.move_child(_owner_banner, flavor_label.get_index())
	flavor_label.visible = false
	# Widok miasta
	_town_view = TownView.new()
	_town_view.building_clicked.connect(_on_building_clicked)
	vbox.add_child(_town_view)
	vbox.move_child(_town_view, buildings_list.get_index())
	# Szczegóły wybranego budynku
	_detail_box = PanelContainer.new()
	_detail_box.add_theme_stylebox_override("panel", _style(Color(0.24, 0.18, 0.11), Color(0.55, 0.42, 0.20), 2, 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_name = Label.new()
	_detail_name.add_theme_color_override("font_color", GOLD)
	_detail_name.add_theme_font_size_override("font_size", 18)
	_detail_desc = Label.new()
	_detail_desc.add_theme_color_override("font_color", PARCH)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_cost = Label.new()
	_detail_cost.add_theme_color_override("font_color", Color(0.85, 0.80, 0.65))
	col.add_child(_detail_name); col.add_child(_detail_desc); col.add_child(_detail_cost)
	h.add_child(col)
	_detail_btn = Button.new()
	_detail_btn.custom_minimum_size = Vector2(150, 36)
	_detail_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_button(_detail_btn)
	_detail_btn.pressed.connect(func(): if _owned and _selected != "": build_requested.emit(_selected))
	h.add_child(_detail_btn)
	_detail_box.add_child(h)
	vbox.add_child(_detail_box)
	vbox.move_child(_detail_box, _town_view.get_index() + 1)
	# Rekrutacja
	_recruit_title = Label.new()
	_recruit_title.text = "— Rekrutacja (Koszary) —"
	_recruit_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recruit_title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(_recruit_title)
	vbox.move_child(_recruit_title, recruit_row.get_index())
	recruit_row.add_theme_constant_override("separation", 6)
	# Rząd rekrutacji w poziomym ScrollContainerze — nie rozpycha panelu na boki
	var rs := ScrollContainer.new()
	rs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rs.custom_minimum_size = Vector2(0, 96)
	rs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ri := recruit_row.get_index()
	vbox.remove_child(recruit_row)
	rs.add_child(recruit_row)
	vbox.add_child(rs)
	vbox.move_child(rs, ri)
	for b in recruit_row.get_children():
		if b is Button:
			_style_button(b)
			_add_unit_icon(b)
	_style_button(leave_button)
	leave_button.custom_minimum_size = Vector2(0, 32)


func open_city(
	region_id: String,
	region_name: String,
	capital: String,
	owned_by_player: bool,
	gold: int,
	income: int,
	army_summary: String,
	buildings: Dictionary = {},
	defs: Dictionary = {}
) -> void:
	_owned = owned_by_player
	_defs = defs
	var cs := get_tree().current_scene
	if _town_view and cs and cs.get("player_faction") != null:
		_town_view.set_faction(str(cs.get("player_faction")))
	title_label.text = "⚜ %s — %s ⚜" % [region_name, capital]
	capital_label.text = "Stolica: %s" % capital
	flavor_label.text = "id: %s" % region_id
	if owned_by_player:
		_owner_banner.text = "Twój zamek — możesz budować i rekrutować"
		_owner_banner.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	else:
		_owner_banner.text = "Zamek obcy — tylko podgląd (zdobądź go, by budować)"
		_owner_banner.add_theme_color_override("font_color", Color(1.0, 0.45, 0.40))
	visible = true
	refresh_economy(gold, income, army_summary, buildings)


func refresh_economy(gold: int, income: int, army_summary: String, buildings: Dictionary = {}) -> void:
	if not visible:
		return
	gold_label.text = "Złoto: %d  ·  Drewno: %d  ·  Ruda: %d  ·  dochód zamku: +%d zł / turę" % [gold, res_wood, res_ore, income if _owned else 0]
	army_label.text = "Armia bohatera: %s" % army_summary
	if not buildings.is_empty() or not _owned:
		_rebuild_buildings(gold, buildings)


func _rebuild_buildings(gold: int, buildings: Dictionary) -> void:
	_gold = gold
	_buildings = buildings
	_town_view.defs = _defs
	_town_view.buildings = buildings if _owned else {}
	_town_view.owned = _owned
	if not _defs.has(_selected) and not _defs.is_empty():
		_selected = _defs.keys()[0]
	_town_view.selected = _selected
	_town_view.queue_redraw()
	_update_detail()
	var k: int = int(buildings.get("koszary", 0))
	recruit_row.visible = _owned
	recruit_row.get_parent().visible = _owned
	_recruit_title.visible = _owned
	_recruit_title.text = "— Rekrutacja (Koszary poz. %d) —" % k
	if not _owned:
		return
	recruit_row.get_node("RecruitPiechota").disabled = k < 1
	recruit_row.get_node("RecruitLucznicy").disabled = k < 2
	recruit_row.get_node("RecruitJazda").disabled = k < 3
	var M = preload("res://scripts/main.gd")
	for b in recruit_row.get_children():
		if str(b.name).begins_with("Recruit_"):
			b.disabled = k < int(M.UNIT_BARRACKS_LEVEL.get(str(b.name).trim_prefix("Recruit_"), 1))


func _update_detail() -> void:
	if not _owned:
		_detail_name.text = "Budynki ukryte"
		_detail_desc.text = "Budynki widoczne tylko w twoich zamkach."
		_detail_cost.text = ""
		_detail_btn.text = "Niedostępne"
		_detail_btn.disabled = true
		return
	if not _defs.has(_selected):
		_detail_btn.visible = false
		return
	_detail_btn.visible = true
	var def: Dictionary = _defs[_selected]
	var lvl: int = int(_buildings.get(_selected, 0))
	var mx: int = int(def["max"])
	_detail_name.text = "%s — poziom %d/%d" % [def["name"], lvl, mx]
	_detail_desc.text = str(def["desc"])
	if lvl >= mx:
		_detail_cost.text = "Budynek w pełni rozbudowany."
		_detail_btn.text = "Maks."
		_detail_btn.disabled = true
		return
	var cost: int = int(def["costs"][lvl])
	var cw: int = int(def.get("wood", [])[lvl]) if lvl < def.get("wood", []).size() else 0
	var co: int = int(def.get("ore", [])[lvl]) if lvl < def.get("ore", []).size() else 0
	var ctxt := "Koszt: %d zł" % cost
	if cw > 0:
		ctxt += " + %d drewna" % cw
	if co > 0:
		ctxt += " + %d rudy" % co
	var missing := _gold < cost or res_wood < cw or res_ore < co
	if missing:
		ctxt += "  (brak zasobów)"
	_detail_cost.text = ctxt
	_detail_btn.text = "Buduj" if lvl == 0 else "Ulepsz"
	_detail_btn.disabled = missing


func _on_building_clicked(bid: String) -> void:
	_selected = bid
	_town_view.selected = bid
	_town_view.queue_redraw()
	_update_detail()


func close_city() -> void:
	visible = false


func _on_leave() -> void:
	close_city()
	left_city.emit()


func _on_recruit(unit_id: String) -> void:
	if _owned:
		recruit_requested.emit(unit_id)
