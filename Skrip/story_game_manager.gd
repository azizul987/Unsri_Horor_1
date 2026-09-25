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
@export var autosave_interval: float = 30.0

# Referensi node dalam game
var player_node: Node3D = null
var amir_node: NPCChaser = null
var pending_restore: bool = false
var picked_flower_indices: Array = []
@export var amir_cinematic_played: bool = false

var _is_cinematic_active: bool = false
var _is_player_dead: bool = false
var _death_hud_layer: CanvasLayer = null
var _warning_hud_layer: CanvasLayer = null

# CanvasLayer HUD notifikasi autosave
var _save_hud_layer: CanvasLayer = null
var _save_hud_label: Label = null

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	if SaveSystem:
		SaveSystem.set_slot(active_slot)

	_setup_save_hud()

	if HorrorDialogue:
		HorrorDialogue.dialogue_finished.connect(_on_dialogue_finished)
		HorrorDialogue.dialogue_event_triggered.connect(_on_dialogue_event_triggered)

	get_tree().node_added.connect(_on_tree_node_added)
	call_deferred(&"_find_scene_nodes")
	_start_autosave_loop()

func _start_autosave_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(autosave_interval).timeout
		if is_instance_valid(player_node) and not get_tree().paused:
			save_game_state()

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _on_tree_node_added(node: Node) -> void:
	if node is NPCChaser:
		amir_node = node
		if not amir_node.caught_player.is_connected(_on_amir_caught_player):
			amir_node.caught_player.connect(_on_amir_caught_player)
		_sync_amir_state()
	elif node.name == "HorrorDoor" and node.has_signal("door_opened"):
		if not node.door_opened.is_connected(_on_amir_door_opened):
			node.door_opened.connect(_on_amir_door_opened)

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

	if is_instance_valid(amir_node):
		if not amir_node.caught_player.is_connected(_on_amir_caught_player):
			amir_node.caught_player.connect(_on_amir_caught_player)

	# Cari Pintu Kamar Amir (HorrorDoor)
	var scene = get_tree().current_scene
	if scene:
		var door = scene.find_child("HorrorDoor", true, false)
		if door and door.has_signal("door_opened"):
			if not door.door_opened.is_connected(_on_amir_door_opened):
				door.door_opened.connect(_on_amir_door_opened)

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
	SaveSystem.set_value("amir_cinematic_played", amir_cinematic_played)

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
		_show_save_indicator("PROGRES TERSIMPAN")
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
	amir_cinematic_played = bool(SaveSystem.get_value("amir_cinematic_played", false))

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
	_show_save_indicator("PROGRES DIMUAT")
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
	_is_player_dead = false
	_is_cinematic_active = false
	_find_scene_nodes()
	load_game_state(active_slot)

func reset_story_state() -> void:
	current_chapter = Chapter.PROLOGUE_DAY
	flowers_collected = 0
	flowers_deposited = 0
	picked_flower_indices.clear()
	amir_phase = 1
	amir_cinematic_played = false
	_is_cinematic_active = false
	_is_player_dead = false
	if is_instance_valid(_death_hud_layer):
		_death_hud_layer.queue_free()
		_death_hud_layer = null
	if is_instance_valid(_warning_hud_layer):
		_warning_hud_layer.queue_free()
		_warning_hud_layer = null

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

	amir_node.is_dormant = not amir_cinematic_played
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

## ============================================================================
## 🎬 SINEMATIK TRANSFORMASI AMIR & SISTEM GAME OVER / MATI
## ============================================================================

func _on_amir_door_opened() -> void:
	if amir_cinematic_played or _is_cinematic_active:
		return
	play_amir_transformation_cinematic()

func play_amir_transformation_cinematic() -> void:
	if _is_cinematic_active or not is_instance_valid(amir_node):
		return
	_is_cinematic_active = true
	amir_cinematic_played = true

	var pm = get_node_or_null("/root/PauseMenu")
	if pm:
		pm.pause_enabled = false

	# Kunci kontrol dan gerak pemain
	if is_instance_valid(player_node):
		if "movement_locked" in player_node:
			player_node.movement_locked = true
		if "velocity" in player_node:
			player_node.velocity = Vector3.ZERO
		var p_cam = player_node.get_node_or_null("Camera3D") if not ("camera" in player_node and player_node.camera) else player_node.camera
		if p_cam:
			p_cam.look_locked = true

	# Posisikan Amir menghadap ke arah pemain
	if is_instance_valid(player_node):
		var target_look = Vector3(player_node.global_position.x, amir_node.global_position.y, player_node.global_position.z)
		if (target_look - amir_node.global_position).length_squared() > 0.1:
			amir_node.look_at(target_look, Vector3.UP)

	# Kamera sinematik close-up ke Amir
	var amir_head = amir_node.global_position + Vector3(0, 1.45, 0)
	var amir_fwd = -amir_node.global_transform.basis.z.normalized()
	var cam_start = amir_head + (amir_fwd * 2.0) + Vector3(0, 0.1, 0)
	var cam_zoom = amir_head + (amir_fwd * 1.2) + Vector3(0, 0.05, 0)

	var cut_cam = Camera3D.new()
	cut_cam.name = "CinematicCutCam"
	cut_cam.near = 0.05
	cut_cam.fov = 65.0
	get_tree().current_scene.add_child(cut_cam)
	cut_cam.global_position = cam_start
	cut_cam.look_at(amir_head, Vector3.UP)
	cut_cam.make_current()

	# Efek aura merah transformasi pada Amir
	var aura_light = OmniLight3D.new()
	aura_light.name = "MonsterAuraLight"
	aura_light.light_color = Color(1.0, 0.05, 0.05)
	aura_light.light_energy = 0.0
	aura_light.omni_range = 6.0
	amir_node.add_child(aura_light)
	aura_light.position = Vector3(0, 1.2, 0)

	var sm = SoundManager.instance if SoundManager.instance else get_node_or_null("/root/SoundManager")

	# Langkah 1: Rintihan/Gasp Amir + cahaya merah mulai redup
	if sm:
		sm.play_sfx_3d("amir_gasp", amir_node.global_position, 25.0)
	var light_tween = create_tween()
	light_tween.tween_property(aura_light, ^"light_energy", 1.2, 0.4)
	await get_tree().create_timer(0.45).timeout

	# Langkah 2: Suara patahan tulang
	if sm:
		sm.play_sfx_3d("bone_crack", amir_node.global_position, 25.0, 4.0)
	await get_tree().create_timer(0.4).timeout

	# Langkah 3: Jeritan monster, jumpscare hit, flare cahaya merah, zoom kamera & getaran
	if sm:
		sm.play_sfx_3d("monster_screech", amir_node.global_position, 30.0, 4.0)
		sm.play_jumpscare("jumpscare_hit", 3.0)

	var zoom_tween = create_tween().set_parallel(true)
	zoom_tween.tween_property(cut_cam, ^"global_position", cam_zoom, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	zoom_tween.tween_property(cut_cam, ^"fov", 50.0, 0.6)
	zoom_tween.tween_property(aura_light, ^"light_energy", 3.5, 0.2)

	# Getaran kamera sinematik
	var orig_rot = cut_cam.rotation
	var shake_tween = create_tween()
	for i in 6:
		var shake_rot = orig_rot + Vector3(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04), randf_range(-0.03, 0.03))
		shake_tween.tween_property(cut_cam, ^"rotation", shake_rot, 0.04)
	shake_tween.tween_property(cut_cam, ^"rotation", orig_rot, 0.05)

	# Tampilkan banner peringatan LARI!
	_show_cinematic_warning("AMIR TELAH BERUBAH MENJADI MONSTER!\nLARI DARI SINI SEKARANG!", 2.8)

	await get_tree().create_timer(1.8).timeout

	# Bersihkan objek sinematik
	if is_instance_valid(cut_cam):
		cut_cam.queue_free()
	if is_instance_valid(aura_light):
		aura_light.queue_free()

	# Kembalikan kamera dan kontrol ke player
	if is_instance_valid(player_node):
		var p_cam = player_node.get_node_or_null("Camera3D") if not ("camera" in player_node and player_node.camera) else player_node.camera
		if p_cam:
			p_cam.make_current()
			p_cam.look_locked = false
		if "movement_locked" in player_node:
			player_node.movement_locked = false

	if pm:
		pm.pause_enabled = true

	# Amir bangun dan mulai memburu pemain
	if is_instance_valid(amir_node):
		amir_node.wake_up()

	if current_chapter == Chapter.PROLOGUE_DAY:
		set_chapter(Chapter.FIRST_NIGHT)

	save_game_state()
	_is_cinematic_active = false

func _show_cinematic_warning(msg: String, duration: float = 2.5) -> void:
	if _warning_hud_layer != null:
		_warning_hud_layer.queue_free()

	_warning_hud_layer = CanvasLayer.new()
	_warning_hud_layer.layer = 90

	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -400.0
	label.offset_right = 400.0
	label.offset_top = 80.0
	label.offset_bottom = 200.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = msg
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.modulate.a = 0.0

	_warning_hud_layer.add_child(label)
	add_child(_warning_hud_layer)

	var tween = create_tween()
	tween.tween_property(label, ^"modulate:a", 1.0, 0.3)
	tween.tween_interval(duration)
	tween.tween_property(label, ^"modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		if is_instance_valid(_warning_hud_layer):
			_warning_hud_layer.queue_free()
			_warning_hud_layer = null
	)

func _on_amir_caught_player() -> void:
	if _is_player_dead or _is_cinematic_active:
		return
	_is_player_dead = true

	var pm = get_node_or_null("/root/PauseMenu")
	if pm:
		pm.pause_enabled = false

	# Hentikan dan kunci gerak player & hadapkan ke Amir
	if is_instance_valid(player_node):
		if "movement_locked" in player_node:
			player_node.movement_locked = true
		if "velocity" in player_node:
			player_node.velocity = Vector3.ZERO
		var p_cam = player_node.get_node_or_null("Camera3D") if not ("camera" in player_node and player_node.camera) else player_node.camera
		if p_cam:
			p_cam.look_locked = true
			if p_cam.has_method("look_at_target") and is_instance_valid(amir_node):
				p_cam.look_at_target(amir_node.global_position + Vector3(0, 1.2, 0))

	# Hentikan gerak Amir
	if is_instance_valid(amir_node):
		amir_node.is_dormant = true
		amir_node.velocity = Vector3.ZERO

	# Efek audio jumpscare & jeritan horor
	var sm = SoundManager.instance if SoundManager.instance else get_node_or_null("/root/SoundManager")
	if sm:
		sm.play_jumpscare("jumpscare_hit", 4.0)
		sm.play_sfx_2d("horror_scream", 2.0)

	_show_death_screen()

func _show_death_screen() -> void:
	if _death_hud_layer != null:
		return

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_death_hud_layer = CanvasLayer.new()
	_death_hud_layer.layer = 100

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.01, 0.01, 0.0)
	_death_hud_layer.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_hud_layer.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)

	var title = Label.new()
	title.text = "KAMU MATI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(0.95, 0.1, 0.1, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Amir telah menangkapmu dalam kegelapan rusun..."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.9))
	vbox.add_child(subtitle)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	var btn_retry = Button.new()
	btn_retry.text = "COBA LAGI"
	btn_retry.custom_minimum_size = Vector2(220, 46)
	btn_retry.pressed.connect(_on_death_retry_pressed)
	vbox.add_child(btn_retry)

	var btn_menu = Button.new()
	btn_menu.text = "MENU UTAMA"
	btn_menu.custom_minimum_size = Vector2(220, 46)
	btn_menu.pressed.connect(_on_death_menu_pressed)
	vbox.add_child(btn_menu)

	add_child(_death_hud_layer)

	var tween = create_tween()
	tween.tween_property(bg, ^"color:a", 0.92, 0.8)
	btn_retry.grab_focus()

func _on_death_retry_pressed() -> void:
	var sm = SoundManager.instance if SoundManager.instance else get_node_or_null("/root/SoundManager")
	if sm:
		sm.play_sfx_2d("ui_click", 2.0)

	if is_instance_valid(_death_hud_layer):
		_death_hud_layer.queue_free()
		_death_hud_layer = null

	_is_player_dead = false
	var pm = get_node_or_null("/root/PauseMenu")
	if pm:
		pm.pause_enabled = true

	if has_save_file():
		request_continue_game()
	get_tree().reload_current_scene()

func _on_death_menu_pressed() -> void:
	var sm = SoundManager.instance if SoundManager.instance else get_node_or_null("/root/SoundManager")
	if sm:
		sm.play_sfx_2d("ui_click", 2.0)

	if is_instance_valid(_death_hud_layer):
		_death_hud_layer.queue_free()
		_death_hud_layer = null

	_is_player_dead = false
	var pm = get_node_or_null("/root/PauseMenu")
	if pm:
		pm.pause_enabled = true

	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
