class_name DialogueInteractable3D
extends Area3D

## Node Area3D interactable untuk diletakkan pada NPC, mayat, pintu terkunci, atau catatan/surat
## yang dapat didekati dan diajak bicara / diperiksa oleh pemain menggunakan tombol interaksi (misal: [E]).

signal interacted(interactor: Node)
signal player_approached(is_inside: bool)

@export_group("Mode Interaksi")
## Centang jika objek ini adalah dokumen/surat/diary yang ingin dibaca di layar penuh
@export var is_note: bool = false

@export_group("Dialog Settings (Jika Bukan Catatan)")
## Resource dialog percakapan dengan karakter ini
@export var dialogue_data: DialogueData = null

@export_group("Catatan / Surat Settings (Jika is_note = true)")
## Resource file surat/catatan yang ingin ditampilkan (opsional, jika diisi akan menimpa kolom di bawah)
@export var note_data: NoteData = null
@export var note_title: String = "Catatan Misterius"
@export_multiline var note_content: String = "Tulisan di kertas ini sudah memudar..."
@export var note_author: String = ""

@export_group("Teks Interaksi")
## Pesan prompt yang muncul saat pemain mendekat atau mengarahkan crosshair
@export var prompt_message: String = "Bicara"
@export var prompt_note_message: String = "Baca Catatan"

var _player_in_range: bool = false
var _current_player: Node3D = null

func _ready() -> void:
	add_to_group(&"dialogue_interactable")
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return

	# Cek apakah pemain menekan tombol E atau Space/Enter
	var is_interact_pressed: bool = (
		(event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E) or
		event.is_action_pressed(&"interact")
	)

	if is_interact_pressed:
		var manager: HorrorDialogueManager = _get_manager()
		# Jangan picu jika dialog/catatan sudah sedang terbuka
		if manager and (manager.is_dialogue_active() or manager.is_note_active()):
			return

		interact(_current_player)
		get_viewport().set_input_as_handled()

## Mengembalikan teks prompt interaksi (kompatibel dengan sistem HUD crosshair)
func get_interaction_prompt() -> String:
	if is_note:
		return "%s [E]" % prompt_note_message
	return "%s [E]" % prompt_message

## Fungsi interaksi yang dapat dipanggil oleh RayCast3D milik Player atau input area
func interact(interactor: Node = null) -> bool:
	var manager: HorrorDialogueManager = _get_manager()
	if manager == null:
		push_error("DialogueInteractable3D: Autoload 'HorrorDialogue' tidak ditemukan!")
		return false

	interacted.emit(interactor)

	if is_note:
		if note_data != null:
			manager.show_note(note_data.title, note_data.content, note_data.author)
		else:
			manager.show_note(note_title, note_content, note_author)
		return true
	elif dialogue_data != null:
		return manager.start_dialogue(dialogue_data)
	else:
		push_warning("DialogueInteractable3D: dialogue_data belum diset dan is_note = false!")
		return false

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player") or body is CharacterBody3D:
		_player_in_range = true
		_current_player = body
		player_approached.emit(true)

func _on_body_exited(body: Node3D) -> void:
	if body == _current_player:
		_player_in_range = false
		_current_player = null
		player_approached.emit(false)

func _get_manager() -> HorrorDialogueManager:
	if Engine.has_singleton("HorrorDialogue"):
		return Engine.get_singleton("HorrorDialogue") as HorrorDialogueManager
	if is_instance_valid(get_node_or_null("/root/HorrorDialogue")):
		return get_node("/root/HorrorDialogue") as HorrorDialogueManager
	return null
