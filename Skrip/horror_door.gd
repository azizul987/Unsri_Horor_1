@tool
class_name HorrorDoor
extends Node3D

## ============================================================================
## 🚪 SISTEM PINTU HOROR INTERAKTIF (HORROR DOOR SYSTEM)
## ============================================================================
## Mengelola pintu interaktif dengan engsel pivot, kunci, HUD interaksi,
## dan integrasi suara 3D SoundManager (derit, tutup, gedoran, kunci).
## Dilengkapi fungsi horor khusus: bang_door(), slam_door(), dan burst_open().
## ============================================================================

signal door_opened
signal door_closed
signal door_locked_interacted
signal door_unlocked(key_id: String)
signal door_banged

@export_group("Status & Kunci Pintu")
## Apakah pintu sedang terbuka
@export var is_open: bool = false:
	set(val):
		is_open = val
		if is_inside_tree():
			_update_door_rotation(false)
			_update_nav_link()

## OPSI KUNCI: Apakah pintu ini membutuhkan kunci?
## Jika FALSE (OPSI TANPA KUNCI), pintu bebas dibuka-tutup langsung oleh pemain tanpa perlu item kunci!
@export var requires_key: bool = false:
	set(val):
		requires_key = val
		if not requires_key:
			is_locked = false
		if is_inside_tree():
			_update_prompt()

## Apakah pintu saat ini sedang terkunci? (Hanya berlaku jika requires_key = true)
@export var is_locked: bool = false:
	set(val):
		is_locked = val if requires_key else false
		if is_inside_tree():
			_update_prompt()

## ID item kunci di inventory yang dibutuhkan untuk membuka pintu ini (misal: "room_key")
@export var required_key_id: String = "room_key"

## Pesan saat pemain mencoba membuka pintu yang terkunci tanpa kunci
@export var locked_message: String = "Pintu ini terkunci rapat dari dalam."

## Pesan saat pemain berhasil membuka kunci
@export var unlock_message: String = "Pintu berhasil dibuka menggunakan kunci!"

@export_group("Animasi Engsel")
## Sudut buka pintu (derajat)
@export_range(45.0, 135.0, 5.0) var open_angle: float = 90.0

## Kecepatan buka/tutup pintu (detik)
@export_range(0.2, 3.0, 0.1) var animation_duration: float = 0.75

## Arah buka: 1 (dorong ke depan/dalam), -1 (tarik ke belakang/luar)
@export_enum("Dorong ke Dalam:1", "Tarik ke Luar:-1") var swing_direction: int = 1

@export_group("Kustom Audio (Opsional)")
@export var sfx_open: AudioStream = null
@export var sfx_close: AudioStream = null
@export var sfx_locked: AudioStream = null
@export var sfx_bang: AudioStream = null

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var hinge: Node3D = _find_hinge()
@onready var interact_area: Area3D = get_node_or_null("InteractArea")
@onready var interaction_hud: CanvasLayer = get_node_or_null("InteractionHUD")
@onready var prompt_label: Label = get_node_or_null("InteractionHUD/PromptLabel")
@onready var door_audio: AudioStreamPlayer3D = get_node_or_null("DoorAudio")
@onready var nav_link: NavigationLink3D = _find_nav_link()

func _find_nav_link() -> NavigationLink3D:
	if has_node("NavigationLink3D"):
		return get_node("NavigationLink3D") as NavigationLink3D
	return find_child("NavigationLink3D", true, false) as NavigationLink3D

func _update_nav_link() -> void:
	if nav_link:
		nav_link.enabled = is_open

func _find_hinge() -> Node3D:
	if has_node("Hinge"):
		return get_node("Hinge") as Node3D
	var p = get_node_or_null("pintu") if has_node("pintu") else get_node_or_null("Pintu")
	if p is Node3D:
		return p as Node3D
	return null

var _is_animating: bool = false
var _player_in_range: bool = false
var _player_node: Node3D = null

func _ready() -> void:
	_update_door_rotation(false)

	if not Engine.is_editor_hint():
		if not nav_link:
			nav_link = NavigationLink3D.new()
			nav_link.name = "NavigationLink3D"
			nav_link.start_position = Vector3(0.0, 0.1, -0.75)
			nav_link.end_position = Vector3(0.0, 0.1, 0.75)
			nav_link.bidirectional = true
			add_child(nav_link)
		_update_nav_link()

		if interact_area:
			interact_area.body_entered.connect(_on_body_entered)
			interact_area.body_exited.connect(_on_body_exited)
		if interaction_hud:
			interaction_hud.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _player_in_range or _is_animating:
		return

	var hd = _get_dialogue()
	if hd and (hd.is_dialogue_active() or hd.is_note_active()):
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		interact()
		get_viewport().set_input_as_handled()

# ============================================================================
# INTERAKSI PEMAIN
# ============================================================================

## Interaksi utama tombol E
func interact() -> void:
	if _is_animating:
		return

	# 1. Jika pintu membutuhkan kunci dan sedang terkunci
	if requires_key and is_locked:
		# Cek apakah pemain membawa kuncinya di inventory
		var has_key: bool = _check_player_has_key()
		var hd = _get_dialogue()
		if has_key:
			# Buka kunci
			is_locked = false
			door_unlocked.emit(required_key_id)
			_play_sound("door_open")
			if hd:
				hd.start_monologue([unlock_message], "KUNCI PINTU")
			toggle_door()
		else:
			# Gagang pintu digerakkan tapi terkunci
			_play_sound("door_locked")
			_shake_door_handle()
			door_locked_interacted.emit()
			if hd:
				hd.start_monologue([locked_message], "PINTU TERKUNCI")
		_update_prompt()
		return

	# 2. Jika tidak terkunci: Buka / Tutup
	toggle_door()

## Membuka atau menutup pintu
func toggle_door() -> void:
	if _is_animating:
		return

	is_open = not is_open
	_update_door_rotation(true)

	if is_open:
		_play_sound("door_open")
		door_opened.emit()
	else:
		_play_sound("door_close")
		door_closed.emit()

	_update_prompt()

func _update_door_rotation(animated: bool = true) -> void:
	if not hinge:
		return

	var target_deg: float = (open_angle * swing_direction) if is_open else 0.0
	var target_rad: float = deg_to_rad(target_deg)

	if animated and not Engine.is_editor_hint():
		_is_animating = true
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(hinge, ^"rotation:y", target_rad, animation_duration)
		tween.tween_callback(func(): _is_animating = false)
	else:
		hinge.rotation.y = target_rad

func _shake_door_handle() -> void:
	if not hinge or Engine.is_editor_hint():
		return
	var orig_y: float = hinge.rotation.y
	var tween = create_tween()
	tween.tween_property(hinge, ^"rotation:y", orig_y + deg_to_rad(2.0), 0.05)
	tween.tween_property(hinge, ^"rotation:y", orig_y - deg_to_rad(2.0), 0.05)
	tween.tween_property(hinge, ^"rotation:y", orig_y, 0.05)

# ============================================================================
# 👻 EVENT HOROR SPESIFIK (MALAM PERTAMA & AMIR)
# ============================================================================

## Membanting pintu tertutup secara mendadak (jumpscare / monster mengurung)
func slam_door() -> void:
	if not hinge:
		return
	is_open = false
	_is_animating = true
	_play_sound("door_bang")

	var tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(hinge, ^"rotation:y", 0.0, 0.2)
	tween.tween_callback(func():
		_is_animating = false
		door_closed.emit()
		_update_prompt()
	)

## Efek pintu digedor keras dari dalam (seperti kamar Amir jam 01.00)
func bang_door(count: int = 3, interval: float = 0.45) -> void:
	if not hinge or Engine.is_editor_hint():
		return

	var orig_y: float = hinge.rotation.y
	for i in range(count):
		get_tree().create_timer(i * interval).timeout.connect(func():
			_play_sound("door_bang")
			door_banged.emit()

			# Guncang daun pintu
			var tween = create_tween()
			var shake_dir: float = randf_range(1.5, 3.5) * swing_direction
			tween.tween_property(hinge, ^"rotation:y", orig_y + deg_to_rad(shake_dir), 0.04)
			tween.tween_property(hinge, ^"rotation:y", orig_y, 0.08)
		)

## Menjebol pintu terbuka lebar secara kasar (saat Amir menerjang keluar!)
func burst_open() -> void:
	if not hinge:
		return
	is_locked = false
	is_open = true
	_is_animating = true
	_play_sound("door_bang")

	var target_rad: float = deg_to_rad(open_angle * 1.25 * swing_direction)
	var tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(hinge, ^"rotation:y", target_rad, 0.25)
	tween.tween_callback(func():
		_is_animating = false
		door_opened.emit()
		_update_prompt()
	)

# ============================================================================
# HELPER & INVENTORY INTEGRATION
# ============================================================================

func _check_player_has_key() -> bool:
	if not requires_key or required_key_id == "":
		return true

	# Cek via Singleton Inventory (easy_inventory)
	var inv = null
	if Engine.has_singleton("Inventory"):
		inv = Engine.get_singleton("Inventory")
	elif is_inside_tree() and is_instance_valid(get_node_or_null("/root/Inventory")):
		inv = get_node("/root/Inventory")

	if inv and "slots" in inv:
		for slot in inv.slots:
			if slot and not slot.is_empty() and slot.item_data:
				if slot.item_data.id == required_key_id or (required_key_id == "room_key" and slot.item_data.id == "room_key_02"):
					return true
	return false

func _play_sound(sound_type: String) -> void:
	var custom_stream: AudioStream = null
	match sound_type:
		"door_open": custom_stream = sfx_open
		"door_close": custom_stream = sfx_close
		"door_locked": custom_stream = sfx_locked
		"door_bang": custom_stream = sfx_bang

	# 1. Gunakan audio lokal jika ada stream kustom
	if custom_stream and door_audio:
		door_audio.stream = custom_stream
		door_audio.play()
		return

	# 2. Gunakan SoundManager Autoload
	var sm = _get_sound_manager()
	if sm and sm.has_method("play_sfx_3d"):
		sm.play_sfx_3d(sound_type, global_position, 22.0)
	elif door_audio:
		# Fallback bawaan dari direktori Asset/Audio jika SoundManager belum aktif
		var fallback_path = "res://Asset/Audio/sfx_" + sound_type + ".wav"
		if ResourceLoader.exists(fallback_path):
			door_audio.stream = load(fallback_path)
		door_audio.play()

func _get_dialogue() -> Node:
	if Engine.has_singleton("HorrorDialogue"):
		return Engine.get_singleton("HorrorDialogue")
	if is_inside_tree() and is_instance_valid(get_node_or_null("/root/HorrorDialogue")):
		return get_node("/root/HorrorDialogue")
	return null

func _get_sound_manager() -> Node:
	if Engine.has_singleton("SoundManager"):
		return Engine.get_singleton("SoundManager")
	if is_inside_tree() and is_instance_valid(get_node_or_null("/root/SoundManager")):
		return get_node("/root/SoundManager")
	return null

func _update_prompt() -> void:
	if not prompt_label:
		return
	if requires_key and is_locked:
		if _check_player_has_key():
			prompt_label.text = "[E] Buka Pintu (Gunakan Kunci)"
		else:
			prompt_label.text = "[E] Pintu Terkunci"
	elif is_open:
		prompt_label.text = "[E] Tutup Pintu"
	else:
		prompt_label.text = "[E] Buka Pintu"

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player") or body is CharacterBody3D:
		_player_in_range = true
		_player_node = body
		_update_prompt()
		if interaction_hud:
			interaction_hud.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player") or body is CharacterBody3D:
		_player_in_range = false
		_player_node = null
		if interaction_hud:
			interaction_hud.visible = false
