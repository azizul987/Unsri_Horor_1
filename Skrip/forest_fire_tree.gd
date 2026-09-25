@tool
class_name ForestFireTree
extends Node3D

## ============================================================================
## 🌲 SISTEM EFEK API KEBAKARAN HUTAN (MODULAR FOREST FIRE VFX)
## ============================================================================
## Scene ini dirancang khusus untuk efek pohon terbakar dalam kebakaran hutan.
## Memiliki 'TreeSlot' kosong sehingga Anda bebas memasukkan model pohon (FBX,
## GLTF, MeshInstance3D, atau .tscn) kapan saja.
## ============================================================================

signal fire_state_changed(is_burning: bool)
signal player_entered_fire_zone(player: Node3D)
signal player_exited_fire_zone(player: Node3D)
signal damage_dealt(target: Node3D, amount: float)

@export_group("Pohon (Tree Slot)")
## Scene pohon (.tscn atau model) yang ingin di-spawn otomatis di dalam TreeSlot (Opsional).
## Anda juga bisa langsung drag & drop model pohon ke node 'TreeSlot' di Scene Tree.
@export var tree_scene: PackedScene = null:
	set(val):
		tree_scene = val
		if is_inside_tree():
			_setup_tree_scene()

## Ketinggian pohon (dalam meter). Mengubah nilai ini akan otomatis menyesuaikan
## posisi kobaran api kanopi, tinggi rambatan api batang, asal asap, dan panduan visual.
@export_range(2.0, 20.0, 0.5) var tree_height: float = 6.0:
	set(val):
		tree_height = val
		if is_inside_tree():
			update_fire_layout()

## Radius ketebalan batang pohon (dalam meter). Menyesuaikan sebaran api di pangkal pohon.
@export_range(0.1, 3.0, 0.1) var trunk_radius: float = 0.5:
	set(val):
		trunk_radius = val
		if is_inside_tree():
			update_fire_layout()

## Tampilkan siluet panduan pohon di 3D Editor (Otomatis hilang saat game dijalankan).
@export var show_editor_preview: bool = true:
	set(val):
		show_editor_preview = val
		_update_preview_visibility()

@export_group("Kontrol Api & Asap")
## Status apakah api sedang berkobar atau padam
@export var is_burning: bool = true:
	set(val):
		is_burning = val
		if is_inside_tree():
			_apply_burning_state()

## Pengali intensitas kobaran lidah api (0.1 = kecil/padam, 1.0 = normal, 2.5 = hebat)
@export_range(0.1, 3.0, 0.1) var fire_intensity: float = 1.0:
	set(val):
		fire_intensity = val
		if is_inside_tree():
			update_fire_layout()

## Kepadatan dan ketebalan asap hitam membubung
@export_range(0.1, 3.0, 0.1) var smoke_density: float = 1.0:
	set(val):
		smoke_density = val
		if is_inside_tree():
			update_fire_layout()

## Arah tiupan angin yang mempengaruhi kepulan asap dan percikan bara melayang
@export var wind_direction: Vector3 = Vector3(1.2, 0.4, 0.6):
	set(val):
		wind_direction = val
		if is_inside_tree():
			update_fire_layout()

@export_group("Pencahayaan Api (Light Flicker)")
## Aktifkan pencahayaan api yang menerangi lingkungan
@export var enable_light: bool = true:
	set(val):
		enable_light = val
		if fire_light:
			fire_light.visible = enable_light and is_burning

## Warna cahaya api pendaran hangat
@export var light_color: Color = Color(1.0, 0.45, 0.12, 1.0):
	set(val):
		light_color = val
		if fire_light:
			fire_light.light_color = light_color

## Kekuatan terang cahaya dasar
@export_range(0.5, 10.0, 0.5) var light_energy_base: float = 3.5

## Seberapa besar goyangan terang-redup api
@export_range(0.0, 3.0, 0.1) var light_flicker_amount: float = 1.2

## Kecepatan kedipan/goyangan api
@export_range(1.0, 30.0, 1.0) var light_flicker_speed: float = 14.0

@export_group("Gameplay Bahaya & Damage")
## Apakah pohon yang terbakar memberi efek panas/damage ke pemain jika mendekat
@export var enable_heat_damage: bool = true

## Jumlah damage per detik jika pemain berada di zona panas
@export_range(0.0, 100.0, 1.0) var damage_per_second: float = 10.0

## Radius zona bahaya panas di sekitar pohon (dalam meter)
@export_range(1.0, 15.0, 0.5) var heat_radius: float = 3.5:
	set(val):
		heat_radius = val
		if is_inside_tree():
			update_fire_layout()

@export_group("Audio Api")
## Audio suara kobaran api / kayu terbakar (opsional)
@export var fire_sound: AudioStream = null:
	set(val):
		fire_sound = val
		if fire_audio:
			fire_audio.stream = fire_sound
			if fire_sound and is_burning and not Engine.is_editor_hint():
				fire_audio.play()

## Volume suara api (dB)
@export_range(-40.0, 10.0, 0.5) var sound_volume_db: float = 0.0:
	set(val):
		sound_volume_db = val
		if fire_audio:
			fire_audio.volume_db = sound_volume_db

## Jarak maksimal suara terdengar (meter)
@export_range(5.0, 100.0, 1.0) var sound_max_distance: float = 35.0:
	set(val):
		sound_max_distance = val
		if fire_audio:
			fire_audio.max_distance = sound_max_distance

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var tree_slot: Node3D = $TreeSlot
@onready var editor_preview: Node3D = $EditorTreePreview
@onready var fire_system: Node3D = $FireSystem
@onready var fire_base: CPUParticles3D = $FireSystem/FireBase
@onready var fire_trunk: CPUParticles3D = $FireSystem/FireTrunk
@onready var fire_canopy: CPUParticles3D = $FireSystem/FireCanopy
@onready var smoke_column: CPUParticles3D = $FireSystem/SmokeColumn
@onready var embers_sparks: CPUParticles3D = $FireSystem/EmbersSparks
@onready var fire_light: OmniLight3D = $FireLight
@onready var fire_audio: AudioStreamPlayer3D = $FireAudio
@onready var heat_area: Area3D = $HeatDamageArea
@onready var heat_shape: CollisionShape3D = $HeatDamageArea/CollisionShape3D

var _flicker_time: float = 0.0
var _overlapping_targets: Array[Node3D] = []

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	# Panduan editor selalu dinonaktifkan di dalam game runtime
	if not Engine.is_editor_hint():
		if editor_preview:
			editor_preview.visible = false
			editor_preview.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		_update_preview_visibility()

	# Jika ada tree_scene di inspector, spawn ke dalam TreeSlot
	_setup_tree_scene()

	# Sambungkan deteksi zona bahaya panas
	if heat_area and not Engine.is_editor_hint():
		if not heat_area.body_entered.is_connected(_on_heat_area_body_entered):
			heat_area.body_entered.connect(_on_heat_area_body_entered)
		if not heat_area.body_exited.is_connected(_on_heat_area_body_exited):
			heat_area.body_exited.connect(_on_heat_area_body_exited)

	# Setup audio jika ada stream
	if fire_audio:
		fire_audio.stream = fire_sound
		fire_audio.volume_db = sound_volume_db
		fire_audio.max_distance = sound_max_distance
		if not Engine.is_editor_hint() and is_burning and fire_sound:
			fire_audio.play()

	update_fire_layout()
	_apply_burning_state()

func _process(delta: float) -> void:
	if not is_burning:
		return

	# Animasi flickering cahaya api alami
	if enable_light and fire_light:
		_flicker_time += delta
		var noise_flicker: float = (
			sin(_flicker_time * light_flicker_speed) * 0.35 +
			sin(_flicker_time * light_flicker_speed * 2.37) * 0.25 +
			(randf() - 0.5) * 0.15
		)
		fire_light.light_energy = max(0.0, light_energy_base + noise_flicker * light_flicker_amount)

	# Logika damage berkala terhadap pemain di zona panas
	if not Engine.is_editor_hint() and enable_heat_damage and _overlapping_targets.size() > 0:
		var current_damage: float = damage_per_second * delta
		for target in _overlapping_targets:
			if is_instance_valid(target):
				_apply_damage_to_target(target, current_damage)

# ============================================================================
# LAYOUT & PENGATURAN SKALA API OTOMATIS
# ============================================================================
## Menata ulang posisi vertikal dan radius partikel api berdasarkan tree_height & trunk_radius
func update_fire_layout() -> void:
	var h: float = tree_height
	var r: float = trunk_radius

	# Skala model pohon agar proporsional dengan tinggi pohon (pohon.fbx tinggi dasarnya ~12-14m)
	if tree_slot:
		var s: float = clampf(h / 12.0, 0.4, 2.0)
		tree_slot.scale = Vector3(s, s, s)

	# 1. Api Pangkal (FireBase): berada di permukaan tanah / akar pohon
	if fire_base:
		fire_base.position = Vector3(0.0, 0.3, 0.0)
		fire_base.emission_sphere_radius = max(0.4, r * 1.4)
		fire_base.scale_amount_min = 1.0 * fire_intensity
		fire_base.scale_amount_max = 1.8 * fire_intensity

	# 2. Api Batang (FireTrunk): merambat di sepanjang batang
	if fire_trunk:
		fire_trunk.position = Vector3(0.0, h * 0.35, 0.0)
		fire_trunk.emission_box_extents = Vector3(r * 0.9, h * 0.3, r * 0.9)
		fire_trunk.scale_amount_min = 0.9 * fire_intensity
		fire_trunk.scale_amount_max = 1.6 * fire_intensity

	# 3. Api Kanopi / Mahkota (FireCanopy): membakar dedaunan di atas
	if fire_canopy:
		fire_canopy.position = Vector3(0.0, h * 0.75, 0.0)
		var canopy_radius: float = max(1.2, r * 2.5)
		fire_canopy.emission_sphere_radius = canopy_radius
		fire_canopy.scale_amount_min = 1.4 * fire_intensity
		fire_canopy.scale_amount_max = 2.4 * fire_intensity

	# 4. Kolom Asap Hitam (SmokeColumn): membubung dari kanopi ke angkasa
	if smoke_column:
		smoke_column.position = Vector3(0.0, h * 0.85, 0.0)
		smoke_column.emission_sphere_radius = max(1.5, r * 2.2)
		smoke_column.direction = Vector3(wind_direction.x, 2.5, wind_direction.z).normalized()
		smoke_column.scale_amount_min = 2.2 * smoke_density
		smoke_column.scale_amount_max = 4.5 * smoke_density

	# 5. Percikan Bara Api (EmbersSparks): beterbangan ke atas ditiup angin
	if embers_sparks:
		embers_sparks.position = Vector3(0.0, h * 0.5, 0.0)
		embers_sparks.emission_box_extents = Vector3(r * 1.5, h * 0.4, r * 1.5)
		embers_sparks.direction = Vector3(wind_direction.x * 1.2, 3.0, wind_direction.z * 1.2).normalized()

	# 6. Lampu Api (FireLight): berada di tengah batang pohon
	if fire_light:
		fire_light.position = Vector3(0.0, h * 0.45, 0.0)
		fire_light.omni_range = max(8.0, h * 2.0)

	# 7. Zona Bahaya Panas (HeatDamageArea)
	if heat_shape and heat_shape.shape is CylinderShape3D:
		var cyl: CylinderShape3D = heat_shape.shape
		cyl.radius = heat_radius
		cyl.height = h * 1.2
		heat_shape.position = Vector3(0.0, h * 0.5, 0.0)

	# 8. Siluet Panduan Editor (Preview Guide)
	if editor_preview:
		_update_preview_guide_dimensions(h, r)

func _update_preview_guide_dimensions(h: float, r: float) -> void:
	var trunk_mesh: MeshInstance3D = editor_preview.get_node_or_null("PreviewTrunk")
	var canopy_mesh: MeshInstance3D = editor_preview.get_node_or_null("PreviewCanopy")

	if trunk_mesh:
		trunk_mesh.position = Vector3(0.0, h * 0.4, 0.0)
		if trunk_mesh.mesh is CylinderMesh:
			var cm: CylinderMesh = trunk_mesh.mesh
			cm.height = h * 0.8
			cm.top_radius = r * 0.85
			cm.bottom_radius = r * 1.1

	if canopy_mesh:
		canopy_mesh.position = Vector3(0.0, h * 0.85, 0.0)
		if canopy_mesh.mesh is SphereMesh:
			var sm: SphereMesh = canopy_mesh.mesh
			sm.radius = max(1.4, r * 2.6)
			sm.height = sm.radius * 1.8

# ============================================================================
# KONTROL STATUS API (ON / OFF)
# ============================================================================
func set_fire_active(active: bool) -> void:
	is_burning = active

func _apply_burning_state() -> void:
	if fire_base:
		fire_base.emitting = is_burning
	if fire_trunk:
		fire_trunk.emitting = is_burning
	if fire_canopy:
		fire_canopy.emitting = is_burning
	if smoke_column:
		smoke_column.emitting = is_burning
	if embers_sparks:
		embers_sparks.emitting = is_burning

	if fire_light:
		fire_light.visible = is_burning and enable_light

	if fire_audio and not Engine.is_editor_hint():
		if is_burning and fire_sound:
			if not fire_audio.playing:
				fire_audio.play()
		else:
			fire_audio.stop()

	fire_state_changed.emit(is_burning)

# ============================================================================
# SLOT POHON & PREVIEW HELPER
# ============================================================================
## Mengembalikan node kontainer slot pohon
func get_tree_slot() -> Node3D:
	return tree_slot

func _setup_tree_scene() -> void:
	if not tree_slot:
		return

	# Jika ada tree_scene yang di-set dan slot masih kosong
	if tree_scene and tree_slot.get_child_count() == 0:
		var inst: Node = tree_scene.instantiate()
		tree_slot.add_child(inst)
		if Engine.is_editor_hint() and get_tree():
			inst.owner = get_tree().edited_scene_root

	_update_preview_visibility()

func _update_preview_visibility() -> void:
	if not editor_preview:
		return

	# Jika sedang runtime dalam game, selalu sembunyikan preview
	if not Engine.is_editor_hint():
		editor_preview.visible = false
		return

	# Di editor: tampilkan hanya jika diizinkan dan belum ada pohon di tree_slot
	var has_custom_tree: bool = tree_slot != null and tree_slot.get_child_count() > 0
	editor_preview.visible = show_editor_preview and not has_custom_tree

# ============================================================================
# ZONA BAHAYA PANAS (HEAT DAMAGE)
# ============================================================================
func _on_heat_area_body_entered(body: Node3D) -> void:
	if body == self:
		return
	if not _overlapping_targets.has(body):
		_overlapping_targets.append(body)
		player_entered_fire_zone.emit(body)

func _on_heat_area_body_exited(body: Node3D) -> void:
	if _overlapping_targets.has(body):
		_overlapping_targets.erase(body)
		player_exited_fire_zone.emit(body)

func _apply_damage_to_target(target: Node3D, amount: float) -> void:
	# Cek apakah target memiliki fungsi take_damage standar
	if target.has_method("take_damage"):
		target.call("take_damage", amount)
		damage_dealt.emit(target, amount)
	elif target.is_in_group(&"player"):
		# Jika pemain belum punya fungsi take_damage, emit sinyal agar script luar bisa menangkap
		damage_dealt.emit(target, amount)
