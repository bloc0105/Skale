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

	# Add-body buttons
	var btn_box := Button.new()
	btn_box.text = "+ Box"
	btn_box.pressed.connect(_on_add_box)
	hbox.add_child(btn_box)

	var btn_cyl := Button.new()
	btn_cyl.text = "+ Cylinder"
	btn_cyl.pressed.connect(_on_add_cylinder)
	hbox.add_child(btn_cyl)

	var btn_sph := Button.new()
	btn_sph.text = "+ Sphere"
	btn_sph.pressed.connect(_on_add_sphere)
	hbox.add_child(btn_sph)

	var btn_hinge := Button.new()
	btn_hinge.text = "+ Hinge"
	btn_hinge.pressed.connect(_on_add_hinge)
	hbox.add_child(btn_hinge)

	var btn_slider := Button.new()
	btn_slider.text = "+ Slider"
	btn_slider.pressed.connect(_on_add_slider)
	hbox.add_child(btn_slider)

	var btn_spring := Button.new()
	btn_spring.text = "+ Spring"
	btn_spring.pressed.connect(_on_add_spring)
	hbox.add_child(btn_spring)

	var btn_weld := Button.new()
	btn_weld.text = "+ Weld"
	btn_weld.pressed.connect(_on_add_weld)
	hbox.add_child(btn_weld)

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
	_btn_play.pressed.connect(_on_play)
	hbox.add_child(_btn_play)

	_btn_pause = Button.new()
	_btn_pause.text = "⏸  Pause"
	_btn_pause.disabled = true
	_btn_pause.pressed.connect(_on_pause)
	hbox.add_child(_btn_pause)

	_btn_stop = Button.new()
	_btn_stop.text = "⏹  Stop"
	_btn_stop.disabled = true
	_btn_stop.pressed.connect(_on_stop)
	hbox.add_child(_btn_stop)


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
	_prop_pos_y = _add_spinbox_row(_prop_panel, "Pos Y", -50.0, 50.0)
	_prop_pos_z = _add_spinbox_row(_prop_panel, "Pos Z", -50.0, 50.0)

	_prop_panel.add_child(HSeparator.new())

	_prop_size_x = _add_spinbox_row(_prop_panel, "Size X", 0.1, 20.0)
	_prop_size_row_x = _prop_panel.get_child(_prop_panel.get_child_count() - 1)
	_prop_size_y = _add_spinbox_row(_prop_panel, "Size Y", 0.1, 20.0)
	_prop_size_row_y = _prop_panel.get_child(_prop_panel.get_child_count() - 1)
	_prop_size_z = _add_spinbox_row(_prop_panel, "Size Z", 0.1, 20.0)
	_prop_size_row_z = _prop_panel.get_child(_prop_panel.get_child_count() - 1)
	_prop_radius = _add_spinbox_row(_prop_panel, "Radius", 0.05, 10.0)
	_prop_radius_row = _prop_panel.get_child(_prop_panel.get_child_count() - 1)
	_prop_height = _add_spinbox_row(_prop_panel, "Height", 0.1, 20.0)
	_prop_height_row = _prop_panel.get_child(_prop_panel.get_child_count() - 1)
	_prop_density = _add_spinbox_row(_prop_panel, "Density", 1.0, 100000.0)
	_prop_density.step = 10.0

	var fixed_row := HBoxContainer.new()
	var fixed_lbl := Label.new(); fixed_lbl.text = "Fixed"
	_prop_fixed = CheckBox.new()
	fixed_row.add_child(fixed_lbl)
	fixed_row.add_child(_prop_fixed)
	_prop_panel.add_child(fixed_row)

	_prop_friction    = _add_spinbox_row(_prop_panel, "Friction",    0.0, 2.0)
	_prop_friction.step = 0.05
	_prop_restitution = _add_spinbox_row(_prop_panel, "Restitution", 0.0, 1.0)
	_prop_restitution.step = 0.05

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
			"hinge":  _status_label.text = "  Click swinging body..."
			"slider": _status_label.text = "  Click sliding body..."
			"spring": _status_label.text = "  Click hanging body..."
			"weld":   _status_label.text = "  Click body to weld..."
	elif _joint_mode == JointMode.SELECTING_B:
		if body != _joint_body_a:
			match _joint_type:
				"hinge":  _create_hinge(_joint_body_a, body)
				"slider": _create_slider(_joint_body_a, body)
				"spring": _create_spring(_joint_body_a, body)
				"weld":   _create_weld(_joint_body_a, body)
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
	if _joint_type == "hinge":
		_status_label.text = "  Click pivot body..."
	else:
		_status_label.text = "  Click guide body (rail)..."


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


func _create_weld(body_a: SkaleBody, body_b: SkaleBody) -> void:
	_joint_counter += 1
	var weld := SkaleFixed.new()
	weld.name = "Weld%d" % _joint_counter
	weld.position = (body_a.position + body_b.position) * 0.5

	_sim.add_child(weld)
	weld.body_a_path = weld.get_path_to(body_a)
	weld.body_b_path = weld.get_path_to(body_b)

	# Small white diamond to mark the weld point.
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

	_select(body_b)


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

	_attach_slider_visual(slider)
	_select(body_b)


func _attach_slider_visual(slider: SkaleSlider) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Visual"
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.06
	cyl.bottom_radius = 0.06
	cyl.height        = 0.5
	mi.mesh = cyl
	# Orient the cylinder along the slide axis (CylinderMesh default is Y-up).
	var axis := slider.axis
	if axis.distance_to(Vector3(0, 1, 0)) > 0.01 and axis.distance_to(Vector3(0, -1, 0)) > 0.01:
		mi.basis = Basis(Vector3(0, 1, 0).cross(axis).normalized(),
		                 axis,
		                 axis.cross(Vector3(0, 1, 0).cross(axis).normalized()))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.80, 0.90)
	mi.material_override = mat
	slider.add_child(mi)


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
