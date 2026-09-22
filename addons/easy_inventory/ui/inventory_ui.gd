class_name InventoryUI
extends CanvasLayer

## Tampilan visual HUD Inventory 4-slot untuk game Kupu-Kupu Malam.
## Mendukung navigasi tombol angka 1-4, scroll wheel, mouse click, serta panel info item.

@export_group("Input Settings")
## Tombol keyboard untuk menggunakan item yang dipilih (Default: F)
@export var use_item_key: Key = KEY_F
## Tombol keyboard untuk membuang item yang dipilih (Default: G)
@export var drop_item_key: Key = KEY_G
## Apakah mengizinkan scroll mouse untuk mengganti slot
@export var enable_mouse_scroll_selection: bool = true

@export_group("Appearance")
## Tampilkan nama dan deskripsi item saat dipilih
@export var show_item_info_panel: bool = true
## Durasi fade info panel (dalam detik)
@export var info_display_duration: float = 3.0

var root_control: Control
var slots_container: HBoxContainer
var info_panel: PanelContainer
var item_name_label: Label
var item_desc_label: Label
var slot_ui_nodes: Array[InventorySlotUI] = []

var _info_timer: float = 0.0
var _inventory_ref: InventoryManager

func _ready() -> void:
	layer = 10
	_build_ui_tree()
	_connect_to_inventory()

func _process(delta: float) -> void:
	if _info_timer > 0.0:
		_info_timer -= delta
		if _info_timer <= 0.0 and info_panel:
			var tween: Tween = create_tween()
			tween.tween_property(info_panel, "modulate:a", 0.0, 0.4)

func _unhandled_input(event: InputEvent) -> void:
	var inv: InventoryManager = _get_inventory()
	if inv == null:
		return

	# Navigasi Slot via Tombol Angka (1, 2, 3, 4, ...)
	if event is InputEventKey and event.pressed and not event.echo:
		var key_code: Key = event.keycode
		if key_code >= KEY_1 and key_code <= KEY_9:
			var pressed_slot: int = key_code - KEY_1
			if pressed_slot < inv.max_slots:
				inv.select_slot(pressed_slot)
				get_viewport().set_input_as_handled()
				return

		# Gunakan Item (F)
		if key_code == use_item_key:
			inv.use_selected_item()
			get_viewport().set_input_as_handled()
			return

		# Buang Item (G)
		if key_code == drop_item_key:
			_handle_drop_item(inv)
			get_viewport().set_input_as_handled()
			return

	# Navigasi Slot via Mouse Scroll Wheel
	if enable_mouse_scroll_selection and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			inv.select_prev_slot()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			inv.select_next_slot()
			get_viewport().set_input_as_handled()

func _build_ui_tree() -> void:
	root_control = Control.new()
	root_control.name = "InventoryRoot"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	# Container Utama di Bawah Tengah Layar
	var bottom_center: VBoxContainer = VBoxContainer.new()
	bottom_center.name = "BottomCenterLayout"
	bottom_center.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom_center.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_center.position = Vector2(-150, -140)
	bottom_center.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_center.add_theme_constant_override("separation", 8)
	bottom_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(bottom_center)

	# Info Panel (Nama & Deskripsi Item)
	if show_item_info_panel:
		info_panel = PanelContainer.new()
		info_panel.name = "ItemInfoPanel"
		info_panel.custom_minimum_size = Vector2(300, 0)
		info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var info_style: StyleBoxFlat = StyleBoxFlat.new()
		info_style.bg_color = Color(0.08, 0.08, 0.08, 0.8)
		info_style.border_color = Color(0.3, 0.3, 0.3, 0.6)
		info_style.set_border_width_all(1)
		info_style.corner_radius_top_left = 6
		info_style.corner_radius_top_right = 6
		info_style.corner_radius_bottom_left = 6
		info_style.corner_radius_bottom_right = 6
		info_panel.add_theme_stylebox_override("panel", info_style)

		var info_vbox: VBoxContainer = VBoxContainer.new()
		info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_vbox.add_theme_constant_override("separation", 2)

		var margin: MarginContainer = MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)

		item_name_label = Label.new()
		item_name_label.name = "ItemName"
		item_name_label.text = ""
		item_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_name_label.add_theme_font_size_override("font_size", 14)
		item_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6, 1.0))
		info_vbox.add_child(item_name_label)

		item_desc_label = Label.new()
		item_desc_label.name = "ItemDesc"
		item_desc_label.text = ""
		item_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_desc_label.add_theme_font_size_override("font_size", 11)
		item_desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 0.9))
		info_vbox.add_child(item_desc_label)

		margin.add_child(info_vbox)
		info_panel.add_child(margin)
		info_panel.modulate.a = 0.0
		bottom_center.add_child(info_panel)

	# Container Slot Inventory (Horisontal)
	slots_container = HBoxContainer.new()
	slots_container.name = "SlotsContainer"
	slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_container.add_theme_constant_override("separation", 10)
	slots_container.mouse_filter = Control.MOUSE_FILTER_PASS
	bottom_center.add_child(slots_container)

## Menghubungkan signal dari InventoryManager
func _connect_to_inventory() -> void:
	var inv: InventoryManager = _get_inventory()
	if inv == null:
		return

	inv.inventory_updated.connect(refresh_ui)
	inv.slot_selected.connect(_on_slot_selected)

	_create_slots(inv.max_slots)
	refresh_ui()

func _create_slots(count: int) -> void:
	for child in slots_container.get_children():
		child.queue_free()
	slot_ui_nodes.clear()

	for i in range(count):
		var slot_ui: InventorySlotUI = InventorySlotUI.new()
		slot_ui.slot_index = i
		slot_ui.gui_input.connect(_on_slot_gui_input.bind(i))
		slots_container.add_child(slot_ui)
		slot_ui_nodes.append(slot_ui)

## Merefresh seluruh tampilan slot
func refresh_ui() -> void:
	var inv: InventoryManager = _get_inventory()
	if inv == null:
		return

	if slot_ui_nodes.size() != inv.max_slots:
		_create_slots(inv.max_slots)

	for i in range(slot_ui_nodes.size()):
		var slot_data: InventorySlotData = inv.get_slot(i)
		var is_selected: bool = (i == inv.selected_slot_index)
		slot_ui_nodes[i].update_slot_display(slot_data, is_selected)

	_update_info_panel(inv.get_selected_item())

func _on_slot_selected(_slot_index: int) -> void:
	refresh_ui()

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var inv: InventoryManager = _get_inventory()
		if inv:
			inv.select_slot(index)

func _update_info_panel(selected_item: ItemData) -> void:
	if not show_item_info_panel or info_panel == null:
		return

	if selected_item == null:
		var tween: Tween = create_tween()
		tween.tween_property(info_panel, "modulate:a", 0.0, 0.2)
		return

	item_name_label.text = selected_item.name
	item_desc_label.text = selected_item.description

	var tween: Tween = create_tween()
	tween.tween_property(info_panel, "modulate:a", 1.0, 0.2)
	_info_timer = info_display_duration

func _handle_drop_item(inv: InventoryManager) -> void:
	var player_node: Node3D = _find_player_node()
	var drop_origin: Vector3 = Vector3.ZERO
	var drop_dir: Vector3 = Vector3.FORWARD

	if player_node != null:
		drop_origin = player_node.global_position
		drop_dir = -player_node.global_transform.basis.z

	inv.drop_selected_item(drop_origin, drop_dir)

func _find_player_node() -> Node3D:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("Player")
	if not nodes.is_empty() and nodes[0] is Node3D:
		return nodes[0] as Node3D
	return null

func _get_inventory() -> InventoryManager:
	if _inventory_ref != null and is_instance_valid(_inventory_ref):
		return _inventory_ref

	if Engine.has_singleton("Inventory"):
		_inventory_ref = Engine.get_singleton("Inventory") as InventoryManager
		return _inventory_ref

	if is_instance_valid(get_node_or_null("/root/Inventory")):
		_inventory_ref = get_node("/root/Inventory") as InventoryManager
		return _inventory_ref

	return null
