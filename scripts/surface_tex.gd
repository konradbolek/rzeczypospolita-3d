extends RefCounted
## Powtarzalne tekstury albedo (PNG w assets/textures). Jedna instancja materiału na parę (id, odcień).

const DIR := "res://assets/textures/"
## Tekstury, które same niosą kolor — albedo_color tylko lekko je podbarwia.
const PRECOLORED := {
	"grass": true, "grass_dry": true, "grass_lush": true, "grass_moss": true,
	"dirt": true, "dirt_path": true, "dirt_dark": true,
	"mud": true, "mud_wet": true, "sand": true, "sand_ripples": true,
	"rock": true, "water": true,
	"wood": true, "wood_plank": true, "wood_log": true,
	"stone": true, "stone_brick": true, "stone_rough": true, "stone_block": true,
	"roof": true, "roof_tile": true,
	"foliage": true, "foliage_dark": true,
	"wheat": true, "wheat_field": true, "gold": true, "skin": true,
}
## Ten sam shader, inna bitmapa. Sól (hash heksa / kolor) wybiera wariant.
const VARIANTS := {
	"grass": ["grass", "grass_dry", "grass_lush", "grass_moss"],
	"dirt": ["dirt", "dirt_path", "dirt_dark"],
	"mud": ["mud", "mud_wet"],
	"sand": ["sand", "sand_ripples"],
	"rock": ["rock", "stone_rough"],
	"wood": ["wood", "wood_plank", "wood_log"],
	"stone": ["stone", "stone_brick", "stone_rough", "stone_block"],
	"roof": ["roof", "roof_tile"],
	"foliage": ["foliage", "foliage_dark"],
	"wheat": ["wheat", "wheat_field"],
	"cloth": ["cloth", "cloth_linen", "cloth_wool"],
	"metal": ["metal", "metal_plate", "metal_mail"],
}
const SCALE := {
	"grass": 1.15, "grass_dry": 1.15, "grass_lush": 1.1, "grass_moss": 1.2,
	"dirt": 1.2, "dirt_path": 1.15, "dirt_dark": 1.25,
	"mud": 1.25, "mud_wet": 1.2, "sand": 1.1, "sand_ripples": 1.05,
	"rock": 1.35, "water": 0.85,
	"wood": 1.55, "wood_plank": 2.4, "wood_log": 2.0,
	"stone": 1.15, "stone_brick": 2.6, "stone_rough": 1.8, "stone_block": 2.2,
	"roof": 1.45, "roof_tile": 2.8, "foliage": 1.05, "foliage_dark": 1.05,
	"cloth": 3.4, "cloth_linen": 3.6, "cloth_wool": 3.2,
	"metal": 2.6, "metal_plate": 2.8, "metal_mail": 4.0,
	"skin": 3.8, "wheat": 1.5, "wheat_field": 1.45, "gold": 2.2,
}

static var _tex: Dictionary = {}
static var _mats: Dictionary = {}
## Bitwa: unshaded + UV siatki. Triplanar (osobny shader na każdą bryłę) na Forward+/Metal
## potrafił domalować armię i zakleszczyć następną klatkę.
static var battle_safe := false


static func pick(id: String, salt: int) -> String:
	if not VARIANTS.has(id):
		return id
	var arr: Array = VARIANTS[id]
	if arr.is_empty():
		return id
	return str(arr[absi(salt) % arr.size()])


static func tex(id: String) -> Texture2D:
	if _tex.has(id):
		return _tex[id]
	var path := DIR + id + ".png"
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[id] = t
	return t


## Wymuszone id albo dobór po kolorze / metaliczności. Zwraca {id, tint, scale}.
static func style(col: Color, metal: float = 0.0, surf: String = "") -> Dictionary:
	var base := surf
	if base == "":
		base = _auto(col, metal)
	var id := pick(base, int(round(col.r * 255.0)) * 3 + int(round(col.g * 255.0)) * 5 + int(round(col.b * 255.0)) * 7)
	var scale := float(SCALE.get(id, SCALE.get(base, 1.2)))
	var tint := col
	if PRECOLORED.has(id) or PRECOLORED.has(base):
		# Tekstura jest już zielona / kamienna / dachówkowa — kolor mesha tylko ją przesuwa.
		tint = Color.WHITE.lerp(col, 0.18)
	return {"id": id, "tint": tint, "scale": scale}


static func _auto(col: Color, metal: float) -> String:
	if metal > 0.22:
		return "metal"
	if col.r > 0.72 and col.g > 0.52 and col.b > 0.38 and col.r > col.g and col.g > col.b * 0.85 and col.s < 0.62 and col.v > 0.7:
		return "skin"
	if col.r > 0.72 and col.g > 0.5 and col.b < 0.42 and col.g > col.b * 1.4:
		return "gold"
	if col.s < 0.16 or (col.s < 0.24 and col.v > 0.45 and col.v < 0.92):
		return "stone"
	if col.r > 0.5 and col.g < 0.32 and col.b < 0.26 and col.r > col.g * 2.2:
		return "roof"
	if col.r > col.g and col.g >= col.b * 0.85 and col.b < 0.45 and col.r < 0.78 and col.s > 0.22:
		return "wood"
	if col.g > col.r * 1.25 and col.g > col.b * 1.15 and col.g > 0.22 and col.r < 0.5:
		return "foliage" if col.v < 0.55 else "grass"
	if col.b > col.r and col.b > col.g and col.s > 0.35 and col.v > 0.45 and col.v < 0.75 and col.h > 0.5 and col.h < 0.7 and col.r < 0.25:
		return "water"
	if col.h > 0.10 and col.h < 0.18 and col.v > 0.65 and col.s > 0.35:
		return "wheat"
	return "cloth"


static func material(col: Color, rough: float = 0.84, metal: float = 0.0, emit: float = 0.0, surf: String = "") -> StandardMaterial3D:
	if battle_safe:
		var safe := style(col, 0.0, surf)
		# style() prawie wybiela teksturę. W bitwie kolor sylwetki ma zostać czytelny,
		# ale albedo (płótno, stal, drewno) nadal mnoży barwę. Bez triplanaru.
		var tint: Color = (safe["tint"] as Color).lerp(col, 0.5)
		return unshaded(str(safe["id"]), tint, 1.0)
	var st := style(col, metal, surf)
	var tint: Color = st["tint"]
	var id := str(st["id"])
	var key := "%s:%d:%d:%d:%d:%d:%d" % [
		id, int(tint.r * 255.0), int(tint.g * 255.0), int(tint.b * 255.0),
		int(rough * 100.0), int(metal * 100.0), int(emit * 100.0),
	]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = metal
	var t := tex(id)
	if t != null:
		m.albedo_texture = t
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * float(st["scale"])
		m.uv1_triplanar_sharpness = 1.35
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


## Płaski albedo (UV siatki, bez triplanaru). Miasto i inne małe sceny.
static func shaded(id: String, tint: Color = Color.WHITE, repeats: float = 2.0) -> StandardMaterial3D:
	return _textured(id, tint, repeats, false)


## Bitwa: bez światła, bez cieni, bez triplanaru.
static func unshaded(id: String, tint: Color = Color.WHITE, scale: float = 1.0) -> StandardMaterial3D:
	return _textured(id, tint, scale, true)


static func _textured(id: String, tint: Color, repeats: float, flat_shade: bool) -> StandardMaterial3D:
	var key := "%s:%s:%d:%d:%d:%.2f" % [
		"safe" if flat_shade else "city",
		id,
		int(tint.r * 255.0), int(tint.g * 255.0), int(tint.b * 255.0),
		repeats,
	]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.9
	m.metallic = 0.0
	m.uv1_triplanar = false
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if flat_shade:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var t := tex(id) if id != "" else null
	if t != null:
		m.albedo_texture = t
		m.uv1_scale = Vector3(repeats, repeats, repeats)
	_mats[key] = m
	return m


## Heksy terenu: UV czapy cylindra, bez triplanaru (dużo instancji). Vertex color przyciemnia mgłę.
static func terrain_material(id: String) -> StandardMaterial3D:
	if battle_safe:
		return unshaded(id, Color.WHITE, 1.15)
	var key := "terrain:" + id
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.albedo_texture = tex(id)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.uv1_scale = Vector3(0.92, 1.15, 0.92)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.92
	_mats[key] = m
	return m
