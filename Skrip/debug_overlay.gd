extends CanvasLayer

const FLOWER_NAMES: Dictionary = {
	1: "Melati Rawa",
	2: "Kembang Api Merah",
	3: "Bunga Bangkai Kerdil",
	4: "Anggrek Kupu-kupu",
	5: "Teratai Abu",
	6: "Kantong Rawa",
	7: "Mawar Arang",
	8: "Kupu-Kupu Induk"
}

var player_node: Node3D = null
var amir_node: Node3D = null

var debug_panel: PanelContainer = null
var debug_label: Label = null
var log_label: Label = null

var flower_panel: PanelContainer = null
var flower_label: Label = null

var recorded_positions: Array[Dictionary] = []

var _toast_label: Label = null
var _toast_timer: SceneTreeTimer = null

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	visible = true
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 1. Panel Monitor Player & Amir (Kiri Atas - Toggle F3)
	debug_panel = PanelContainer.new()
	debug_panel.name = "DebugPanel"
	debug_panel.offset_left = 16
	debug_panel.offset_top = 16
	debug_panel.offset_right = 510
	debug_panel.offset_bottom = 340
	debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_panel.visible = false
	add_child(debug_panel)

	var p_style: StyleBoxFlat = StyleBoxFlat.new()
	p_style.bg_color = Color(0, 0, 0, 0.78)
	p_style.set_corner_radius_all(6)
	p_style.content_margin_left = 12
	p_style.content_margin_top = 10
	p_style.content_margin_right = 12
	p_style.content_margin_bottom = 10
	debug_panel.add_theme_stylebox_override("panel", p_style)

	var p_vbox: VBoxContainer = VBoxContainer.new()
	debug_panel.add_child(p_vbox)

	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", 13)
	debug_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	p_vbox.add_child(debug_label)

	log_label = Label.new()
	log_label.add_theme_font_size_override("font_size", 11)
	log_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	p_vbox.add_child(log_label)

	# 2. Panel Radar & Status 7 Bunga (Kanan Atas - Toggle F2)
	flower_panel = PanelContainer.new()
	flower_panel.name = "FlowerPanel"
	flower_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	flower_panel.offset_left = -580
	flower_panel.offset_top = 16
	flower_panel.offset_right = -16
	flower_panel.offset_bottom = 540
	flower_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flower_panel.visible = false
	add_child(flower_panel)

	var f_style: StyleBoxFlat = StyleBoxFlat.new()
	f_style.bg_color = Color(0.04, 0.04, 0.08, 0.88)
	f_style.border_color = Color(1.0, 0.4, 0.7, 0.7)
	f_style.set_border_width_all(1)
	f_style.set_corner_radius_all(6)
	f_style.content_margin_left = 12
	f_style.content_margin_top = 10
	f_style.content_margin_right = 12
	f_style.content_margin_bottom = 10
	flower_panel.add_theme_stylebox_override("panel", f_style)

	var f_vbox: VBoxContainer = VBoxContainer.new()
	flower_panel.add_child(f_vbox)

	flower_label = Label.new()
	flower_label.add_theme_font_size_override("font_size", 12)
	flower_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	f_vbox.add_child(flower_label)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			get_viewport().set_input_as_handled()
			_record_current_pos()
		elif event.keycode == KEY_F2:
			get_viewport().set_input_as_handled()
			_toggle_flower_panel()
		elif event.keycode == KEY_F3:
			get_viewport().set_input_as_handled()
			_toggle_debug_panel()
		elif event.keycode == KEY_F4:
			get_viewport().set_input_as_handled()
			_toggle_camcorder_shader()
		elif event.keycode == KEY_F5:
			get_viewport().set_input_as_handled()
			_toggle_unshaded_mode()
		elif event.keycode == KEY_F7:
			get_viewport().set_input_as_handled()
			_force_spawn_flowers()
		elif event.keycode == KEY_F8:
			get_viewport().set_input_as_handled()
			_print_flower_debug_log()

func _toggle_debug_panel() -> void:
	if is_instance_valid(debug_panel):
		debug_panel.visible = not debug_panel.visible

func _toggle_flower_panel() -> void:
	if is_instance_valid(flower_panel):
		flower_panel.visible = not flower_panel.visible
		_show_toast("🌸 Monitor 7 Bunga: %s" % ("DIBUKA [F2]" if flower_panel.visible else "DITUTUP"))

func _force_spawn_flowers() -> void:
	var sm: Node = get_node_or_null("/root/StoryManager")
	if sm and sm.has_method("distribute_random_flowers_to_tables"):
		sm.set("flowers_randomized", false)
		sm.distribute_random_flowers_to_tables()
		_show_toast("🌸 [F7] 7 Bunga berhasil didistribusikan ulang ke laci meja!")
	else:
		_show_toast("StoryManager tidak ditemukan!")

func _print_flower_debug_log() -> void:
	var d: Dictionary = _get_all_flower_data()
	print("\n========================================================")
	print("🌸 [DEBUG REPORT: STATUS 7 BUNGA MISTIS]")
	print("========================================================")
	print("Skrip Randomize : %s" % ("SUDAH DIACAK" if d["is_randomized"] else "BELUM DIACAK"))
	print("Total Meja      : %d meja interaktif ditemukan" % d["total_tables"])
	print("Bunga di Meja   : %d / 7 terpasang" % d["tables_with_flowers"])
	print("Progres Pemain  : Diambil: %d/8 | Di Altar: %d/8" % [d["flowers_picked"], d["flowers_deposited"]])
	print("--------------------------------------------------------")
	for i in range(1, 8):
		var f: Dictionary = d["flowers"][i]
		print("Bunga %d (%s): %s -> %s (Jarak: %.1fm)" % [i, f["name"], f["status"], f["detail"], f["distance"]])
	var f8: Dictionary = d["flowers"][8]
	print("Bunga 8 (%s): %s -> %s" % [f8["name"], f8["status"], f8["detail"]])
	print("========================================================\n")
	_show_toast("🌸 [F8] Log detail 7 Bunga dicetak ke Console Output!")

func _toggle_camcorder_shader() -> void:
	var toggled: bool = false
	var new_state: bool = false

	for node in get_tree().get_nodes_in_group(&"player_camera"):
		if node.has_method("toggle_camcorder_shader"):
			new_state = node.toggle_camcorder_shader()
			toggled = true

	if not toggled:
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam and cam.has_method("toggle_camcorder_shader"):
			new_state = cam.toggle_camcorder_shader()
			toggled = true

	if not toggled:
		if not is_instance_valid(player_node):
			_find_nodes()
		if is_instance_valid(player_node):
			var found_cam: Node = player_node.find_child("Camera3D", true, false)
			if found_cam and found_cam.has_method("toggle_camcorder_shader"):
				new_state = found_cam.toggle_camcorder_shader()
				toggled = true

	if toggled:
		_show_toast("Shader VHS / Camcorder: %s" % ("AKTIF" if new_state else "NONAKTIF (Anti-Lag)"))
	else:
		_show_toast("Shader VHS: Camera3D tidak ditemukan")

func _toggle_unshaded_mode() -> void:
	var vp: Viewport = get_viewport()
	if vp:
		if vp.debug_draw == Viewport.DEBUG_DRAW_UNSHADED:
			vp.debug_draw = Viewport.DEBUG_DRAW_DISABLED
			_show_toast("Rendering 3D: NORMAL (Lighting & Shadow Aktif)")
		else:
			vp.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
			_show_toast("Rendering 3D: UNSHADED (Zero Light / Super Enteng)")

func _show_toast(msg: String) -> void:
	print("[DEBUG] %s" % msg)
	if not is_instance_valid(_toast_label):
		_toast_label = Label.new()
		_toast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_toast_label.offset_top = 24.0
		_toast_label.offset_bottom = 64.0
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_toast_label.add_theme_font_size_override("font_size", 15)
		_toast_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		var bg: StyleBoxFlat = StyleBoxFlat.new()
		bg.bg_color = Color(0.0, 0.0, 0.0, 0.85)
		bg.set_corner_radius_all(6)
		bg.content_margin_left = 18
		bg.content_margin_right = 18
		bg.content_margin_top = 8
		bg.content_margin_bottom = 8
		_toast_label.add_theme_stylebox_override("normal", bg)
		_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_toast_label)

	_toast_label.text = msg
	_toast_label.visible = true

	if _toast_timer:
		_toast_timer.timeout.disconnect(_on_toast_timeout)
	_toast_timer = get_tree().create_timer(2.2)
	_toast_timer.timeout.connect(_on_toast_timeout)

func _on_toast_timeout() -> void:
	if is_instance_valid(_toast_label):
		_toast_label.visible = false

func _record_current_pos() -> void:
	if not is_instance_valid(player_node):
		_find_nodes()
	if is_instance_valid(player_node):
		var p: Vector3 = player_node.global_position
		var fl: String = _get_floor_name(p.y)
		var entry: Dictionary = {
			"floor": fl,
			"pos": p
		}
		recorded_positions.append(entry)
		if recorded_positions.size() > 6:
			recorded_positions.pop_front()
		print("[DEBUG RECORDER] %s: X=%.2f, Y=%.2f, Z=%.2f" % [fl, p.x, p.y, p.z])

func _process(_delta: float) -> void:
	var is_debug_open: bool = (is_instance_valid(debug_panel) and debug_panel.visible)
	var is_flower_open: bool = (is_instance_valid(flower_panel) and flower_panel.visible)

	if not is_debug_open and not is_flower_open:
		return

	if not is_instance_valid(player_node) or not is_instance_valid(amir_node):
		_find_nodes()

	# Update Panel Bunga jika sedang terbuka
	if is_flower_open and is_instance_valid(flower_label):
		flower_label.text = _generate_flower_debug_text()

	# Update Panel Utama jika sedang terbuka
	if is_debug_open and is_instance_valid(debug_label):
		_update_debug_panel_text()

func _update_debug_panel_text() -> void:
	var p_pos: Vector3 = player_node.global_position if (is_instance_valid(player_node) and player_node.is_inside_tree()) else Vector3.ZERO
	var a_pos: Vector3 = amir_node.global_position if (is_instance_valid(amir_node) and amir_node.is_inside_tree()) else Vector3.ZERO

	var dist_3d: float = p_pos.distance_to(a_pos) if (is_instance_valid(player_node) and is_instance_valid(amir_node)) else 0.0
	var horiz_dist: float = Vector2(p_pos.x - a_pos.x, p_pos.z - a_pos.z).length()
	var vert_dist: float = abs(p_pos.y - a_pos.y)

	var p_floor: String = _get_floor_name(p_pos.y)
	var a_floor: String = _get_floor_name(a_pos.y)

	var a_state: String = "N/A"
	var next_tp: float = 0.0
	if is_instance_valid(amir_node):
		var chasing = amir_node.get("_is_chasing")
		var resting = amir_node.get("_is_resting")
		var grace = amir_node.get("_spawn_grace")
		var tp = amir_node.get("_teleport_timer")
		next_tp = tp if tp != null else 0.0
		if resting:
			a_state = "Resting"
		elif chasing:
			a_state = "Chasing Player"
		elif grace != null and grace > 0.0:
			a_state = "Grace Period (%.1fs)" % grace
		else:
			a_state = "Patrol"

	var shader_text: String = "N/A"
	for node in get_tree().get_nodes_in_group(&"player_camera"):
		if "enable_camcorder_shader" in node:
			shader_text = "AKTIF" if node.enable_camcorder_shader else "NONAKTIF (Anti-Lag)"
			break
	if shader_text == "N/A":
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam and "enable_camcorder_shader" in cam:
			shader_text = "AKTIF" if cam.enable_camcorder_shader else "NONAKTIF (Anti-Lag)"
	var unshaded_text: String = "UNSHADED" if get_viewport().debug_draw == Viewport.DEBUG_DRAW_UNSHADED else "NORMAL"

	var flower_data: Dictionary = _get_all_flower_data()
	var ready_flowers: int = 0
	for i in range(1, 8):
		var st: String = flower_data["flowers"][i]["status"]
		if st == "IN_DRAWER" or st == "PICKED":
			ready_flowers += 1

	var text: String = "=== DEBUG MONITOR (F3: Tutup) ===\n"
	text += "PERF  : [F4] VHS: %s | [F5] Render 3D: %s\n" % [shader_text, unshaded_text]
	text += "BUNGA : [F2] 7 Bunga di Laci: %d/7 %s | Tas: %d/8 | Altar: %d/8\n" % [
		ready_flowers,
		"(LENGKAP)" if ready_flowers >= 7 else "(BELUM LENGKAP!)",
		flower_data["flowers_picked"],
		flower_data["flowers_deposited"]
	]
	text += "PLAYER: Pos (X: %.2f, Y: %.2f, Z: %.2f) | %s\n" % [p_pos.x, p_pos.y, p_pos.z, p_floor]
	if is_instance_valid(amir_node):
		text += "AMIR  : Pos (X: %.2f, Y: %.2f, Z: %.2f) | %s\n" % [a_pos.x, a_pos.y, a_pos.z, a_floor]
		text += "STATUS: %s | Next TP: %.1fs | Visible: %s\n" % [a_state, next_tp, str(amir_node.visible)]
		text += "JARAK : 3D: %.2fm | Horiz: %.2fm | Vert: %.2fm\n" % [dist_3d, horiz_dist, vert_dist]
	else:
		text += "AMIR  : [TIDAK DITEMUKAN DI SCENE]\n"

	debug_label.text = text

	var rec_text: String = "\n[CATATAN POSISI LANTAI (Tekan F1)]:\n"
	if recorded_positions.is_empty():
		rec_text += "Tekan F1 saat di tiap lantai untuk mencatat posisi.\n"
	else:
		for r in recorded_positions:
			rec_text += "• %s -> (X: %.2f, Y: %.2f, Z: %.2f)\n" % [r["floor"], r["pos"].x, r["pos"].y, r["pos"].z]
	log_label.text = rec_text

func _generate_flower_debug_text() -> String:
	var d: Dictionary = _get_all_flower_data()
	var ready_count: int = 0
	for i in range(1, 8):
		var st: String = d["flowers"][i]["status"]
		if st == "IN_DRAWER" or st == "PICKED":
			ready_count += 1

	var script_badge: String = "SUDAH DIACAK" if d["is_randomized"] else "BELUM DIACAK"
	var complete_badge: String = "(✅ LENGKAP 7/7)" if ready_count >= 7 else "(⚠️ BELUM LENGKAP %d/7)" % ready_count

	var text: String = "=== 🌸 RADAR & STATUS 7 BUNGA (F2: Tutup) ===\n"
	text += "Skrip Randomize : %s\n" % script_badge
	text += "Total Meja      : %d meja interaktif ditemukan\n" % d["total_tables"]
	text += "Bunga di Laci   : %d / 7 Terpasang %s\n" % [d["tables_with_flowers"], complete_badge]
	text += "Progres Pemain  : Diambil: %d/8 | Di Altar: %d/8\n" % [d["flowers_picked"], d["flowers_deposited"]]
	text += "--------------------------------------------------------\n"

	for i in range(1, 8):
		var f: Dictionary = d["flowers"][i]
		var stat_desc: String = ""
		match f["status"]:
			"IN_DRAWER":
				stat_desc = "[DI LACI] %s | Jarak: %.1fm" % [f["detail"], f["distance"]]
			"IN_WORLD":
				stat_desc = "[DI DUNIA] %s | Jarak: %.1fm" % [f["detail"], f["distance"]]
			"PICKED":
				stat_desc = "[SUDAH DIAMBIL] Di Tas / Di Altar"
			"NOT_SPAWNED":
				stat_desc = "[⚠️ BELUM DISPAWN OLEH SKRIP]"
		text += "• Bunga %d (%s):\n  -> %s\n" % [i, f["name"], stat_desc]

	var f8: Dictionary = d["flowers"][8]
	var f8_desc: String = ""
	match f8["status"]:
		"IN_DRAWER", "IN_WORLD":
			f8_desc = "[TERSEDIA] %s | Jarak: %.1fm" % [f8["detail"], f8["distance"]]
		"PICKED":
			f8_desc = "[SUDAH DIAMBIL]"
		"NOT_SPAWNED":
			f8_desc = "[KAMAR AMIR] Bunga khusus ritual akhir"
	text += "• Bunga 8 (%s):\n  -> %s\n" % [f8["name"], f8_desc]

	text += "--------------------------------------------------------\n"
	text += "[F7] Paksa Acak Ulang Meja | [F8] Cetak Log Lengkap"
	return text

func _get_all_flower_data() -> Dictionary:
	var data: Dictionary = {
		"is_randomized": false,
		"total_tables": 0,
		"tables_with_flowers": 0,
		"flowers_picked": 0,
		"flowers_deposited": 0,
		"flowers": {}
	}

	var sm: Node = get_node_or_null("/root/StoryManager")
	var picked_indices: Array = []
	if sm:
		data["is_randomized"] = bool(sm.get("flowers_randomized"))
		data["flowers_picked"] = int(sm.get("flowers_collected"))
		data["flowers_deposited"] = int(sm.get("flowers_deposited"))
		var p_list = sm.get("picked_flower_indices")
		if p_list is Array:
			picked_indices = p_list

	if not is_instance_valid(player_node):
		_find_nodes()
	var p_pos: Vector3 = player_node.global_position if (is_instance_valid(player_node) and player_node.is_inside_tree()) else Vector3.ZERO

	for i in range(1, 9):
		var fname: String = FLOWER_NAMES.get(i, "Bunga %d" % i)
		data["flowers"][i] = {
			"name": fname,
			"status": "NOT_SPAWNED",
			"detail": "Belum ada di scene",
			"distance": 9999.0,
			"pos": Vector3.ZERO,
			"is_open": false
		}
		if picked_indices.has(i):
			data["flowers"][i]["status"] = "PICKED"
			data["flowers"][i]["detail"] = "Sudah diambil pemain"

	# Cari semua meja di scene
	var all_tables: Array = []
	for node in get_tree().get_nodes_in_group(&"meja"):
		if node is Node3D:
			all_tables.append(node)
	if all_tables.is_empty():
		var scene: Node = get_tree().current_scene
		if scene:
			for child in scene.find_children("*", "InteractiveTable", true, false):
				if child is Node3D:
					all_tables.append(child)

	data["total_tables"] = all_tables.size()

	for table in all_tables:
		var item: Resource = table.get("current_item_data")
		if item == null:
			item = table.get("starting_item")
		var f_idx: int = _get_flower_index_from_item(item)
		if f_idx >= 1 and f_idx <= 8:
			data["tables_with_flowers"] += 1
			if not picked_indices.has(f_idx):
				var t_pos: Vector3 = table.global_position
				var dist: float = p_pos.distance_to(t_pos) if is_instance_valid(player_node) else 0.0
				var fl_name: String = _get_floor_name(t_pos.y)
				var room_name: String = _get_node_room_name(table)
				var is_open: bool = bool(table.get("is_open"))
				var drawer_str: String = "Laci Terbuka" if is_open else "Laci Tertutup"
				data["flowers"][f_idx]["status"] = "IN_DRAWER"
				data["flowers"][f_idx]["detail"] = "%s (%s) | %s" % [fl_name, room_name, drawer_str]
				data["flowers"][f_idx]["distance"] = dist
				data["flowers"][f_idx]["pos"] = t_pos
				data["flowers"][f_idx]["is_open"] = is_open

	# Cek bunga pickup bebas (di luar laci meja)
	for node in get_tree().get_nodes_in_group(&"flower_pickup"):
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var p: Node = node.get_parent()
		if p and (p.name == "ItemSlot" or p.name.begins_with("Cube_")):
			continue
		var f_idx: int = int(node.get("flower_index")) if node.get("flower_index") != null else 0
		if f_idx >= 1 and f_idx <= 8 and not picked_indices.has(f_idx) and data["flowers"][f_idx]["status"] == "NOT_SPAWNED":
			var n_pos: Vector3 = node.global_position
			var dist: float = p_pos.distance_to(n_pos) if is_instance_valid(player_node) else 0.0
			var fl_name: String = _get_floor_name(n_pos.y)
			var room_name: String = _get_node_room_name(node)
			data["flowers"][f_idx]["status"] = "IN_WORLD"
			data["flowers"][f_idx]["detail"] = "%s (%s)" % [fl_name, room_name]
			data["flowers"][f_idx]["distance"] = dist
			data["flowers"][f_idx]["pos"] = n_pos

	return data

func _get_flower_index_from_item(item: Resource) -> int:
	if item == null:
		return 0
	if "flower_index" in item and int(item.flower_index) > 0:
		return int(item.flower_index)
	if "id" in item:
		var id_str: String = String(item.id)
		if id_str.begins_with("flower_"):
			return id_str.trim_prefix("flower_").to_int()
	return 0

func _get_node_room_name(node: Node3D) -> String:
	if not is_instance_valid(node):
		return "N/A"
	var curr: Node = node.get_parent()
	while is_instance_valid(curr) and curr != get_tree().root:
		var n: String = curr.name
		if n.begins_with("Kamar") or n.begins_with("Loby") or n.begins_with("Dapur") or n.begins_with("Toilet") or n.begins_with("Rusun"):
			return n
		curr = curr.get_parent()
	var p: Node = node.get_parent()
	return p.name if is_instance_valid(p) else "Map"

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
		var scene: Node = get_tree().current_scene
		if scene:
			var found: Node = scene.find_child("CharacterBody3D2", true, false)
			if found is Node3D:
				amir_node = found
