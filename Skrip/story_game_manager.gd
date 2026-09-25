class_name StoryGameManager
extends Node

## Pengatur Alur Cerita & Integrasi SaveSystem untuk Game Kupu-Kupu Malam (UNSRI Horor).
## Mengelola perpindahan babak (Prolog, Malam Pertama, Perburuan 8 Bunga, Ritual Akhir),
## fase kecerdasan buatan Amir (Fase 1, 2, 3), dan penyimpanan data pemain (posisi, rotasi, inventory, bunga).

enum Chapter {
	PROLOGUE_DAY = 0,    ## Siang hari: prolog santai, obrolan gigitan kupu-kupu & instruksi
	FIRST_NIGHT = 1,     ## Malam pertama: suara patahan tulang, teror kamar Amir, tutorial sembunyi
	HUNTING_FLOWERS = 2, ## Gameplay utama: mencari 8 bunga, Amir berpatroli, radar kupu-kupu
	FINAL_RITUAL = 3,    ## Ke-8 bunga lengkap, altar siap untuk ritual penentuan ending
	ENDING = 4           ## Permainan selesai (Ending 1: Sembuh atau Ending 2: Bakar)
}

signal chapter_changed(new_chapter: Chapter)
signal flower_count_changed(collected: int, deposited: int)
signal amir_phase_changed(new_phase: int)
signal game_saved
signal game_loaded

static var instance: StoryGameManager

@export_group("Progres Cerita")
@export var current_chapter: Chapter = Chapter.PROLOGUE_DAY
@export var flowers_collected: int = 0
@export var flowers_deposited: int = 0
@export var max_flowers: int = 8
@export var amir_phase: int = 1

@export_group("Slot SaveSystem")
@export var active_slot: int = 1

# Referensi node dalam game
var player_node: Node3D = null
var amir_node: NPCChaser = null
var pending_restore: bool = false
var picked_flower_indices: Array = []

# CanvasLayer HUD notifikasi autosave
var _save_hud_layer: CanvasLayer = null
var _save_hud_label: Label = null

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	# Pastikan slot save aktif di SaveSystem
	if SaveSystem:
		SaveSystem.set_slot(active_slot)

	_setup_save_hud()

	# Hubungkan event selesai dialog dari addon HorrorDialogue
	if HorrorDialogue:
		HorrorDialogue.dialogue_finished.connect(_on_dialogue_finished)
		HorrorDialogue.dialogue_event_triggered.connect(_on_dialogue_event_triggered)

	# Tunggu frame pertama agar node pemain dan Amir sudah siap di scene
	call_deferred(&"_find_scene_nodes")

func _exit_tree() -> void:
	if instance == self:
		instance = null

## Mencari node Player dan Amir di dalam scene saat ini
func _find_scene_nodes() -> void:
	# Cari Player
	for node in get_tree().get_nodes_in_group(&"player"):
		if node is Node3D:
			player_node = node
			break
	if player_node == null:
		var scene = get_tree().current_scene
		if scene:
			player_node = scene.find_child("CharacterBody3D", true, false)

	# Cari Amir (NPCChaser)
	for node in get_tree().get_nodes_in_group(&"chaser"):
		if node is NPCChaser:
			amir_node = node
			break
	if amir_node == null:
		var scene = get_tree().current_scene
		if scene:
			var found = scene.find_child("CharacterBody3D2", true, false)
			if found is NPCChaser:
				amir_node = found

	# Terapkan fase Amir sesuai progres saat ini
	_sync_amir_state()

## ============================================================================
## 💾 SISTEM PENYIMPANAN DATA (SAVESYSTEM EASY_SAVE)
## ============================================================================

## Menyimpan posisi, rotasi, status cerita, dan progres bunga ke disk
func save_game_state(custom_slot: int = -1) -> bool:
	if SaveSystem == null:
		return false

	if not is_instance_valid(player_node) or not is_instance_valid(amir_node):
		_find_scene_nodes()

	var slot: int = active_slot if custom_slot < 0 else custom_slot
	SaveSystem.set_slot(slot)

	if is_instance_valid(player_node):
		SaveSystem.set_value("player_position", player_node.global_position)
		SaveSystem.set_value("player_rotation_y", player_node.rotation.y)
		if "camera" in player_node and player_node.camera:
			SaveSystem.set_value("camera_pitch", player_node.camera.rotation.x)
		if "is_crouching" in player_node:
			SaveSystem.set_value("player_crouching", player_node.is_crouching)

	SaveSystem.set_value("current_chapter", int(current_chapter))
	SaveSystem.set_value("flowers_collected", flowers_collected)
	SaveSystem.set_value("flowers_deposited", flowers_deposited)
	SaveSystem.set_value("amir_phase", amir_phase)
	SaveSystem.set_value("picked_flower_indices", picked_flower_indices)

	if is_instance_valid(amir_node):
		SaveSystem.set_value("amir_position", amir_node.global_position)
		SaveSystem.set_value("amir_rotation_y", amir_node.rotation.y)

	var inv: Node = get_node_or_null("/root/Inventory")
	if inv and inv.has_method("save_to_dictionary"):
		SaveSystem.set_value("inventory_data", inv.save_to_dictionary())

	if SaveSystem.has_method("save_nodes_in_group"):
		SaveSystem.save_nodes_in_group("saveable")

	var success: bool = SaveSystem.save_game()
	if success:
		_show_save_indicator("💾 PROGRES TERSIMPAN")
		game_saved.emit()

	return success

func load_game_state(custom_slot: int = -1) -> bool:
	if SaveSystem == null:
		return false

	var slot: int = active_slot if custom_slot < 0 else custom_slot
	if not SaveSystem.slot_exists(slot):
		return false

	SaveSystem.set_slot(slot)
	var success: bool = SaveSystem.load_game()
	if not success:
		return false

	if not is_instance_valid(player_node) or not is_instance_valid(amir_node):
		_find_scene_nodes()

	current_chapter = SaveSystem.get_value("current_chapter", Chapter.PROLOGUE_DAY) as Chapter
	flowers_collected = int(SaveSystem.get_value("flowers_collected", 0))
	flowers_deposited = int(SaveSystem.get_value("flowers_deposited", 0))
	amir_phase = int(SaveSystem.get_value("amir_phase", 1))
	picked_flower_indices = SaveSystem.get_value("picked_flower_indices", [])

	if is_instance_valid(player_node):
		var saved_pos = SaveSystem.get_value("player_position", null)
		if saved_pos is Vector3:
			player_node.global_position = saved_pos
		elif saved_pos is Dictionary and saved_pos.get("__type__") == "Vector3":
			player_node.global_position = Vector3(saved_pos.get("x", 0.0), saved_pos.get("y", 0.0), saved_pos.get("z", 0.0))

		var saved_rot_y = SaveSystem.get_value("player_rotation_y", null)
		if saved_rot_y != null:
			player_node.rotation.y = float(saved_rot_y)
			if "camera" in player_node and player_node.camera and "yaw" in player_node.camera:
				player_node.camera.yaw = float(saved_rot_y)

		var saved_pitch = SaveSystem.get_value("camera_pitch", null)
		if saved_pitch != null and "camera" in player_node and player_node.camera:
			player_node.camera.rotation.x = float(saved_pitch)
			if "pitch" in player_node.camera:
				player_node.camera.pitch = float(saved_pitch)

		if "velocity" in player_node:
			player_node.velocity = Vector3.ZERO

	if is_instance_valid(amir_node):
		var amir_pos = SaveSystem.get_value("amir_position", null)
		if amir_pos is Vector3:
			amir_node.global_position = amir_pos
		elif amir_pos is Dictionary and amir_pos.get("__type__") == "Vector3":
			amir_node.global_position = Vector3(amir_pos.get("x", 0.0), amir_pos.get("y", 0.0), amir_pos.get("z", 0.0))

	if SaveSystem.has_method("load_nodes_in_group"):
		SaveSystem.load_nodes_in_group("saveable")

	var inv: Node = get_node_or_null("/root/Inventory")
	if inv and SaveSystem.has_value("inventory_data"):
		var inv_data = SaveSystem.get_value("inventory_data")
		if inv_data is Dictionary:
			inv.load_from_dictionary(inv_data)

	if picked_flower_indices.size() > 0:
		for flower in get_tree().get_nodes_in_group(&"flower_pickup"):
			if "flower_index" in flower and picked_flower_indices.has(flower.flower_index):
				flower.queue_free()

	_sync_amir_state()
	flower_count_changed.emit(flowers_collected, flowers_deposited)
	chapter_changed.emit(current_chapter)
	_show_save_indicator("📂 PROGRES DIMUAT")
	game_loaded.emit()

	return true

func request_continue_game(slot: int = 1) -> void:
	active_slot = slot
	pending_restore = true
	if SaveSystem:
		SaveSystem.set_slot(slot)
		SaveSystem.load_game()

func apply_loaded_game() -> void:
	if not pending_restore:
		return
	pending_restore = false
	_find_scene_nodes()
	load_game_state(active_slot)

func has_save_file(slot: int = -1) -> bool:
	if SaveSystem == null:
		return false
	var target_slot: int = active_slot if slot < 0 else slot
	return SaveSystem.slot_exists(target_slot)

func collect_flower(idx: int = -1) -> void:
	if idx > 0 and not picked_flower_indices.has(idx):
		picked_flower_indices.append(idx)
	flowers_collected = mini(flowers_collected + 1, max_flowers)
	flower_count_changed.emit(flowers_collected, flowers_deposited)
	_evaluate_amir_phase()
	save_game_state()

## Mendepositkan bunga yang ada di inventory ke Altar (mengosongkan slot tas)
func deposit_flower_to_altar(amount: int = 1) -> void:
	flowers_deposited = mini(flowers_deposited + amount, max_flowers)
	flower_count_changed.emit(flowers_collected, flowers_deposited)
	_evaluate_amir_phase()

	# Jika 8 bunga sudah terkumpul di altar, masuk ke babak ritual akhir
	if flowers_deposited >= max_flowers and current_chapter != Chapter.FINAL_RITUAL:
		set_chapter(Chapter.FINAL_RITUAL)

	# Autosave setiap kali deposit bunga berhasil
	save_game_state()

## Evaluasi fase AI Amir berdasarkan jumlah total bunga
func _evaluate_amir_phase() -> void:
	var total_flowers: int = maxi(flowers_collected, flowers_deposited)
	var new_phase: int = 1
	if total_flowers >= 6:
		new_phase = 3
	elif total_flowers >= 3:
		new_phase = 2
	else:
		new_phase = 1

	if new_phase != amir_phase:
		amir_phase = new_phase
		amir_phase_changed.emit(amir_phase)
		_sync_amir_state()

## Sinkronisasi pengaturan ke NPCChaser
func _sync_amir_state() -> void:
	if not is_instance_valid(amir_node):
		return

	if amir_node.has_method("set_phase"):
		amir_node.set_phase(amir_phase)

	# Jika masih di babak prolog siang hari, sembunyikan atau matikan pergerakan Amir
	if current_chapter == Chapter.PROLOGUE_DAY:
		amir_node.process_mode = Node.PROCESS_MODE_DISABLED
		amir_node.visible = false
	else:
		amir_node.process_mode = Node.PROCESS_MODE_INHERIT
		amir_node.visible = true

## Mengubah babak cerita
func set_chapter(new_chapter: Chapter) -> void:
	if current_chapter == new_chapter:
		return
	current_chapter = new_chapter
	chapter_changed.emit(current_chapter)
	_sync_amir_state()
	save_game_state()

## ============================================================================
## 🎭 DIALOG & EVENT HANDLERS
## ============================================================================

func _on_dialogue_finished(_dialogue_id: String = "") -> void:
	pass

func _on_dialogue_event_triggered(event_name: String) -> void:
	var sm = SoundManager.instance if SoundManager.instance else get_node_or_null("/root/SoundManager")
	match event_name:
		"play_bone_crack_sfx":
			if sm:
				var pos = amir_node.global_position if is_instance_valid(amir_node) else Vector3.ZERO
				sm.play_sfx_3d("bone_crack", pos, 25.0)
		"amir_burst_door":
			var door = get_tree().current_scene.find_child("AmirRoomDoor", true, false)
			if door and door.has_method("burst_open"):
				door.burst_open()
			elif sm:
				sm.play_sfx_2d("door_bang")
			if sm:
				sm.play_jumpscare("jumpscare_hit", 3.0)
		"prologue_day_completed":
			set_chapter(Chapter.FIRST_NIGHT)
		"first_night_chase_started":
			set_chapter(Chapter.HUNTING_FLOWERS)
		"game_ending_cure_completed":
			play_ending(true)
		"game_ending_burn_completed":
			play_ending(false)

## Memulai dialog prolog siang hari
func play_prologue_day() -> void:
	var res = load("res://addons/horror_dialogue/examples/dialogues/prologue_day.tres")
	if res and HorrorDialogue:
		HorrorDialogue.start_dialogue(res)

## Memulai dialog insiden malam pertama
func play_first_night_incident() -> void:
	var res = load("res://addons/horror_dialogue/examples/dialogues/first_night_incident.tres")
	if res and HorrorDialogue:
		HorrorDialogue.start_dialogue(res)

var is_cure_ending: bool = true

## Memulai sinematik ending
func play_ending(is_cure: bool) -> void:
	is_cure_ending = is_cure
	set_chapter(Chapter.ENDING)
	get_tree().change_scene_to_file("res://Scenes/ending_cinematic.tscn")

## ============================================================================
## 🖥️ UI AUTOSAVE INDICATOR
## ============================================================================

func _setup_save_hud() -> void:
	_save_hud_layer = CanvasLayer.new()
	_save_hud_layer.layer = 50

	_save_hud_label = Label.new()
	_save_hud_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_save_hud_label.offset_left = -220.0
	_save_hud_label.offset_top = 20.0
	_save_hud_label.offset_right = -20.0
	_save_hud_label.offset_bottom = 50.0
	_save_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_save_hud_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 0.9))
	_save_hud_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_save_hud_label.add_theme_constant_override("shadow_offset_x", 1)
	_save_hud_label.add_theme_constant_override("shadow_offset_y", 1)
	_save_hud_label.add_theme_font_size_override("font_size", 14)
	_save_hud_label.modulate.a = 0.0

	_save_hud_layer.add_child(_save_hud_label)
	add_child(_save_hud_layer)

func _show_save_indicator(text: String) -> void:
	if _save_hud_label == null:
		return
	_save_hud_label.text = text
	var tween = create_tween()
	tween.tween_property(_save_hud_label, ^"modulate:a", 1.0, 0.3)
	tween.tween_interval(1.8)
	tween.tween_property(_save_hud_label, ^"modulate:a", 0.0, 0.6)
