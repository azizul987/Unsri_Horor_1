class_name FlowerAltar
extends Area3D

## Altar Persembahan 8 Bunga Kupu-Kupu Malam (UNSRI Horor).
## Terletak di halaman depan rusun / area terbuka.
## Tempat pemain meletakkan bunga yang ditemukan agar tas (4 slot) tidak penuh.
## Setelah 8 bunga terkumpul, pemain dapat menentukan nasib Amir (Ending 1: Sembuh atau Ending 2: Bakar).

signal flower_deposited(total_deposited: int)
signal ritual_ready
signal ritual_completed(is_cure: bool)

@export_group("Konfigurasi Altar")
@export var prompt_deposit: String = "Persembahkan Bunga ke Altar"
@export var prompt_ritual: String = "Mulai Ritual Akhir"

var _player_in_range: bool = false
var _hud_layer: CanvasLayer = null
var _hud_label: Label = null
var _altar_light: OmniLight3D = null

func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if HorrorDialogue:
		HorrorDialogue.dialogue_finished.connect(_on_dialogue_finished)

	_setup_hud()
	_setup_altar_light()

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return

	# Jangan proses interaksi jika dialog atau catatan sedang aktif di layar!
	if HorrorDialogue and (HorrorDialogue.is_dialogue_active() or HorrorDialogue.is_note_active()):
		return

	# Hanya tangani penekanan tombol E (jangan gunakan ui_accept agar tidak bentrok dengan tombol Space/Enter untuk lanjut dialog)
	var is_interact: bool = (
		event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E
	)

	if is_interact:
		interact()
		get_viewport().set_input_as_handled()

## Interaksi utama dengan Altar
func interact() -> void:
	# Sembunyikan prompt interaksi saat dialog terbuka agar layar bersih
	if _hud_label:
		_hud_label.visible = false

	var story = StoryManager if StoryManager else StoryGameManager.instance
	var current_dep: int = story.flowers_deposited if story else 0

	# 1. Jika 8 bunga sudah lengkap, picu Ritual Akhir
	if current_dep >= 8:
		_trigger_final_ritual_choice()
		return

	# 2. Cek apakah pemain membawa bunga di inventory
	var flowers_in_bag: int = 0
	if Inventory:
		for i in range(Inventory.slots.size()):
			var slot = Inventory.slots[i]
			if not slot.is_empty() and slot.item_data and slot.item_data.is_flower():
				flowers_in_bag += 1

	if flowers_in_bag > 0:
		# Pindahkan bunga dari tas ke Altar
		var transferred: int = 0
		if Inventory:
			for i in range(Inventory.slots.size()):
				var slot = Inventory.slots[i]
				if not slot.is_empty() and slot.item_data and slot.item_data.is_flower():
					Inventory.remove_item_at_slot(i, slot.quantity)
					transferred += 1

		if story:
			story.deposit_flower_to_altar(transferred)
			current_dep = story.flowers_deposited

		_pulse_altar_light()
		flower_deposited.emit(current_dep)

		# Mainkan audio lonceng / chime mistis via SoundManager
		if SoundManager and SoundManager.has_method("play_sfx_3d"):
			SoundManager.play_sfx_3d("flower_bell", global_position, 20.0)

		# Buka Kepingan Fakta Cerita sesuai urutan bunga (1 sampai 8)
		if HorrorDialogue:
			var fragment_lines: Array = _get_lore_fragment(current_dep)
			HorrorDialogue.start_monologue(fragment_lines, "ALTAR TANAH — KEPINGAN INGATAN")

		_update_hud()
	else:
		# Pemain tidak membawa bunga
		if HorrorDialogue:
			HorrorDialogue.start_monologue([
				"Altar tanah ini masih membutuhkan persembahan bunga kehidupan...",
				"Bunga terkumpul di altar: [b]%d / 8[/b]." % current_dep,
				"Cari sisa bunga di koridor rusun, dapur, kamar, atau area bekas kebakaran."
			], "ALTAR TANAH")

## Memulai pemilihan ending jika 8 bunga sudah lengkap
func _trigger_final_ritual_choice() -> void:
	if HorrorDialogue:
		# Pilihan interaktif melalui HorrorDialogue
		var line = DialogueLine.new()
		line.speaker_name = "RITUAL TERAKHIR"
		line.speaker_color = Color(1.0, 0.4, 0.2, 1.0)
		line.text = "Ke-8 bunga telah lengkap di atas altar. Amir yang bermutasi telah tiba di hadapanmu.\nApa yang akan kamu lakukan?"

		var choice_cure = DialogueChoice.new()
		choice_cure.text = "Lakukan Ritual Penyembuhan (Ending 1: Sembuh)"
		choice_cure.event_signal = "trigger_ending_cure"

		var choice_burn = DialogueChoice.new()
		choice_burn.text = "Bakar Altar dan Bunga Bersama Amir (Ending 2: Bakar)"
		choice_burn.event_signal = "trigger_ending_burn"

		line.choices = [choice_cure, choice_burn]

		var data = DialogueData.new()
		data.dialogue_id = "ritual_final_choice"
		data.lines = [line]

		HorrorDialogue.start_dialogue(data)

		# Hubungkan respons pilihan
		if not HorrorDialogue.dialogue_event_triggered.is_connected(_on_ritual_choice_selected):
			HorrorDialogue.dialogue_event_triggered.connect(_on_ritual_choice_selected)

func _on_ritual_choice_selected(event_name: String) -> void:
	var story = StoryManager if StoryManager else StoryGameManager.instance
	if event_name == "trigger_ending_cure":
		if story:
			story.play_ending(true)
		ritual_completed.emit(true)
	elif event_name == "trigger_ending_burn":
		if story:
			story.play_ending(false)
		ritual_completed.emit(false)

func _on_body_entered(body: Node3D) -> void:
	if body is Player or body.is_in_group(&"player"):
		_player_in_range = true
		_update_hud()

func _on_body_exited(body: Node3D) -> void:
	if body is Player or body.is_in_group(&"player"):
		_player_in_range = false
		if _hud_label:
			_hud_label.visible = false

func _on_dialogue_finished(_dialogue_id: String) -> void:
	if _player_in_range:
		_update_hud()

func _setup_altar_light() -> void:
	_altar_light = OmniLight3D.new()
	_altar_light.light_color = Color(0.3, 0.6, 1.0, 1.0)
	_altar_light.light_energy = 0.8
	_altar_light.omni_range = 5.0
	_altar_light.position = Vector3(0, 0.6, 0)
	add_child(_altar_light)

func _pulse_altar_light() -> void:
	if _altar_light == null:
		return
	var tween = create_tween()
	tween.tween_property(_altar_light, ^"light_energy", 2.5, 0.4)
	tween.tween_property(_altar_light, ^"light_energy", 0.8, 1.0)

func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 20

	_hud_label = Label.new()
	_hud_label.set_anchors_preset(Control.PRESET_CENTER)
	_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_label.offset_top = 40.0
	_hud_label.offset_bottom = 70.0
	_hud_label.offset_left = -250.0
	_hud_label.offset_right = 250.0
	_hud_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 1.0))
	_hud_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hud_label.add_theme_constant_override("shadow_offset_x", 1)
	_hud_label.add_theme_constant_override("shadow_offset_y", 1)
	_hud_label.add_theme_font_size_override("font_size", 15)
	_hud_label.visible = false

	_hud_layer.add_child(_hud_label)
	add_child(_hud_layer)

func _update_hud() -> void:
	if _hud_label == null or not _player_in_range:
		return

	var story = StoryManager if StoryManager else StoryGameManager.instance
	var dep: int = story.flowers_deposited if story else 0

	if dep >= 8:
		_hud_label.text = "[E] " + prompt_ritual + " (8/8 Bunga Lengkap)"
	else:
		_hud_label.text = "[E] " + prompt_deposit + " (%d/8)" % dep

	_hud_label.visible = true

func _get_lore_fragment(index: int) -> Array:
	match index:
		1:
			return [
				"[color=#ffd700]Kepingan Fakta I Terbuka:[/color]",
				"\"Malam itu ada bau asap menyengat dari arah rawa... kami kira cuma warga yang membakar sampah.\"",
				"Bunga di altar: [b]1 / 8[/b]."
			]
		2:
			return [
				"[color=#ffd700]Kepingan Fakta II Terbuka:[/color]",
				"\"Catatan tua rusun: Kupu-kupu malam rawa bukan serangga biasa... mereka terikat dengan tanah yang mereka huni.\"",
				"Bunga di altar: [b]2 / 8[/b]."
			]
		3:
			return [
				"[color=#ffd700]Kepingan Fakta III Terbuka:[/color]",
				"\"Peringatan: Jika ada yang terkena gigitannya, tubuhnya perlahan meminjam wujud mereka. Dia bukan lagi manusia sepenuhnya.\"",
				"Bunga di altar: [b]3 / 8[/b]."
			]
		4:
			return [
				"[color=#ffd700]Kepingan Fakta IV Terbuka (Pesan WhatsApp di HP):[/color]",
				"\"Woy, kalian kemarin malam ke mana sama Amir? Kok pas balik bajunya Amir bau bensin menyengat?!\"",
				"Bunga di altar: [b]4 / 8[/b]."
			]
		5:
			return [
				"[color=#ffd700]Kepingan Fakta V Terbuka (Rekaman Suara):[/color]",
				"\"Amir tertawa: 'Tenang aja bro... apinya gak bakal gede. Kita cuma main-main sebentar doang... gak ada yang tahu.'\"",
				"Bunga di altar: [b]5 / 8[/b]."
			]
		6:
			return [
				"[color=#ffd700]Kepingan Fakta VI Terbuka (Foto Galeri):[/color]",
				"Terlihat foto Amir memegang korek api dan botol minyak tanah di semak belukar sambil tersenyum jahil...",
				"Amir pelakunya! Dia yang menyulut api kebakaran hutan!",
				"Bunga di altar: [b]6 / 8[/b]."
			]
		7:
			return [
				"[color=#ffd700]Kepingan Fakta VII Terbuka (Video Bukti):[/color]",
				"Rekaman HP memperlihatkan dahan pohon meledak tersulut api, Amir tertawa lalu lari panik saat api tak terkendali!",
				"Amir tahu dialah penyebab koloni kupu-kupu punah, tapi menyembunyikannya dari semua orang!",
				"Bunga di altar: [b]7 / 8[/b]."
			]
		8:
			return [
				"[color=#ffd700]Kepingan Fakta Terakhir VIII (Peringatan Ritual):[/color]",
				"\"Kutukan ini menuntut tebusan. 8 bunga telah berkumpul. Kamu punya dua pilihan: kembalikan sisa jiwanya, atau bakar dia bersama dosa yang ia perbuat!\"",
				"Bunga di altar: [b]8 / 8[/b]. Altar siap untuk penentuan akhir!"
			]
		_:
			return [
				"[color=yellow]Kamu meletakkan bunga di atas lingkaran tanah altar.[/color]",
				"Bunga di altar: [b]%d / 8[/b]." % index
			]
