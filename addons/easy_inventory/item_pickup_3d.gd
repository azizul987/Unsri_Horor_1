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
## Teks interaksi yang muncul di HUD/Crosshair
@export var prompt_message: String = "Ambil %s"
## Jika true, item langsung terambil saat disentuh pemain (tanpa perlu tekan tombol interaksi)
@export var auto_pickup_on_touch: bool = false

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

var _initial_y: float = 0.0
var _time_elapsed: float = 0.0

func _ready() -> void:
	_initial_y = position.y
	monitoring = true
	monitorable = true

	if auto_pickup_on_touch:
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if enable_bobbing or enable_rotation:
		_time_elapsed += delta

		if enable_bobbing:
			position.y = _initial_y + sin(_time_elapsed * bob_speed) * bob_height

		if enable_rotation:
			rotate_y(rotation_speed * delta)

## Mengembalikan teks interaksi yang sudah diformat dengan nama item
func get_interaction_prompt() -> String:
	if item_data != null:
		return prompt_message % item_data.name
	return "Ambil Item"

## Fungsi interaksi yang dipanggil oleh RayCast3D interaksi milik Player
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
		picked_up.emit(interactor)
		_play_pickup_sound_and_free()
		return true

	# Inventory penuh
	return false

func _on_body_entered(body: Node3D) -> void:
	if auto_pickup_on_touch and body is CharacterBody3D:
		interact(body)

func _play_pickup_sound_and_free() -> void:
	if pickup_sound != null:
		var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		audio_player.stream = pickup_sound
		audio_player.global_position = global_position
		audio_player.finished.connect(audio_player.queue_free)
		get_tree().current_scene.add_child(audio_player)
		audio_player.play()

	queue_free()

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
