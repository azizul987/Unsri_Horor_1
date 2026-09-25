class_name ItemPickup3D
extends Area3D

## Node 3D interactable yang diletakkan di world scene untuk mengambil item ke dalam inventory.
## Cocok untuk Bunga, Biskuit, Baterai, Kunci Kamar, dll.

signal picked_up(interactor: Node)

@export_group("Item Settings")
## Data item yang akan diambil pemain
@export var item_data: ItemData
## Jumlah item yang didapat
@export_range(1, 99) var quantity: int = 1
## Format teks interaksi yang muncul di HUD/Crosshair
@export var prompt_message: String = "[E] Ambil %s"
## Jika true, item langsung terambil saat disentuh pemain (tanpa perlu tekan tombol interaksi)
@export var auto_pickup_on_touch: bool = false
## Apakah menampilkan monolog/pesan saat item berhasil diambil
@export var show_pickup_message: bool = true

@export_group("Floating / Visual Animation")
## Efek melayang naik turun lembut
@export var enable_bobbing: bool = true
@export var bob_speed: float = 2.0
@export var bob_height: float = 0.05
## Efek berputar perlahan pada sumbu Y
@export var enable_rotation: bool = true
@export var rotation_speed: float = 1.0

@export_group("Audio")
## Efek suara saat item diambil
@export var pickup_sound: AudioStream

@onready var interaction_hud: CanvasLayer = get_node_or_null("InteractionHUD")
@onready var prompt_label: Label = get_node_or_null("InteractionHUD/PromptLabel")

var _initial_y: float = 0.0
var _time_elapsed: float = 0.0
var _player_in_range: bool = false
var _player_node: Node = null

func _ready() -> void:
	_initial_y = position.y
	monitoring = true
	monitorable = true

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if interaction_hud:
		interaction_hud.visible = false

func _process(delta: float) -> void:
	if enable_bobbing or enable_rotation:
		_time_elapsed += delta

		if enable_bobbing:
			position.y = _initial_y + sin(_time_elapsed * bob_speed) * bob_height

		if enable_rotation:
			rotate_y(rotation_speed * delta)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return

	var hd = _get_dialogue()
	if hd and (hd.is_dialogue_active() or hd.is_note_active()):
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		interact(_player_node)
		get_viewport().set_input_as_handled()

## Mengembalikan teks interaksi yang sudah diformat dengan nama item
func get_interaction_prompt() -> String:
	if item_data != null:
		return prompt_message % item_data.name
	return "[E] Ambil Item"

## Fungsi interaksi yang dipanggil oleh tombol E atau RayCast3D milik Player
func interact(interactor: Node = null) -> bool:
	if item_data == null:
		push_warning("ItemPickup3D: item_data belum diatur!")
		return false

	# Cari referensi Inventory (Autoload atau child dari interactor)
	var inv: InventoryManager = _get_inventory_manager(interactor)
	if inv == null:
		push_error("ItemPickup3D: InventoryManager tidak ditemukan!")
		return false

	var success: bool = inv.add_item(item_data, quantity)
	if success:
		var hd = _get_dialogue()
		if show_pickup_message and hd:
			var msg: String = "Kamu mengambil [b]%s[/b]." % item_data.name
			if item_data.description != "":
				msg += "\n[color=#b0b0b0]%s[/color]" % item_data.description
			hd.start_monologue([msg], "ITEM DITEMUKAN")

		picked_up.emit(interactor)
		_play_pickup_sound_and_free()
		return true

	# Inventory penuh (maksimal 4 item)
	var hd_full = _get_dialogue()
	if hd_full:
		hd_full.start_monologue(["Tas kamu penuh! Tidak bisa membawa lebih banyak item."], "INVENTORY PENUH")
	return false

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player") or body is CharacterBody3D:
		_player_in_range = true
		_player_node = body

		if auto_pickup_on_touch:
			interact(body)
			return

		if interaction_hud and prompt_label:
			prompt_label.text = get_interaction_prompt()
			interaction_hud.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player") or body is CharacterBody3D:
		_player_in_range = false
		_player_node = null
		if interaction_hud:
			interaction_hud.visible = false

func _play_pickup_sound_and_free() -> void:
	if pickup_sound != null:
		var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		audio_player.stream = pickup_sound
		audio_player.global_position = global_position
		audio_player.finished.connect(audio_player.queue_free)
		get_tree().current_scene.add_child(audio_player)
		audio_player.play()
	else:
		var sm = _get_sound_manager()
		if sm and sm.has_method("play_sfx_3d"):
			sm.play_sfx_3d("flower_bell", global_position, 15.0, -3.0, 1.25)

	if interaction_hud:
		interaction_hud.visible = false
	queue_free()

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

func _get_inventory_manager(interactor: Node) -> InventoryManager:
	# 1. Cek singleton Autoload "Inventory"
	if Engine.has_singleton("Inventory"):
		return Engine.get_singleton("Inventory") as InventoryManager
	if is_instance_valid(get_node_or_null("/root/Inventory")):
		return get_node("/root/Inventory") as InventoryManager

	# 2. Cek apakah interactor memiliki child InventoryManager
	if interactor != null:
		for child in interactor.get_children():
			if child is InventoryManager:
				return child

	return null
