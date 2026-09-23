class_name BedHidingSpot3D
extends Area3D

## Komponen interaktif untuk bersembunyi / nyelinap di bawah kasur (Under-Bed Hiding Spot).
## Pemain mendekati kasur, menekan tombol [E] untuk merayap ke kolong kasur.
## Monster (Amir) akan kehilangan jejak pemain selama pemain bersembunyi di bawah kasur!

signal player_entered_hiding
signal player_exited_hiding

@export_group("Posisi Titik")
## Titik di kolong kasur tempat pemain bertiarap (Marker3D child)
@export var hiding_marker: Marker3D
## Titik di samping kasur tempat pemain berdiri setelah keluar (Marker3D child)
@export var exit_marker: Marker3D

@export_group("Teks Interaksi")
@export var prompt_enter: String = "Sembunyi di Bawah Kasur"
@export var prompt_exit: String = "Keluar dari Bawah Kasur"

@export_group("Audio")
## Efek suara merayap kain / gesekan lantai
@export var crawl_sound: AudioStream = null

var _is_occupied: bool = false
var _player_in_range: bool = false
var _current_player: Player = null
var _audio_player: AudioStreamPlayer3D = null

# Posisi & rotasi pemain saat berdiri sesaat sebelum masuk ke bawah kasur
var _pre_hiding_player_pos: Vector3 = Vector3.ZERO
var _pre_hiding_player_rot_y: float = 0.0

# CanvasLayer HUD bawaan agar prompt otomatis tampil di layar tanpa setup tambahan
var _hud_layer: CanvasLayer = null
var _hud_label: Label = null

func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Auto-generate Marker jika belum diset di inspector
	_setup_default_markers()

	# Setup Audio Player
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.max_distance = 15.0
	_audio_player.volume_db = -4.0
	add_child(_audio_player)

	if crawl_sound == null:
		_audio_player.stream = HorrorAudioSynth.get_crawl_sound()
	else:
		_audio_player.stream = crawl_sound

	# Setup HUD prompt otomatis
	_setup_hud()

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range and not _is_occupied:
		return

	# Jangan proses interaksi jika dialog atau catatan sedang aktif di layar!
	if HorrorDialogue and (HorrorDialogue.is_dialogue_active() or HorrorDialogue.is_note_active()):
		return

	# Tombol E atau Spasi/Enter untuk Masuk/Keluar dari bawah kasur
	var is_interact: bool = (
		(event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E) or
		event.is_action_pressed(&"ui_accept")
	)

	# Jika sedang sembunyi di bawah kasur, tombol arah (W/S/Spasi) juga bisa digunakan untuk merayap keluar
	if _is_occupied and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_W, KEY_S, KEY_SPACE]:
			is_interact = true

	if is_interact:
		toggle_hiding()
		get_viewport().set_input_as_handled()

## Masuk atau keluar dari bawah kasur
func toggle_hiding() -> void:
	if _is_occupied:
		exit_bed()
	else:
		enter_bed()

## Merayap masuk ke kolong kasur
func enter_bed() -> void:
	if _current_player == null or _is_occupied:
		return

	_is_occupied = true
	_play_crawl_sfx()

	# Simpan posisi berdiri pemain sebelum masuk agar keluar di titik yang sama persis
	_pre_hiding_player_pos = _current_player.global_position
	_pre_hiding_player_rot_y = _current_player.rotation.y

	# Cari ketinggian lantai yang akurat di kolong kasur (mencegah tembus lantai)
	var spot_pos: Vector3 = hiding_marker.global_position
	var floor_y: float = _detect_floor_y(spot_pos)

	# Ketinggian mata saat tiarap di atas lantai: 22 cm (0.22 meter)
	# Karakter diposisikan di kolong pada ketinggian mata tiarap ini,
	# dengan kamera lokal Y diatur ke 0.0 sehingga Camera World Y = floor_y + 0.22 (PASTI di atas lantai!)
	var crawl_eye_height: float = 0.22
	var target_body_pos: Vector3 = Vector3(spot_pos.x, floor_y + crawl_eye_height, spot_pos.z)
	var target_camera_y: float = 0.0

	# Arah hadap pandangan kamera: menghadap ke arah luar (menghadap ke arah pemain datang)
	var crawl_vec: Vector3 = spot_pos - _pre_hiding_player_pos
	crawl_vec.y = 0.0
	var look_yaw: float = 0.0
	if crawl_vec.length_squared() > 0.01:
		var outward_dir: Vector3 = -crawl_vec.normalized()
		look_yaw = atan2(-outward_dir.x, -outward_dir.z)
	else:
		look_yaw = global_rotation.y

	_current_player.enter_hiding_spot(target_body_pos, look_yaw, 0.55, target_camera_y)

	_update_hud(true)
	player_entered_hiding.emit()

## Merayap keluar dari bawah kasur
func exit_bed() -> void:
	if _current_player == null or not _is_occupied:
		return

	_is_occupied = false
	_play_crawl_sfx()

	# Kembalikan pemain ke posisi berdiri semula sebelum masuk (dijamin aman di atas lantai)
	var exit_pos: Vector3 = _pre_hiding_player_pos
	# Jika exit_marker di-override manual oleh level designer
	if exit_marker and exit_marker.is_inside_tree() and exit_marker.name != "ExitPoint":
		exit_pos = exit_marker.global_position

	_current_player.exit_hiding_spot(exit_pos)

	_update_hud(false)
	player_exited_hiding.emit()

func _detect_floor_y(at_pos: Vector3) -> float:
	var space_state := get_world_3d().direct_space_state
	# Cast vertical ray dari 1 meter di atas ke 2.5 meter di bawah
	var ray_from := Vector3(at_pos.x, global_position.y + 0.8, at_pos.z)
	var ray_to := Vector3(at_pos.x, global_position.y - 2.5, at_pos.z)

	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	var exclude_list: Array[RID] = [get_rid()]
	var p_body = get_parent().get_node_or_null("StaticBody3D")
	if p_body is CollisionObject3D:
		exclude_list.append(p_body.get_rid())
	var d_body = get_node_or_null("StaticBody3D")
	if d_body is CollisionObject3D:
		exclude_list.append(d_body.get_rid())
	if _current_player:
		exclude_list.append(_current_player.get_rid())
	query.exclude = exclude_list

	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position.y

	# Fallback ke global_position.y kasur jika tidak ada collider
	return global_position.y

func _on_body_entered(body: Node3D) -> void:
	if body is Player or body.is_in_group(&"player"):
		_player_in_range = true
		_current_player = body as Player
		_update_hud(true)

func _on_body_exited(body: Node3D) -> void:
	if body == _current_player and not _is_occupied:
		_player_in_range = false
		_current_player = null
		_update_hud(false)

func _play_crawl_sfx() -> void:
	if _audio_player and _audio_player.stream:
		_audio_player.pitch_scale = randf_range(0.95, 1.05)
		_audio_player.play()

func _setup_default_markers() -> void:
	if hiding_marker == null:
		var found = get_node_or_null("HidingPoint")
		if found is Marker3D:
			hiding_marker = found
		else:
			hiding_marker = Marker3D.new()
			hiding_marker.name = "HidingPoint"
			# Posisi default di kolong kasur
			hiding_marker.position = Vector3(0.0, 0.22, 0.0)
			add_child(hiding_marker)

	if exit_marker == null:
		var found = get_node_or_null("ExitPoint")
		if found is Marker3D:
			exit_marker = found
		else:
			exit_marker = Marker3D.new()
			exit_marker.name = "ExitPoint"
			# Posisi default di samping kasur
			exit_marker.position = Vector3(1.15, 0.85, 0.0)
			add_child(exit_marker)

func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 20

	_hud_label = Label.new()
	_hud_label.set_anchors_preset(Control.PRESET_CENTER)
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.offset_top = 35.0
	_hud_label.offset_bottom = 65.0
	_hud_label.offset_left = -200.0
	_hud_label.offset_right = 200.0
	_hud_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
	_hud_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hud_label.add_theme_constant_override("shadow_offset_x", 1)
	_hud_label.add_theme_constant_override("shadow_offset_y", 1)
	_hud_label.add_theme_font_size_override("font_size", 15)
	_hud_label.visible = false

	_hud_layer.add_child(_hud_label)
	add_child(_hud_layer)

func _update_hud(show: bool) -> void:
	if _hud_label == null:
		return

	if not show:
		_hud_label.visible = false
		return

	if _is_occupied:
		_hud_label.text = "[E] " + prompt_exit
		_hud_label.visible = true
	elif _player_in_range:
		_hud_label.text = "[E] " + prompt_enter
		_hud_label.visible = true
