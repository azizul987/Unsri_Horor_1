class_name MainMenuController
extends Control

@export_file("*.tscn") var start_game_scene: String = "res://Scenes/main.tscn"

@onready var play_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PlayButton
@onready var continue_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ContinueButton
@onready var quit_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitButton
@onready var ambience_audio: AudioStreamPlayer = $AmbienceAudio

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	play_button.pressed.connect(_on_play_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	_check_save_state()
	play_button.grab_focus()

func _check_save_state() -> void:
	var has_save: bool = false
	var root: Window = get_tree().root
	if root.has_node("SaveSystem"):
		var ss = root.get_node("SaveSystem")
		if ss.has_method("get_all_used_slots"):
			var slots: Array = ss.get_all_used_slots()
			has_save = slots.size() > 0

	continue_button.visible = has_save
	if not has_save:
		play_button.focus_neighbor_bottom = quit_button.get_path()
		quit_button.focus_neighbor_top = play_button.get_path()

func _on_play_pressed() -> void:
	_animate_button(play_button)
	var sm: Node = get_node_or_null("/root/StoryManager")
	if sm:
		sm.pending_restore = false
	var root: Window = get_tree().root
	if root.has_node("SaveSystem"):
		var ss = root.get_node("SaveSystem")
		if ss.has_method("set_slot"):
			ss.set_slot(1)
	var inv: Node = get_node_or_null("/root/Inventory")
	if inv and inv.has_method("clear_inventory"):
		inv.clear_inventory()

	await get_tree().create_timer(0.15).timeout
	if not start_game_scene.is_empty():
		get_tree().change_scene_to_file(start_game_scene)

func _on_continue_pressed() -> void:
	_animate_button(continue_button)
	var root: Window = get_tree().root
	var target_slot: int = 1
	if root.has_node("SaveSystem"):
		var ss = root.get_node("SaveSystem")
		if ss.has_method("get_all_used_slots"):
			var slots: Array = ss.get_all_used_slots()
			if slots.size() > 0:
				target_slot = slots[0]

	var sm: Node = get_node_or_null("/root/StoryManager")
	if sm and sm.has_method("request_continue_game"):
		sm.request_continue_game(target_slot)
	elif root.has_node("SaveSystem"):
		var ss = root.get_node("SaveSystem")
		if ss.has_method("set_slot") and ss.has_method("load_game"):
			ss.set_slot(target_slot)
			ss.load_game()

	await get_tree().create_timer(0.15).timeout
	if not start_game_scene.is_empty():
		get_tree().change_scene_to_file(start_game_scene)

func _on_quit_pressed() -> void:
	_animate_button(quit_button)
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

func _animate_button(btn: Button) -> void:
	if btn == null:
		return
	btn.pivot_offset = btn.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.06)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
