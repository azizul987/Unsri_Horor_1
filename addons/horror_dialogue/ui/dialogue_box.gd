class_name HorrorDialogueBox
extends CanvasLayer

## Controller visual kotak dialog, typewriter horor, dan pilihan respon.

signal line_finished_typing
signal next_line_requested
signal choice_selected(choice_index: int, choice: DialogueChoice)

@onready var top_bar: ColorRect = $TopLetterbox
@onready var bottom_bar: ColorRect = $BottomLetterbox
@onready var main_panel: PanelContainer = $BottomLetterbox/PanelContainer
@onready var speaker_label: Label = $BottomLetterbox/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/SpeakerLabel
@onready var text_label: RichTextLabel = $BottomLetterbox/PanelContainer/MarginContainer/VBoxContainer/DialogueText
@onready var avatar_rect: TextureRect = $BottomLetterbox/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/Avatar
@onready var prompt_indicator: Label = $BottomLetterbox/PanelContainer/MarginContainer/VBoxContainer/PromptIndicator
@onready var choices_container: VBoxContainer = $BottomLetterbox/PanelContainer/MarginContainer/VBoxContainer/ChoicesContainer
@onready var typing_audio_player: AudioStreamPlayer = $TypingAudioPlayer
@onready var voice_audio_player: AudioStreamPlayer = $VoiceAudioPlayer

var _current_line: DialogueLine = null
var _is_typing: bool = false
var _type_timer: float = 0.0
var _current_char_index: int = 0
var _total_chars: int = 0
var _active_choices: Array[DialogueChoice] = []
var _is_open: bool = false
var _waiting_for_input: bool = false

# Karakter tanda baca yang memicu jeda suspensif
const SUSPENSE_PUNCTUATION: String = ".,!?…"

func _ready() -> void:
	visible = false
	prompt_indicator.visible = false
	choices_container.visible = false
	
	# Default audio jika belum diset
	if typing_audio_player.stream == null:
		typing_audio_player.stream = HorrorAudioSynth.get_typewriter_click()

func _process(delta: float) -> void:
	if not _is_typing or _current_line == null:
		return

	_type_timer += delta
	var speed: float = maxf(0.005, _current_line.typing_speed)

	while _type_timer >= speed and _is_typing:
		_type_timer -= speed
		_current_char_index += 1
		text_label.visible_characters = _current_char_index

		# Mainkan audio ketik dengan variasi pitch horor
		_play_type_sfx()

		# Cek apakah karakter saat ini adalah tanda baca suspensif
		var parsed_text: String = text_label.get_parsed_text()
		if _current_char_index < parsed_text.length():
			var char_str: String = parsed_text[_current_char_index - 1]
			if SUSPENSE_PUNCTUATION.contains(char_str):
				_type_timer -= speed * 4.0 # Jeda hening menegangkan

		if _current_char_index >= _total_chars:
			_finish_typing()
			break

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	# Handle shortcut tombol angka 1-9 untuk memilih opsi
	if _waiting_for_input and not _active_choices.is_empty():
		for i in range(min(9, _active_choices.size())):
			var key_code: Key = KEY_1 + i
			if event is InputEventKey and event.pressed and not event.echo and event.keycode == key_code:
				_select_choice(i)
				get_viewport().set_input_as_handled()
				return

	# Handle tombol lanjut / skip (E, Space, Enter, atau Klik Kiri)
	var is_advance_action: bool = (
		event.is_action_pressed(&"ui_accept") or 
		(event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)) or
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	)

	if is_advance_action:
		if _is_typing:
			# Skip animasi ketik langsung ke teks lengkap
			_finish_typing(true)
			get_viewport().set_input_as_handled()
		elif _waiting_for_input and _active_choices.is_empty():
			# Lanjut ke baris dialog berikutnya
			_waiting_for_input = false
			prompt_indicator.visible = false
			next_line_requested.emit()
			get_viewport().set_input_as_handled()

## Membuka tampilan UI kotak dialog dengan transisi sinematik
func open_dialogue() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	
	# Bersihkan konten lama
	text_label.text = ""
	text_label.visible_characters = 0
	speaker_label.text = ""
	prompt_indicator.visible = false
	_clear_choices()

	# Efek transisi masuk Bar Sinematik
	top_bar.custom_minimum_size.y = 0
	bottom_bar.custom_minimum_size.y = 0
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(top_bar, ^"custom_minimum_size:y", 50.0, 0.3)
	tween.tween_property(bottom_bar, ^"custom_minimum_size:y", 180.0, 0.3)
	tween.tween_property(main_panel, ^"modulate:a", 1.0, 0.3).from(0.0)

## Menutup UI kotak dialog
func close_dialogue() -> void:
	if not _is_open:
		return
	_is_open = false
	_is_typing = false
	_waiting_for_input = false
	_clear_choices()

	if voice_audio_player.playing:
		voice_audio_player.stop()

	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(top_bar, ^"custom_minimum_size:y", 0.0, 0.25)
	tween.tween_property(bottom_bar, ^"custom_minimum_size:y", 0.0, 0.25)
	tween.tween_property(main_panel, ^"modulate:a", 0.0, 0.2)
	await tween.finished
	visible = false

## Menampilkan baris dialog baru
func display_line(line: DialogueLine) -> void:
	if not _is_open:
		open_dialogue()

	_current_line = line
	_clear_choices()
	prompt_indicator.visible = false
	_waiting_for_input = false

	# Setup nama pembicara
	if line.speaker_name.strip_edges().is_empty():
		speaker_label.visible = false
	else:
		speaker_label.visible = true
		speaker_label.text = line.speaker_name.to_upper()
		speaker_label.modulate = line.speaker_color

	# Setup avatar jika ada
	if avatar_rect:
		if line.speaker_avatar != null:
			avatar_rect.texture = line.speaker_avatar
			avatar_rect.visible = true
		else:
			avatar_rect.visible = false

	# Setup audio voiceover / sound effect
	if line.voice_audio != null:
		voice_audio_player.stream = line.voice_audio
		voice_audio_player.play()
	else:
		if voice_audio_player.playing:
			voice_audio_player.stop()

	# Atur suara ketikan khusus jika diset
	if line.custom_typing_sound != null:
		typing_audio_player.stream = line.custom_typing_sound
	else:
		typing_audio_player.stream = HorrorAudioSynth.get_typewriter_click()

	# Setup teks & inisialisasi typewriter
	text_label.text = line.text
	_total_chars = text_label.get_parsed_text().length()
	text_label.visible_characters = 0
	_current_char_index = 0
	_type_timer = 0.0
	_is_typing = true

func _finish_typing(skip_instant: bool = false) -> void:
	_is_typing = false
	text_label.visible_characters = -1
	_current_char_index = _total_chars

	line_finished_typing.emit()

	# Jika ada pilihan jawaban (branching choices)
	if _current_line != null and not _current_line.choices.is_empty():
		_display_choices(_current_line.choices)
	else:
		# Tidak ada pilihan, tampilkan petunjuk lanjut
		_waiting_for_input = true
		prompt_indicator.visible = true
		_blink_prompt()

func _play_type_sfx() -> void:
	if typing_audio_player.stream != null:
		typing_audio_player.pitch_scale = randf_range(0.92, 1.08)
		typing_audio_player.play()

func _blink_prompt() -> void:
	prompt_indicator.modulate.a = 1.0
	var tween: Tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tween.tween_property(prompt_indicator, ^"modulate:a", 0.3, 0.5)
	tween.tween_property(prompt_indicator, ^"modulate:a", 1.0, 0.5)

func _display_choices(choices: Array[DialogueChoice]) -> void:
	_active_choices = choices
	choices_container.visible = true
	_waiting_for_input = true

	var index: int = 0
	for choice: DialogueChoice in choices:
		var btn := Button.new()
		var prefix: String = "[%d] " % (index + 1) if index < 9 else "- "
		btn.text = prefix + choice.text
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.focus_mode = Control.FOCUS_ALL

		# Style tombol horor: latar gelap, teks merah/abu-abu
		btn.theme_type_variation = "FlatButton"
		btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.3, 0.3))
		btn.add_theme_color_override("font_focus_color", Color(1.0, 0.3, 0.3))

		# Cek apakah ada syarat item di Inventory
		var has_required_item: bool = _check_item_requirement(choice.required_item_id)
		if not has_required_item:
			btn.disabled = true
			btn.text += " " + choice.locked_hint
			btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4))

		var current_idx: int = index
		var bound_choice: DialogueChoice = choice
		btn.pressed.connect(func(): _select_choice(current_idx))
		choices_container.add_child(btn)
		index += 1

	# Beri fokus otomatis ke pilihan pertama yang aktif
	for child in choices_container.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			break

func _select_choice(index: int) -> void:
	if index < 0 or index >= _active_choices.size():
		return
	var choice: DialogueChoice = _active_choices[index]

	# Cek syarat item
	if not _check_item_requirement(choice.required_item_id):
		return

	# Mainkan audio konfirmasi
	_play_type_sfx()

	_clear_choices()
	_waiting_for_input = false
	choice_selected.emit(index, choice)

func _clear_choices() -> void:
	_active_choices.clear()
	choices_container.visible = false
	for child in choices_container.get_children():
		child.queue_free()

func _check_item_requirement(item_id: String) -> bool:
	if item_id.strip_edges().is_empty():
		return true

	# Periksa apakah singleton Inventory ada
	if Engine.has_singleton("Inventory"):
		var inv = Engine.get_singleton("Inventory")
		if inv.has_method("has_item"):
			return inv.has_item(item_id)
	elif is_instance_valid(get_node_or_null("/root/Inventory")):
		var inv = get_node("/root/Inventory")
		if inv.has_method("has_item"):
			return inv.has_item(item_id)

	return true
