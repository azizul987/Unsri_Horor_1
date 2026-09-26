@tool
class_name MainLevel
extends Node3D

## ============================================================================
## 💡 TOOL KONTROL ENVI & LIGHTING (MAIN LEVEL)
## ============================================================================
## Tool script untuk scene Main:
## - Centang 'mode_terang_clear' di Inspector untuk beralih ke pencahayaan terang/clear.
## - Uncentang (matikan) untuk mengembalikan ke pencahayaan horor gelap asli (envi lama).
## - Berjalan secara real-time di Editor Godot (tanpa play game) dan saat in-game.
## - Tombol pintas in-game: Tekan F6 saat bermain untuk toggle terang/gelap secara instan.
## ============================================================================

@export_group("⚡ Toggle Pencahayaan (Centang / Uncentang)")
## Centang [x]: Mode Terang / Clear (Editing / Level Design / Terang)
## Uncentang [ ]: Mode Horor Gelap Asli (Envi Lama)
@export var mode_terang_clear: bool = false:
	set(val):
		mode_terang_clear = val
		_apply_environment()

@export_group("☀️ Pengaturan Mode Terang (Clear)")
@export_range(0.1, 2.0, 0.05) var terang_ambient_energy: float = 0.65:
	set(val):
		terang_ambient_energy = val
		if mode_terang_clear:
			_apply_environment()

@export var terang_ambient_color: Color = Color(0.75, 0.8, 0.9, 1.0):
	set(val):
		terang_ambient_color = val
		if mode_terang_clear:
			_apply_environment()

@export_range(0.1, 3.0, 0.05) var terang_sun_energy: float = 1.0:
	set(val):
		terang_sun_energy = val
		if mode_terang_clear:
			_apply_environment()

@export var terang_sun_color: Color = Color(1.0, 0.98, 0.92, 1.0):
	set(val):
		terang_sun_color = val
		if mode_terang_clear:
			_apply_environment()

@export var terang_fog_enabled: bool = false:
	set(val):
		terang_fog_enabled = val
		if mode_terang_clear:
			_apply_environment()

@export_group("🌑 Pengaturan Mode Horor (Envi Lama)")
@export_range(0.0, 0.5, 0.01) var horor_ambient_energy: float = 0.06:
	set(val):
		horor_ambient_energy = val
		if not mode_terang_clear:
			_apply_environment()

@export var horor_ambient_color: Color = Color(0.03, 0.035, 0.05, 1.0):
	set(val):
		horor_ambient_color = val
		if not mode_terang_clear:
			_apply_environment()

@export_range(0.0, 0.5, 0.01) var horor_sun_energy: float = 0.08:
	set(val):
		horor_sun_energy = val
		if not mode_terang_clear:
			_apply_environment()

@export var horor_sun_color: Color = Color(0.35, 0.45, 0.65, 1.0):
	set(val):
		horor_sun_color = val
		if not mode_terang_clear:
			_apply_environment()

@export var horor_fog_enabled: bool = true:
	set(val):
		horor_fog_enabled = val
		if not mode_terang_clear:
			_apply_environment()

@export_range(0.001, 0.1, 0.001) var horor_fog_density: float = 0.02:
	set(val):
		horor_fog_density = val
		if not mode_terang_clear:
			_apply_environment()

@export var horor_fog_color: Color = Color(0.03, 0.035, 0.05, 1.0):
	set(val):
		horor_fog_color = val
		if not mode_terang_clear:
			_apply_environment()

var _toast_label: Label = null
var _toast_timer: SceneTreeTimer = null

func _ready() -> void:
	if not Engine.is_editor_hint():
		mode_terang_clear = false
	_apply_environment()
	if not Engine.is_editor_hint():
		call_deferred(&"_check_continue_game")

func _check_continue_game() -> void:
	var sm = get_node_or_null("/root/StoryManager")
	if sm and sm.has_method("apply_loaded_game"):
		sm.apply_loaded_game()
	if sm and sm.has_method("on_main_level_ready"):
		sm.on_main_level_ready()

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	# Shortcut F6 saat play game untuk toggle terang/gelap (hanya di debug build)
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		mode_terang_clear = not mode_terang_clear
		_show_in_game_toast("Pencahayaan: " + ("Mode Terang (Clear)" if mode_terang_clear else "Mode Horor (Envi Lama)"))

func _get_world_env() -> WorldEnvironment:
	if has_node("WorldEnvironment"):
		return get_node("WorldEnvironment") as WorldEnvironment
	return find_child("WorldEnvironment", true, false) as WorldEnvironment

func _get_directional_light() -> DirectionalLight3D:
	if has_node("DirectionalLight3D"):
		return get_node("DirectionalLight3D") as DirectionalLight3D
	return find_child("DirectionalLight3D", true, false) as DirectionalLight3D

func _apply_environment() -> void:
	var we: WorldEnvironment = _get_world_env()
	var dl: DirectionalLight3D = _get_directional_light()

	if we and we.environment:
		var env: Environment = we.environment
		if mode_terang_clear:
			# Mode Terang / Clear
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = terang_ambient_color
			env.ambient_light_energy = terang_ambient_energy
			env.fog_enabled = terang_fog_enabled

			# Sky terang bersih
			if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
				var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
				sky_mat.sky_top_color = Color(0.35, 0.55, 0.85, 1.0)
				sky_mat.sky_horizon_color = Color(0.7, 0.78, 0.88, 1.0)
				sky_mat.ground_bottom_color = Color(0.2, 0.22, 0.25, 1.0)
				sky_mat.ground_horizon_color = Color(0.5, 0.55, 0.6, 1.0)
		else:
			# Mode Horor Gelap (Envi Lama)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = horor_ambient_color
			env.ambient_light_energy = horor_ambient_energy
			env.fog_enabled = horor_fog_enabled
			env.fog_light_color = horor_fog_color
			env.fog_density = horor_fog_density

			# Sky horor malam berkabut
			if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
				var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
				sky_mat.sky_top_color = Color(0.02, 0.01, 0.01, 1.0)
				sky_mat.sky_horizon_color = Color(0.18, 0.05, 0.02, 1.0)
				sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.01, 1.0)
				sky_mat.ground_horizon_color = Color(0.12, 0.04, 0.01, 1.0)

	if dl:
		if mode_terang_clear:
			dl.light_energy = terang_sun_energy
			dl.light_color = terang_sun_color
		else:
			dl.light_energy = horor_sun_energy
			dl.light_color = horor_sun_color

func _show_in_game_toast(msg: String) -> void:
	if _toast_label == null:
		var cl = CanvasLayer.new()
		cl.layer = 15
		add_child(cl)
		_toast_label = Label.new()
		_toast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_toast_label.offset_top = 20.0
		_toast_label.offset_bottom = 50.0
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_toast_label.add_theme_font_size_override("font_size", 16)
		_toast_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6, 1.0))
		_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		_toast_label.add_theme_constant_override("shadow_offset_x", 1)
		_toast_label.add_theme_constant_override("shadow_offset_y", 1)
		cl.add_child(_toast_label)

	_toast_label.text = msg + " (Tekan F6 untuk ganti)"
	_toast_label.visible = true

	var my_timer = get_tree().create_timer(2.5)
	_toast_timer = my_timer
	my_timer.timeout.connect(func():
		if _toast_timer == my_timer and _toast_label:
			_toast_label.visible = false
	)
