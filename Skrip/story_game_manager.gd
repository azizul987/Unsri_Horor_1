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
		push_warning("StoryGameManager: Addon SaveSystem tidak ditemukan.")
		return false

	var slot: int = active_slot if custom_slot < 0 else custom_slot
	SaveSystem.set_slot(slot)

	# 1. Simpan Posisi & Rotasi Pemain
	if is_instance_valid(player_node):
		SaveSystem.set_value("player_position", player_node.global_position)
		SaveSystem.set_value("player_rotation_y", player_node.rotation.y)

	# 2. Simpan Status Cerita
	SaveSystem.set_value("current_chapter", int(current_chapter))
	SaveSystem.set_value("flowers_collected", flowers_collected)
	SaveSystem.set_value("flowers_deposited", flowers_deposited)
	SaveSystem.set_value("amir_phase", amir_phase)

	# 3. Simpan Posisi Amir (jika ada di scene)
	if is_instance_valid(amir_node):
		SaveSystem.set_value("amir_position", amir_node.global_position)
		SaveSystem.set_value("amir_rotation_y", amir_node.rotation.y)

	# 4. Tulis ke file disk JSON (user://saves/save_slot_X.json)
	var success: bool = SaveSystem.save_game()
	if success:
		_show_save_indicator("💾 PROGRES TERSIMPAN")
		game_saved.emit()

	return success

## Memulihkan posisi pemain dan progres cerita dari SaveSystem
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

	# 1. Pulihkan Cerita
	current_chapter = SaveSystem.get_value("current_chapter", Chapter.PROLOGUE_DAY) as Chapter
	flowers_collected = int(SaveSystem.get_value("flowers_collected", 0))
	flowers_deposited = int(SaveSystem.get_value("flowers_deposited", 0))
	amir_phase = int(SaveSystem.get_value("amir_phase", 1))

	# 2. Pulihkan Posisi & Rotasi Pemain
	if is_instance_valid(player_node):
		var saved_pos = SaveSystem.get_value("player_position", null)
		if saved_pos != null:
			player_node.global_position = saved_pos
		var saved_rot_y = SaveSystem.get_value("player_rotation_y", null)
		if saved_rot_y != null:
			player_node.rotation.y = float(saved_rot_y)

	# 3. Pulihkan Posisi Amir
	if is_instance_valid(amir_node):
		var amir_pos = SaveSystem.get_value("amir_position", null)
		if amir_pos != null:
			amir_node.global_position = amir_pos

	_sync_amir_state()
	flower_count_changed.emit(flowers_collected, flowers_deposited)
	chapter_changed.emit(current_chapter)
	_show_save_indicator("📂 PROGRES DIMUAT")
	game_loaded.emit()

	return true

## Memeriksa apakah ada file save game sebelumnya
func has_save_file(slot: int = -1) -> bool:
	if SaveSystem == null:
		return false
	var target_slot: int = active_slot if slot < 0 else slot
	return SaveSystem.slot_exists(target_slot)

## ============================================================================
## 🌺 SISTEM ALUR BUNGA & MANAJEMEN FASE
## ============================================================================

## Dipanggil saat pemain mengambil sebuah bunga di map
func collect_flower() -> void:
	flowers_collected = mini(flowers_collected + 1, max_flowers)
	flower_count_changed.emit(flowers_collected, flowers_deposited)
	_evaluate_amir_phase()
	# Autosave saat pemain memungut bunga
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

func _on_dialogue_finished() -> void:
	pass

func _on_dialogue_event_triggered(event_name: String) -> void:
	match event_name:
		"prologue_day_completed":
			set_chapter(Chapter.FIRST_NIGHT)
		"first_night_chase_started":
			set_chapter(Chapter.HUNTING_FLOWERS)
		"game_ending_cure_completed":
			set_chapter(Chapter.ENDING)
		"game_ending_burn_completed":
			set_chapter(Chapter.ENDING)

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

## Memulai dialog ending
func play_ending(is_cure: bool) -> void:
	var path: String = "res://addons/horror_dialogue/examples/dialogues/ending_cure.tres" if is_cure else "res://addons/horror_dialogue/examples/dialogues/ending_burn.tres"
	var res = load(path)
	if res and HorrorDialogue:
		HorrorDialogue.start_dialogue(res)

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
