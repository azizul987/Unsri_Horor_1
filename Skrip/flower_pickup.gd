@tool
class_name FlowerPickup
extends Area3D

## ============================================================================
## 🌸 MASTER SISTEM PICKUP 8 BUNGA MISTIS (KUPU-KUPU MALAM)
## ============================================================================
## Memiliki 8 BENTUK 3D BASE MODEL YANG BERBEDA UNTUK TIAP BUNGA:
## 1. Melati Rawa (Kelopak bintang datar kuncup kecil)
## 2. Kembang Api Merah (Kuncup prisma lancip mirip lidah api)
## 3. Bunga Bangkai Kerdil (Mangkuk ceper tebal melebar di lantai)
## 4. Anggrek Kupu-kupu (Sayap ganda melebar ke samping)
## 5. Teratai Abu (3 lapis kelopak berundak bertingkat)
## 6. Kantong Rawa (Corong silinder kantong semar dengan bibir menyala)
## 7. Mawar Arang (Pecahan kristal arang kayu hitam berurat bara oranye)
## 8. Kupu-Kupu Induk (Kupu-kupu malam bersayap 4 dengan antena & jantung berdenyut)
##
## Dilengkapi Slot Model Kustom (CustomMeshSlot) jika ingin memakai model sendiri!
## ============================================================================

signal picked_up(flower_index: int, item_data: ItemData)

const FLOWER_PRESETS = {
	1: {
		"name": "Melati Rawa (Bunga 1)",
		"color": Color(0.85, 0.95, 1.0, 1.0),
		"resource": "res://addons/easy_inventory/examples/items/flower_01.tres",
		"monologue": "Aroma Melati Rawa ini... menenangkan kepalaku dari kepanikan."
	},
	2: {
		"name": "Kembang Api Merah (Bunga 2)",
		"color": Color(1.0, 0.25, 0.15, 1.0),
		"resource": "res://addons/easy_inventory/examples/items/flower_02.tres",
		"monologue": "Kelopaknya terasa hangat di tangan seperti lidah api yang membara."
	},
	3: {
		"name": "Bunga Bangkai Kerdil (Bunga 3)",
		"color": Color(0.65, 0.2, 0.9, 1.0),
		"resource": "res://addons/easy_inventory/examples/items/flower_03.tres",
		"monologue": "Aroma humus rawa basah... baunya menyamarkan keberadaanku dari Amir."
	},
	4: {
		"name": "Anggrek Kupu-kupu (Bunga 4)",
		"color": Color(1.0, 0.85, 0.25, 1.0),
		"resource": "res://addons/easy_inventory/examples/items/flower_04.tres",
		"monologue": "Kelopaknya kaku menyerupai sayap serangga dengan pendaran emas..."
	},
	5: {
		"name": "Teratai Abu (Bunga 5)",
		"color": Color(0.8, 0.9, 1.0, 1.0),
		"resource": "res://addons/easy_inventory/examples/items/flower_05.tres",
		"monologue": "Kelopaknya terasa dingin, seperti butiran abu padat yang membeku."
	},
	6: {
		"name": "Kantong Rawa (Bunga 6)",
		"color": Color(0.2, 1.0, 0.5, 1.0),
		"resource": "res://addons/easy_inventory/examples/items/flower_06.tres",
		"monologue": "Bunga kantong rawa liar... cairan hijau di dalamnya berpijar terang di kegelapan."
	},
	7: {
		"name": "Mawar Arang (Bunga 7)",
		"color": Color(1.0, 0.45, 0.05, 1.0),
		"resource": "res://addons/easy_inventory/examples/items/flower_07.tres",
		"monologue": "Hitam legam berurat bara api... sisa kebakaran hutan yang disulut Amir."
	},
	8: {
		"name": "Kupu-Kupu Induk (Bunga 8)",
		"color": Color(1.0, 0.2, 0.7, 1.0),
		"resource": "res://addons/easy_inventory/examples/items/flower_08.tres",
		"monologue": "Ini dia... Bunga kupu-kupu dari kamar Amir. Jantung bunga ini berdenyut pelan..."
	}
}

@export_group("Pilihan Bunga (1 - 8)")
## Pilih nomor bunga (1 sampai 8). Bentuk 3D, warna glow, nama, resource, dan partikel akan otomatis menyesuaikan!
@export_range(1, 8, 1) var flower_index: int = 1:
	set(val):
		flower_index = clampi(val, 1, 8)
		if is_inside_tree():
			_apply_preset()

@export_group("Slot Model 3D Kustom")
## Model 3D bunga buatan Anda (.tscn, FBX, atau GLTF).
## Jika Anda memasang model di sini (atau drag ke node CustomMeshSlot),
## maka bentuk 3D bawaan otomatis tersembunyi dan digantikan oleh model Anda!
@export var custom_model: PackedScene = null:
	set(val):
		custom_model = val
		if is_inside_tree():
			_setup_custom_model()

## Tetap nyalakan efek pendaran cahaya & partikel debu meskipun memakai model kustom
@export var keep_vfx_with_custom_model: bool = true

@export_group("Efek Animasi Melayang")
## Apakah bunga mengambang naik-turun secara halus
@export var enable_hover: bool = true
@export var hover_speed: float = 2.2
@export var hover_height: float = 0.06

## Kecepatan putaran halus bunga
@export var enable_spin: bool = true
@export var spin_speed: float = 1.0

@export_group("Interaksi & Dialog")
## Tampilkan monolog pemikiran MC saat memungut bunga ini
@export var show_pickup_monologue: bool = true

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var visual_root: Node3D = $VisualRoot
@onready var base_model: Node3D = $VisualRoot/BaseModel
@onready var custom_mesh_slot: Node3D = $VisualRoot/CustomMeshSlot
@onready var flower_light: OmniLight3D = $VisualRoot/FlowerLight
@onready var spore_particles: CPUParticles3D = $VisualRoot/SporeParticles
@onready var interaction_hud: CanvasLayer = $InteractionHUD
@onready var prompt_label: Label = $InteractionHUD/PromptLabel

var item_data: ItemData = null
var current_glow_color: Color = Color.WHITE
var current_flower_name: String = ""
var current_monologue: String = ""

var _initial_y: float = 0.0
var _anim_time: float = 0.0
var _player_in_range: bool = false
var _player_node: Node3D = null

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	_initial_y = visual_root.position.y if visual_root else position.y

	# Setup deteksi player
	monitoring = true
	monitorable = true
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
		if interaction_hud:
			interaction_hud.visible = false

	_apply_preset()
	_setup_custom_model()
	_update_model_visibility()

func _process(delta: float) -> void:
	# Animasi melayang & berputar halus (berjalan di Editor dan In-Game)
	if visual_root and (enable_hover or enable_spin):
		_anim_time += delta

		if enable_hover:
			visual_root.position.y = _initial_y + sin(_anim_time * hover_speed) * hover_height

		if enable_spin:
			visual_root.rotate_y(spin_speed * delta)

	# Efek bernafas pada cahaya pendaran (pulsing light)
	if flower_light and is_instance_valid(flower_light):
		var pulse: float = 0.85 + 0.3 * sin(_anim_time * 3.5)
		flower_light.light_energy = 1.2 * pulse

	# Efek denyut khusus untuk Bunga 8 (Kupu-Kupu Induk)
	if flower_index == 8 and base_model:
		var variant_8: Node3D = base_model.get_node_or_null("Flower_8") as Node3D
		if variant_8 and variant_8.visible:
			var core: Node3D = variant_8.get_node_or_null("Core") as Node3D
			if core:
				var s: float = 1.0 + 0.18 * sin(_anim_time * 4.5)
				core.scale = Vector3(s, s, s)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _player_in_range:
		return

	# Jangan ambil jika sedang membuka dialog atau catatan
	if HorrorDialogue and (HorrorDialogue.is_dialogue_active() or HorrorDialogue.is_note_active()):
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		pickup_flower()
		get_viewport().set_input_as_handled()

# ============================================================================
# PRESET & VISUAL SETUP (BENTUK 3D & WARNA SESUAI INDEX)
# ============================================================================
func _apply_preset() -> void:
	var preset = FLOWER_PRESETS.get(flower_index, FLOWER_PRESETS[1])
	current_flower_name = preset["name"]
	current_glow_color = preset["color"]
	current_monologue = preset["monologue"]

	# Muat item_data resource
	var res_path: String = preset["resource"]
	if ResourceLoader.exists(res_path):
		item_data = load(res_path) as ItemData

	# 1. Update Bentuk 3D: Aktifkan HANYA varian bentuk yang sesuai nomor bunga
	if base_model:
		for i in range(1, 9):
			var variant_node: Node3D = base_model.get_node_or_null("Flower_%d" % i) as Node3D
			if variant_node:
				variant_node.visible = (i == flower_index)

		# Berikan pendaran warna ke Core pada varian yang aktif
		var active_variant: Node3D = base_model.get_node_or_null("Flower_%d" % flower_index) as Node3D
		if active_variant:
			var core: MeshInstance3D = active_variant.find_child("Core", true, false) as MeshInstance3D
			if core:
				var mat: StandardMaterial3D = core.get_surface_override_material(0) as StandardMaterial3D
				if mat == null:
					mat = StandardMaterial3D.new()
					mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					core.set_surface_override_material(0, mat)
				mat.albedo_color = current_glow_color

	# 2. Update warna cahaya OmniLight3D
	if flower_light:
		flower_light.light_color = current_glow_color

	# 3. Update partikel spora debu
	if spore_particles:
		spore_particles.color = Color(current_glow_color.r, current_glow_color.g, current_glow_color.b, 0.85)

	# 4. Update HUD prompt text
	if prompt_label:
		prompt_label.text = "[E] Ambil " + current_flower_name

func _setup_custom_model() -> void:
	if not custom_mesh_slot:
		return

	# Jika ada custom_model di inspector dan slot masih kosong
	if custom_model != null and custom_mesh_slot.get_child_count() == 0:
		var inst: Node = custom_model.instantiate()
		custom_mesh_slot.add_child(inst)
		if Engine.is_editor_hint() and get_tree():
			inst.owner = get_tree().edited_scene_root

	_update_model_visibility()

func _update_model_visibility() -> void:
	if not base_model or not custom_mesh_slot:
		return

	var has_custom: bool = custom_mesh_slot.get_child_count() > 0 or custom_model != null
	base_model.visible = not has_custom

	# Atur apakah lampu & partikel tetap menyala
	if flower_light:
		flower_light.visible = (not has_custom) or keep_vfx_with_custom_model
	if spore_particles:
		spore_particles.visible = (not has_custom) or keep_vfx_with_custom_model

# ============================================================================
# LOGIKA PICKUP INTERAKSI
# ============================================================================
func pickup_flower() -> bool:
	if item_data == null:
		var preset = FLOWER_PRESETS.get(flower_index, FLOWER_PRESETS[1])
		item_data = load(preset["resource"]) as ItemData

	# 1. Cek slot tas di Inventory
	var inv: InventoryManager = _get_inventory()
	if inv != null:
		var success: bool = inv.add_item(item_data, 1)
		if not success:
			# Tas penuh (maksimal 4 item)
			_show_inventory_full_warning()
			return false

	# 2. Notifikasi ke StoryGameManager (tambah counter bunga & evaluasi fase Amir)
	var story = StoryManager if StoryManager else StoryGameManager.instance
	if story:
		story.collect_flower()

	# 3. Mainkan audio pickup chime lembut
	_play_pickup_chime()

	# 4. Tampilkan monolog singkat pemikiran MC
	if show_pickup_monologue and HorrorDialogue and current_monologue != "":
		HorrorDialogue.start_monologue([
			"[color=#ffd700]Kamu memungut [b]%s[/b].[/color]" % current_flower_name,
			current_monologue
		], "BUNGA KEHIDUPAN")

	picked_up.emit(flower_index, item_data)

	# Sembunyikan dan hapus bunga dari dunia
	if interaction_hud:
		interaction_hud.visible = false
	queue_free()
	return true

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player") or body is CharacterBody3D:
		_player_in_range = true
		_player_node = body
		if interaction_hud:
			interaction_hud.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player") or body is CharacterBody3D:
		_player_in_range = false
		_player_node = null
		if interaction_hud:
			interaction_hud.visible = false

func _show_inventory_full_warning() -> void:
	if HorrorDialogue:
		HorrorDialogue.start_monologue([
			"[color=red]Tas kamu penuh! (Maksimal 4 item).[/color]",
			"Bawa bunga yang ada di tas ke [b]Altar Halaman Depan[/b] untuk disimpan!"
		], "INVENTORY PENUH")

func _play_pickup_chime() -> void:
	var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	audio_player.global_position = global_position
	audio_player.unit_size = 4.0
	audio_player.max_distance = 20.0

	var chime: AudioStreamWAV = _generate_crystal_chime()
	audio_player.stream = chime
	get_tree().current_scene.add_child(audio_player)
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)

func _generate_crystal_chime() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.6
	var sample_count: int = int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	var f1: float = 880.0
	var f2: float = 1320.0

	for i in range(sample_count):
		var t: float = float(i) / float(sample_rate)
		var progress: float = float(i) / float(sample_count)
		var envelope: float = (1.0 - progress) * (1.0 - progress)

		var s1: float = sin(t * TAU * f1) * 0.5
		var s2: float = sin(t * TAU * f2) * 0.3
		var sample_val: float = (s1 + s2) * envelope
		var val_s16: int = clampi(int(sample_val * 24000.0), -32768, 32767)
		bytes.encode_s16(i * 2, val_s16)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _get_inventory() -> InventoryManager:
	if Engine.has_singleton("Inventory"):
		return Engine.get_singleton("Inventory") as InventoryManager
	if is_instance_valid(get_node_or_null("/root/Inventory")):
		return get_node("/root/Inventory") as InventoryManager
	return null
