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
@export var patrol_speed: float = 2.0
@export var turn_speed: float = 10.0
@export var stopping_distance: float = 0.8
@export var detection_range: float = 8.0
@export var teleport_interval: float = 35.0
@export var always_chase: bool = true
@export var floor_heights: Array[float] = [1.05, 4.65, 8.15, 11.35, 14.65]

@export_group("Target")
@export var target_player: Node3D

@onready var nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _repath_timer: float = 0.0
var _last_player_pos: Vector3 = Vector3.ZERO
var _teleport_timer: float = 45.0
var _patrol_target: Vector3 = Vector3.ZERO
var _patrol_wait: float = 0.0
var _patrol_timeout: float = 10.0
var _is_chasing: bool = false
var _spawn_grace: float = 5.0
var _nav_ready: bool = false

var _chase_duration: float = 0.0
var _rest_timer: float = 0.0
var _is_resting: bool = false

# Cache partikel kupu-kupu radar pada player
var _player_particles: CPUParticles3D = null
var _player_light: OmniLight3D = null

# Audio atmospheric cooldown
var _creepy_sound_timer: float = 0.0
var _has_attacked: bool = false

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
	_setup_nav.call_deferred()

func _setup_nav() -> void:
	var map = get_world_3d().navigation_map if is_inside_tree() and get_world_3d() else RID()
	while is_inside_tree() and map.is_valid() and NavigationServer3D.map_get_iteration_id(map) == 0:
		await get_tree().physics_frame
	_nav_ready = true
	_pick_new_patrol_point()

func _physics_process(delta: float) -> void:
	if not _nav_ready:
		if not is_on_floor():
			velocity.y -= _gravity * delta
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	if not is_instance_valid(target_player):
		_find_player()
		move_and_slide()
		return

	var player_pos: Vector3 = target_player.global_position
	var to_player: Vector3 = Vector3(player_pos.x - global_position.x, 0.0, player_pos.z - global_position.z)
	var horizontal_dist: float = to_player.length()
	var same_floor: bool = abs(player_pos.y - global_position.y) < 2.5

	var radar_dist: float = horizontal_dist if same_floor else global_position.distance_to(player_pos) + 20.0
	_update_butterfly_radar(radar_dist)

	if _creepy_sound_timer > 0.0:
		_creepy_sound_timer -= delta
	elif same_floor and horizontal_dist < 16.0 and target_player.get("is_hidden") != true:
		_creepy_sound_timer = randf_range(5.0, 9.0)
		var sm = SoundManager.instance if SoundManager.instance else get_node_or_null("/root/SoundManager")
		if sm and sm.has_method("play_sfx_3d"):
			var sound_choice = "creepy_rattle" if randf() < 0.5 else "bone_crack"
			sm.play_sfx_3d(sound_choice, global_position, 20.0, 0.0, randf_range(0.85, 1.15))

	if target_player.get("is_hidden") == true:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta * 2.5)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta * 2.5)
		move_and_slide()
		_chase_duration = 0.0
		_is_chasing = false
		return

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
		elif _is_chasing:
			_chase_duration += delta
			if _chase_duration >= 5.5:
				_is_resting = true
				_rest_timer = 3.5
				return

	if _spawn_grace > 0.0:
		_spawn_grace -= delta

	_teleport_timer -= delta
	if _teleport_timer <= 0.0:
		if not _is_chasing or horizontal_dist > 8.0:
			teleport_to_other_floor()
		else:
			_teleport_timer = 5.0

	_is_chasing = _spawn_grace <= 0.0 and same_floor and (always_chase or horizontal_dist < detection_range)

	if _is_chasing:
		_repath_timer += delta
		if _repath_timer >= 0.15 or player_pos.distance_squared_to(_last_player_pos) > 0.04:
			_repath_timer = 0.0
			_update_target_position()
	else:
		_patrol_timeout -= delta
		var dist_to_patrol = global_position.distance_to(_patrol_target)
		if (nav_agent and nav_agent.is_navigation_finished()) or dist_to_patrol < 1.2 or _patrol_timeout <= 0.0:
			_patrol_wait -= delta
			if _patrol_wait <= 0.0 or _patrol_timeout <= 0.0:
				_patrol_wait = randf_range(1.5, 3.5)
				_pick_new_patrol_point()

	if same_floor and horizontal_dist <= stopping_distance:
		_look_towards(player_pos, delta)
		if not _has_attacked:
			_has_attacked = true
			var sm = SoundManager.instance if SoundManager.instance else get_node_or_null("/root/SoundManager")
			if sm:
				sm.play_jumpscare("jumpscare_hit")
				sm.play_sfx_3d("monster_screech", global_position, 25.0)
		caught_player.emit()
		if not always_chase:
			velocity.x = move_toward(velocity.x, 0.0, speed * delta * 5.0)
			velocity.z = move_toward(velocity.z, 0.0, speed * delta * 5.0)
			move_and_slide()
			return
	else:
		_has_attacked = false

	var current_speed: float = speed if _is_chasing else patrol_speed
	var horizontal_dir: Vector3 = Vector3.ZERO
	if nav_agent and not nav_agent.is_navigation_finished():
		var next_path_pos: Vector3 = nav_agent.get_next_path_position()
		var to_waypoint: Vector3 = Vector3(next_path_pos.x - global_position.x, 0.0, next_path_pos.z - global_position.z)
		if to_waypoint.length_squared() > 0.04:
			horizontal_dir = to_waypoint.normalized()
		elif _is_chasing:
			horizontal_dir = to_player.normalized()
	elif _is_chasing:
		horizontal_dir = to_player.normalized()

	if horizontal_dir != Vector3.ZERO:
		velocity.x = horizontal_dir.x * current_speed
		velocity.z = horizontal_dir.z * current_speed
		_look_towards(global_position + horizontal_dir, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, current_speed * delta * 5.0)

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

func _get_floor_heights() -> Array[float]:
	var heights: Array[float] = floor_heights.duplicate()
	var scene = get_tree().current_scene
	if scene:
		var node = scene.find_child("Node", true, false)
		if node:
			var sb = node.find_child("StaticBody3D", true, false)
			if sb:
				var l1 = sb.find_child("Lantai", true, false)
				var l2 = sb.find_child("Lantai2", true, false)
				var l3 = sb.find_child("Lantai3", true, false)
				var l4 = sb.find_child("Lantai4", true, false)
				if l1 and l2 and l3 and l4:
					heights = [
						1.05,
						l1.global_position.y + 4.65,
						l2.global_position.y + 4.65,
						l3.global_position.y + 4.65,
						l4.global_position.y + 4.65
					]
	return heights

func _pick_new_patrol_point() -> void:
	_patrol_timeout = 15.0
	var feet_y = global_position.y - 0.75
	var raw_pt = Vector3(randf_range(16.5, 17.2), feet_y, randf_range(-20.0, 8.0))
	var map = get_world_3d().navigation_map if is_inside_tree() and get_world_3d() else RID()
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		var snapped = NavigationServer3D.map_get_closest_point(map, raw_pt)
		if snapped != Vector3.ZERO and abs(snapped.y - feet_y) < 1.8:
			_patrol_target = snapped
		else:
			_patrol_target = raw_pt
	else:
		_patrol_target = raw_pt
	if nav_agent:
		nav_agent.target_position = _patrol_target

func teleport_to_other_floor() -> void:
	var floors = _get_floor_heights()
	var other_floors: Array[float] = []
	for f in floors:
		if abs(f - global_position.y) > 2.0:
			other_floors.append(f)
	if other_floors.is_empty():
		return
	var target_y: float = other_floors.pick_random()
	var raw_pt = Vector3(randf_range(16.5, 17.2), target_y, randf_range(-18.0, 6.0))
	var final_pos = raw_pt
	var map = get_world_3d().navigation_map if is_inside_tree() and get_world_3d() else RID()
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		var feet_pt = Vector3(raw_pt.x, target_y - 0.75, raw_pt.z)
		var snapped = NavigationServer3D.map_get_closest_point(map, feet_pt)
		if snapped != Vector3.ZERO and abs(snapped.y - feet_pt.y) < 1.8:
			final_pos = Vector3(snapped.x, snapped.y + 0.85, snapped.z)
	global_position = final_pos
	velocity = Vector3.ZERO
	_is_chasing = false
	_teleport_timer = teleport_interval
	_pick_new_patrol_point()

func get_save_data() -> Dictionary:
	return {
		"position": global_position,
		"rotation_y": rotation.y,
		"phase": phase,
		"teleport_timer": _teleport_timer
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("position"):
		global_position = data["position"]
	if data.has("rotation_y"):
		rotation.y = float(data["rotation_y"])
	if data.has("phase"):
		phase = int(data["phase"])
	if data.has("teleport_timer"):
		_teleport_timer = float(data["teleport_timer"])
