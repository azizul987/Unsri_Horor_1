class_name RamaNPC
extends Node3D

## NPC Rama di Lantai 2 Rusun (Bagian dari Misi 2).
## Memberikan lore cerita tentang alasan kenapa Amir berubah agresif sejak pintu dibuka,
## serta mengarahkan pemain ke Tahap 3 (mengumpulkan 8 bunga).

@export var auto_trigger_on_approach: bool = false
@onready var interactable: DialogueInteractable3D = get_node_or_null("DialogueInteractable3D")

func _ready() -> void:
	add_to_group(&"npc_rama")
	if interactable:
		interactable.dialogue_data = _build_story_dialogue()
		interactable.interacted.connect(_on_interacted)
		interactable.player_approached.connect(_on_player_approached)

func _build_story_dialogue() -> DialogueData:
	var data := DialogueData.new()
	data.dialogue_id = "rama_story"
	data.repeatable = true
	data.on_finish_event = "mbah_rama_story_finished"

	var lines_data: Array[Array] = [
		["Rama", Color(0.3, 0.8, 1.0), "Ssshh... pelankan langkahmu! Beruntung kamu bisa lolos saat pintu kamar Amir itu terbuka..."],
		["Aku", Color(0.9, 0.9, 0.9), "Rama?! Apa yang sebenarnya terjadi padanya?! Kenapa Amir langsung mengamuk begitu pintunya terbuka?!"],
		["Rama", Color(0.3, 0.8, 1.0), "Kemarin siang Amir tanpa sengaja membakar semak rawa dan memusnahkan sarang serangga mistis. Kutukan Kupu-Kupu Malam merasuki tubuhnya, terkurung di kamar, lalu meledak liar saat pintunya dibuka!"],
		["Rama", Color(0.3, 0.8, 1.0), "Amir kehilangan akal dan menyerang siapa saja. Satu-satunya cara menolongnya: [color=yellow]kumpulkan 8 bunga mistis[/color] yang tercecer di rusun ini dan bawa ke Altar persembahan!"]
	]

	for item in lines_data:
		var line := DialogueLine.new()
		line.speaker_name = item[0]
		line.speaker_color = item[1]
		line.text = item[2]
		line.typing_speed = 0.032
		data.lines.append(line)

	return data

func _build_reminder_dialogue() -> DialogueData:
	var data := DialogueData.new()
	data.dialogue_id = "rama_reminder"
	data.repeatable = true

	var line := DialogueLine.new()
	line.speaker_name = "Rama"
	line.speaker_color = Color(0.3, 0.8, 1.0)
	line.text = "Kumpulkan 8 bunga yang tersebar di sekitar area ini untuk melanjutkan. Jika Amir mengejarmu, cepat sembunyi di bawah kasur!"
	data.lines.append(line)

	return data

func _on_player_approached(is_inside: bool) -> void:
	if is_inside and auto_trigger_on_approach and interactable:
		var sm = StoryGameManager.instance
		if sm and sm.current_mission == StoryGameManager.MissionStep.FIND_MBAH_RAMA:
			interactable.interact()

func _on_interacted(_interactor: Node) -> void:
	var sm = StoryGameManager.instance
	if sm and sm.current_mission != StoryGameManager.MissionStep.FIND_MBAH_RAMA:
		interactable.dialogue_data = _build_reminder_dialogue()
