class_name HorrorDialogueManager
extends Node

## Singleton Autoload pusat pengatur alur dialog, monolog batin, dan pembaca dokumen lore horor.
## Didaftarkan sebagai 'HorrorDialogue' di Project Settings.

signal dialogue_started(dialogue_id: String)
signal dialogue_line_started(line: DialogueLine)
signal dialogue_event_triggered(event_name: String)
signal dialogue_finished(dialogue_id: String)
signal choice_made(choice: DialogueChoice)
signal note_opened(title: String)
signal note_closed(title: String)

var dialogue_box_scene: PackedScene = preload("res://addons/horror_dialogue/ui/dialogue_box.tscn")
var note_reader_scene: PackedScene = preload("res://addons/horror_dialogue/ui/note_reader_ui.tscn")

var _dialogue_box: HorrorDialogueBox = null
var _note_reader: HorrorNoteReaderUI = null

var _current_dialogue: DialogueData = null
var _current_line_index: int = 0
var _is_dialogue_active: bool = false
var _is_note_active: bool = false
var _player_frozen: bool = false

# Menyimpan ID dialog yang sudah pernah dimainkan
var _completed_dialogues: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_spawn_ui_nodes()

func _spawn_ui_nodes() -> void:
	if _dialogue_box == null:
		_dialogue_box = dialogue_box_scene.instantiate() as HorrorDialogueBox
		add_child(_dialogue_box)
		_dialogue_box.next_line_requested.connect(_on_next_line_requested)
		_dialogue_box.choice_selected.connect(_on_choice_selected)

	if _note_reader == null:
		_note_reader = note_reader_scene.instantiate() as HorrorNoteReaderUI
		add_child(_note_reader)
		_note_reader.note_closed.connect(_on_note_closed)

## Memulai rangkaian percakapan dari Resource DialogueData
func start_dialogue(data: DialogueData) -> bool:
	if data == null or data.lines.is_empty():
		push_warning("HorrorDialogue: DialogueData kosong atau null!")
		return false

	# Jika dialog ini tidak boleh diulang dan sudah pernah diselesaikan
	if not data.repeatable and is_dialogue_completed(data.dialogue_id):
		return false

	_current_dialogue = data
	_current_line_index = 0
	_is_dialogue_active = true

	dialogue_started.emit(data.dialogue_id)
	_dialogue_box.open_dialogue()
	_show_current_line()
	return true

## Menampilkan monolog batin cepat untuk pemain tanpa perlu membuat file Resource
func start_monologue(lines: Array[String], speaker: String = "Aku", typing_speed: float = 0.035, freeze: bool = true) -> void:
	var temp_data := DialogueData.new()
	temp_data.dialogue_id = "quick_monologue_" + str(Time.get_ticks_msec())
	temp_data.repeatable = true

	for text_content in lines:
		var line := DialogueLine.new()
		line.speaker_name = speaker
		line.speaker_color = Color(0.85, 0.85, 0.95, 1.0) # Abu-abu kebiruan batin
		line.text = text_content
		line.typing_speed = typing_speed
		line.freeze_player = freeze
		temp_data.lines.append(line)

	start_dialogue(temp_data)

## Menampilkan 1 baris dialog sederhana (misal pesan interaksi / peringatan)
func start_simple_dialogue(speaker: String, text: String, color: Color = Color(0.9, 0.25, 0.25), freeze: bool = true) -> void:
	var temp_data := DialogueData.new()
	temp_data.dialogue_id = "quick_simple_" + str(Time.get_ticks_msec())
	temp_data.repeatable = true

	var line := DialogueLine.new()
	line.speaker_name = speaker
	line.speaker_color = color
	line.text = text
	line.freeze_player = freeze
	temp_data.lines.append(line)

	start_dialogue(temp_data)

## Membuka jendela pembaca dokumen/surat lore horor
func show_note(title: String, content: String, author: String = "", freeze: bool = true) -> void:
	if _note_reader == null:
		_spawn_ui_nodes()

	_is_note_active = true
	note_opened.emit(title)

	if freeze:
		_set_player_movement_frozen(true)

	_note_reader.display_note(title, content, author)

## Menghentikan paksa semua dialog dan menutup UI
func close_all() -> void:
	if _is_dialogue_active:
		_dialogue_box.close_dialogue()
		_is_dialogue_active = false
	if _is_note_active:
		_note_reader.close_note()
		_is_note_active = false
	_set_player_movement_frozen(false)

func is_dialogue_active() -> bool:
	return _is_dialogue_active

func is_note_active() -> bool:
	return _is_note_active

func is_dialogue_completed(dialogue_id: String) -> bool:
	if dialogue_id.is_empty():
		return false
	return _completed_dialogues.has(dialogue_id)

func mark_dialogue_completed(dialogue_id: String) -> void:
	if not dialogue_id.is_empty():
		_completed_dialogues[dialogue_id] = true

func reset_completed_dialogues() -> void:
	_completed_dialogues.clear()

# ==================== INTERNAL HANDLERS ====================

func _show_current_line() -> void:
	if _current_dialogue == null or _current_line_index >= _current_dialogue.lines.size():
		_finish_dialogue()
		return

	var line: DialogueLine = _current_dialogue.lines[_current_line_index]
	dialogue_line_started.emit(line)

	# Freeze player jika diinstruksikan oleh baris ini
	if line.freeze_player:
		_set_player_movement_frozen(true)
	else:
		_set_player_movement_frozen(false)

	# Pancarkan event signal jika ada
	if not line.event_signal.strip_edges().is_empty():
		dialogue_event_triggered.emit(line.event_signal)

	_dialogue_box.display_line(line)

func _on_next_line_requested() -> void:
	_current_line_index += 1
	_show_current_line()

func _on_choice_selected(choice_index: int, choice: DialogueChoice) -> void:
	choice_made.emit(choice)

	# Pancarkan trigger event dari pilihan jika ada
	if not choice.trigger_event.strip_edges().is_empty():
		dialogue_event_triggered.emit(choice.trigger_event)

	# Jika pilihan ini mengarah ke DialogueData cabang berikutnya
	if choice.next_dialogue is DialogueData:
		start_dialogue(choice.next_dialogue as DialogueData)
	else:
		# Jika tidak ada dialog cabang, lanjut ke baris berikutnya
		_on_next_line_requested()

func _finish_dialogue() -> void:
	var finished_id: String = ""
	if _current_dialogue != null:
		finished_id = _current_dialogue.dialogue_id
		if not _current_dialogue.repeatable and not finished_id.is_empty():
			mark_dialogue_completed(finished_id)

		if not _current_dialogue.on_finish_event.strip_edges().is_empty():
			dialogue_event_triggered.emit(_current_dialogue.on_finish_event)

	_current_dialogue = null
	_current_line_index = 0
	_is_dialogue_active = false

	_dialogue_box.close_dialogue()
	_set_player_movement_frozen(false)
	dialogue_finished.emit(finished_id)

func _on_note_closed(title: String) -> void:
	_is_note_active = false
	_set_player_movement_frozen(false)
	note_closed.emit(title)

# ==================== PLAYER FREEZE CONTROLLER ====================

func _set_player_movement_frozen(freeze: bool) -> void:
	_player_frozen = freeze

	# Cari player dari grup "player"
	var players: Array[Node] = get_tree().get_nodes_in_group(&"player")
	for p in players:
		if p is CharacterBody3D:
			# Matikan pemrosesan fisika pergerakan
			p.set_physics_process(not freeze)
			if freeze:
				p.velocity = Vector3.ZERO

			# Cari node Camera3D di dalam anak-anak player
			var cam: Camera3D = p.find_child("Camera3D", true, false) as Camera3D
			if cam != null:
				cam.set_process_unhandled_input(not freeze)

	# Atur mode kursor mouse
	if freeze:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
