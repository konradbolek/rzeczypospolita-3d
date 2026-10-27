extends Control
## Pełnoekranowa nakładka walki.

signal closed(player_won: bool, survivors: Array, enemy_survivors: Array)

@onready var field: Node2D = $BattleView/BattleField
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
	field.position = Vector2(220, 140)
	field.start_battle(player_units, is_siege, enemy_units)
	status_label.text = title


func _on_status(text: String) -> void:
	status_label.text = text


func _on_battle_over(player_won: bool) -> void:
	_won = player_won
	result_box.visible = true
	result_label.text = "Zwycięstwo!" if player_won else "Porażka…"


func _on_close() -> void:
	visible = false
	var survivors: Array = field.get_survivor_unit_ids()
	closed.emit(_won, survivors, field.get_enemy_survivor_unit_ids())
