class_name Player
extends CharacterBody3D

@export_group("Movement")
@export var speed: float = 5.0
@export var enable_jump: bool = false
@export var jump_velocity: float = 4.5

@export_group("Auto Step Up / Tangga")
@export var enable_step_up: bool = true
## Tinggi maksimal tangga atau mesh yang bisa dinaiki otomatis (dalam meter)
@export var max_step_height: float = 0.25
## Jarak deteksi tangga ke depan (dari batas collider)
@export var step_check_distance: float = 0.35
## Haluskan pergerakan kamera saat naik/turun tangga agar tidak patah-patah
@export var smooth_step_camera: bool = true
@export var camera_smooth_speed: float = 20.0

@export_group("Hiding & Crawling / Sembunyi")
## Status apakah pemain sedang bersembunyi (di bawah kasur / lemari)
@export var is_hidden: bool = false
## Apakah kontrol gerak dikunci saat sembunyi di hiding spot
var movement_locked: bool = false
## Ketinggian posisi kamera saat sembunyi di bawah kasur
@export var hiding_camera_y: float = -0.35
## Dukungan tombol merangkak manual (Ctrl / C)
@export var enable_crouch: bool = true
var is_crouching: bool = false

signal hiding_state_changed(is_hidden: bool)
signal crouch_state_changed(is_crouching: bool)

@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var camera: Camera3D = get_node_or_null("Camera3D")

var half_height: float = 1.0
var collider_radius: float = 0.5
var default_camera_pos_y: float = 0.0
var was_on_floor: bool = false
var is_jumping: bool = false

func _ready() -> void:
	add_to_group(&"player")
	add_to_group(&"saveable")
	# Aktifkan floor snap agar saat turun tangga karakter tidak melayang/membal
	floor_snap_length = max_step_height
	floor_constant_speed = true

	# Dapatkan dimensi collider secara dinamis
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CapsuleShape3D or collision_shape.shape is CylinderShape3D:
			half_height = collision_shape.shape.height * 0.5
			collider_radius = collision_shape.shape.radius
		elif collision_shape.shape is BoxShape3D:
			half_height = collision_shape.shape.size.y * 0.5
			collider_radius = max(collision_shape.shape.size.x, collision_shape.shape.size.z) * 0.5

	if camera:
		default_camera_pos_y = camera.position.y

func _physics_process(delta: float) -> void:
	# Jika sedang bersembunyi (di bawah kasur / lemari), matikan gerak
	if movement_locked:
		velocity = Vector3.ZERO
		return

	was_on_floor = is_on_floor()

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		if is_jumping and velocity.y <= 0:
			is_jumping = false
			floor_snap_length = max_step_height

	# Handle jump.
	if enable_jump and Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
		is_jumping = true
		floor_snap_length = 0.0 # Matikan snap saat melompat agar tidak tertarik ke bawah

	# Dapatkan input arah pergerakan
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Pergerakan lokal (local movement) berdasarkan arah menghadap karakter
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# Simpan posisi Y sebelum step-up dan move_and_slide untuk smoothing kamera
	var prev_global_y := global_position.y

	# Cek dan lakukan auto step up jika ada tangga / mesh rendah di depan
	if enable_step_up and (is_on_floor() or was_on_floor) and not is_jumping:
		_handle_step_up()

	move_and_slide()

	# Smoothing kamera saat naik atau turun tangga
	if smooth_step_camera and camera:
		# Jika turun tangga (snapped down) saat berjalan di lantai
		if is_on_floor() and was_on_floor and not is_jumping:
			var y_diff: float = prev_global_y - global_position.y
			if y_diff > 0.01 and y_diff <= max_step_height:
				camera.position.y += y_diff
		
		# Kembalikan posisi kamera secara halus ke posisi default
		camera.position.y = lerpf(camera.position.y, default_camera_pos_y, delta * camera_smooth_speed)


func _handle_step_up() -> void:
	var move_dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
	if move_dir.is_zero_approx():
		return

	var space_state := get_world_3d().direct_space_state
	var feet_y := global_position.y - half_height

	# Vektor samping untuk raycast tengah, kiri, dan kanan
	var side_dir := move_dir.cross(Vector3.UP).normalized()
	var ray_offsets: Array[Vector3] = [
		Vector3.ZERO,
		side_dir * (collider_radius * 0.6),
		-side_dir * (collider_radius * 0.6)
	]

	for offset: Vector3 in ray_offsets:
		var ray_origin: Vector3 = global_position + offset
		var cast_distance: float = collider_radius + step_check_distance

		# 1. Ray Bawah: Cek apakah ada rintangan di depan setinggi kaki
		var low_from: Vector3 = Vector3(ray_origin.x, feet_y + 0.05, ray_origin.z)
		var low_to: Vector3 = low_from + (move_dir * cast_distance)

		var low_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(low_from, low_to)
		low_query.exclude = [get_rid()]
		var low_hit: Dictionary = space_state.intersect_ray(low_query)

		# Jika tidak ada tabrakan di bawah, lanjut cek offset berikutnya
		if low_hit.is_empty():
			continue

		# Jika permukaan yang ditabrak adalah lereng yang bisa dinaiki biasa, biarkan move_and_slide menangani
		var low_normal: Vector3 = low_hit.normal
		if low_normal.angle_to(up_direction) <= floor_max_angle:
			continue

		# 2. Ray Atas: Cek tepat di atas titik benturan apakah ada dinding tinggi
		# (Cukup cek di posisi rintangan, jangan terlalu jauh ke depan agar tidak menabrak anak tangga berikutnya)
		var low_hit_pos: Vector3 = low_hit.position
		var high_from: Vector3 = Vector3(low_hit_pos.x, feet_y + max_step_height + 0.05, low_hit_pos.z) - (move_dir * 0.05)
		var high_to: Vector3 = high_from + (move_dir * 0.15)

		var high_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(high_from, high_to)
		high_query.exclude = [get_rid()]
		var high_hit: Dictionary = space_state.intersect_ray(high_query)

		# Jika tepat di atas rintangan ada tabrakan, berarti ini dinding tinggi (bukan anak tangga)
		if not high_hit.is_empty():
			continue

		# 3. Ray Turun (Downcast): Cari permukaan atas anak tangga/mesh
		var down_origin: Vector3 = Vector3(low_hit_pos.x, feet_y + max_step_height + 0.05, low_hit_pos.z) + (move_dir * 0.08)
		var down_target: Vector3 = Vector3(down_origin.x, feet_y + 0.01, down_origin.z)

		var down_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(down_origin, down_target)
		down_query.exclude = [get_rid()]
		var down_hit: Dictionary = space_state.intersect_ray(down_query)

		if down_hit.is_empty():
			continue

		# Pastikan permukaan atas anak tangga cukup datar untuk dipijak
		var down_normal: Vector3 = down_hit.normal
		if down_normal.angle_to(up_direction) > floor_max_angle:
			continue

		var target_step_y: float = down_hit.position.y
		var step_height: float = target_step_y - feet_y

		if step_height <= 0.02 or step_height > max_step_height:
			continue

		# 4. Tes Ruang Bebas (Headroom test): pastikan karakter tidak terjepit di langit-langit atau dinding
		var target_transform: Transform3D = global_transform
		target_transform.origin.y = target_step_y + half_height
		
		var test_result := PhysicsTestMotionResult3D.new()
		var test_params := PhysicsTestMotionParameters3D.new()
		test_params.from = target_transform
		test_params.motion = Vector3(0, 0.01, 0)
		
		if PhysicsServer3D.body_test_motion(get_rid(), test_params, test_result):
			# Terhalang di atas (misal ada langit-langit rendah)
			continue

		# 5. Lakukan Step Up!
		var y_diff: float = (target_step_y + half_height) - global_position.y
		global_position.y = target_step_y + half_height

		# Geser sedikit ke depan agar tidak tersangkut di bibir anak tangga
		global_position += move_dir * 0.05

		# Sesuaikan kamera agar tidak menyentak secara instan
		if smooth_step_camera and camera:
			camera.position.y -= y_diff

		# Berhasil naik tangga, hentikan loop offset
		break

## Memulai sembunyi di bawah kasur dengan transisi kamera tiarap halus
func enter_hiding_spot(hiding_global_pos: Vector3, look_yaw: float, duration: float = 0.55, target_camera_local_y: float = 0.0) -> void:
	is_hidden = true
	movement_locked = true
	velocity = Vector3.ZERO

	if collision_shape:
		collision_shape.set_deferred(&"disabled", true)

	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, ^"global_position", hiding_global_pos, duration)
	
	if camera:
		tween.tween_property(camera, ^"position:y", target_camera_local_y, duration)

		# Haluskan rotasi kamera saat merayap agar menghadap ke luar kolong kasur secara alami
		var current_yaw: float = rotation.y
		if "yaw" in camera:
			current_yaw = camera.yaw
		var angle_diff: float = wrapf(look_yaw - current_yaw, -PI, PI)
		var final_yaw: float = current_yaw + angle_diff
		
		tween.tween_property(self, ^"rotation:y", final_yaw, duration)
		if "yaw" in camera:
			tween.tween_property(camera, ^"yaw", final_yaw, duration)
		if "pitch" in camera:
			tween.tween_property(camera, ^"pitch", 0.0, duration)
		tween.tween_property(camera, ^"rotation:x", 0.0, duration)

		await tween.finished
		if camera.has_method("set_hiding_camera_clamps"):
			camera.set_hiding_camera_clamps(true, final_yaw, 65.0, -22.0, 28.0)
		elif camera.has_method("set_yaw_clamp"):
			camera.set_yaw_clamp(true, final_yaw, deg_to_rad(65.0))
	else:
		await tween.finished

	hiding_state_changed.emit(true)

## Keluar dari bawah kasur kembali berdiri di samping kasur
func exit_hiding_spot(exit_global_pos: Vector3, duration: float = 0.5) -> void:
	if camera and camera.has_method("reset_yaw_clamp"):
		camera.reset_yaw_clamp()

	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"global_position", exit_global_pos, duration)

	if camera:
		tween.tween_property(camera, ^"position:y", default_camera_pos_y, duration)

	await tween.finished

	if collision_shape:
		collision_shape.set_deferred(&"disabled", false)

	is_hidden = false
	movement_locked = false
	hiding_state_changed.emit(false)

## ============================================================================
## 💾 DUKUNGAN EASY_SAVE (SAVESYSTEM)
## ============================================================================

func get_save_data() -> Dictionary:
	return {
		"position": global_position,
		"rotation_y": rotation.y,
		"camera_pitch": camera.rotation.x if camera else 0.0,
		"is_crouching": is_crouching
	}

func load_save_data(data: Dictionary) -> void:
	if data.has("position"):
		global_position = data["position"]
	if data.has("rotation_y"):
		rotation.y = float(data["rotation_y"])
		if camera and "yaw" in camera:
			camera.yaw = rotation.y
	if data.has("camera_pitch") and camera:
		camera.rotation.x = float(data["camera_pitch"])
		if "pitch" in camera:
			camera.pitch = camera.rotation.x


