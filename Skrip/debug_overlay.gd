extends CanvasLayer

var player_node: Node3D = null
var amir_node: Node3D = null
var debug_label: Label = null
var log_label: Label = null
var recorded_positions: Array[Dictionary] = []

func _ready() -> void:
	visible = false
	set_process(false)
	set_process_input(false)
	layer = 120

	var panel = PanelContainer.new()
	panel.name = "DebugPanel"
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_right = 460
	panel.offset_bottom = 290
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", 14)
	debug_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	vbox.add_child(debug_label)

	log_label = Label.new()
	log_label.add_theme_font_size_override("font_size", 12)
	log_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(log_label)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			visible = not visible
		elif event.keycode == KEY_F1:
			_record_current_pos()

func _record_current_pos() -> void:
	if not is_instance_valid(player_node):
		_find_nodes()
	if is_instance_valid(player_node):
		var p = player_node.global_position
		var fl = _get_floor_name(p.y)
		var entry = {
			"floor": fl,
			"pos": p
		}
		recorded_positions.append(entry)
		if recorded_positions.size() > 6:
			recorded_positions.pop_front()
		print("[DEBUG RECORDER] %s: X=%.2f, Y=%.2f, Z=%.2f" % [fl, p.x, p.y, p.z])

func _process(_delta: float) -> void:
	if not visible:
		return

	if not is_instance_valid(player_node) or not is_instance_valid(amir_node):
		_find_nodes()

	var panel = get_node_or_null("DebugPanel")
	if not is_instance_valid(player_node):
		if panel:
			panel.visible = false
		return
	elif panel:
		panel.visible = true

	var p_pos = player_node.global_position if (is_instance_valid(player_node) and player_node.is_inside_tree()) else Vector3.ZERO
	var a_pos = amir_node.global_position if (is_instance_valid(amir_node) and amir_node.is_inside_tree()) else Vector3.ZERO

	var dist_3d = p_pos.distance_to(a_pos) if (is_instance_valid(player_node) and is_instance_valid(amir_node)) else 0.0
	var horiz_dist = Vector2(p_pos.x - a_pos.x, p_pos.z - a_pos.z).length()
	var vert_dist = abs(p_pos.y - a_pos.y)

	var p_floor = _get_floor_name(p_pos.y)
	var a_floor = _get_floor_name(a_pos.y)

	var a_state = "N/A"
	var next_tp = 0.0
	if is_instance_valid(amir_node):
		var chasing = amir_node.get("_is_chasing")
		var resting = amir_node.get("_is_resting")
		var grace = amir_node.get("_spawn_grace")
		next_tp = amir_node.get("_teleport_timer") if amir_node.get("_teleport_timer") != null else 0.0
		if resting:
			a_state = "Resting"
		elif chasing:
			a_state = "Chasing Player"
		elif grace != null and grace > 0.0:
			a_state = "Grace Period (%.1fs)" % grace
		else:
			a_state = "Patrol"

	var text = "=== DEBUG MONITOR (F3 to Toggle) ===\n"
	text += "PLAYER: Pos (X: %.2f, Y: %.2f, Z: %.2f) | %s\n" % [p_pos.x, p_pos.y, p_pos.z, p_floor]
	if is_instance_valid(amir_node):
		text += "AMIR  : Pos (X: %.2f, Y: %.2f, Z: %.2f) | %s\n" % [a_pos.x, a_pos.y, a_pos.z, a_floor]
		text += "STATUS: %s | Next TP: %.1fs | Visible: %s\n" % [a_state, next_tp, str(amir_node.visible)]
		text += "JARAK : 3D: %.2fm | Horiz: %.2fm | Vert: %.2fm\n" % [dist_3d, horiz_dist, vert_dist]
	else:
		text += "AMIR  : [TIDAK DITEMUKAN DI SCENE]\n"

	debug_label.text = text

	var rec_text = "\n[CATATAN POSISI LANTAI (Tekan F1)]:\n"
	if recorded_positions.is_empty():
		rec_text += "Tekan F1 saat di tiap lantai untuk mencatat posisi.\n"
	else:
		for r in recorded_positions:
			rec_text += "• %s -> (X: %.2f, Y: %.2f, Z: %.2f)\n" % [r["floor"], r["pos"].x, r["pos"].y, r["pos"].z]
	log_label.text = rec_text

func _get_floor_name(y: float) -> String:
	if y >= 13.0:
		return "Lantai 5 (Lantai 4)"
	elif y >= 9.5:
		return "Lantai 4 (Lantai 3)"
	elif y >= 6.0:
		return "Lantai 3 (Lantai 2)"
	elif y >= 2.5:
		return "Lantai 2 (Lantai 1)"
	else:
		return "Lantai 1 (Ground)"

func _find_nodes() -> void:
	for node in get_tree().get_nodes_in_group(&"player"):
		if node is Node3D:
			player_node = node
			break
	for node in get_tree().get_nodes_in_group(&"chaser"):
		if node is Node3D:
			amir_node = node
			break
	if amir_node == null:
		var scene = get_tree().current_scene
		if scene:
			var found = scene.find_child("CharacterBody3D2", true, false)
			if found is Node3D:
				amir_node = found
