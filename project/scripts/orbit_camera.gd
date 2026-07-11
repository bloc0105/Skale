extends Camera3D

var target   := Vector3.ZERO
var distance := 12.0
var yaw      := 45.0
var pitch    := -30.0

var _orbiting := false
var _panning  := false
var _last_mouse := Vector2.ZERO

func _ready() -> void:
	_update_transform()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_MIDDLE:
				_orbiting = mb.pressed
				_last_mouse = mb.position
			MOUSE_BUTTON_RIGHT:
				_panning = mb.pressed
				_last_mouse = mb.position
			MOUSE_BUTTON_WHEEL_UP:
				distance = max(1.0, distance * 0.9)
				_update_transform()
			MOUSE_BUTTON_WHEEL_DOWN:
				distance = min(200.0, distance * 1.1)
				_update_transform()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var delta := mm.position - _last_mouse
		_last_mouse = mm.position

		if _orbiting:
			yaw   -= delta.x * 0.3
			pitch  = clamp(pitch - delta.y * 0.3, -89.0, -1.0)
			_update_transform()
		elif _panning:
			var right := transform.basis.x
			var scale := distance * 0.002
			target -= right    * delta.x * scale
			target += Vector3.UP * delta.y * scale
			_update_transform()

func _update_transform() -> void:
	var r_yaw   := deg_to_rad(yaw)
	var r_pitch := deg_to_rad(pitch)
	var offset  := Vector3(
		cos(r_pitch) * sin(r_yaw),
		sin(r_pitch),
		cos(r_pitch) * cos(r_yaw)
	) * distance
	position = target + offset
	look_at(target, Vector3.UP)
