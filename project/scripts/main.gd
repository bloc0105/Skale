extends Node

# ── Mode state ───────────────────────────────────────────────────────────────
enum Mode { DESIGN, RUN, PAUSED }
var _mode := Mode.DESIGN

# ── Scene nodes ──────────────────────────────────────────────────────────────
var _sim:    SkaleSimulation
var _camera: Camera3D

# ── UI nodes ─────────────────────────────────────────────────────────────────
var _btn_play:  Button
var _btn_pause: Button
var _btn_stop:  Button

var _prop_panel:       Control
var _prop_label:       Label
var _prop_pos_x:       SpinBox
var _prop_pos_y:       SpinBox
var _prop_pos_z:       SpinBox
var _prop_size_x:      SpinBox
var _prop_size_y:      SpinBox
var _prop_size_z:      SpinBox
var _prop_size_row_x:  HBoxContainer
var _prop_size_row_y:  HBoxContainer
var _prop_size_row_z:  HBoxContainer
var _prop_radius:      SpinBox
var _prop_height:      SpinBox
var _prop_radius_row:  HBoxContainer
var _prop_height_row:  HBoxContainer
var _prop_density:     SpinBox
var _prop_fixed:       CheckBox
var _prop_friction:    SpinBox
var _prop_restitution: SpinBox

# ── Selection ────────────────────────────────────────────────────────────────
var _selected: SkaleBody = null
var _body_counter  := 0
var _joint_counter := 0
var _updating_props := false   # guard against feedback loops
var _show_joints   := true

# ── Joint creation state ──────────────────────────────────────────────────────
enum JointMode { NONE, PICKING_AXIS, SELECTING_A, SELECTING_B }
var _joint_mode   := JointMode.NONE
var _joint_body_a: SkaleBody = null
var _joint_axis   := Vector3(0, 0, 1)   # default: Z axis, pendulum swings in XY
var _joint_type   := "hinge"            # "hinge", "slider", "spring", or "weld"
var _status_label: Label
var _axis_buttons: HBoxContainer

# ── Colors ───────────────────────────────────────────────────────────────────
const COLOR_DYNAMIC  := Color(0.30, 0.55, 1.00)
const COLOR_FIXED    := Color(0.45, 0.45, 0.50)
const COLOR_SELECTED := Color(1.00, 0.70, 0.20)
const COLOR_FLOOR    := Color(0.25, 0.25, 0.30)


func _ready() -> void:
	_build_world()
	_build_ui()


func _process(_delta: float) -> void:
	_update_slider_visuals()
	if _mode == Mode.RUN:
		_update_spring_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			match key.keycode:
				KEY_DELETE:
					_delete_selected()
				KEY_ESCAPE:
					if _joint_mode != JointMode.NONE:
						_joint_mode = JointMode.NONE
						_joint_body_a = null
						_status_label.text = ""
						_axis_buttons.visible = false
						_restore_body_colors()


# ─────────────────────────────────────────────────────────────────────────────
# World
# ─────────────────────────────────────────────────────────────────────────────

func _build_world() -> void:
	# Directional light
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 1.2
	add_child(light)

	# Ambient environment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.12, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.4)
	env.ambient_light_energy = 0.6
	env_node.environment = env
	add_child(env_node)

	# Orbit camera
	_camera = Camera3D.new()
	_camera.set_script(load("res://scripts/orbit_camera.gd"))
	add_child(_camera)

	# Physics simulation node
	_sim = SkaleSimulation.new()
	add_child(_sim)

	# Default floor body (always present, not selectable)
	_add_floor()

	# World axis indicator at origin
	_build_axis()


func _build_axis() -> void:
	# Three thin unlit bars: X=red, Y=green, Z=blue, each 1m long from origin.
	var axes := [
		[Vector3(0.5, 0, 0), Vector3(1.0, 0.02, 0.02), Color(1.0, 0.2, 0.2)],
		[Vector3(0, 0.5, 0), Vector3(0.02, 1.0, 0.02), Color(0.2, 1.0, 0.2)],
		[Vector3(0, 0, 0.5), Vector3(0.02, 0.02, 1.0), Color(0.2, 0.4, 1.0)],
	]
	for entry in axes:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = entry[1]
		mi.mesh = bm
		mi.position = entry[0]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = entry[2]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		add_child(mi)


func _add_floor() -> void:
	var body := SkaleBody.new()
	body.name = "Floor"
	body.box_size = Vector3(20.0, 0.2, 20.0)
	body.density = 1000.0
	body.set_fixed(true)
	body.position = Vector3(0, -0.1, 0)
	_sim.add_child(body)
	_attach_mesh(body, COLOR_FLOOR)


# ─────────────────────────────────────────────────────────────────────────────
# Body helpers
# ─────────────────────────────────────────────────────────────────────────────

func _attach_mesh(body: SkaleBody, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _make_mesh(body)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	body.add_child(mi)


func _make_mesh(body: SkaleBody) -> Mesh:
	match body.shape_type:
		SkaleBody.CYLINDER:
			var m := CylinderMesh.new()
			m.top_radius    = body.radius
			m.bottom_radius = body.radius
			m.height        = body.height
			return m
		SkaleBody.SPHERE:
			var m := SphereMesh.new()
			m.radius = body.radius
			m.height = body.radius * 2.0
			return m
		_: # BOX
			var m := BoxMesh.new()
			m.size = body.box_size
			return m


func _make_picker_shape(body: SkaleBody) -> Shape3D:
	match body.shape_type:
		SkaleBody.CYLINDER:
			var s := CylinderShape3D.new()
			s.radius = body.radius
			s.height = body.height
			return s
		SkaleBody.SPHERE:
			var s := SphereShape3D.new()
			s.radius = body.radius
			return s
		_: # BOX
			var s := BoxShape3D.new()
			s.size = body.box_size
			return s


func _attach_picker(body: SkaleBody) -> void:
	var area := Area3D.new()
	area.name = "Picker"
	var cs := CollisionShape3D.new()
	cs.shape = _make_picker_shape(body)
	area.add_child(cs)
	body.add_child(area)
	area.input_event.connect(_on_body_clicked.bind(body))


func _set_mesh_color(body: SkaleBody, color: Color) -> void:
	var mi := body.get_node_or_null("Mesh") as MeshInstance3D
	if mi and mi.material_override:
		(mi.material_override as StandardMaterial3D).albedo_color = color


func _rebuild_mesh(body: SkaleBody) -> void:
	var mi := body.get_node_or_null("Mesh") as MeshInstance3D
	if mi:
		mi.mesh = _make_mesh(body)

	var picker := body.get_node_or_null("Picker") as Area3D
	if picker:
		var cs := picker.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if cs:
			cs.shape = _make_picker_shape(body)


# ─────────────────────────────────────────────────────────────────────────────
# UI
# ─────────────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	_build_toolbar(root)
	_build_props_panel(root)


func _build_toolbar(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchor(SIDE_LEFT,   0); panel.set_offset(SIDE_LEFT,   0)
	panel.set_anchor(SIDE_RIGHT,  1); panel.set_offset(SIDE_RIGHT,  0)
	panel.set_anchor(SIDE_TOP,    0); panel.set_offset(SIDE_TOP,    0)
	panel.set_anchor(SIDE_BOTTOM, 0); panel.set_offset(SIDE_BOTTOM, 44)
	root.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)

	# Spacer
	var m := Label.new(); m.text = "  "; hbox.add_child(m)

	# File buttons
	var btn_save := Button.new()
	btn_save.text = "Save"
	btn_save.tooltip_text = "Save the current scene to a .skale file."
	btn_save.pressed.connect(_show_save_dialog)
	hbox.add_child(btn_save)

	var btn_load := Button.new()
	btn_load.text = "Load"
	btn_load.tooltip_text = "Load a .skale scene file. Clears the current scene first."
	btn_load.pressed.connect(_show_load_dialog)
	hbox.add_child(btn_load)

	hbox.add_child(VSeparator.new())

	# Add-body buttons
	var btn_box := Button.new()
	btn_box.text = "+ Box"
	btn_box.tooltip_text = "Add a box body. Default 1×1×1 m, density 1000 kg/m³.\nEdit size and properties in the panel on the right."
	btn_box.pressed.connect(_on_add_box)
	hbox.add_child(btn_box)

	var btn_cyl := Button.new()
	btn_cyl.text = "+ Cylinder"
	btn_cyl.tooltip_text = "Add a cylinder body. Default radius 0.5 m, height 1 m.\nChrono aligns the cylinder axis with Y."
	btn_cyl.pressed.connect(_on_add_cylinder)
	hbox.add_child(btn_cyl)

	var btn_sph := Button.new()
	btn_sph.text = "+ Sphere"
	btn_sph.tooltip_text = "Add a sphere body. Default radius 0.5 m."
	btn_sph.pressed.connect(_on_add_sphere)
	hbox.add_child(btn_sph)

	var btn_hinge := Button.new()
	btn_hinge.text = "+ Hinge"
	btn_hinge.tooltip_text = "Revolute joint — one rotational DOF around a fixed axis.\nWorkflow: pick axis (X/Y/Z) → click pivot body → click swinging body.\nExpected: swinging body rotates freely around the axis; pivot body stays fixed."
	btn_hinge.pressed.connect(_on_add_hinge)
	hbox.add_child(btn_hinge)

	var btn_slider := Button.new()
	btn_slider.text = "+ Slider"
	btn_slider.tooltip_text = "Prismatic joint — one translational DOF along a fixed axis.\nWorkflow: pick axis → click guide body (rail) → click sliding body.\nExpected: sliding body moves only along the chosen axis; no rotation."
	btn_slider.pressed.connect(_on_add_slider)
	hbox.add_child(btn_slider)

	var btn_spring := Button.new()
	btn_spring.text = "+ Spring"
	btn_spring.tooltip_text = "Spring-damper between two bodies.\nWorkflow: click anchor body → click hanging body.\nRest length is set from initial distance. Default stiffness 2000 N/m, damping 10 Ns/m.\nExpected: hanging body oscillates up and down."
	btn_spring.pressed.connect(_on_add_spring)
	hbox.add_child(btn_spring)

	var btn_weld := Button.new()
	btn_weld.text = "+ Weld"
	btn_weld.tooltip_text = "Fixed joint — locks two bodies together at their current relative pose.\nWorkflow: click first body → click second body.\nExpected: the two bodies move as one rigid object."
	btn_weld.pressed.connect(_on_add_weld)
	hbox.add_child(btn_weld)

	var btn_motor := Button.new()
	btn_motor.text = "+ Motor"
	btn_motor.tooltip_text = "Rotational motor — drives a body at constant angular speed (default 1 rad/s ≈ 9.5 RPM).\nWorkflow: pick rotation axis → click stator body (fixed reference) → click driven body.\nExpected: driven body rotates continuously around the axis."
	btn_motor.pressed.connect(_on_add_motor)
	hbox.add_child(btn_motor)

	var btn_actuator := Button.new()
	btn_actuator.text = "+ Actuator"
	btn_actuator.tooltip_text = "Linear actuator — drives a body at constant speed along an axis (default 0.5 m/s).\nWorkflow: pick slide axis → click anchor body → click moving body.\nExpected: moving body translates along the axis at constant speed."
	btn_actuator.pressed.connect(_on_add_actuator)
	hbox.add_child(btn_actuator)

	var btn_ball := Button.new()
	btn_ball.text = "+ Ball"
	btn_ball.tooltip_text = "Ball (spherical) joint — 3 rotational DOFs, no translation.\nWorkflow: click socket body → click ball body.\nExpected: ball body can rotate freely in any direction around the anchor point but cannot move away from it."
	btn_ball.pressed.connect(_on_add_ball)
	hbox.add_child(btn_ball)

	_axis_buttons = HBoxContainer.new()
	_axis_buttons.visible = false
	_axis_buttons.add_theme_constant_override("separation", 2)
	var axis_lbl := Label.new(); axis_lbl.text = " Axis:"
	_axis_buttons.add_child(axis_lbl)
	for axis_name in ["X", "Y", "Z"]:
		var btn := Button.new()
		btn.text = axis_name
		btn.toggle_mode = true
		btn.pressed.connect(_on_axis_picked.bind(axis_name))
		_axis_buttons.add_child(btn)
	hbox.add_child(_axis_buttons)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hbox.add_child(_status_label)

	hbox.add_child(VSeparator.new())

	# Playback
	_btn_play = Button.new()
	_btn_play.text = "▶  Play"
	_btn_play.tooltip_text = "Start the physics simulation. Bodies begin moving under gravity and constraints.\nThe scene cannot be edited while running.\nIf paused, resumes from the paused state."
	_btn_play.pressed.connect(_on_play)
	hbox.add_child(_btn_play)

	_btn_pause = Button.new()
	_btn_pause.text = "⏸  Pause"
	_btn_pause.tooltip_text = "Freeze the simulation at the current instant.\nPress Play to resume from this point."
	_btn_pause.disabled = true
	_btn_pause.pressed.connect(_on_pause)
	hbox.add_child(_btn_pause)

	_btn_stop = Button.new()
	_btn_stop.text = "⏹  Stop"
	_btn_stop.tooltip_text = "End the simulation and reset all bodies to their design positions.\nThe scene becomes editable again."
	_btn_stop.disabled = true
	_btn_stop.pressed.connect(_on_stop)
	hbox.add_child(_btn_stop)

	hbox.add_child(VSeparator.new())

	var btn_joints := Button.new()
	btn_joints.text = "Joints"
	btn_joints.tooltip_text = "Toggle visibility of joint gizmos (spheres, cylinders, etc.).\nHiding them gives a clean view of just the bodies.\nPhysics are unaffected — joints still work when hidden."
	btn_joints.toggle_mode = true
	btn_joints.button_pressed = true
	btn_joints.toggled.connect(_on_toggle_joints)
	hbox.add_child(btn_joints)


func _build_props_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchor(SIDE_LEFT,   1); panel.set_offset(SIDE_LEFT,   -230)
	panel.set_anchor(SIDE_RIGHT,  1); panel.set_offset(SIDE_RIGHT,  0)
	panel.set_anchor(SIDE_TOP,    0); panel.set_offset(SIDE_TOP,    44)
	panel.set_anchor(SIDE_BOTTOM, 1); panel.set_offset(SIDE_BOTTOM, 0)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Properties"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_prop_label = Label.new()
	_prop_label.text = "No body selected"
	vbox.add_child(_prop_label)

	_prop_panel = VBoxContainer.new()
	_prop_panel.visible = false
	vbox.add_child(_prop_panel)

	_prop_pos_x = _add_spinbox_row(_prop_panel, "Pos X", -50.0, 50.0)
	_prop_pos_x.tooltip_text = "X position of the body in world space (metres)."
	_prop_pos_y = _add_spinbox_row(_prop_panel, "Pos Y", -50.0, 50.0)
	_prop_pos_y.tooltip_text = "Y position of the body in world space (metres). Y is up."
	_prop_pos_z = _add_spinbox_row(_prop_panel, "Pos Z", -50.0, 50.0)
	_prop_pos_z.tooltip_text = "Z position of the body in world space (metres)."

	_prop_panel.add_child(HSeparator.new())

	_prop_size_x = _add_spinbox_row(_prop_panel, "Size X", 0.1, 20.0)
	_prop_size_x.tooltip_text = "Width of the box along the X axis (metres)."
	_prop_size_row_x = _prop_panel.get_child(_prop_panel.get_child_count() - 1)
	_prop_size_y = _add_spinbox_row(_prop_panel, "Size Y", 0.1, 20.0)
	_prop_size_y.tooltip_text = "Height of the box along the Y axis (metres)."
	_prop_size_row_y = _prop_panel.get_child(_prop_panel.get_child_count() - 1)
	_prop_size_z = _add_spinbox_row(_prop_panel, "Size Z", 0.1, 20.0)
	_prop_size_z.tooltip_text = "Depth of the box along the Z axis (metres)."
	_prop_size_row_z = _prop_panel.get_child(_prop_panel.get_child_count() - 1)
	_prop_radius = _add_spinbox_row(_prop_panel, "Radius", 0.05, 10.0)
	_prop_radius.tooltip_text = "Radius of the cylinder or sphere (metres)."
	_prop_radius_row = _prop_panel.get_child(_prop_panel.get_child_count() - 1)
	_prop_height = _add_spinbox_row(_prop_panel, "Height", 0.1, 20.0)
	_prop_height.tooltip_text = "Height of the cylinder along its Y axis (metres)."
	_prop_height_row = _prop_panel.get_child(_prop_panel.get_child_count() - 1)
	_prop_density = _add_spinbox_row(_prop_panel, "Density", 1.0, 100000.0)
	_prop_density.step = 10.0
	_prop_density.tooltip_text = "Mass per unit volume (kg/m³). Mass = density × volume.\nWater ≈ 1000, steel ≈ 7800, wood ≈ 500."

	var fixed_row := HBoxContainer.new()
	var fixed_lbl := Label.new(); fixed_lbl.text = "Fixed"
	_prop_fixed = CheckBox.new()
	_prop_fixed.tooltip_text = "When checked, the body is pinned in place and cannot move.\nUse for walls, floors, anchor points, and motor stators."
	fixed_row.add_child(fixed_lbl)
	fixed_row.add_child(_prop_fixed)
	_prop_panel.add_child(fixed_row)

	_prop_friction    = _add_spinbox_row(_prop_panel, "Friction",    0.0, 2.0)
	_prop_friction.step = 0.05
	_prop_friction.tooltip_text = "Surface friction coefficient (dimensionless).\n0 = frictionless ice, 0.5 = default, 1.0+ = very grippy rubber."
	_prop_restitution = _add_spinbox_row(_prop_panel, "Restitution", 0.0, 1.0)
	_prop_restitution.step = 0.05
	_prop_restitution.tooltip_text = "Bounciness on collision (0–1).\n0 = no bounce (clay), 0.5 = moderate, 1.0 = perfectly elastic (ideal ball)."

	# Wire signals
	_prop_pos_x.value_changed.connect(func(_v): _apply_props())
	_prop_pos_y.value_changed.connect(func(_v): _apply_props())
	_prop_pos_z.value_changed.connect(func(_v): _apply_props())
	_prop_size_x.value_changed.connect(func(_v): _apply_props())
	_prop_size_y.value_changed.connect(func(_v): _apply_props())
	_prop_size_z.value_changed.connect(func(_v): _apply_props())
	_prop_radius.value_changed.connect(func(_v): _apply_props())
	_prop_height.value_changed.connect(func(_v): _apply_props())
	_prop_density.value_changed.connect(func(_v): _apply_props())
	_prop_fixed.toggled.connect(func(_v): _apply_props())
	_prop_friction.value_changed.connect(func(_v): _apply_props())
	_prop_restitution.value_changed.connect(func(_v): _apply_props())


func _add_spinbox_row(parent: Control, label_text: String, min_v: float, max_v: float) -> SpinBox:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(90, 0)
	var sb := SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.step = 0.1
	sb.custom_minimum_size = Vector2(80, 0)
	row.add_child(lbl)
	row.add_child(sb)
	parent.add_child(row)
	return sb


# ─────────────────────────────────────────────────────────────────────────────
# Selection
# ─────────────────────────────────────────────────────────────────────────────

func _on_body_clicked(_cam, event: InputEvent, _pos, _norm, _idx, body: SkaleBody) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not (mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT):
		return

	if _joint_mode == JointMode.SELECTING_A:
		_joint_body_a = body
		_joint_mode = JointMode.SELECTING_B
		_set_mesh_color(body, Color(1.0, 0.35, 0.35))
		match _joint_type:
			"hinge":    _status_label.text = "  Click swinging body..."
			"slider":   _status_label.text = "  Click sliding body..."
			"spring":   _status_label.text = "  Click hanging body..."
			"weld":     _status_label.text = "  Click body to weld..."
			"motor":    _status_label.text = "  Click driven body..."
			"actuator": _status_label.text = "  Click moving body..."
			"ball":     _status_label.text = "  Click pivoting body..."
	elif _joint_mode == JointMode.SELECTING_B:
		if body != _joint_body_a:
			match _joint_type:
				"hinge":    _create_hinge(_joint_body_a, body)
				"slider":   _create_slider(_joint_body_a, body)
				"spring":   _create_spring(_joint_body_a, body)
				"weld":     _create_weld(_joint_body_a, body)
				"motor":    _create_motor(_joint_body_a, body)
				"actuator": _create_actuator(_joint_body_a, body)
				"ball":     _create_ball(_joint_body_a, body)
		_joint_mode = JointMode.NONE
		_joint_body_a = null
		_status_label.text = ""
		_axis_buttons.visible = false
		_restore_body_colors()
	else:
		_select(body)


func _select(body: SkaleBody) -> void:
	if _selected and is_instance_valid(_selected):
		var col := COLOR_FIXED if _selected.get_fixed() else COLOR_DYNAMIC
		_set_mesh_color(_selected, col)

	_selected = body

	if body:
		_set_mesh_color(body, COLOR_SELECTED)
		_prop_label.text = body.name
		_prop_panel.visible = true
		_load_props()
	else:
		_prop_label.text = "No body selected"
		_prop_panel.visible = false


func _load_props() -> void:
	if not _selected:
		return
	_updating_props = true
	_prop_pos_x.value          = _selected.position.x
	_prop_pos_y.value          = _selected.position.y
	_prop_pos_z.value          = _selected.position.z
	_prop_size_x.value         = _selected.box_size.x
	_prop_size_y.value         = _selected.box_size.y
	_prop_size_z.value         = _selected.box_size.z
	_prop_radius.value         = _selected.radius
	_prop_height.value         = _selected.height
	_prop_density.value        = _selected.density
	_prop_fixed.button_pressed = _selected.get_fixed()
	_prop_friction.value       = _selected.friction
	_prop_restitution.value    = _selected.restitution
	_update_shape_rows(_selected.shape_type)
	_updating_props = false


func _update_shape_rows(shape_type: int) -> void:
	var is_box := shape_type == SkaleBody.BOX
	var is_cyl := shape_type == SkaleBody.CYLINDER
	_prop_size_row_x.visible = is_box
	_prop_size_row_y.visible = is_box
	_prop_size_row_z.visible = is_box
	_prop_radius_row.visible = not is_box
	_prop_height_row.visible = is_cyl


func _apply_props() -> void:
	if _updating_props or not _selected or _mode != Mode.DESIGN:
		return
	_selected.position    = Vector3(_prop_pos_x.value, _prop_pos_y.value, _prop_pos_z.value)
	_selected.box_size    = Vector3(_prop_size_x.value, _prop_size_y.value, _prop_size_z.value)
	_selected.radius      = _prop_radius.value
	_selected.height      = _prop_height.value
	_selected.density     = _prop_density.value
	_selected.set_fixed(_prop_fixed.button_pressed)
	_selected.friction    = _prop_friction.value
	_selected.restitution = _prop_restitution.value
	_rebuild_mesh(_selected)


# ─────────────────────────────────────────────────────────────────────────────
# Toolbar actions
# ─────────────────────────────────────────────────────────────────────────────

func _on_add_hinge() -> void:
	if _mode != Mode.DESIGN:
		return
	_joint_type = "hinge"
	_joint_mode = JointMode.PICKING_AXIS
	_joint_body_a = null
	_axis_buttons.visible = true
	_status_label.text = "  Pick swing axis, then click pivot body..."


func _on_add_slider() -> void:
	if _mode != Mode.DESIGN:
		return
	_joint_type = "slider"
	_joint_mode = JointMode.PICKING_AXIS
	_joint_body_a = null
	_axis_buttons.visible = true
	_status_label.text = "  Pick slide axis, then click guide body (rail)..."


func _on_add_weld() -> void:
	if _mode != Mode.DESIGN:
		return
	_joint_type = "weld"
	_joint_mode = JointMode.SELECTING_A
	_joint_body_a = null
	_axis_buttons.visible = false
	_status_label.text = "  Click first body to weld..."


func _on_add_spring() -> void:
	if _mode != Mode.DESIGN:
		return
	_joint_type = "spring"
	_joint_mode = JointMode.SELECTING_A   # no axis needed
	_joint_body_a = null
	_axis_buttons.visible = false
	_status_label.text = "  Click anchor body (fixed end)..."
	# Un-press all axis buttons
	for i in range(1, _axis_buttons.get_child_count()):
		var btn := _axis_buttons.get_child(i) as Button
		if btn:
			btn.button_pressed = false


func _on_add_motor() -> void:
	if _mode != Mode.DESIGN:
		return
	_joint_type = "motor"
	_joint_mode = JointMode.PICKING_AXIS
	_joint_body_a = null
	_axis_buttons.visible = true
	_status_label.text = "  Pick rotation axis, then click stator body..."


func _on_add_actuator() -> void:
	if _mode != Mode.DESIGN:
		return
	_joint_type = "actuator"
	_joint_mode = JointMode.PICKING_AXIS
	_joint_body_a = null
	_axis_buttons.visible = true
	_status_label.text = "  Pick slide axis, then click anchor body..."


func _on_add_ball() -> void:
	if _mode != Mode.DESIGN:
		return
	_joint_type = "ball"
	_joint_mode = JointMode.SELECTING_A
	_joint_body_a = null
	_axis_buttons.visible = false
	_status_label.text = "  Click socket body..."


func _on_axis_picked(axis_name: String) -> void:
	match axis_name:
		"X": _joint_axis = Vector3(1, 0, 0)
		"Y": _joint_axis = Vector3(0, 1, 0)
		"Z": _joint_axis = Vector3(0, 0, 1)
	# Press only the chosen button
	var names := ["X", "Y", "Z"]
	for i in range(names.size()):
		var btn := _axis_buttons.get_child(i + 1) as Button
		if btn:
			btn.button_pressed = (names[i] == axis_name)
	_joint_mode = JointMode.SELECTING_A
	match _joint_type:
		"hinge":    _status_label.text = "  Click pivot body..."
		"motor":    _status_label.text = "  Click stator body..."
		"actuator": _status_label.text = "  Click anchor body..."
		_:          _status_label.text = "  Click guide body (rail)..."


func _create_hinge(body_a: SkaleBody, body_b: SkaleBody) -> void:
	_joint_counter += 1
	var hinge := SkaleHinge.new()
	hinge.name = "Hinge%d" % _joint_counter

	# Anchor at the top face of body_a (the pivot/fixed end).
	var anchor := body_a.position + Vector3(0, body_a.box_size.y * 0.5, 0)
	hinge.anchor = anchor
	hinge.axis   = _joint_axis
	hinge.position = anchor

	_sim.add_child(hinge)
	hinge.body_a_path = hinge.get_path_to(body_a)
	hinge.body_b_path = hinge.get_path_to(body_b)

	_attach_hinge_visual(hinge)
	_select(body_b)


func _attach_hinge_visual(hinge: SkaleHinge) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Visual"
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.75, 0.0)
	mi.material_override = mat
	hinge.add_child(mi)
	mi.visible = _show_joints


func _create_weld(body_a: SkaleBody, body_b: SkaleBody) -> void:
	_joint_counter += 1
	var weld := SkaleFixed.new()
	weld.name = "Weld%d" % _joint_counter
	weld.position = (body_a.position + body_b.position) * 0.5

	_sim.add_child(weld)
	weld.body_a_path = weld.get_path_to(body_a)
	weld.body_b_path = weld.get_path_to(body_b)
	_attach_weld_visual(weld)
	_select(body_b)


func _attach_weld_visual(weld: SkaleFixed) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Visual"
	var box := BoxMesh.new()
	box.size = Vector3(0.15, 0.15, 0.15)
	mi.mesh = box
	mi.rotation_degrees = Vector3(45, 45, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	mi.material_override = mat
	weld.add_child(mi)
	mi.visible = _show_joints


func _create_motor(body_a: SkaleBody, body_b: SkaleBody) -> void:
	_joint_counter += 1
	var motor := SkaleMotor.new()
	motor.name = "Motor%d" % _joint_counter
	motor.axis = _joint_axis
	motor.anchor = body_a.position
	motor.position = body_a.position

	_sim.add_child(motor)
	motor.body_a_path = motor.get_path_to(body_a)
	motor.body_b_path = motor.get_path_to(body_b)
	_attach_motor_visual(motor)
	_select(body_b)


func _attach_motor_visual(motor: SkaleMotor) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Visual"
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.15
	cyl.bottom_radius = 0.15
	cyl.height        = 0.06
	mi.mesh = cyl
	var axis := motor.axis
	if axis.distance_to(Vector3(0, 1, 0)) > 0.01 and axis.distance_to(Vector3(0, -1, 0)) > 0.01:
		mi.basis = Basis(Vector3(0, 1, 0).cross(axis).normalized(),
		                 axis,
		                 axis.cross(Vector3(0, 1, 0).cross(axis).normalized()))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.0)
	mi.material_override = mat
	motor.add_child(mi)
	mi.visible = _show_joints


func _create_actuator(body_a: SkaleBody, body_b: SkaleBody) -> void:
	_joint_counter += 1
	var actuator := SkaleActuator.new()
	actuator.name = "Actuator%d" % _joint_counter
	var anchor := (body_a.position + body_b.position) * 0.5
	actuator.axis = _joint_axis
	actuator.anchor = anchor
	actuator.position = anchor

	_sim.add_child(actuator)
	actuator.body_a_path = actuator.get_path_to(body_a)
	actuator.body_b_path = actuator.get_path_to(body_b)
	_attach_actuator_visual(actuator)
	_select(body_b)


func _attach_actuator_visual(actuator: SkaleActuator) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Visual"
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.06
	cyl.bottom_radius = 0.06
	cyl.height        = 0.5
	mi.mesh = cyl
	var axis := actuator.axis
	if axis.distance_to(Vector3(0, 1, 0)) > 0.01 and axis.distance_to(Vector3(0, -1, 0)) > 0.01:
		mi.basis = Basis(Vector3(0, 1, 0).cross(axis).normalized(),
		                 axis,
		                 axis.cross(Vector3(0, 1, 0).cross(axis).normalized()))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.1)
	mi.material_override = mat
	actuator.add_child(mi)
	mi.visible = _show_joints


func _create_ball(body_a: SkaleBody, body_b: SkaleBody) -> void:
	_joint_counter += 1
	var ball := SkaleBall.new()
	ball.name = "Ball%d" % _joint_counter
	var anchor := (body_a.position + body_b.position) * 0.5
	ball.anchor = anchor
	ball.position = anchor

	_sim.add_child(ball)
	ball.body_a_path = ball.get_path_to(body_a)
	ball.body_b_path = ball.get_path_to(body_b)
	_attach_ball_visual(ball)
	_select(body_b)


func _attach_ball_visual(ball: SkaleBall) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Visual"
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.2, 0.9)
	mi.material_override = mat
	ball.add_child(mi)
	mi.visible = _show_joints


func _create_spring(body_a: SkaleBody, body_b: SkaleBody) -> void:
	_joint_counter += 1
	var spring := SkaleSpring.new()
	spring.name = "Spring%d" % _joint_counter
	spring.position = (body_a.position + body_b.position) * 0.5

	_sim.add_child(spring)
	spring.body_a_path = spring.get_path_to(body_a)
	spring.body_b_path = spring.get_path_to(body_b)

	_attach_spring_visual(spring, body_a.position, body_b.position)
	_select(body_b)


func _attach_spring_visual(spring: SkaleSpring, pt_a: Vector3, pt_b: Vector3) -> void:
	# Draw a thin cylinder from body_a center to body_b center.
	var diff := pt_b - pt_a
	var length := diff.length()
	if length < 0.001:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Visual"
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.04
	cyl.bottom_radius = 0.04
	cyl.height        = length
	mi.mesh = cyl
	# Cylinder default is Y-up; rotate to align with the spring direction.
	var up := Vector3(0, 1, 0)
	var dir := diff.normalized()
	if dir.distance_to(up) > 0.01 and dir.distance_to(-up) > 0.01:
		mi.basis = Basis(up.cross(dir).normalized(), dir,
		                 dir.cross(up.cross(dir).normalized()))
	# Position at midpoint relative to the spring node.
	mi.position = Vector3.ZERO
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.3, 0.9)
	mi.material_override = mat
	spring.add_child(mi)
	mi.visible = _show_joints


func _create_slider(body_a: SkaleBody, body_b: SkaleBody) -> void:
	_joint_counter += 1
	var slider := SkaleSlider.new()
	slider.name = "Slider%d" % _joint_counter

	# Anchor at the midpoint between the two bodies.
	var anchor := (body_a.position + body_b.position) * 0.5
	slider.anchor = anchor
	slider.axis   = _joint_axis
	slider.position = anchor

	_sim.add_child(slider)
	slider.body_a_path = slider.get_path_to(body_a)
	slider.body_b_path = slider.get_path_to(body_b)

	_attach_slider_visual(slider, body_a.position, body_b.position)
	_select(body_b)


func _attach_slider_visual(slider: SkaleSlider, pos_a: Vector3, pos_b: Vector3) -> void:
	var container := Node3D.new()
	container.name = "Visual"

	var local_a := slider.to_local(pos_a)
	var local_b := slider.to_local(pos_b)
	var diff    := local_a - local_b
	var length  := diff.length()

	if length > 0.01:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius    = 0.008
		cyl.bottom_radius = 0.008
		cyl.height        = length
		mi.mesh = cyl
		mi.basis     = _axis_basis(diff)
		mi.position  = (local_a + local_b) * 0.5
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 1, 1)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		container.add_child(mi)

	slider.add_child(container)
	container.visible = _show_joints


# ─────────────────────────────────────────────────────────────────────────────
# Save / Load
# ─────────────────────────────────────────────────────────────────────────────

func _show_save_dialog() -> void:
	if _mode != Mode.DESIGN:
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.add_filter("*.skale", "Skale Scene")
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.current_dir = OS.get_environment("HOME")
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		_save_scene(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2i(800, 500))


func _show_load_dialog() -> void:
	if _mode != Mode.DESIGN:
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.skale", "Skale Scene")
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.current_dir = OS.get_environment("HOME")
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		_load_scene(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2i(800, 500))


func _save_scene(path: String) -> void:
	var bodies := []
	var joints := []

	for i in _sim.get_child_count():
		var child := _sim.get_child(i)

		if child is SkaleBody:
			var body := child as SkaleBody
			if body.name == "Floor":
				continue
			bodies.append({
				"name":       body.name,
				"shape_type": body.shape_type,
				"position":   [body.position.x, body.position.y, body.position.z],
				"box_size":   [body.box_size.x, body.box_size.y, body.box_size.z],
				"radius":     body.radius,
				"height":     body.height,
				"density":    body.density,
				"fixed":      body.get_fixed(),
				"friction":   body.friction,
				"restitution": body.restitution,
			})

		elif child is SkaleHinge:
			var h := child as SkaleHinge
			var na := child.get_node_or_null(h.body_a_path) as SkaleBody
			var nb := child.get_node_or_null(h.body_b_path) as SkaleBody
			joints.append({
				"type":   "hinge",
				"name":   child.name,
				"body_a": na.name if na else "",
				"body_b": nb.name if nb else "",
				"anchor": [h.anchor.x, h.anchor.y, h.anchor.z],
				"axis":   [h.axis.x,   h.axis.y,   h.axis.z],
			})

		elif child is SkaleSlider:
			var s := child as SkaleSlider
			var na := child.get_node_or_null(s.body_a_path) as SkaleBody
			var nb := child.get_node_or_null(s.body_b_path) as SkaleBody
			joints.append({
				"type":   "slider",
				"name":   child.name,
				"body_a": na.name if na else "",
				"body_b": nb.name if nb else "",
				"anchor": [s.anchor.x, s.anchor.y, s.anchor.z],
				"axis":   [s.axis.x,   s.axis.y,   s.axis.z],
			})

		elif child is SkaleSpring:
			var sp := child as SkaleSpring
			var na := child.get_node_or_null(sp.body_a_path) as SkaleBody
			var nb := child.get_node_or_null(sp.body_b_path) as SkaleBody
			joints.append({
				"type":     "spring",
				"name":     child.name,
				"body_a":   na.name if na else "",
				"body_b":   nb.name if nb else "",
				"stiffness": sp.stiffness,
				"damping":   sp.damping,
			})

		elif child is SkaleFixed:
			var f := child as SkaleFixed
			var na := child.get_node_or_null(f.body_a_path) as SkaleBody
			var nb := child.get_node_or_null(f.body_b_path) as SkaleBody
			joints.append({
				"type":   "weld",
				"name":   child.name,
				"body_a": na.name if na else "",
				"body_b": nb.name if nb else "",
			})

		elif child is SkaleMotor:
			var mo := child as SkaleMotor
			var na := child.get_node_or_null(mo.body_a_path) as SkaleBody
			var nb := child.get_node_or_null(mo.body_b_path) as SkaleBody
			joints.append({
				"type":   "motor",
				"name":   child.name,
				"body_a": na.name if na else "",
				"body_b": nb.name if nb else "",
				"anchor": [mo.anchor.x, mo.anchor.y, mo.anchor.z],
				"axis":   [mo.axis.x,   mo.axis.y,   mo.axis.z],
				"speed":  mo.speed,
			})

		elif child is SkaleActuator:
			var ac := child as SkaleActuator
			var na := child.get_node_or_null(ac.body_a_path) as SkaleBody
			var nb := child.get_node_or_null(ac.body_b_path) as SkaleBody
			joints.append({
				"type":   "actuator",
				"name":   child.name,
				"body_a": na.name if na else "",
				"body_b": nb.name if nb else "",
				"anchor": [ac.anchor.x, ac.anchor.y, ac.anchor.z],
				"axis":   [ac.axis.x,   ac.axis.y,   ac.axis.z],
				"speed":  ac.speed,
			})

		elif child is SkaleBall:
			var bl := child as SkaleBall
			var na := child.get_node_or_null(bl.body_a_path) as SkaleBody
			var nb := child.get_node_or_null(bl.body_b_path) as SkaleBody
			joints.append({
				"type":   "ball",
				"name":   child.name,
				"body_a": na.name if na else "",
				"body_b": nb.name if nb else "",
				"anchor": [bl.anchor.x, bl.anchor.y, bl.anchor.z],
			})

	var data := {"version": 1, "bodies": bodies, "joints": joints}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func _load_scene(path: String) -> void:
	if _mode != Mode.DESIGN:
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data:
		return

	# Clear everything except the Floor.
	_select(null)
	for i in range(_sim.get_child_count() - 1, -1, -1):
		var child := _sim.get_child(i)
		if child is SkaleBody and (child as SkaleBody).name == "Floor":
			continue
		child.queue_free()

	await get_tree().process_frame

	_body_counter  = 0
	_joint_counter = 0

	# Recreate bodies.
	for bd in data["bodies"]:
		var body := SkaleBody.new()
		body.name       = str(bd["name"])
		body.shape_type = int(bd["shape_type"])
		var p: Array = bd["position"]
		body.position   = Vector3(p[0], p[1], p[2])
		var bs: Array = bd["box_size"]
		body.box_size   = Vector3(bs[0], bs[1], bs[2])
		body.radius      = float(bd["radius"])
		body.height      = float(bd["height"])
		body.density     = float(bd["density"])
		body.set_fixed(bool(bd["fixed"]))
		body.friction    = float(bd["friction"])
		body.restitution = float(bd["restitution"])
		_sim.add_child(body)
		var col := COLOR_FIXED if body.get_fixed() else COLOR_DYNAMIC
		_attach_mesh(body, col)
		_attach_picker(body)
		_body_counter += 1

	# Recreate joints.
	for jd in data["joints"]:
		var body_a := _sim.get_node_or_null(str(jd["body_a"])) as SkaleBody
		var body_b := _sim.get_node_or_null(str(jd["body_b"])) as SkaleBody
		if not body_a or not body_b:
			continue
		_joint_counter += 1

		match str(jd["type"]):
			"hinge":
				var hinge := SkaleHinge.new()
				hinge.name = str(jd["name"])
				var a: Array = jd["anchor"]
				var ax: Array = jd["axis"]
				hinge.anchor   = Vector3(a[0], a[1], a[2])
				hinge.axis     = Vector3(ax[0], ax[1], ax[2])
				hinge.position = hinge.anchor
				_sim.add_child(hinge)
				hinge.body_a_path = hinge.get_path_to(body_a)
				hinge.body_b_path = hinge.get_path_to(body_b)
				_attach_hinge_visual(hinge)

			"slider":
				var slider := SkaleSlider.new()
				slider.name = str(jd["name"])
				var a: Array = jd["anchor"]
				var ax: Array = jd["axis"]
				slider.anchor   = Vector3(a[0], a[1], a[2])
				slider.axis     = Vector3(ax[0], ax[1], ax[2])
				slider.position = slider.anchor
				_sim.add_child(slider)
				slider.body_a_path = slider.get_path_to(body_a)
				slider.body_b_path = slider.get_path_to(body_b)
				_attach_slider_visual(slider, body_a.position, body_b.position)

			"spring":
				var spring := SkaleSpring.new()
				spring.name      = str(jd["name"])
				spring.stiffness = float(jd["stiffness"])
				spring.damping   = float(jd["damping"])
				spring.position  = (body_a.position + body_b.position) * 0.5
				_sim.add_child(spring)
				spring.body_a_path = spring.get_path_to(body_a)
				spring.body_b_path = spring.get_path_to(body_b)
				_attach_spring_visual(spring, body_a.position, body_b.position)

			"weld":
				var weld := SkaleFixed.new()
				weld.name     = str(jd["name"])
				weld.position = (body_a.position + body_b.position) * 0.5
				_sim.add_child(weld)
				weld.body_a_path = weld.get_path_to(body_a)
				weld.body_b_path = weld.get_path_to(body_b)
				_attach_weld_visual(weld)

			"motor":
				var motor := SkaleMotor.new()
				motor.name = str(jd["name"])
				var a: Array = jd["anchor"]
				var ax: Array = jd["axis"]
				motor.anchor   = Vector3(a[0], a[1], a[2])
				motor.axis     = Vector3(ax[0], ax[1], ax[2])
				motor.speed    = float(jd["speed"])
				motor.position = motor.anchor
				_sim.add_child(motor)
				motor.body_a_path = motor.get_path_to(body_a)
				motor.body_b_path = motor.get_path_to(body_b)
				_attach_motor_visual(motor)

			"actuator":
				var actuator := SkaleActuator.new()
				actuator.name = str(jd["name"])
				var a: Array = jd["anchor"]
				var ax: Array = jd["axis"]
				actuator.anchor   = Vector3(a[0], a[1], a[2])
				actuator.axis     = Vector3(ax[0], ax[1], ax[2])
				actuator.speed    = float(jd["speed"])
				actuator.position = actuator.anchor
				_sim.add_child(actuator)
				actuator.body_a_path = actuator.get_path_to(body_a)
				actuator.body_b_path = actuator.get_path_to(body_b)
				_attach_actuator_visual(actuator)

			"ball":
				var ball := SkaleBall.new()
				ball.name = str(jd["name"])
				var a: Array = jd["anchor"]
				ball.anchor   = Vector3(a[0], a[1], a[2])
				ball.position = ball.anchor
				_sim.add_child(ball)
				ball.body_a_path = ball.get_path_to(body_a)
				ball.body_b_path = ball.get_path_to(body_b)
				_attach_ball_visual(ball)


func _delete_selected() -> void:
	if not _selected or _mode != Mode.DESIGN:
		return
	if _selected.name == "Floor":
		return
	var body := _selected
	_select(null)
	# Remove any joints that reference this body before freeing it.
	for i in range(_sim.get_child_count() - 1, -1, -1):
		var child := _sim.get_child(i)
		var path_a := NodePath()
		var path_b := NodePath()
		if child is SkaleHinge:
			path_a = (child as SkaleHinge).body_a_path
			path_b = (child as SkaleHinge).body_b_path
		elif child is SkaleSlider:
			path_a = (child as SkaleSlider).body_a_path
			path_b = (child as SkaleSlider).body_b_path
		elif child is SkaleSpring:
			path_a = (child as SkaleSpring).body_a_path
			path_b = (child as SkaleSpring).body_b_path
		elif child is SkaleFixed:
			path_a = (child as SkaleFixed).body_a_path
			path_b = (child as SkaleFixed).body_b_path
		elif child is SkaleMotor:
			path_a = (child as SkaleMotor).body_a_path
			path_b = (child as SkaleMotor).body_b_path
		elif child is SkaleActuator:
			path_a = (child as SkaleActuator).body_a_path
			path_b = (child as SkaleActuator).body_b_path
		elif child is SkaleBall:
			path_a = (child as SkaleBall).body_a_path
			path_b = (child as SkaleBall).body_b_path
		else:
			continue
		if child.get_node_or_null(path_a) == body or child.get_node_or_null(path_b) == body:
			child.queue_free()
	body.queue_free()


func _update_slider_visuals() -> void:
	for i in _sim.get_child_count():
		var slider := _sim.get_child(i) as SkaleSlider
		if not slider:
			continue
		var node_a := slider.get_node_or_null(slider.body_a_path) as SkaleBody
		var node_b := slider.get_node_or_null(slider.body_b_path) as SkaleBody
		if not node_a or not node_b:
			continue
		var container := slider.get_node_or_null("Visual") as Node3D
		if not container or container.get_child_count() == 0:
			continue
		var mi := container.get_child(0) as MeshInstance3D
		if not mi:
			continue
		var pt_a := node_a.global_position
		var pt_b := node_b.global_position
		var diff := pt_a - pt_b
		var length := diff.length()
		if length < 0.01:
			continue
		slider.global_position = (pt_a + pt_b) * 0.5
		var cyl := mi.mesh as CylinderMesh
		if cyl:
			cyl.height = length
		mi.position = Vector3.ZERO
		mi.global_basis = _axis_basis(diff)


func _update_spring_visuals() -> void:
	for i in _sim.get_child_count():
		var spring := _sim.get_child(i) as SkaleSpring
		if not spring:
			continue
		var node_a := spring.get_node_or_null(spring.body_a_path) as SkaleBody
		var node_b := spring.get_node_or_null(spring.body_b_path) as SkaleBody
		if not node_a or not node_b:
			continue
		var mi := spring.get_node_or_null("Visual") as MeshInstance3D
		if not mi:
			continue
		var pt_a := node_a.global_position
		var pt_b := node_b.global_position
		var diff := pt_b - pt_a
		var length := diff.length()
		if length < 0.001:
			continue
		spring.global_position = (pt_a + pt_b) * 0.5
		var cyl := mi.mesh as CylinderMesh
		if cyl:
			cyl.height = length
		var dir := diff.normalized()
		var up := Vector3(0, 1, 0)
		var right := up.cross(dir) if abs(dir.dot(up)) < 0.999 else Vector3(1, 0, 0)
		right = right.normalized()
		mi.global_basis = Basis(right, dir, right.cross(dir).normalized())


func _on_toggle_joints(pressed: bool) -> void:
	_show_joints = pressed
	_set_joints_visible(pressed)


func _set_joints_visible(show: bool) -> void:
	for i in _sim.get_child_count():
		var child := _sim.get_child(i)
		if child is SkaleBody:
			continue
		var visual := child.get_node_or_null("Visual") as Node3D
		if visual:
			visual.visible = show


# ── Joint visual helpers ──────────────────────────────────────────────────────

# Returns a Basis whose Y column points along dir.
func _axis_basis(dir: Vector3) -> Basis:
	var d := dir.normalized()
	var up := Vector3(0, 1, 0)
	if d.distance_to(up) < 0.01:
		return Basis.IDENTITY
	if d.distance_to(-up) < 0.01:
		return Basis(Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1))
	var right := up.cross(d).normalized()
	return Basis(right, d, d.cross(right).normalized())


# Arrow pointing +Y. Caller applies _axis_basis to orient.
func _make_arrow_y(length: float, color: Color, bidirectional: bool = false) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if bidirectional:
		var shaft := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.012; sm.bottom_radius = 0.012; sm.height = length
		shaft.mesh = sm; shaft.material_override = mat
		root.add_child(shaft)

		for sign in [1, -1]:
			var head := MeshInstance3D.new()
			var hm := CylinderMesh.new()
			hm.top_radius = 0.0 if sign > 0 else 0.045
			hm.bottom_radius = 0.045 if sign > 0 else 0.0
			hm.height = 0.10
			head.mesh = hm; head.material_override = mat
			head.position = Vector3(0, sign * (length * 0.5 + 0.05), 0)
			root.add_child(head)
	else:
		var shaft := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.012; sm.bottom_radius = 0.012; sm.height = length
		shaft.mesh = sm; shaft.material_override = mat
		shaft.position = Vector3(0, length * 0.5, 0)
		root.add_child(shaft)

		var head := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.0; hm.bottom_radius = 0.045; hm.height = 0.10
		head.mesh = hm; head.material_override = mat
		head.position = Vector3(0, length + 0.05, 0)
		root.add_child(head)

	return root


# Flat torus ring in XZ plane (perp to Y). Caller applies _axis_basis to orient.
func _make_ring_y(avg_radius: float, width: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = avg_radius - width * 0.5
	tm.outer_radius = avg_radius + width * 0.5
	tm.ring_segments = 48
	mi.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi


# Two thin tubes: red to pos_a, blue to pos_b, in the joint's local space.
func _make_body_tubes(joint: Node3D, pos_a: Vector3, pos_b: Vector3) -> Node3D:
	var root := Node3D.new()
	for pair in [[pos_a, Color(1.0, 0.35, 0.35)], [pos_b, Color(0.35, 0.65, 1.0)]]:
		var world_pos: Vector3 = pair[0]
		var color: Color = pair[1]
		var local := joint.to_local(world_pos)
		var length := local.length()
		if length < 0.05:
			continue
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.012; cm.bottom_radius = 0.012; cm.height = length
		mi.mesh = cm
		mi.basis = _axis_basis(local)
		mi.position = local * 0.5
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		root.add_child(mi)
	return root


func _restore_body_colors() -> void:
	for i in _sim.get_child_count():
		var body := _sim.get_child(i) as SkaleBody
		if body:
			var col := COLOR_FIXED if body.get_fixed() else COLOR_DYNAMIC
			if body == _selected:
				col = COLOR_SELECTED
			_set_mesh_color(body, col)


func _on_add_box() -> void:
	if _mode != Mode.DESIGN:
		return
	_body_counter += 1
	var body := SkaleBody.new()
	body.name = "Box%d" % _body_counter
	body.shape_type = SkaleBody.BOX
	body.box_size = Vector3(1.0, 1.0, 1.0)
	body.density = 1000.0
	body.position = Vector3(randf_range(-3.0, 3.0), 3.0, randf_range(-3.0, 3.0))
	_sim.add_child(body)
	_attach_mesh(body, COLOR_DYNAMIC)
	_attach_picker(body)
	_select(body)


func _on_add_cylinder() -> void:
	if _mode != Mode.DESIGN:
		return
	_body_counter += 1
	var body := SkaleBody.new()
	body.name = "Cylinder%d" % _body_counter
	body.shape_type = SkaleBody.CYLINDER
	body.radius = 0.5
	body.height = 1.0
	body.density = 1000.0
	body.position = Vector3(randf_range(-3.0, 3.0), 3.0, randf_range(-3.0, 3.0))
	_sim.add_child(body)
	_attach_mesh(body, COLOR_DYNAMIC)
	_attach_picker(body)
	_select(body)


func _on_add_sphere() -> void:
	if _mode != Mode.DESIGN:
		return
	_body_counter += 1
	var body := SkaleBody.new()
	body.name = "Sphere%d" % _body_counter
	body.shape_type = SkaleBody.SPHERE
	body.radius = 0.5
	body.density = 1000.0
	body.position = Vector3(randf_range(-3.0, 3.0), 3.0, randf_range(-3.0, 3.0))
	_sim.add_child(body)
	_attach_mesh(body, COLOR_DYNAMIC)
	_attach_picker(body)
	_select(body)


func _on_play() -> void:
	if _mode == Mode.DESIGN:
		_mode = Mode.RUN
		_sim.play()
		_btn_play.disabled  = true
		_btn_pause.disabled = false
		_btn_stop.disabled  = false
		_set_props_editable(false)
	elif _mode == Mode.PAUSED:
		_mode = Mode.RUN
		_sim.resume()
		_btn_play.text      = "▶  Play"
		_btn_play.disabled  = true
		_btn_pause.disabled = false


func _on_pause() -> void:
	if _mode == Mode.RUN:
		_mode = Mode.PAUSED
		_sim.pause()
		_btn_play.text      = "▶  Resume"
		_btn_play.disabled  = false
		_btn_pause.disabled = true


func _on_stop() -> void:
	_mode = Mode.DESIGN
	_joint_mode = JointMode.NONE
	_joint_body_a = null
	_status_label.text = ""
	_axis_buttons.visible = false
	_sim.stop()
	_btn_play.text      = "▶  Play"
	_btn_play.disabled  = false
	_btn_pause.disabled = true
	_btn_stop.disabled  = true
	_set_props_editable(true)
	# Restore mesh colors
	for i in _sim.get_child_count():
		var body := _sim.get_child(i) as SkaleBody
		if body:
			var col := COLOR_FIXED if body.get_fixed() else COLOR_DYNAMIC
			if body == _selected:
				col = COLOR_SELECTED
			_set_mesh_color(body, col)


func _set_props_editable(editable: bool) -> void:
	_prop_pos_x.editable       = editable
	_prop_pos_y.editable       = editable
	_prop_pos_z.editable       = editable
	_prop_size_x.editable      = editable
	_prop_size_y.editable      = editable
	_prop_size_z.editable      = editable
	_prop_density.editable     = editable
	_prop_fixed.disabled       = not editable
	_prop_friction.editable    = editable
	_prop_restitution.editable = editable
