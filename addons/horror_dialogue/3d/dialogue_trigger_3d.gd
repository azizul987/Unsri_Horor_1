class_name DialogueTrigger3D
extends Area3D

## Node Area3D untuk memicu narasi cerita, monolog batin, atau percakapan otomatis
## ketika pemain melangkah masuk ke dalam area collider di dunia 3D.

signal triggered(interactor: Node3D)

@export_group("Dialogue Settings")
## Resource dialog yang akan diputar (DialogueData)
@export var dialogue_data: DialogueData = null

@export_group("Quick Monologue (Alternatif Cepat)")
## Jika true, akan menggunakan baris teks cepat di bawah ini tanpa perlu membuat file .tres
@export var use_quick_monologue: bool = false
@export var quick_speaker_name: String = "Aku"
@export_multiline var quick_lines: Array[String] = []
@export var freeze_player: bool = true

@export_group("Trigger Rules")
## Apakah trigger ini hanya aktif 1 kali seumur permainan?
@export var trigger_once: bool = true
## Hanya aktif jika node yang menyentuh berada di grup "player"
@export var require_player_group: bool = true
## Jeda sebelum dialog dimulai setelah pemain menyentuh area (dalam detik)
@export var trigger_delay: float = 0.0

var _is_triggered: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _is_triggered and trigger_once:
		return

	# Cek apakah objek adalah Player
	if require_player_group and not body.is_in_group(&"player"):
		return

	_is_triggered = true
	triggered.emit(body)

	if trigger_delay > 0.0:
		await get_tree().create_timer(trigger_delay).timeout

	_execute_dialogue()

func _execute_dialogue() -> void:
	# Cek singleton HorrorDialogue
	var manager: HorrorDialogueManager = _get_manager()
	if manager == null:
		push_error("DialogueTrigger3D: Autoload 'HorrorDialogue' tidak ditemukan!")
		return

	if use_quick_monologue and not quick_lines.is_empty():
		manager.start_monologue(quick_lines, quick_speaker_name, 0.035, freeze_player)
	elif dialogue_data != null:
		manager.start_dialogue(dialogue_data)

func _get_manager() -> HorrorDialogueManager:
	if Engine.has_singleton("HorrorDialogue"):
		return Engine.get_singleton("HorrorDialogue") as HorrorDialogueManager
	if is_instance_valid(get_node_or_null("/root/HorrorDialogue")):
		return get_node("/root/HorrorDialogue") as HorrorDialogueManager
	return null
