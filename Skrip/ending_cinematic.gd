class_name EndingCinematic
extends Node3D

## ============================================================================
## 🎬 ENDING CINEMATIC: KUPU-KUPU MALAM (DUA AKHIR CERITA)
## ============================================================================
## Mendukung 2 Ending sesuai GDD:
## - Ending 1 (Sembuh / Penyucian): 8 Bunga menyucikan Amir. Kutukan terangkat.
##   Amir sadar dan akhirnya mengaku bahwa dialah yang tanpa sengaja membakar hutan.
## - Ending 2 (Bakar / Amukan Hutan): Altar dan bunga dibakar. Roh hutan marah.
##   Amir sepenuhnya bermutasi menjadi Monster Ngengat, dan menghilang ke rawa malam.
## ============================================================================

## Tipe ending yang dijalankan (true = Ending 1: Sembuh, false = Ending 2: Bakar)
@export var is_cure_ending: bool = true

@onready var cam: Camera3D = $Camera3D
@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var sub_label: Label = $UI/Subtitles/Label
@onready var ending_title: Label = $UI/EndingTitle/TitleLabel
@onready var ending_sub: Label = $UI/EndingTitle/SubLabel
@onready var restart_btn: Button = $UI/EndingTitle/RestartButton
@onready var altar_light: OmniLight3D = $AltarLight
@onready var amir_glow: OmniLight3D = $Amir/AmirGlow

var _is_transitioning: bool = false

func _ready() -> void:
	fade_rect.color = Color(0, 0, 0, 1)
	sub_label.text = ""
	ending_title.text = ""
	ending_sub.text = ""
	restart_btn.visible = false
	restart_btn.pressed.connect(_on_restart_pressed)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Cek apakah tipe ending dioper via StoryGameManager
	var story = StoryManager if StoryManager else StoryGameManager.instance
	if story and "is_cure_ending" in story:
		is_cure_ending = story.is_cure_ending

	get_tree().create_timer(0.6).timeout.connect(_start_ending_sequence)

func _start_ending_sequence() -> void:
	if is_cure_ending:
		_play_ending_cure()
	else:
		_play_ending_burn()

# ============================================================================
# ENDING 1: PENYUCIAN (SEMBUH)
# ============================================================================
func _play_ending_cure() -> void:
	var sm = SoundManager.instance if SoundManager.instance else get_node_or_null("/root/SoundManager")
	if sm:
		sm.stop_ambience(1.5)
		sm.play_sfx_2d("flower_bell", 2.0)

	altar_light.light_color = Color(0.9, 0.95, 1.0, 1.0)
	altar_light.light_energy = 4.0

	# Fade in perlahan
	var tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, ^"color:a", 0.0, 3.0)

	# Kamera meluncur mendekat ke Amir yang tersungkur di depan altar
	var tween_cam = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_cam.tween_property(cam, ^"position", cam.position + Vector3(0.0, -0.4, -2.5), 8.0)

	await get_tree().create_timer(1.8).timeout
	_show_sub("Serbuk sari dari ke-8 bunga mistis melebur di atas altar, menyelimuti tubuh Amir...")

	await get_tree().create_timer(4.0).timeout
	# Redupkan cahaya kutukan di tubuh Amir
	var tween_glow = create_tween()
	tween_glow.tween_property(amir_glow, ^"light_energy", 0.0, 2.5)

	_show_sub("Guratan hijau kehitaman di kulit Amir perlahan memudar... kabut malam mulai terangkat.")

	await get_tree().create_timer(4.5).timeout
	if sm:
		sm.play_sfx_2d("amir_gasp", -1.0)

	_show_sub("Amir: \"Ugh... kepalaku... MC? Kenapa... kenapa kita ada di halaman rusun...?\"")

	await get_tree().create_timer(4.5).timeout
	_show_sub("Amir: \"Aku ingat sekarang... siang itu... aku merokok di dekat semak rawa... puntung api itu jatuh...\"")

	await get_tree().create_timer(5.0).timeout
	_show_sub("Amir: \"Aku panik dan kabur saat api membesar... Maafkan aku, MC... Aku tidak tahu gambut itu akan membalas dendam sejauh ini...\"")

	await get_tree().create_timer(5.5).timeout
	_show_sub("Fajar menyingsing di atas kampus UNSRI. Kutukan Kupu-Kupu Malam akhirnya beristirahat dalam damai.")

	await get_tree().create_timer(5.0).timeout
	_show_final_card(
		"ENDING 1 — PENYUCIAN (SEBUAH PENGAKUAN)",
		"Kamu menyelamatkan nyawa Amir dan memulihkan kedamaian rawa UNSRI.\nKebenaran tentang kebakaran hutan akhirnya terungkap.",
		Color(0.4, 0.9, 0.6, 1.0)
	)

# ============================================================================
# ENDING 2: AMUKAN HUTAN (BAKAR)
# ============================================================================
func _play_ending_burn() -> void:
	var sm = SoundManager.instance if SoundManager.instance else get_node_or_null("/root/SoundManager")
	if sm:
		sm.play_sfx_2d("forest_fire", 2.0)
		sm.play_sfx_2d("creepy_rattle", 1.0)

	altar_light.light_color = Color(1.0, 0.25, 0.05, 1.0)
	altar_light.light_energy = 5.0

	var tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, ^"color:a", 0.0, 1.5)

	# Guncangan kamera dramatis
	var orig_pos = cam.position
	var tween_shake = create_tween().set_loops(20)
	tween_shake.tween_property(cam, ^"position", orig_pos + Vector3(randf_range(-0.06, 0.06), randf_range(-0.04, 0.04), 0.0), 0.06)

	await get_tree().create_timer(1.2).timeout
	_show_sub("Api membakar altar! Bunga-bunga kehidupan terbakar habis menjadi abu hitam pekat!")

	await get_tree().create_timer(3.5).timeout
	if sm:
		sm.play_sfx_2d("monster_screech", 3.0)
		sm.play_sfx_2d("horror_scream", 2.0)

	# Pendaran merah/hijau liar di tubuh Amir
	amir_glow.light_color = Color(0.1, 1.0, 0.3, 1.0)
	var tween_glow2 = create_tween()
	tween_glow2.tween_property(amir_glow, ^"light_energy", 6.0, 0.2)

	_show_sub("Roh hutan rawa mengamuk! Ribuan ngengat hitam keluar dari pepohonan, menyatu ke dalam raga Amir!")

	await get_tree().create_timer(4.5).timeout
	_show_sub("Sosok Amir lenyap... digantikan oleh monster malam bersayap jelaga dengan mata menyala merah.")

	await get_tree().create_timer(4.5).timeout
	if sm:
		sm.play_jumpscare("jumpscare_hit", 3.0)

	var tween_cut = create_tween()
	tween_cut.tween_property(fade_rect, ^"color:a", 1.0, 0.3)
	await tween_cut.finished

	_show_sub("")
	await get_tree().create_timer(1.5).timeout
	_show_final_card(
		"ENDING 2 — ABU DAN KUTUKAN (AMUKAN RAWA)",
		"Tanpa bunga kehidupan, kutukan hutan menelan segalanya.\nAmir menghilang ke dalam rimba rawa sumatera, menjadi legenda Kupu-Kupu Malam untuk selamanya.",
		Color(1.0, 0.3, 0.2, 1.0)
	)

func _show_sub(text: String) -> void:
	sub_label.text = text
	var tween = create_tween()
	sub_label.modulate.a = 0.0
	tween.tween_property(sub_label, ^"modulate:a", 1.0, 0.3)

func _show_final_card(title: String, subtitle: String, title_col: Color) -> void:
	sub_label.text = ""
	ending_title.text = title
	ending_title.modulate = title_col
	ending_sub.text = subtitle
	restart_btn.visible = true

	var tween = create_tween()
	tween.tween_property(ending_title, ^"modulate:a", 1.0, 1.2)
	tween.tween_property(ending_sub, ^"modulate:a", 1.0, 0.8)

func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/intro_cinematic.tscn")
