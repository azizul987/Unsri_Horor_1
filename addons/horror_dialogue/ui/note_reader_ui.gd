class_name HorrorNoteReaderUI
extends CanvasLayer

## Controller visual untuk membaca dokumen, diary, dan surat horor.

signal note_closed(title: String)

@onready var backdrop: ColorRect = $Backdrop
@onready var paper_panel: PanelContainer = $PaperPanel
@onready var title_label: Label = $PaperPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var author_label: Label = $PaperPanel/MarginContainer/VBoxContainer/AuthorLabel
@onready var content_label: RichTextLabel = $PaperPanel/MarginContainer/VBoxContainer/ScrollContainer/ContentLabel
@onready var close_hint: Label = $PaperPanel/MarginContainer/VBoxContainer/CloseHint
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

var _is_open: bool = false
var _current_title: String = ""

func _ready() -> void:
	visible = false
	if audio_player.stream == null:
		audio_player.stream = HorrorAudioSynth.get_paper_sound()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	var is_close_action: bool = (
		event.is_action_pressed(&"ui_cancel") or
		(event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE))
	)

	if is_close_action:
		close_note()
		get_viewport().set_input_as_handled()

## Membuka dan menampilkan isi dokumen/catatan
func display_note(title: String, content: String, author: String = "") -> void:
	_current_title = title
	_is_open = true
	visible = true

	title_label.text = title.to_upper()
	content_label.text = content

	if author.strip_edges().is_empty():
		author_label.visible = false
	else:
		author_label.visible = true
		author_label.text = "- " + author

	# Reset scroll ke paling atas
	var scroll = $PaperPanel/MarginContainer/VBoxContainer/ScrollContainer
	scroll.scroll_vertical = 0

	# Mainkan suara kertas
	_play_paper_sfx()

	# Efek transisi muncul perlahan
	paper_panel.modulate.a = 0.0
	paper_panel.scale = Vector2(0.95, 0.95)
	backdrop.modulate.a = 0.0
	
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(backdrop, ^"modulate:a", 1.0, 0.3)
	tween.tween_property(paper_panel, ^"modulate:a", 1.0, 0.3)
	tween.tween_property(paper_panel, ^"scale", Vector2.ONE, 0.3)

## Menutup pembaca catatan
func close_note() -> void:
	if not _is_open:
		return
	_is_open = false

	_play_paper_sfx()

	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(backdrop, ^"modulate:a", 0.0, 0.2)
	tween.tween_property(paper_panel, ^"modulate:a", 0.0, 0.2)
	await tween.finished
	visible = false
	note_closed.emit(_current_title)

func _play_paper_sfx() -> void:
	if audio_player.stream != null:
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.play()
