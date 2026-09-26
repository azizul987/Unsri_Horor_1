@tool
class_name InteractiveTable
extends Node3D

## ============================================================================
## 🗄️ SISTEM MEJA DENGAN LACI INTERAKTIF (INTERACTIVE TABLE)
## ============================================================================
## Meja horor interaktif dengan laci yang dapat dibuka/tutup via raycast kamera.
## Level designer dapat menaruh item (Kunci, Biskuit, atau Bunga) di dalam laci.
## Item di dalam laci terikat pada laci sehingga IKUT BERGERAK dan TIDAK AKAN JATUH.
## ============================================================================

signal drawer_opened
signal drawer_closed
signal item_taken(item: ItemData, quantity: int)

@export_group("Status & Konfigurasi Laci")
## Apakah laci sedang dalam keadaan terbuka
@export var is_open: bool = false:
	set(val):
		is_open = val
		if is_inside_tree():
			_update_drawer_position(false)

## Jarak geser laci saat ditarik keluar (dalam meter)
@export var slide_distance: float = 0.45:
	set(val):
		slide_distance = val
		if is_inside_tree():
			_update_drawer_position(false)

## Durasi animasi buka/tutup (detik)
@export_range(0.2, 2.0, 0.05) var animation_duration: float = 0.45

## Arah geser: 1 (tarik maju keluar +Z), -1 (dorong ke dalam -Z)
@export_enum("Maju ke Depan (+Z):1", "Maju ke Belakang (-Z):-1") var slide_direction: int = -1:
	set(val):
		slide_direction = val
		if is_inside_tree():
			_update_drawer_position(false)

@export_group("Item di Dalam Laci (Level Designer)")
## Item yang diletakkan di dalam laci untuk ditemukan pemain (Kunci, Biskuit, Bunga, dll)
@export var starting_item: ItemData = null

## Jumlah item awal
@export_range(1, 99) var starting_quantity: int = -1

@export_group("Audio")
@export var sfx_open: AudioStream = preload("res://Asset/Audio/sfx_door_open.wav")
@export var sfx_close: AudioStream = preload("res://Asset/Audio/sfx_door_close.wav")

# ============================================================================
# NODE REFERENCES
# ============================================================================
const DEFAULT_CLOSED_POS: Vector3 = Vector3(0.3255191, 0.50608504, 1.231879)

@onready var drawer_node: Node3D = _find_drawer_node()
@onready var item_slot: Node3D = _find_or_create_item_slot()
@onready var table_audio: AudioStreamPlayer3D = get_node_or_null("TableAudio")

# Internal state
var _closed_local_pos: Vector3 = Vector3.ZERO
var _is_animating: bool = false
var _current_tween: Tween = null

# Item yang saat ini ada di dalam laci
var current_item_data: ItemData = null
var current_item_quantity: int = 0
var _spawned_item_node: Node3D = null

func _find_drawer_node() -> Node3D:
	if has_node("Drawer"):
		return get_node("Drawer") as Node3D
	if has_node("meja_dibuka/Cube_185"):
		return get_node("meja_dibuka/Cube_185") as Node3D
	if has_node("Cube_185"):
		return get_node("Cube_185") as Node3D
	var found = find_child("Cube_185", true, false)
	if found is Node3D:
		return found as Node3D
	return null

func _get_closed_pos() -> Vector3:
	if _closed_local_pos != Vector3.ZERO:
		return _closed_local_pos

	var drawer: Node3D = drawer_node if drawer_node else _find_drawer_node()
	if drawer:
		# Jika nama node adalah Cube_185 (mesh laci bawaan meja_dibuka),
		# gunakan posisi asli DEFAULT_CLOSED_POS agar tidak terkorupsi saat dibuka/ditutup
		if drawer.name == "Cube_185":
			_closed_local_pos = DEFAULT_CLOSED_POS
			return _closed_local_pos

		if absf(drawer.position.z) > 0.05:
			_closed_local_pos = drawer.position
			return _closed_local_pos

	_closed_local_pos = DEFAULT_CLOSED_POS
	return _closed_local_pos

func _find_or_create_item_slot() -> Node3D:
	var drawer = _find_drawer_node()
	if drawer == null:
		return null
	if drawer.has_node("ItemSlot"):
		return drawer.get_node("ItemSlot") as Node3D
	var slot: Node3D = Node3D.new()
	slot.name = "ItemSlot"
	slot.scale = Vector3.ONE * 3.261245
	slot.position = Vector3(-0.07, -0.02, 1.12)
	drawer.add_child(slot)
	return slot

func _ready() -> void:
	add_to_group("meja")
	add_to_group("saveable")
	if drawer_node == null:
		drawer_node = _find_drawer_node()
	if item_slot == null:
		item_slot = _find_or_create_item_slot()

	_closed_local_pos = _get_closed_pos()
	_update_drawer_position(false)

	if not Engine.is_editor_hint():
		# Spawn item awal yang ditentukan oleh level designer
		if starting_item != null:
			put_item(starting_item, starting_quantity)
		elif current_item_data != null:
			_create_item_in_slot()
			_update_item_visibility()
		else:
			_update_item_visibility()

# ============================================================================
# INTERAKSI KAMERA RAYCAST
# ============================================================================

## Prompt teks yang ditampilkan di crosshair tengah layar saat pemain melihat meja/laci
func get_interaction_prompt() -> String:
	if not is_open:
		return "[E] Buka Laci"
	else:
		return "[E] Tutup Laci"

## Fungsi interaksi yang dipanggil oleh raycast kamera pemain saat menekan E
func interact(_interactor: Node = null) -> void:
	if _is_animating:
		return
	toggle_drawer()

## Buka atau tutup laci
func toggle_drawer() -> void:
	if _is_animating:
		return

	is_open = not is_open
	_update_drawer_position(true)

	if is_open:
		_play_sound("open")
		drawer_opened.emit()
	else:
		_play_sound("close")
		drawer_closed.emit()

func _update_drawer_position(animated: bool = true) -> void:
	if drawer_node == null:
		drawer_node = _find_drawer_node()
	if not drawer_node:
		return

	var closed_pos: Vector3 = _get_closed_pos()
	var target_pos: Vector3 = closed_pos
	if is_open:
		target_pos = closed_pos + Vector3(0, 0, slide_distance * float(slide_direction))

	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	if animated and not Engine.is_editor_hint() and is_inside_tree():
		_is_animating = true
		_current_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_current_tween.tween_property(drawer_node, ^"position", target_pos, animation_duration)
		_current_tween.tween_callback(func():
			_is_animating = false
			_update_item_visibility()
		)
	else:
		_is_animating = false
		drawer_node.position = target_pos
		_update_item_visibility()

# ============================================================================
# PENGELOLAAN ITEM DI DALAM LACI ("TIDAK JATUH")
# ============================================================================

## Memasukkan item ke dalam laci (diparent ke ItemSlot di dalam laci, tanpa gravitasi)
func put_item(item: ItemData, qty: int = 1) -> bool:
	if item == null:
		return false

	current_item_data = item
	current_item_quantity = qty

	if drawer_node == null:
		drawer_node = _find_drawer_node()
	if item_slot == null:
		item_slot = _find_or_create_item_slot()

	_create_item_in_slot()
	_update_item_visibility()
	return true

## Spawn visual item di dalam ItemSlot (terikat sebagai child agar bergerak bersama laci)
func _create_item_in_slot() -> void:
	_clear_item_in_slot_visual()
	if item_slot == null:
		item_slot = _find_or_create_item_slot()
	if not item_slot or current_item_data == null:
		return

	# Kasus 1: Jika item adalah BUNGA MISTIS (FLOWER)
	var is_flower_item: bool = (current_item_data.item_type == ItemData.ItemType.FLOWER or current_item_data.flower_index > 0)
	if is_flower_item:
		var flower_scene_path: String = "res://Scenes/flower_pickup.tscn"
		if ResourceLoader.exists(flower_scene_path):
			var fl_scene: PackedScene = load(flower_scene_path) as PackedScene
			if fl_scene:
				var fl_inst = fl_scene.instantiate() as Node3D
				if fl_inst:
					fl_inst.set("flower_index", current_item_data.flower_index)
					fl_inst.set("item_data", current_item_data)
					fl_inst.set("enable_hover", false)
					fl_inst.set("enable_spin", false)
					fl_inst.scale = Vector3.ONE * 0.7
					# Sesuaikan collision shape agar pas di dalam laci
					var col: CollisionShape3D = fl_inst.get_node_or_null("CollisionShape3D") as CollisionShape3D
					if col:
						var s: SphereShape3D = SphereShape3D.new()
						s.radius = 0.35
						col.shape = s
					# Hapus InteractionHUD internal agar tidak bentrok dengan raycast crosshair
					var fl_hud = fl_inst.get_node_or_null("InteractionHUD")
					if fl_hud:
						fl_hud.queue_free()
					# Hubungkan sinyal picked_up
					if fl_inst.has_signal("picked_up"):
						fl_inst.connect("picked_up", _on_item_picked_up)
					item_slot.add_child(fl_inst)
					fl_inst.position = Vector3.ZERO
					_spawned_item_node = fl_inst
					return

	# Kasus 2: Item standar (Kunci, Biskuit, Alat, dll)
	var pickup_scene: PackedScene = load("res://addons/easy_inventory/item_pickup_3d.tscn")
	if pickup_scene:
		_spawned_item_node = pickup_scene.instantiate() as Node3D
		if _spawned_item_node:
			_spawned_item_node.set("item_data", current_item_data)
			_spawned_item_node.set("quantity", current_item_quantity)
			_spawned_item_node.set("enable_bobbing", false)
			_spawned_item_node.set("enable_rotation", false)

			# Hapus InteractionHUD bawaan agar raycast crosshair yang menangani
			var item_hud = _spawned_item_node.get_node_or_null("InteractionHUD")
			if item_hud:
				item_hud.queue_free()

			var mesh_inst: MeshInstance3D = _spawned_item_node.get_node_or_null("MeshInstance3D") as MeshInstance3D
			if current_item_data.id == "room_key":
				if mesh_inst:
					mesh_inst.scale = Vector3.ONE * 1.8
			elif current_item_data.world_mesh_scene != null:
				if mesh_inst:
					mesh_inst.visible = false
				var custom_mesh: Node = current_item_data.world_mesh_scene.instantiate()
				if custom_mesh is Node3D:
					custom_mesh.scale = Vector3.ONE * 1.2
					_spawned_item_node.add_child(custom_mesh)

			if _spawned_item_node.has_signal("picked_up"):
				_spawned_item_node.connect("picked_up", _on_item_picked_up)

			item_slot.add_child(_spawned_item_node)
			_spawned_item_node.position = Vector3.ZERO

func _on_item_picked_up(_a = null, _b = null) -> void:
	if current_item_data:
		item_taken.emit(current_item_data, current_item_quantity)
	current_item_data = null
	current_item_quantity = 0
	_spawned_item_node = null

func _clear_item_in_slot_visual() -> void:
	if _spawned_item_node and is_instance_valid(_spawned_item_node):
		_spawned_item_node.queue_free()
		_spawned_item_node = null
	if item_slot == null:
		item_slot = _find_or_create_item_slot()
	if item_slot:
		for child in item_slot.get_children():
			child.queue_free()

## Update visibilitas & interaksi item: hanya aktif saat laci terbuka
func _update_item_visibility() -> void:
	if item_slot == null:
		item_slot = _find_or_create_item_slot()
	if not item_slot:
		return

	var should_be_active: bool = is_open and not _is_animating
	item_slot.visible = is_open

	if _spawned_item_node and is_instance_valid(_spawned_item_node):
		if _spawned_item_node is CollisionObject3D:
			(_spawned_item_node as CollisionObject3D).set_deferred(&"monitoring", should_be_active)
			(_spawned_item_node as CollisionObject3D).set_deferred(&"monitorable", should_be_active)
		var col: CollisionShape3D = _spawned_item_node.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col:
			col.set_deferred(&"disabled", not should_be_active)

func _play_sound(type: String) -> void:
	var stream: AudioStream = sfx_open if type == "open" else sfx_close
	if stream and table_audio:
		table_audio.stream = stream
		table_audio.play()

# ============================================================================
# DUKUNGAN SERIALISASI / SAVE SYSTEM (EASYSAVE)
# ============================================================================

func get_save_data() -> Dictionary:
	return {
		"is_open": is_open,
		"item_id": current_item_data.id if current_item_data else "",
		"item_quantity": current_item_quantity
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("is_open"):
		is_open = bool(data["is_open"])
		_update_drawer_position(false)
	if data.has("item_id") and str(data["item_id"]) != "":
		var item_path = "res://addons/easy_inventory/examples/items/%s.tres" % str(data["item_id"])
		if ResourceLoader.exists(item_path):
			var loaded_res = load(item_path) as ItemData
			var qty = int(data.get("item_quantity", 1))
			put_item(loaded_res, qty)
	else:
		current_item_data = null
		current_item_quantity = 0
		_clear_item_in_slot_visual()
