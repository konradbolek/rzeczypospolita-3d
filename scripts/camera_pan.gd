extends Camera2D
## Pan WASD / strzałki + zoom kółkiem.

@export var pan_speed: float = 600.0
@export var zoom_step: float = 0.1
@export var zoom_min: float = 0.2
@export var zoom_max: float = 2.5


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("pan_left") or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_action_pressed("pan_right") or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_action_pressed("pan_up") or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_action_pressed("pan_down") or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	var v3 := get_parent().get_node_or_null("World3D")
	if v3 and dir != Vector2.ZERO:
		var y: float = v3.yaw
		dir = Vector2(cos(y) * dir.x + sin(y) * dir.y, -sin(y) * dir.x + cos(y) * dir.y)
	if dir != Vector2.ZERO:
		position += dir.normalized() * pan_speed * delta / zoom.x


var _touches: Dictionary = {} # index -> Vector2
var _pinch_d: float = 0.0


func _unhandled_input(event: InputEvent) -> void:
	# Dotyk (iOS): przeciąganie jednym palcem = przesuwanie, dwa palce = zoom
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_d = 0.0
		return
	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			if event.relative.length() > 2.0:
				position -= event.relative / zoom.x * 0.5
		elif _touches.size() >= 2:
			var k: Array = _touches.keys()
			var d: float = (_touches[k[0]] as Vector2).distance_to(_touches[k[1]])
			if _pinch_d > 0.0:
				_set_zoom(zoom.x * d / _pinch_d)
			_pinch_d = d
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom.x + zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom.x - zoom_step)


func _set_zoom(value: float) -> void:
	var z := clampf(value, zoom_min, zoom_max)
	zoom = Vector2(z, z)
