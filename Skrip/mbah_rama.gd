class_name MbahRamaNPC
extends Node3D

## NPC Mbah Rama di Lantai 2 Rusun.
## Memberikan arahan cerita (lore) tentang musibah Amir dan instruksi mencari 8 bunga.

@onready var interactable: DialogueInteractable3D = get_node_or_null("DialogueInteractable3D")

func _ready() -> void:
	if interactable:
		interactable.dialogue_data = _build_story_dialogue()
		interactable.interacted.connect(_on_interacted)

func _build_story_dialogue() -> DialogueData:
	var data := DialogueData.new()
	data.dialogue_id = "mbah_rama_story"
	data.repeatable = true
	data.on_finish_event = "mbah_rama_story_finished"

	var lines_data = [
		["Mbah Rama", Color(0.3, 0.8, 1.0), "Ssshh... pelankan langkahmu, nak. Kau beruntung masih bisa lolos dari cengkeraman Amir..."],
		["Aku", Color(0.9, 0.9, 0.9), "Mbah Rama?! Apa yang sebenarnya terjadi padanya?! Kenapa Amir berubah menjadi monster buas?!"],
		["Mbah Rama", Color(0.3, 0.8, 1.0), "Asap kebakaran hutan kemarin membangkitkan kutukan kuno [wave amp=20.0 freq=3.0]Kupu-Kupu Malam[/wave]. Amir tergigit dan jiwanya kini terbelenggu kegelapan rusun ini."],
		["Mbah Rama", Color(0.3, 0.8, 1.0), "Hanya ada satu cara menghentikannya: carilah [color=yellow]8 Bunga Kupu-Kupu Malam[/color] yang tercecer di berbagai lantai rusun ini, lalu bawa ke Altar persembahan di lantai dasar."],
		["Mbah Rama", Color(0.3, 0.8, 1.0), "Dan ingat, jika Amir mengejarmu... [shake rate=15.0 level=4]segera lari dan sembunyi di bawah kasur![/shake] Cepatlah pergi, selamatkan Amir dan rusun ini!"]
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
	data.dialogue_id = "mbah_rama_reminder"
	data.repeatable = true

	var line := DialogueLine.new()
	line.speaker_name = "Mbah Rama"
	line.speaker_color = Color(0.3, 0.8, 1.0)
	line.text = "Cepat cari ke-8 bunga itu nak, dan bawa ke Altar persembahan di lantai 1... Waktu kita tidak banyak!"
	data.lines.append(line)

	return data

func _on_interacted(_interactor: Node) -> void:
	var sm = StoryGameManager.instance
	if sm and sm.current_mission != StoryGameManager.MissionStep.FIND_MBAH_RAMA:
		interactable.dialogue_data = _build_reminder_dialogue()
