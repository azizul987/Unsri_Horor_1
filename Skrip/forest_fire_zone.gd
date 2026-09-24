@tool
class_name ForestFireZone
extends Node3D

## ============================================================================
## 🌲🔥 GENERATOR ZONA KEBAKARAN HUTAN (FOREST FIRE ZONE SYSTEM)
## ============================================================================
## Mengelola satu area hutan terbakar secara otomatis.
## Fitur unggulan:
## 1. Men-spawn puluhan pohon terbakar secara acak di dalam area (Zone Size).
## 2. Mengacak tinggi pohon, ketebalan batang, dan rotasi agar tampak alami.
## 3. Optimasi Performa Cerdas (Light Budget): Hanya menyalakan lampu api di
##    beberapa pohon utama agar FPS tidak drop (tetap lancar 60+ FPS).
## 4. Efek Atmosfer Hutan: Hujan abu & bara melayang di seluruh area hutan.
## ============================================================================

const BURNING_TREE_SCENE_PATH = "res://Scenes/forest_fire_tree.tscn"

@export_group("Area & Jumlah Pohon")
## Ukuran area hutan terbakar dalam meter (Panjang X, Lebar Z)
@export var zone_size: Vector2 = Vector2(40.0, 40.0):
	set(val):
		zone_size = val
		if is_inside_tree() and Engine.is_editor_hint():
			_update_zone_preview()

## Jumlah pohon terbakar yang ingin dibuat di dalam zona ini
@export_range(3, 100, 1) var tree_count: int = 15

## Jarak aman dari titik tengah zona (agar ada jalan/celah di tengah untuk lewat pemain)
@export_range(0.0, 15.0, 0.5) var center_clearance: float = 3.0

@export_group("Model & Variasi Pohon")
## Model pohon Anda (.tscn) yang akan otomatis dipasang ke SEMUA pohon di hutan ini (Opsional).
## Anda bisa mengisinya nanti kapan saja!
@export var tree_model: PackedScene = null:
	set(val):
		tree_model = val
		if is_inside_tree() and tree_model != null:
			_apply_tree_model_to_all()

## Rentang acak tinggi pohon (meter)
@export var min_tree_height: float = 4.5
@export var max_tree_height: float = 8.5

## Rentang acak ketebalan batang pohon (meter)
@export var min_trunk_radius: float = 0.35
@export var max_trunk_radius: float = 0.65

@export_group("Optimasi Performa (Anti-Lag)")
## Jumlah maksimal pohon yang menyalakan lampu (OmniLight3D).
## Jika Anda punya 30 pohon, menyalakan 30 lampu akan membuat game berat.
## Cukup nyalakan 3 - 5 lampu utama untuk menerangi seluruh hutan!
@export_range(1, 20, 1) var max_active_lights: int = 4

## Persentase pohon yang berkobar api (0.8 = 80% berkobar api, 20% hanya berasap)
@export_range(0.2, 1.0, 0.05) var fire_ratio: float = 0.85

@export_group("Aksi Generator (Klik di Inspector)")
## Centang kotak ini untuk meng-generate pohon hutan sekarang
@export var generate_forest_now: bool = false:
	set(val):
		if val:
			generate_zone()
			generate_forest_now = false

## Centang kotak ini untuk menghapus seluruh pohon yang telah di-generate
@export var clear_forest_now: bool = false:
	set(val):
		if val:
			clear_zone()
			clear_forest_now = false

@export_group("Atmosfer Global Hutan")
## Aktifkan hujan abu dan percikan bara melayang di seluruh area hutan
@export var enable_ambient_embers: bool = true:
	set(val):
		enable_ambient_embers = val
		if ambient_embers:
			ambient_embers.emitting = enable_ambient_embers

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var trees_container: Node3D = $TreesContainer
@onready var ambient_embers: CPUParticles3D = $AmbientEmbers
@onready var zone_boundary_guide: MeshInstance3D = $ZoneBoundaryGuide
@onready var zone_audio: AudioStreamPlayer3D = $ZoneAudio

func _ready() -> void:
	if not Engine.is_editor_hint():
		if zone_boundary_guide:
			zone_boundary_guide.visible = false
	else:
		_update_zone_preview()

# ============================================================================
# GENERATOR LOGIC
# ============================================================================
## Menghasilkan hutan pohon terbakar secara acak di dalam area
func generate_zone() -> void:
	clear_zone()

	if not trees_container:
		trees_container = Node3D.new()
		trees_container.name = "TreesContainer"
		add_child(trees_container)
		if Engine.is_editor_hint() and get_tree():
			trees_container.owner = get_tree().edited_scene_root

	var tree_res: PackedScene = load(BURNING_TREE_SCENE_PATH)
	if not tree_res:
		push_error("Gagal memuat scene pohon terbakar: " + BURNING_TREE_SCENE_PATH)
		return

	var half_x: float = zone_size.x * 0.5
	var half_z: float = zone_size.y * 0.5
	var spawned_lights: int = 0

	# Buat daftar posisi acak
	for i in range(tree_count):
		var tree_node: ForestFireTree = tree_res.instantiate() as ForestFireTree
		if not tree_node:
			continue

		# Cari koordinat X dan Z yang tidak menumpuk di tengah
		var pos_x: float = randf_range(-half_x, half_x)
		var pos_z: float = randf_range(-half_z, half_z)
		var dist_from_center: float = Vector2(pos_x, pos_z).length()

		if dist_from_center < center_clearance:
			var dir: Vector2 = Vector2(pos_x, pos_z).normalized()
			if dir.length_squared() < 0.01:
				dir = Vector2(1, 0)
			var new_pos: Vector2 = dir * (center_clearance + randf_range(1.0, 4.0))
			pos_x = clamp(new_pos.x, -half_x, half_x)
			pos_z = clamp(new_pos.y, -half_z, half_z)

		tree_node.position = Vector3(pos_x, 0.0, pos_z)
		tree_node.rotation.y = randf_range(0.0, TAU)

		# Acak dimensi pohon
		var h: float = randf_range(min_tree_height, max_tree_height)
		var r: float = randf_range(min_trunk_radius, max_trunk_radius)
		tree_node.tree_height = h
		tree_node.trunk_radius = r

		# Pasang model pohon kustom jika ada
		if tree_model != null:
			tree_node.tree_scene = tree_model

		# Optimasi Lampu: hanya beberapa pohon pertama yang menyalakan lampu
		if spawned_lights < max_active_lights:
			tree_node.enable_light = true
			spawned_lights += 1
		else:
			tree_node.enable_light = false

		# Variasi api: sebagian pohon hanya berasap
		if randf() > fire_ratio:
			tree_node.fire_intensity = 0.2
			tree_node.smoke_density = 1.3

		trees_container.add_child(tree_node)
		if Engine.is_editor_hint() and get_tree():
			tree_node.owner = get_tree().edited_scene_root

	print("🔥 Berhasil men-generate %d pohon kebakaran hutan di zona %dx%d m!" % [tree_count, int(zone_size.x), int(zone_size.y)])

## Menghapus seluruh pohon di dalam zona
func clear_zone() -> void:
	if not trees_container:
		trees_container = get_node_or_null("TreesContainer")
		if not trees_container:
			return

	for child in trees_container.get_children():
		child.queue_free()

## Memasang model pohon ke seluruh pohon yang sudah ada di dalam zona
func _apply_tree_model_to_all() -> void:
	if not trees_container:
		return
	for child in trees_container.get_children():
		if child is ForestFireTree:
			child.tree_scene = tree_model

## Memperbarui kotak batas area di 3D Editor
func _update_zone_preview() -> void:
	if not zone_boundary_guide:
		return
	if zone_boundary_guide.mesh is BoxMesh:
		var bm: BoxMesh = zone_boundary_guide.mesh
		bm.size = Vector3(zone_size.x, 0.2, zone_size.y)
	if ambient_embers:
		ambient_embers.emission_box_extents = Vector3(zone_size.x * 0.5, 6.0, zone_size.y * 0.5)
		ambient_embers.position = Vector3(0.0, 6.0, 0.0)
