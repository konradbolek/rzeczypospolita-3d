extends Node
## Prosty menedżer dźwięku (Autoload "AudioManager"). Brak pliku = cisza, bez crasha.

const DIR := "res://assets/audio/"
const SFX := ["click", "move", "battle_start", "victory", "defeat", "pickup", "levelup", "spell",
	"sfx_sword", "sfx_musket", "sfx_arrow", "sfx_charge", "sfx_shout", "sfx_hurrah", "sfx_roar", "sfx_howl", "sfx_coins"]
const SETTINGS := "user://audio.cfg"

var volume: float = 0.8
var _streams: Dictionary = {}
var _music: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		volume = clampf(float(cfg.get_value("audio", "volume", 0.8)), 0.0, 1.0)
	for n in SFX + ["ambient_map", "music_menu", "music_map", "music_battle"]:
		var s := _load(n)
		if s:
			_streams[n] = s
	_music = AudioStreamPlayer.new()
	add_child(_music)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_apply_volume()


func _load(n: String) -> AudioStream:
	var path := DIR + n + ".wav"
	if not FileAccess.file_exists(path):
		return null
	var s := AudioStreamWAV.load_from_file(path)
	return s


func play(n: String) -> void:
	if not _streams.has(n) or volume <= 0.0:
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[n]
			p.play()
			return


var _track: String = ""
var _music2: AudioStreamPlayer = null


## Ścieżki: "menu", "map", "battle" (płynne przejście). Brak pliku = stary ambient.
func play_track(t: String) -> void:
	var key := "music_" + t
	if not _streams.has(key):
		play_music()
		return
	if _track == t and _music.playing:
		return
	_track = t
	var s: AudioStreamWAV = _streams[key]
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	if _music2 == null:
		_music2 = AudioStreamPlayer.new()
		add_child(_music2)
	var old := _music
	_music = _music2
	_music2 = old
	_music.stream = s
	_music.volume_db = -40.0
	_music.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_music, "volume_db", -6.0, 1.2)
	if old.playing:
		tw.tween_property(old, "volume_db", -40.0, 1.2)
		tw.chain().tween_callback(old.stop)


func play_music() -> void:
	if not _streams.has("ambient_map") or _music.playing:
		return
	var s: AudioStreamWAV = _streams["ambient_map"]
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	_music.stream = s
	_music.volume_db = -8.0
	_music.play()


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.save(SETTINGS)


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus, volume <= 0.0)
