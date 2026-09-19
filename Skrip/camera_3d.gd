extends Camera3D

@export var mouse_sensitivity: float = 0.003
@export var pitch_limit: float = deg_to_rad(89)
@export var enable_camcorder_shader: bool = true # Centang ini di inspector untuk menyalakan/mematikan
@export var enable_color_bleed: bool = true # Opsi untuk mematikan color bleed jika terasa berat

var yaw: float = 0.0
var pitch: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
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
	if event is InputEventMouseMotion:
		# Akumulasi rotasi dari gerakan mouse
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -pitch_limit, pitch_limit)
		
		# Set rotasi secara absolut agar lebih mulus (tidak patah-patah)
		get_parent().rotation.y = yaw
		rotation.x = pitch
		
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
