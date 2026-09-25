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
	var sm = get_node_or_null("/root/StoryManager")
	if sm:
		sm.player_node = self
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

	# Raycast interaction dari kamera
	_update_interact_raycast()

# ─── Sistem Interact Raycast (pickup item dari pandangan kamera) ───────────
@export_group("Interaction")
## Jarak maksimal interaksi dari pandangan kamera (dalam meter)
@export var interact_distance: float = 2.5

var _interact_target: Node = null   # Node yang sedang diarahkan
var _interact_label: Label = null   # Label HUD untuk prompt interaksi

func _ready_interaction() -> void:
	# Buat label prompt tepat di tengah layar (sama persis seperti horror_door dan flower_pickup)
	var cl: CanvasLayer = CanvasLayer.new()
	cl.name = "InteractHUD"
	cl.layer = 20
	add_child(cl)

	_interact_label = Label.new()
	_interact_label.name = "InteractPrompt"
	_interact_label.set_anchors_preset(Control.PRESET_CENTER)
	_interact_label.anchor_left = 0.5
	_interact_label.anchor_top = 0.5
	_interact_label.anchor_right = 0.5
	_interact_label.anchor_bottom = 0.5
	_interact_label.offset_left = -200.0
	_interact_label.offset_right = 200.0
	_interact_label.offset_top = 35.0
	_interact_label.offset_bottom = 65.0
	_interact_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_interact_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interact_label.add_theme_font_size_override("font_size", 14)
	_interact_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_interact_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_interact_label.add_theme_constant_override("shadow_offset_x", 1)
	_interact_label.add_theme_constant_override("shadow_offset_y", 1)
	_interact_label.visible = false
	cl.add_child(_interact_label)

func _is_pickup_node(node: Node) -> bool:
	if node == null:
		return false
	if node is ItemPickup3D:
		return true
	if "item_data" in node and node.get("item_data") != null:
		return true
	if node.is_in_group(&"item_pickup"):
		return true
	if node is FlowerPickup or node.has_method("pickup_flower"):
		return true
	return false

func _find_pickup_node(node: Node) -> Node:
	var curr: Node = node
	while curr != null:
		if _is_pickup_node(curr):
			return curr
		if curr is CharacterBody3D or curr == get_tree().current_scene:
			break
		curr = curr.get_parent()
	return null

func _find_interactive_table(node: Node) -> InteractiveTable:
	var curr: Node = node
	while curr != null:
		if curr is InteractiveTable:
			return curr as InteractiveTable
		if curr is CharacterBody3D or curr == get_tree().current_scene:
			break
		curr = curr.get_parent()
	return null

func _update_interact_raycast() -> void:
	# Inisialisasi label saat pertama kali dipanggil
	if _interact_label == null:
		_ready_interaction()

	if camera == null:
		return

	# Cast ray dari posisi kamera ke arah pandangan
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var cam_origin: Vector3 = camera.global_position
	var cam_forward: Vector3 = -camera.global_transform.basis.z
	var ray_end: Vector3 = cam_origin + cam_forward * interact_distance

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cam_origin, ray_end)
	query.exclude = [get_rid()]
	query.collide_with_areas = true   # Detect Area3D (ItemPickup3D / FlowerPickup)
	query.collide_with_bodies = true

	var result: Dictionary = space.intersect_ray(query)

	var new_target: Node = null
	if result.has("collider"):
		var collider: Node = result["collider"]
		# 1. Prioritaskan item pickup (bisa di lantai atau di dalam laci meja)
		var pickup: Node = _find_pickup_node(collider)
		if pickup != null:
			new_target = pickup
		else:
			# 2. Jika bukan item, periksa apakah yang dilihat adalah InteractiveTable
			var table: InteractiveTable = _find_interactive_table(collider)
			if table != null:
				# Kalau laci terbuka dan ada item di dalamnya, skip — biar pemain arahkan ke item
				var has_item_in_open_drawer: bool = table.is_open and table.current_item_data != null
				if not has_item_in_open_drawer:
					new_target = table

	# Update target
	if _interact_target != new_target:
		_interact_target = new_target

	# Tampilkan / sembunyikan prompt
	if _interact_label:
		if _interact_target != null and is_instance_valid(_interact_target):
			var prompt_text: String = "[E] Interaksi"
			if _interact_target is InteractiveTable:
				prompt_text = (_interact_target as InteractiveTable).get_interaction_prompt()
			elif _interact_target.has_method("get_interaction_prompt"):
				prompt_text = str(_interact_target.call("get_interaction_prompt"))
			elif "current_flower_name" in _interact_target and str(_interact_target.current_flower_name) != "":
				prompt_text = "[E] Ambil " + str(_interact_target.current_flower_name)
			elif "item_data" in _interact_target and _interact_target.item_data != null:
				prompt_text = "[E] Ambil " + str(_interact_target.item_data.name)
			_interact_label.text = prompt_text
			_interact_label.visible = true
		else:
			_interact_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and _interact_target != null and is_instance_valid(_interact_target):
			if _interact_target is InteractiveTable or _interact_target.has_method("toggle_drawer"):
				_interact_target.call("interact", self)
				if _interact_label and is_instance_valid(_interact_target):
					_interact_label.text = str(_interact_target.call("get_interaction_prompt"))
				get_viewport().set_input_as_handled()
			elif _interact_target.has_method("pickup_flower"):
				_interact_target.call("pickup_flower")
				_interact_target = null
				if _interact_label:
					_interact_label.visible = false
				get_viewport().set_input_as_handled()
			elif _interact_target.has_method("interact"):
				_interact_target.call("interact", self)
				_interact_target = null
				if _interact_label:
					_interact_label.visible = false
				get_viewport().set_input_as_handled()


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
		var p = data["position"]
		if p is Vector3:
			global_position = p
		elif p is Dictionary and p.get("__type__") == "Vector3":
			global_position = Vector3(p.get("x", 0.0), p.get("y", 0.0), p.get("z", 0.0))
	if data.has("rotation_y"):
		rotation.y = float(data["rotation_y"])
		if camera and "yaw" in camera:
			camera.yaw = rotation.y
	if data.has("camera_pitch") and camera:
		camera.rotation.x = float(data["camera_pitch"])
		if "pitch" in camera:
			camera.pitch = camera.rotation.x
	velocity = Vector3.ZERO
