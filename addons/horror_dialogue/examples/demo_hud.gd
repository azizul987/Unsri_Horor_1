extends CanvasLayer

## HUD sederhana untuk scene demo Horror Dialogue
## Menampilkan crosshair titik, petunjuk tombol, dan prompt interaksi dinamis.

@onready var prompt_label: Label = $PromptLabel
@onready var crosshair: ColorRect = $Crosshair
@onready var guide_label: Label = $GuidePanel/MarginContainer/VBoxContainer/GuideText

func _ready() -> void:
	prompt_label.visible = false
	
	# Dengarkan interaksi dari semua node DialogueInteractable3D
	for node in get_tree().get_nodes_in_group(&"dialogue_interactable"):
		if node is DialogueInteractable3D:
			_connect_interactable(node)

	# Dengarkan jika ada interactable baru yang dimasukkan ke tree
	get_tree().node_added.connect(_on_node_added)

func _connect_interactable(interactable: DialogueInteractable3D) -> void:
	interactable.player_approached.connect(func(is_inside: bool):
		if is_inside:
			prompt_label.text = "[E] " + interactable.get_interaction_prompt()
			prompt_label.visible = true
		else:
			prompt_label.visible = false
	)

func _on_node_added(node: Node) -> void:
	if node is DialogueInteractable3D:
		_connect_interactable(node)

func _process(_delta: float) -> void:
	# Jika dialog atau catatan sedang aktif, sembunyikan prompt dan crosshair
	if Engine.has_singleton("HorrorDialogue"):
		var mgr = Engine.get_singleton("HorrorDialogue")
		if mgr.is_dialogue_active() or mgr.is_note_active():
			prompt_label.visible = false
			crosshair.visible = false
			return

	crosshair.visible = true
