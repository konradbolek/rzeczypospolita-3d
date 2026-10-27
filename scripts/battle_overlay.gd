extends Control
## Pełnoekranowa nakładka walki.
## Pole jest Node3D w głównym widoku. SubViewport z own_world_3d, kamerą i światłem
## zawieszał grę przy wejściu w bitwę (renderer 4.7, drugi świat 3D + cienie).

signal closed(player_won: bool, survivors: Array, enemy_survivors: Array)

@onready var field: Node3D = $"../../BattleField"
@onready var battle_view: Control = $BattleView
@onready var status_label: Label = $Top/StatusLabel
@onready var result_box: PanelContainer = $ResultBox
@onready var result_label: Label = $ResultBox/Margin/VBox/ResultLabel
@onready var close_button: Button = $ResultBox/Margin/VBox/CloseButton

var _won: bool = true


func _ready() -> void:
	visible = false
	result_box.visible = false
	field.battle_over.connect(_on_battle_over)
	field.status.connect(_on_status)
	close_button.pressed.connect(_on_close)


func open_battle(title: String = "Walka", player_units: Array = [], is_siege: bool = false, enemy_units: Array = []) -> void:
	visible = true
	result_box.visible = false
	_won = true
	field.visible = true
	field.position = Vector3.ZERO
	field.start_battle(player_units, is_siege, enemy_units)
	status_label.text = title


func _battle_local(screen_pos: Vector2) -> Vector2:
	return screen_pos


func _input(event: InputEvent) -> void:
	if not visible or field == null or not field.is_processing_input():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		field.handle_pointer(event, Vector2.ZERO)
		return
	if event is InputEventMouse:
		if result_box.visible and result_box.get_global_rect().has_point(event.position):
			return
		var box := battle_view.get_global_rect()
		if not box.has_point(event.position):
			return
		field.handle_pointer(event, _battle_local(event.position))
		if event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()


func _on_status(text: String) -> void:
	status_label.text = text


func _on_battle_over(player_won: bool) -> void:
	_won = player_won
	result_box.visible = true
	result_label.text = "Zwycięstwo!" if player_won else "Porażka…"


func _on_close() -> void:
	visible = false
	field.deactivate()
	var survivors: Array = field.get_survivor_unit_ids()
	closed.emit(_won, survivors, field.get_enemy_survivor_unit_ids())
