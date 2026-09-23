class_name NPCChaser
extends CharacterBody3D

## AI Musuh Amir (Kupu-Kupu Malam).
## Memiliki 3 Fase Agresivitas berdasarkan jumlah bunga yang ditemukan/didepositkan.
## Mengendalikan partikel kupu-kupu pemain sebagai radar bahaya (Signature Mechanic).
## Terintegrasi dengan SaveSystem untuk posisi dan status AI.

signal caught_player
signal phase_changed(new_phase: int)

@export_group("Fase Agresivitas Amir")
## Fase saat ini (1 = Pasif/Kamar, 2 = Patroli Koridor, 3 = Agresif Penuh)
@export_range(1, 3, 1) var phase: int = 1:
	set(val):
		phase = clampi(val, 1, 3)
		_apply_phase_settings()
		phase_changed.emit(phase)

@export_group("Movement")
@export var speed: float = 3.5
@export var turn_speed: float = 10.0
@export var stopping_distance: float = 0.8
@export var always_chase: bool = true

@export_group("Target")
@export var target_player: Node3D

@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _repath_timer: float = 0.0
var _last_player_pos: Vector3 = Vector3.ZERO

# Timer lelah / jeda nafas pada Fase 1
var _chase_duration: float = 0.0
var _rest_timer: float = 0.0
var _is_resting: bool = false

# Cache partikel kupu-kupu radar pada player
var _player_particles: CPUParticles3D = null
var _player_light: OmniLight3D = null

func _ready() -> void:
	add_to_group(&"chaser")
	add_to_group(&"saveable")

	floor_snap_length = 0.45
	floor_constant_speed = true

	if nav_agent:
		nav_agent.target_desired_distance = stopping_distance
		nav_agent.path_desired_distance = 1.5

	_apply_phase_settings()
	_find_player()

	if target_player:
		_update_target_position()

func _physics_process(delta: float) -> void:
	# 1. Terapkan gravitasi jika di udara
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	# 2. Pastikan target player ada
	if not is_instance_valid(target_player):
		_find_player()
		move_and_slide()
		return

	# Hitung jarak horizontal ke player
	var player_pos: Vector3 = target_player.global_position
	var to_player: Vector3 = Vector3(player_pos.x - global_position.x, 0.0, player_pos.z - global_position.z)
	var horizontal_dist: float = to_player.length()

	# 3. Update Signature Mechanic: Radar Kupu-Kupu berdasarkan jarak
	_update_butterfly_radar(horizontal_dist)

	# 4. Jika player sedang sembunyi di bawah kasur / lemari, Amir kehilangan jejak
	if target_player.get("is_hidden") == true:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta * 2.5)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta * 2.5)
		move_and_slide()
		_chase_duration = 0.0
		return

	# 5. Logika lelah khusus Fase 1 (memberi ruang nafas eksplorasi pemain)
	if phase == 1:
		if _is_resting:
			_rest_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, speed * delta * 4.0)
			velocity.z = move_toward(velocity.z, 0.0, speed * delta * 4.0)
			move_and_slide()
			if _rest_timer <= 0.0:
				_is_resting = false
				_chase_duration = 0.0
			return
		else:
			_chase_duration += delta
			if _chase_duration >= 5.5:
				_is_resting = true
				_rest_timer = 3.5
				return

	# 6. Update target posisi NavigationAgent
	_repath_timer += delta
	if _repath_timer >= 0.1 or player_pos.distance_squared_to(_last_player_pos) > 0.04:
		_repath_timer = 0.0
		_update_target_position()

	# 7. Jika sudah menyentuh player
	if horizontal_dist <= stopping_distance:
		_look_towards(player_pos, delta)
		caught_player.emit()
		if not always_chase:
			velocity.x = move_toward(velocity.x, 0.0, speed * delta * 5.0)
			velocity.z = move_toward(velocity.z, 0.0, speed * delta * 5.0)
			move_and_slide()
			return

	# 8. Tentukan arah pergerakan NavMesh
	var horizontal_dir: Vector3 = Vector3.ZERO
	if nav_agent and not nav_agent.is_navigation_finished():
		var next_path_pos: Vector3 = nav_agent.get_next_path_position()
		var to_waypoint: Vector3 = Vector3(next_path_pos.x - global_position.x, 0.0, next_path_pos.z - global_position.z)
		if to_waypoint.length_squared() > 0.04:
			horizontal_dir = to_waypoint.normalized()
		else:
			horizontal_dir = to_player.normalized()
	else:
		horizontal_dir = to_player.normalized()

	# 9. Gerakkan Amir
	if horizontal_dir != Vector3.ZERO:
		velocity.x = horizontal_dir.x * speed
		velocity.z = horizontal_dir.z * speed
		_look_towards(global_position + horizontal_dir, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta * 5.0)

	move_and_slide()

## Mengubah parameter kecepatan dan kelincahan Amir sesuai 3 Fase GDD
func set_phase(new_phase: int) -> void:
	phase = new_phase

func _apply_phase_settings() -> void:
	match phase:
		1:
			# Fase 1 (0-2 Bunga): Lambat, sering merintih/lelah
			speed = 2.8
			turn_speed = 7.0
			always_chase = false
		2:
			# Fase 2 (3-5 Bunga): Kecepatan sedang, patroli aktif
			speed = 3.6
			turn_speed = 10.0
			always_chase = true
		3:
			# Fase 3 (6-8 Bunga): Monster penuh, sangat cepat & agresif
			speed = 4.8
			turn_speed = 14.0
			always_chase = true

## 🦋 SIGNATURE MECHANIC: Mengatur intensitas kupu-kupu berdasarkan jarak horizontal
func _update_butterfly_radar(dist: float) -> void:
	if not is_instance_valid(_player_particles):
		_find_player_particles()

	if not is_instance_valid(_player_particles):
		return

	# Jika player sedang sembunyi di bawah kasur, redam kepakan kupu-kupu
	if target_player and target_player.get("is_hidden") == true:
		_player_particles.emitting = false
		if _player_light:
			_player_light.light_energy = lerpf(_player_light.light_energy, 0.0, 0.1)
		return

	if dist > 25.0:
		# Aman (>25m): Tidak ada kupu-kupu
		_player_particles.emitting = false
		if _player_light:
			_player_light.light_energy = lerpf(_player_light.light_energy, 0.0, 0.1)
	elif dist > 17.0:
		# Peringatan 1 (18-25m): 1-2 kupu-kupu melintas
		_player_particles.emitting = true
		_player_particles.amount = 3
		if _player_light:
			_player_light.light_energy = lerpf(_player_light.light_energy, 0.2, 0.1)
	elif dist > 10.0:
		# Peringatan 2 (10-17m): 8-12 kupu-kupu berkumpul, lampu berkedip
		_player_particles.emitting = true
		_player_particles.amount = 12
		if _player_light:
			_player_light.light_energy = randf_range(0.3, 0.7)
	else:
		# Peringatan 3 (<10m): Puluhan kupu-kupu mengerumuni layar! LARI!
		_player_particles.emitting = true
		_player_particles.amount = 35
		if _player_light:
			_player_light.light_energy = randf_range(0.8, 1.4)

func _find_player_particles() -> void:
	if target_player:
		var found = target_player.find_child("KupuKupuParticles_", true, false)
		if found is CPUParticles3D:
			_player_particles = found
		var found_light = target_player.find_child("ButterflyLight", true, false)
		if found_light is OmniLight3D:
			_player_light = found_light

func _update_target_position() -> void:
	if not is_instance_valid(target_player):
		return
	_last_player_pos = target_player.global_position
	if nav_agent:
		nav_agent.target_position = _last_player_pos

func _look_towards(target_pos: Vector3, delta: float) -> void:
	var look_dir: Vector3 = target_pos - global_position
	look_dir.y = 0.0
	if look_dir.length_squared() < 0.001:
		return
	var target_basis: Basis = Basis.looking_at(look_dir.normalized(), Vector3.UP)
	basis = basis.slerp(target_basis, turn_speed * delta)

func _find_player() -> void:
	for node in get_tree().get_nodes_in_group(&"player"):
		if node is Node3D and node != self:
			target_player = node as Node3D
			_find_player_particles()
			return

	var current_scene: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	if current_scene:
		var found: Node = current_scene.find_child("CharacterBody3D", true, false)
		if found is Node3D and found != self:
			target_player = found as Node3D
			_find_player_particles()

## ============================================================================
## 💾 DUKUNGAN EASY_SAVE (SAVESYSTEM)
## ============================================================================

func get_save_data() -> Dictionary:
	return {
		"position": global_position,
		"rotation_y": rotation.y,
		"phase": phase
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("position"):
		global_position = data["position"]
	if data.has("rotation_y"):
		rotation.y = float(data["rotation_y"])
	if data.has("phase"):
		phase = int(data["phase"])
