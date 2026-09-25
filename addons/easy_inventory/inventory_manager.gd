class_name InventoryManager
extends Node

## Pengelola sistem inventory utama. Dapat berjalan sebagai Autoload Singleton (Inventory)
## atau sebagai child node pada Player. Default 4 slot sesuai tema survival horror Kupu-Kupu Malam.

signal inventory_updated()
signal slot_selected(slot_index: int)
signal item_added(item_data: ItemData, slot_index: int, quantity: int)
signal item_removed(item_data: ItemData, slot_index: int, quantity: int)
signal item_used(item_data: ItemData, slot_index: int)
signal item_dropped(item_data: ItemData, quantity: int, drop_position: Vector3)
signal flower_count_changed(total_flowers: int)

@export_group("Configuration")
## Jumlah maksimal slot inventory (Default: 4 slot untuk survival horror)
@export var max_slots: int = 4
## Scene generic untuk 3D pickup saat item dibuang (jika ItemData tidak mendefinisikan world_mesh_scene)
@export var default_pickup_scene: PackedScene

@export_group("UI")
## Otomatis memunculkan HUD UI Inventory saat game dimulai jika belum ada
@export var auto_spawn_ui: bool = true

var slots: Array[InventorySlotData] = []
var selected_slot_index: int = 0:
	set(value):
		var clamped: int = clampi(value, 0, max(0, max_slots - 1))
		if selected_slot_index != clamped:
			selected_slot_index = clamped
			slot_selected.emit(selected_slot_index)

var _ui_instance: Node = null

func _ready() -> void:
	_initialize_slots()
	if auto_spawn_ui:
		call_deferred(&"_ensure_ui")

func _ensure_ui() -> void:
	if not is_inside_tree():
		return
	var existing = get_tree().get_nodes_in_group(&"inventory_ui")
	if not existing.is_empty():
		return
	# Hanya spawn jika ada Player di scene (bukan di cutscene/intro/splash)
	var players = get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		players = get_tree().get_nodes_in_group(&"Player")
	if players.is_empty():
		return

	if _ui_instance == null:
		var ui_scene: PackedScene = load("res://addons/easy_inventory/ui/inventory_ui.tscn")
		if ui_scene:
			_ui_instance = ui_scene.instantiate()
			add_child(_ui_instance)

## Inisialisasi slot kosong sesuai ukuran max_slots
func _initialize_slots() -> void:
	slots.clear()
	for i in range(max_slots):
		var new_slot: InventorySlotData = InventorySlotData.new()
		slots.append(new_slot)
	inventory_updated.emit()

## Menambahkan item ke inventory. Mengembalikan true jika berhasil masuk, false jika inventory penuh.
func add_item(item_data: ItemData, quantity: int = 1) -> bool:
	if item_data == null or quantity <= 0:
		return false

	var remaining_qty: int = quantity

	# 1. Coba tambahkan ke slot yang sudah ada item yang sama (jika stackable)
	if item_data.max_stack > 1:
		for i in range(slots.size()):
			var slot: InventorySlotData = slots[i]
			if not slot.is_empty() and slot.item_data.id == item_data.id:
				var available_space: int = item_data.max_stack - slot.quantity
				if available_space > 0:
					var to_add: int = mini(available_space, remaining_qty)
					slot.quantity += to_add
					remaining_qty -= to_add
					item_added.emit(item_data, i, to_add)
					if remaining_qty <= 0:
						break

	# 2. Jika masih ada sisa, cari slot kosong pertama
	if remaining_qty > 0:
		for i in range(slots.size()):
			var slot: InventorySlotData = slots[i]
			if slot.is_empty():
				var to_add: int = mini(item_data.max_stack, remaining_qty)
				slot.item_data = item_data
				slot.quantity = to_add
				remaining_qty -= to_add
				item_added.emit(item_data, i, to_add)
				if remaining_qty <= 0:
					break

	# Jika ada item yang berhasil masuk
	if remaining_qty < quantity:
		inventory_updated.emit()
		if item_data.is_flower():
			flower_count_changed.emit(get_flower_count())
		return true

	# Gagal: Inventory penuh
	return false

## Menghapus sejumlah kuantitas item pada slot index tertentu
func remove_item_at_slot(slot_index: int, quantity: int = 1) -> bool:
	if not _is_valid_slot_index(slot_index):
		return false

	var slot: InventorySlotData = slots[slot_index]
	if slot.is_empty() or quantity <= 0:
		return false

	var item_ref: ItemData = slot.item_data
	var to_remove: int = mini(slot.quantity, quantity)
	slot.quantity -= to_remove

	if slot.quantity <= 0:
		slot.clear()

	item_removed.emit(item_ref, slot_index, to_remove)
	inventory_updated.emit()

	if item_ref.is_flower():
		flower_count_changed.emit(get_flower_count())

	return true

## Menghapus item berdasarkan ID unik (misalnya saat kunci pintu dipakai untuk membuka ruangan)
func remove_item_by_id(item_id: String, quantity: int = 1) -> bool:
	var remaining_to_remove: int = quantity
	for i in range(slots.size()):
		var slot: InventorySlotData = slots[i]
		if not slot.is_empty() and slot.item_data.id == item_id:
			var to_remove: int = mini(slot.quantity, remaining_to_remove)
			slot.quantity -= to_remove
			remaining_to_remove -= to_remove

			item_removed.emit(slot.item_data, i, to_remove)
			if slot.quantity <= 0:
				slot.clear()

			if remaining_to_remove <= 0:
				break

	if remaining_to_remove < quantity:
		inventory_updated.emit()
		return true

	return false

## Memeriksa apakah inventory memiliki item tertentu dengan kuantitas minimal
func has_item(item_id: String, min_quantity: int = 1) -> bool:
	return get_item_count(item_id) >= min_quantity

## Mendapatkan total jumlah kuantitas suatu item di semua slot
func get_item_count(item_id: String) -> int:
	var total: int = 0
	for slot in slots:
		if not slot.is_empty() and slot.item_data.id == item_id:
			total += slot.quantity
	return total

## Mendapatkan total bunga (1-8) yang saat ini sedang dibawa
func get_flower_count() -> int:
	var count: int = 0
	for slot in slots:
		if not slot.is_empty() and slot.item_data.is_flower():
			count += 1
	return count

## Memeriksa apakah bunga dengan index tertentu (1 sampai 8) sudah diambil
func has_flower(flower_index: int) -> bool:
	for slot in slots:
		if not slot.is_empty() and slot.item_data.flower_index == flower_index:
			return true
	return false

## Mendapatkan data slot pada index tertentu
func get_slot(slot_index: int) -> InventorySlotData:
	if _is_valid_slot_index(slot_index):
		return slots[slot_index]
	return null

## Memilih slot tertentu (0 sampai max_slots - 1)
func select_slot(slot_index: int) -> void:
	selected_slot_index = slot_index

## Memilih slot berikutnya
func select_next_slot() -> void:
	selected_slot_index = (selected_slot_index + 1) % max_slots

## Memilih slot sebelumnya
func select_prev_slot() -> void:
	selected_slot_index = (selected_slot_index - 1 + max_slots) % max_slots

## Mendapatkan ItemData yang saat ini sedang aktif dipilih
func get_selected_item() -> ItemData:
	var slot: InventorySlotData = get_slot(selected_slot_index)
	if slot and not slot.is_empty():
		return slot.item_data
	return null

## Menggunakan item yang sedang dipilih
func use_selected_item() -> void:
	var slot: InventorySlotData = get_slot(selected_slot_index)
	if slot == null or slot.is_empty():
		return

	var current_item: ItemData = slot.item_data
	if not current_item.is_usable:
		return

	item_used.emit(current_item, selected_slot_index)

	# Jika item bertipe consumable (makanan, baterai, obat), kurangi jumlahnya
	if current_item.item_type == ItemData.ItemType.CONSUMABLE:
		remove_item_at_slot(selected_slot_index, 1)

## Membuang item yang sedang dipilih ke dunia 3D
func drop_selected_item(drop_origin: Vector3, drop_forward: Vector3 = Vector3.FORWARD) -> void:
	drop_item_at_slot(selected_slot_index, drop_origin, drop_forward)

## Membuang item dari slot tertentu ke dunia 3D
func drop_item_at_slot(slot_index: int, drop_origin: Vector3, drop_forward: Vector3 = Vector3.FORWARD) -> void:
	var slot: InventorySlotData = get_slot(slot_index)
	if slot == null or slot.is_empty():
		return

	var item_to_drop: ItemData = slot.item_data
	if not item_to_drop.is_droppable:
		return

	# Raycast ke bawah untuk cari posisi lantai — tidak mungkin tembus
	var drop_pos: Vector3 = _raycast_floor_position(drop_origin, drop_forward)

	remove_item_at_slot(slot_index, 1)
	item_dropped.emit(item_to_drop, 1, drop_pos)
	_spawn_pickup_at(item_to_drop, 1, drop_pos)

## Cari posisi lantai dengan raycast Physics — jauh lebih reliable dari RigidBody
func _raycast_floor_position(from: Vector3, forward: Vector3) -> Vector3:
	# Titik asal ray: depan player, setinggi pinggang
	var ray_from: Vector3 = from + forward.normalized() * 0.8 + Vector3.UP * 0.3
	var ray_to: Vector3 = ray_from + Vector3.DOWN * 6.0

	# Ambil physics space dari player Node3D (lebih reliable dari viewport)
	var space: PhysicsDirectSpaceState3D = null
	var player_rid: RID = RID()

	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	if players.is_empty():
		players = get_tree().get_nodes_in_group(&"Player")

	if not players.is_empty() and players[0] is Node3D:
		var player: Node3D = players[0] as Node3D
		space = player.get_world_3d().direct_space_state
		if player is PhysicsBody3D:
			player_rid = (player as PhysicsBody3D).get_rid()

	# Fallback ke viewport jika tidak ada player
	if space == null:
		var vp: Viewport = get_viewport()
		if vp:
			var w3d: World3D = vp.find_world_3d()
			if w3d:
				space = w3d.direct_space_state

	if space == null:
		return from + forward.normalized() * 0.8 + Vector3(0, 0.05, 0)

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collision_mask = 0xFFFFFFFF  # Deteksi SEMUA layer
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if player_rid.is_valid():
		query.exclude = [player_rid]  # Jangan hit player sendiri

	var result: Dictionary = space.intersect_ray(query)

	if result.has("position"):
		return (result["position"] as Vector3) + Vector3.UP * 0.05
	else:
		return from + forward.normalized() * 0.8 + Vector3(0, 0.05, 0)

## Mengosongkan seluruh isi inventory
func clear_inventory() -> void:
	for slot in slots:
		slot.clear()
	inventory_updated.emit()
	flower_count_changed.emit(0)

## Spawn ItemPickup3D yang bisa diinteraksi (Area3D + CollisionShape + Visual)
func _spawn_pickup_at(item_data: ItemData, qty: int, pos: Vector3) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var pickup_node: Node = null

	# Gunakan default_pickup_scene jika di-set di inspector
	if default_pickup_scene != null:
		pickup_node = default_pickup_scene.instantiate()
		if pickup_node:
			pickup_node.set("item_data", item_data)
			pickup_node.set("quantity", qty)

	# Fallback: buat ItemPickup3D Area3D secara runtime dengan visual
	if pickup_node == null:
		var item_pickup_script: Script = load("res://addons/easy_inventory/item_pickup_3d.gd")
		if item_pickup_script:
			var area_pickup: Area3D = Area3D.new()
			area_pickup.name = "DroppedItem_%s" % item_data.id
			area_pickup.set_script(item_pickup_script)

			# CollisionShape — sphere ukuran wajar agar mudah di-raycast
			var col: CollisionShape3D = CollisionShape3D.new()
			var sphere: SphereShape3D = SphereShape3D.new()
			sphere.radius = 0.25
			col.shape = sphere
			area_pickup.add_child(col)

			# ── Visual Mesh ──────────────────────────────────────────────
			# Prioritas 1: spawn world_mesh_scene dari ItemData sebagai child visual
			if item_data.world_mesh_scene != null:
				var visual: Node = item_data.world_mesh_scene.instantiate()
				if visual is Node3D:
					# Nonaktifkan script pada visual agar tidak conflict
					visual.set_script(null)
					(visual as Node3D).scale = Vector3.ONE * 0.6
					area_pickup.add_child(visual)

			# Prioritas 2: fallback — sphere kecil berwarna agar item terlihat
			elif true:
				var mesh_inst: MeshInstance3D = MeshInstance3D.new()
				var sm: SphereMesh = SphereMesh.new()
				sm.radius = 0.08
				sm.height = 0.16
				var mat: StandardMaterial3D = StandardMaterial3D.new()
				match item_data.item_type:
					ItemData.ItemType.FLOWER:
						mat.albedo_color = Color(0.8, 0.2, 0.9)
						mat.emission_enabled = true
						mat.emission = Color(0.5, 0.1, 0.7)
					ItemData.ItemType.KEY:
						mat.albedo_color = Color(0.9, 0.75, 0.2)
						mat.metallic = 0.8
					ItemData.ItemType.CONSUMABLE:
						mat.albedo_color = Color(0.3, 0.8, 0.4)
					_:
						mat.albedo_color = Color(0.7, 0.65, 0.5)
				sm.material = mat
				mesh_inst.mesh = sm
				area_pickup.add_child(mesh_inst)

			area_pickup.set("item_data", item_data)
			area_pickup.set("quantity", qty)
			pickup_node = area_pickup

	if pickup_node and pickup_node is Node3D:
		pickup_node.set("enable_rotation", true)
		pickup_node.set("rotation_speed", 1.5)
		pickup_node.set("enable_bobbing", true)
		pickup_node.set("bob_height", 0.04)
		pickup_node.set("bob_speed", 2.0)
		current_scene.add_child(pickup_node)
		(pickup_node as Node3D).global_position = pos + Vector3(0, 0.12, 0)

func _is_valid_slot_index(index: int) -> bool:
	return index >= 0 and index < slots.size()
# ==============================================================================
# INTEGRASI SERIALIZATION / SAVE SYSTEM (KOMPATIBEL DENGAN EASYSAVE)
# ==============================================================================

## Menyimpan status inventory ke Dictionary
func save_to_dictionary() -> Dictionary:
	var slot_data_list: Array[Dictionary] = []
	for slot in slots:
		slot_data_list.append(slot.to_dict())

	return {
		"selected_slot_index": selected_slot_index,
		"max_slots": max_slots,
		"slots": slot_data_list
	}

## Memuat status inventory dari Dictionary
func load_from_dictionary(data: Dictionary) -> void:
	if data.is_empty():
		return

	if data.has("max_slots"):
		max_slots = int(data.get("max_slots", 4))

	_initialize_slots()

	var slot_data_list: Array = data.get("slots", [])
	for i in range(mini(slots.size(), slot_data_list.size())):
		var slot_dict: Dictionary = slot_data_list[i]
		slots[i].from_dict(slot_dict)

	if data.has("selected_slot_index"):
		selected_slot_index = int(data.get("selected_slot_index", 0))

	inventory_updated.emit()
	flower_count_changed.emit(get_flower_count())
