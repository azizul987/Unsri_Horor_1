extends Camera3D

@export var mouse_sensitivity: float = 0.003
@export var pitch_limit: float = deg_to_rad(89)
@export var enable_camcorder_shader: bool = true # Centang ini di inspector untuk menyalakan/mematikan
@export var enable_color_bleed: bool = true # Opsi untuk mematikan color bleed jika terasa berat
@export var look_locked: bool = false

var yaw: float = 0.0
var pitch: float = 0.0

var yaw_clamp_enabled: bool = false
var clamp_center_yaw: float = 0.0
var clamp_half_range: float = deg_to_rad(65.0)

var pitch_limit_default: float = deg_to_rad(89)
var current_pitch_limit_min: float = -deg_to_rad(89)
var current_pitch_limit_max: float = deg_to_rad(89)

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Set near clipping plane kecil agar objek sangat dekat (seperti lantai) tidak tembus
	near = 0.03
	yaw = get_parent().rotation.y
	pitch = rotation.x
	
	if enable_camcorder_shader:
		# Setup Camcorder Shader
		var canvas = CanvasLayer.new()
		var rect = ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var material = ShaderMaterial.new()
		material.shader = preload("res://Shaders/camcorder.gdshader")
		
		# Perbaiki noise agar tidak terlihat seperti pixel/blok besar (gunakan noise halus)
		var noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_VALUE
		noise.frequency = 1.0 # Frekuensi tinggi agar bintiknya kecil-kecil
		
		var noise_tex = NoiseTexture2D.new()
		noise_tex.noise = noise
		noise_tex.seamless = true # Supaya tekstur menyambung mulus
		material.set_shader_parameter("film_grain_noise", noise_tex)
		
		# Matikan ketajaman (sharpness) sementara karena sering bikin gambar jadi pecah/pixelate
		# jika mipmap layar tidak diaktifkan di pengaturan project
		material.set_shader_parameter("sharpness_enabled", false)
		
		# Opsi untuk menyalakan atau mematikan Color Bleed dari Inspector
		material.set_shader_parameter("color_bleed_enabled", enable_color_bleed)
		
		# Efek Color Bleed dikembalikan ke 0.2 (halus)
		material.set_shader_parameter("color_bleed_intensity", 0.2)
		material.set_shader_parameter("anti_bleed_intensity", 1.8)
		
		rect.material = material
		canvas.add_child(rect)
		add_child(canvas)




func _unhandled_input(event: InputEvent) -> void:
	if look_locked:
		return

	if event is InputEventMouseMotion:
		# Akumulasi rotasi dari gerakan mouse
		yaw -= event.relative.x * mouse_sensitivity
		if yaw_clamp_enabled:
			# Gunakan wrapf agar aman dari bug lompatan sudut 180 derajat (-PI sampai PI)
			var diff: float = wrapf(yaw - clamp_center_yaw, -PI, PI)
			diff = clampf(diff, -clamp_half_range, clamp_half_range)
			yaw = clamp_center_yaw + diff

		pitch -= event.relative.y * mouse_sensitivity
		pitch = clampf(pitch, current_pitch_limit_min, current_pitch_limit_max)
		
		# Set rotasi secara absolut agar lebih mulus (tidak patah-patah)
		get_parent().rotation.y = yaw
		rotation.x = pitch
		
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func look_at_target(target_global_pos: Vector3) -> void:
	var parent_node = get_parent() as Node3D
	if not parent_node:
		return
	var to_target = target_global_pos - global_position
	var flat_dir = Vector3(to_target.x, 0.0, to_target.z).normalized()
	if flat_dir.length_squared() > 0.001:
		yaw = atan2(-flat_dir.x, -flat_dir.z)
		parent_node.rotation.y = yaw
	var horiz_dist = Vector2(to_target.x, to_target.z).length()
	pitch = clampf(atan2(to_target.y, horiz_dist), current_pitch_limit_min, current_pitch_limit_max)
	rotation.x = pitch

## Mengunci batas sudut tengok kamera (yaw dan pitch) saat sembunyi di bawah kasur
func set_hiding_camera_clamps(enabled: bool, center_yaw: float = 0.0, half_yaw_deg: float = 65.0, min_pitch_deg: float = -22.0, max_pitch_deg: float = 28.0) -> void:
	yaw_clamp_enabled = enabled
	if enabled:
		clamp_center_yaw = center_yaw
		clamp_half_range = deg_to_rad(half_yaw_deg)
		current_pitch_limit_min = deg_to_rad(min_pitch_deg)
		current_pitch_limit_max = deg_to_rad(max_pitch_deg)

		var diff: float = wrapf(yaw - clamp_center_yaw, -PI, PI)
		diff = clampf(diff, -clamp_half_range, clamp_half_range)
		yaw = clamp_center_yaw + diff
		pitch = clampf(pitch, current_pitch_limit_min, current_pitch_limit_max)

		get_parent().rotation.y = yaw
		rotation.x = pitch
	else:
		current_pitch_limit_min = -pitch_limit_default
		current_pitch_limit_max = pitch_limit_default

func set_yaw_clamp(enabled: bool, center_yaw: float = 0.0, half_range_rad: float = deg_to_rad(65.0)) -> void:
	set_hiding_camera_clamps(enabled, center_yaw, rad_to_deg(half_range_rad))

func reset_yaw_clamp() -> void:
	set_hiding_camera_clamps(false)


