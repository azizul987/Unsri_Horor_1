class_name EasyPauseMenu
extends CanvasLayer

## Menu Pause modular dan reusable untuk Godot 4.x.
## Otomatis menangani freeze tree, auto mouse capture/release, animasi tween, dan tombol aksi.

signal paused
signal resumed
signal restarted
signal save_pressed
signal main_menu_pressed
signal quit_pressed

@export_group("Input & Trigger")
## Mengizinkan atau melarang pause menu secara global (misal matikan saat cutscene).
@export var pause_enabled: bool = true
## Nama input action untuk toggle pause (default: "ui_cancel").
@export var pause_action: StringName = &"ui_cancel"
## Apakah tombol ESC fisik selalu diizinkan untuk toggle pause.
@export var allow_escape_key: bool = true
## Daftar nama scene yang dilarang memunculkan pause menu (misal Main Menu, Splash, GameOver).
@export var forbidden_scenes: PackedStringArray = ["MainMenu", "MainMenui", "TitleScreen", "Splash"]

@export_group("Mouse Management")
## Otomatis melepas mouse capture saat pause dan menguncinya kembali saat resume (krusial untuk game 3D/FPS).
@export var manage_mouse_mode: bool = true

@export_group("Buttons Visibility")
@export var show_restart_button: bool = true
@export var show_save_button: bool = true
@export var show_main_menu_button: bool = true
@export var show_quit_button: bool = true

@export_group("Navigation")
## Path file scene (.tscn) untuk kembali ke menu utama.
@export_file("*.tscn") var main_menu_scene_path: String = "res://Scenes/main_menu.tscn"

@export_group("Animation")
## Durasi animasi buka dan tutup menu (detik).
@export_range(0.05, 1.0, 0.05) var animation_duration: float = 0.22
## Warna dan transparansi backdrop overlay saat game dipause.
@export var backdrop_color: Color = Color(0.0, 0.0, 0.0, 0.65)

@export_group("Audio")
## Sound effect opsional saat tombol ditekan.
@export var sfx_button_click: AudioStream

var _saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _is_animating: bool = false
var _audio_player: AudioStreamPlayer

@onready var backdrop: ColorRect = $Backdrop
@onready var center_container: CenterContainer = $CenterContainer
@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var resume_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RestartButton
@onready var save_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SaveButton
@onready var main_menu_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MainMenuButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitButton


func _ready() -> void:
	# WAJIB PROCESS_MODE_ALWAYS agar UI dan animasi tetap berjalan saat get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	hide()

	_setup_audio()
	_apply_button_visibilities()
	_connect_signals()

func _input(event: InputEvent) -> void:
	if _is_pause_event(event):
		if not is_pause_allowed():
			return
		toggle_pause()
		get_viewport().set_input_as_handled()


## ============================================================================
## PUBLIC CONTROL METHODS
## ============================================================================

## Memeriksa apakah game saat ini sedang dalam kondisi pause.
func is_game_paused() -> bool:
	return get_tree().paused

## Mengaktifkan atau menonaktifkan kemampuan pause (misal saat cutscene/dialog).
func set_pause_enabled(enabled: bool) -> void:
	pause_enabled = enabled

## Memeriksa apakah scene aktif saat ini mengizinkan aksi pause.
func is_pause_allowed() -> bool:
	if not pause_enabled:
		return false

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		var scene_node_name: String = current_scene.name.to_lower()
		var scene_file_name: String = current_scene.scene_file_path.get_file().get_basename().to_lower()

		for forbidden_name: String in forbidden_scenes:
			var forb_lower: String = forbidden_name.to_lower()
			if scene_node_name == forb_lower or scene_file_name == forb_lower:
				return false
	return true

## Buka atau tutup pause menu secara bergantian.
func toggle_pause() -> void:
	if is_game_paused():
		resume_game()
	else:
		pause_game()

## Menghentikan sementara game dan membuka menu pause.
func pause_game() -> void:
	if is_game_paused() or _is_animating:
		return

	if manage_mouse_mode:
		_saved_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	get_tree().paused = true
	show()
	_animate_open()
	paused.emit()

## Melanjutkan kembali game dan menutup menu pause.
func resume_game() -> void:
	if not is_game_paused() or _is_animating:
		return

	_animate_close(func() -> void:
		get_tree().paused = false
		hide()
		if manage_mouse_mode:
			Input.mouse_mode = _saved_mouse_mode
		resumed.emit()
	)


## ============================================================================
## PRIVATE HELPERS & BUTTON HANDLERS
## ============================================================================

func _connect_signals() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	save_button.pressed.connect(_on_save_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _apply_button_visibilities() -> void:
	restart_button.visible = show_restart_button
	save_button.visible = show_save_button
	main_menu_button.visible = show_main_menu_button
	quit_button.visible = show_quit_button and OS.has_feature("pc")

func _setup_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "PauseSFXPlayer"
	_audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_audio_player)

func _play_sfx() -> void:
	if sfx_button_click != null and _audio_player != null:
		_audio_player.stream = sfx_button_click
		_audio_player.play()

func _is_pause_event(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if not pause_action.is_empty() and event.is_action_pressed(pause_action):
		return true
	if allow_escape_key and event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			return true
	return false

func _on_resume_pressed() -> void:
	_play_sfx()
	_animate_button_bounce(resume_button)
	resume_game()

func _on_restart_pressed() -> void:
	_play_sfx()
	_animate_button_bounce(restart_button)
	restarted.emit()

	# Lepas pause sebelum reload scene agar scene baru tidak membeku
	get_tree().paused = false
	if manage_mouse_mode:
		Input.mouse_mode = _saved_mouse_mode
	get_tree().reload_current_scene()

func _on_save_pressed() -> void:
	_play_sfx()
	_animate_button_bounce(save_button)
	save_pressed.emit()

	var saved_success: bool = false
	var root: Window = get_tree().root
	var ss: Node = root.get_node_or_null("SaveSystem")
	if ss:
		if ss.has_method("has_active_slot") and not ss.has_active_slot():
			if ss.has_method("set_slot"):
				ss.set_slot(1)

		var player: Node = get_tree().get_first_node_in_group(&"player")
		if player:
			ss.set_value("player_position", player.global_position)
			ss.set_value("player_rotation_y", player.rotation.y)
			if "camera" in player and player.camera:
				ss.set_value("camera_pitch", player.camera.rotation.x)
			if "is_crouching" in player:
				ss.set_value("player_crouching", player.is_crouching)

		if ss.has_method("save_nodes_in_group"):
			ss.save_nodes_in_group("saveable")

		var inv: Node = root.get_node_or_null("Inventory")
		if inv and inv.has_method("save_to_dictionary"):
			ss.set_value("inventory_data", inv.save_to_dictionary())

		var sm: Node = root.get_node_or_null("StoryManager")
		if sm and sm.has_method("save_game_state"):
			saved_success = sm.save_game_state()
		elif ss.has_method("save_game"):
			saved_success = bool(ss.save_game())

	var original_text: String = save_button.text
	save_button.text = "Tersimpan! ✓" if saved_success else "Tersimpan!"
	save_button.disabled = true

	var timer: SceneTreeTimer = get_tree().create_timer(1.2, true)
	await timer.timeout
	if is_instance_valid(save_button):
		save_button.text = original_text
		save_button.disabled = false

func _on_main_menu_pressed() -> void:
	_play_sfx()
	_animate_button_bounce(main_menu_button)
	main_menu_pressed.emit()

	get_tree().paused = false
	hide()
	_is_animating = false
	if manage_mouse_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var path: String = main_menu_scene_path
	if path.is_empty():
		path = "res://Scenes/main_menu.tscn"
	get_tree().call_deferred(&"change_scene_to_file", path)

func _on_quit_pressed() -> void:
	_play_sfx()
	_animate_button_bounce(quit_button)
	quit_pressed.emit()
	get_tree().quit()


## ============================================================================
## TWEEN ANIMATIONS (PAUSE-SAFE)
## ============================================================================

func _animate_open() -> void:
	_is_animating = true

	backdrop.color = Color(backdrop_color.r, backdrop_color.g, backdrop_color.b, 0.0)
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.75, 0.75)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var tween: Tween = create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_property(backdrop, "color", backdrop_color, animation_duration)
	tween.tween_property(panel, "scale", Vector2.ONE, animation_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, animation_duration * 0.8)

	tween.chain().tween_callback(func() -> void:
		_is_animating = false
		if is_instance_valid(resume_button):
			resume_button.grab_focus()
	)

func _animate_close(on_finished_callback: Callable) -> void:
	_is_animating = true

	var tween: Tween = create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_property(backdrop, "color:a", 0.0, animation_duration * 0.7)
	tween.tween_property(panel, "scale", Vector2(0.85, 0.85), animation_duration * 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, animation_duration * 0.6)

	tween.chain().tween_callback(func() -> void:
		_is_animating = false
		if on_finished_callback.is_valid():
			on_finished_callback.call()
	)

func _animate_button_bounce(btn: Button) -> void:
	if btn == null:
		return
	btn.pivot_offset = btn.size / 2.0
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.06)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
