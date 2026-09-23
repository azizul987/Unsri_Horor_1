class_name NPCChaser
extends CharacterBody3D

## Sinyal yang dipancarkan saat NPC berhasil menyentuh / dekat dengan player
signal caught_player

@export_group("Movement")
## Kecepatan lari / jalan NPC (meter/detik)
@export var speed: float = 3.5
## Kecepatan memutar badan menghadap arah lari
@export var turn_speed: float = 10.0
## Jarak berhenti di depan player. Jika 0.8m, NPC akan terus menempel ketat di badan player.
@export var stopping_distance: float = 0.8
## Jika true, NPC akan SELALU mengejar kemanapun player bergerak (tidak pernah berhenti total).
@export var always_chase: bool = true

@export_group("Target")
## Referensi node Player. Jika kosong, script otomatis mendeteksi Player.
@export var target_player: Node3D

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _repath_timer: float = 0.0
var _last_player_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Floor snap agar saat menuruni tangga atau ramp karakter tidak membal/melayang
	floor_snap_length = 0.45
	floor_constant_speed = true
	
	if nav_agent:
		nav_agent.target_desired_distance = stopping_distance
		# Dibuat 1.5m agar waypoint di lantai tetap terdeteksi oleh pivot NPC yang tingginya ~1.1m di atas tanah
		nav_agent.path_desired_distance = 1.5
	
	# Cari player segera saat spawn
	_find_player()
	if target_player:
		_update_target_position()

func _physics_process(delta: float) -> void:
	# 1. Terapkan gravitasi jika sedang di udara
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	# 2. Pastikan target player ada
	if not is_instance_valid(target_player):
		_find_player()
		move_and_slide()
		return

	# Jika player sedang sembunyi di bawah kasur / lemari, Amir kehilangan jejak
	if target_player.get("is_hidden") == true:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta * 2.5)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta * 2.5)
		move_and_slide()
		return

	# 3. Update target posisi NavigationAgent terus-menerus mengikuti Player
	_repath_timer += delta
	if _repath_timer >= 0.1 or target_player.global_position.distance_squared_to(_last_player_pos) > 0.04:
		_repath_timer = 0.0
		_update_target_position()

	# 4. Hitung jarak langsung ke player (horizontal)
	var player_pos: Vector3 = target_player.global_position
	var to_player: Vector3 = Vector3(player_pos.x - global_position.x, 0.0, player_pos.z - global_position.z)
	var horizontal_dist: float = to_player.length()
	
	# Jika sudah menempel sangat dekat (dalam stopping_distance)
	if horizontal_dist <= stopping_distance:
		_look_towards(player_pos, delta)
		caught_player.emit()
		
		# Jika tidak diset always_chase, berhenti saat menempel
		if not always_chase:
			velocity.x = move_toward(velocity.x, 0.0, speed * delta * 5.0)
			velocity.z = move_toward(velocity.z, 0.0, speed * delta * 5.0)
			move_and_slide()
			return

	# 5. Tentukan arah gerak horizontal menuju player
	var horizontal_dir: Vector3 = Vector3.ZERO

	if nav_agent and not nav_agent.is_navigation_finished():
		var next_path_pos: Vector3 = nav_agent.get_next_path_position()
		var to_waypoint: Vector3 = Vector3(next_path_pos.x - global_position.x, 0.0, next_path_pos.z - global_position.z)
		
		# Jika waypoint NavMesh masih di depan kita
		if to_waypoint.length_squared() > 0.04:
			horizontal_dir = to_waypoint.normalized()
		else:
			# Fallback lurus ke player jika waypoint terlalu dekat/habis
			horizontal_dir = to_player.normalized()
	else:
		# Fallback ke arah player jika NavMesh belum kebake / beda lantai
		horizontal_dir = to_player.normalized()

	# 6. Gerakkan karakter
	if horizontal_dir != Vector3.ZERO:
		velocity.x = horizontal_dir.x * speed
		velocity.z = horizontal_dir.z * speed
		_look_towards(global_position + horizontal_dir, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta * 5.0)

	# 7. Jalankan pergerakan fisika
	move_and_slide()

## Memperbarui target posisi ke NavigationAgent
func _update_target_position() -> void:
	if not is_instance_valid(target_player):
		return
	_last_player_pos = target_player.global_position
	if nav_agent:
		nav_agent.target_position = _last_player_pos

## Memutar badan NPC secara halus menghadap titik target
func _look_towards(target_pos: Vector3, delta: float) -> void:
	var look_dir: Vector3 = target_pos - global_position
	look_dir.y = 0.0 # Kunci di sumbu datar agar tidak mendongak/menunduk aneh
	
	if look_dir.length_squared() < 0.001:
		return
		
	var target_basis: Basis = Basis.looking_at(look_dir.normalized(), Vector3.UP)
	basis = basis.slerp(target_basis, turn_speed * delta)

## Mencari Player secara otomatis di dalam Scene
func _find_player() -> void:
	# Coba cari dari grup "player"
	for node in get_tree().get_nodes_in_group(&"player"):
		if node is Node3D and node != self:
			target_player = node as Node3D
			return

	# Fallback: cari node CharacterBody3D selain diri sendiri
	var current_scene: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	if current_scene:
		var found: Node = current_scene.find_child("CharacterBody3D", true, false)
		if found is Node3D and found != self:
			target_player = found as Node3D
