class_name IntroCinematic
extends Node3D

## ============================================================================
## 🎬 INTRO CINEMATIC: KUPU-KUPU MALAM (UNSRI HOROR)
## ============================================================================
## Alur Sinematik Prolog:
## 1. Scene Kebakaran Hutan: Kamera panning dramatis di area hutan terbakar,
##    efek bara api, asap, dan kepakan sayap kupu-kupu hijau mistis.
## 2. Kupu-kupu terbang meninggalkan hutan menuju Rusun UNSRI.
## 3. Kamar Rusun Amir: Amir duduk termenung. Kupu-kupu masuk lewat ventilasi/jendela.
## 4. Kupu-kupu hinggap dan menggigit lengan Amir. Amir kaget (sfx_amir_gasp).
##    [CATATAN NARATIF]: Sama sekali TIDAK membocorkan bahwa Amir yang membakar!
##    Amir hanya merasa perih misterius dan bingung.
## 5. Layar hitam (Fade to Black), teks "Jam 01:00 WIB", lalu masuk ke Scenes/main.tscn.
## ============================================================================

@export_group("Target Scene")
@export_file("*.tscn") var gameplay_scene_path: String = "res://Scenes/main.tscn"

# Node References
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sub_label: Label = $UI/Subtitles/Label
@onready var skip_label: Label = $UI/SkipPrompt
@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var title_screen: Control = $UI/TitleScreen
@onready var title_time_label: Label = $UI/TitleScreen/TimeLabel
@onready var title_sub_label: Label = $UI/TitleScreen/SubLabel

@onready var cam_forest: Camera3D = $ForestShot/CameraForest
@onready var cam_dorm: Camera3D = $DormShot/CameraDorm
@onready var cam_close: Camera3D = $DormShot/CameraCloseUp

@onready var butterfly: Node3D = $ForestShot/Moth
@onready var dorm_butterfly: Node3D = $DormShot/DormMoth
@onready var amir_arm_light: OmniLight3D = $DormShot/AmirModel/ArmGlow

var _is_transitioning: bool = false
var _intro_coroutine: bool = false

func _ready() -> void:
	fade_rect.color = Color(0, 0, 0, 1)
	sub_label.text = ""
	title_screen.modulate = Color(1, 1, 1, 0)
	skip_label.visible = true

	# Pastikan mouse tertangkap atau bebas untuk UI
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Mulai urutan intro setelah 0.5 detik
	get_tree().create_timer(0.5).timeout.connect(_start_cinematic_sequence)

func _unhandled_input(event: InputEvent) -> void:
	# Tombol Space atau Escape untuk SKIP intro langsung ke game
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]:
			_skip_cinematic()

func _skip_cinematic() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_fade_and_load_main()

# ============================================================================
# SEQUENCE DIRECTOR
# ============================================================================

func _start_cinematic_sequence() -> void:
	if _is_transitioning:
		return

	# Mainkan suara hutan terbakar
	var sm = SoundManager.instance if SoundManager.instance else get_node_or_null("/root/SoundManager")
	if sm:
		sm.play_sfx_2d("forest_fire", 0.0)

	# -------------------------------------------------------------------------
	# SHOT 1: Hutan Gambut Terbakar
	# -------------------------------------------------------------------------
	cam_forest.current = true
	cam_dorm.current = false
	cam_close.current = false

	# Fade in dari hitam
	var tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, ^"color:a", 0.0, 2.5)

	# Kamera meluncur perlahan
	var tween_cam = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_cam.tween_property(cam_forest, ^"position", cam_forest.position + Vector3(0.0, 1.2, -6.0), 7.0)

	await get_tree().create_timer(1.2).timeout
	if _is_transitioning: return
	_show_sub("Beberapa hari lalu... kebakaran misterius melanda area hutan rawa di perbatasan kampus.")

	await get_tree().create_timer(3.8).timeout
	if _is_transitioning: return
	_show_sub("Asap tebal mengepung rusunawa... tanah gambut terbakar hingga ke akarnya.")

	# Kupu-kupu terbang keluar dari reruntuhan pohon terbakar
	if sm:
		sm.play_sfx_2d("moth_flap", 2.0)
	var tween_moth = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_moth.tween_property(butterfly, ^"position", butterfly.position + Vector3(1.5, 4.0, -12.0), 3.5)

	await get_tree().create_timer(3.0).timeout
	if _is_transitioning: return
	_show_sub("Namun dari abu hutan yang menghitam... sesuatu yang terkutuk bangkit kembali.")

	# Fade to black sebelum beralih ke kamar rusun
	var tween_cut = create_tween()
	tween_cut.tween_property(fade_rect, ^"color:a", 1.0, 1.2)
	await tween_cut.finished
	if _is_transitioning: return

	# -------------------------------------------------------------------------
	# SHOT 2: Kamar Rusun Amir (Malam Hari)
	# -------------------------------------------------------------------------
	if sm:
		sm.play_ambience("ambience_drone", 2.0, -2.0)

	cam_forest.current = false
	cam_dorm.current = true

	var tween_fade2 = create_tween()
	tween_fade2.tween_property(fade_rect, ^"color:a", 0.0, 1.5)

	_show_sub("Rusun UNSRI — Kamar 204")
	await get_tree().create_timer(2.2).timeout
	if _is_transitioning: return

	_show_sub("Amir: \"Kenapa hawanya panas sekali malam ini... bau gosong itu masih belum hilang juga...\"")
	await get_tree().create_timer(4.0).timeout
	if _is_transitioning: return

	# -------------------------------------------------------------------------
	# SHOT 3: Kupu-Kupu Masuk dan Menggigit Amir
	# -------------------------------------------------------------------------
	cam_dorm.current = false
	cam_close.current = true

	if sm:
		sm.play_sfx_2d("moth_loop", 1.0)

	dorm_butterfly.visible = true
	var tween_moth2 = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Bergerak ke arah lengan Amir
	tween_moth2.tween_property(dorm_butterfly, ^"position", Vector3(0.18, 0.95, -0.42), 2.2)

	await tween_moth2.finished
	if _is_transitioning: return

	# GIGITAN! (SFX Gasp & Bone Crack halus / Stinger)
	if sm:
		sm.play_sfx_2d("amir_gasp", 3.0)
		sm.play_sfx_2d("bone_crack", -2.0, 1.3)

	# Efek kilau racun di lengan Amir
	if amir_arm_light:
		var tween_glow = create_tween()
		tween_glow.tween_property(amir_arm_light, ^"light_energy", 3.5, 0.1)
		tween_glow.tween_property(amir_arm_light, ^"light_energy", 0.8, 1.0)

	# Kamera tersentak kaget
	var orig_cam_pos = cam_close.position
	var tween_shake = create_tween()
	tween_shake.tween_property(cam_close, ^"position", orig_cam_pos + Vector3(0.04, -0.03, 0.05), 0.04)
	tween_shake.tween_property(cam_close, ^"position", orig_cam_pos, 0.08)

	_show_sub("Amir: \"AGHHH! Apa itu barusan?! Nyamuk...?! Kenapa rasanya membakar perih seperti ini?!\"")
	await get_tree().create_timer(3.8).timeout
	if _is_transitioning: return

	_show_sub("Amir: \"Tanganku... kulitku kenapa menghitam begini...? Tolong... siapa saja...\"")
	await get_tree().create_timer(3.5).timeout
	if _is_transitioning: return

	# -------------------------------------------------------------------------
	# SHOT 4: Layar Gelap & Judul Waktu
	# -------------------------------------------------------------------------
	var tween_fade3 = create_tween()
	tween_fade3.tween_property(fade_rect, ^"color:a", 1.0, 1.8)
	await tween_fade3.finished
	if _is_transitioning: return

	_show_sub("")
	skip_label.visible = false

	# Tampilkan Title Card Horor
	var tween_title = create_tween()
	tween_title.tween_property(title_screen, ^"modulate:a", 1.0, 1.5)
	await tween_title.finished
	if _is_transitioning: return

	# Suara gedoran pintu misterius di kejauhan sebelum masuk game
	if sm:
		sm.play_sfx_2d("door_bang", 1.0)

	await get_tree().create_timer(2.8).timeout
	_fade_and_load_main()

func _show_sub(text: String) -> void:
	sub_label.text = text
	var tween = create_tween()
	sub_label.modulate.a = 0.0
	tween.tween_property(sub_label, ^"modulate:a", 1.0, 0.3)

func _fade_and_load_main() -> void:
	_is_transitioning = true
	var tween = create_tween()
	tween.tween_property(fade_rect, ^"color:a", 1.0, 0.8)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(gameplay_scene_path)
	)
