class_name InventorySlotUI
extends PanelContainer

## Komponen visual satu slot inventory.
## Menampilkan icon 2D jika tersedia, atau nama item sebagai teks.

@export var slot_index: int = 0

var icon_rect: TextureRect
var fallback_name_label: Label
var count_label: Label
var key_label: Label

var _is_selected: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(68, 68)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_setup_nodes()
	_update_style()

func _setup_nodes() -> void:
	# Margin container
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	add_child(margin)

	# Icon 2D (jika item punya icon texture)
	icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.visible = false
	margin.add_child(icon_rect)

	# Label nama item teks
	fallback_name_label = Label.new()
	fallback_name_label.name = "FallbackNameLabel"
	fallback_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fallback_name_label.add_theme_font_size_override("font_size", 10)
	fallback_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 1.0))
	fallback_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fallback_name_label.visible = false
	margin.add_child(fallback_name_label)

	# Hotkey label (pojok kiri atas)
	key_label = Label.new()
	key_label.name = "KeyLabel"
	key_label.text = str(slot_index + 1)
	key_label.add_theme_font_size_override("font_size", 11)
	key_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	key_label.position = Vector2(5, 3)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(key_label)

	# Quantity label (pojok kanan bawah)
	count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 13)
	count_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 1.0))
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count_label.offset_left = -28
	count_label.offset_top = -20
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(count_label)

## Mengupdate tampilan slot dari InventorySlotData
func update_slot_display(slot_data: InventorySlotData, is_selected_slot: bool) -> void:
	_is_selected = is_selected_slot

	if key_label:
		key_label.text = str(slot_index + 1)

	if slot_data == null or slot_data.is_empty():
		_show_empty()
	else:
		_show_item(slot_data)

	_update_style()

func _show_empty() -> void:
	if icon_rect:
		icon_rect.texture = null
		icon_rect.visible = false
	if fallback_name_label:
		fallback_name_label.text = ""
		fallback_name_label.visible = false
	if count_label:
		count_label.text = ""

func _show_item(slot_data: InventorySlotData) -> void:
	var item: ItemData = slot_data.item_data

	if count_label:
		count_label.text = str(slot_data.quantity) if slot_data.quantity > 1 else ""

	if item.icon != null:
		if icon_rect:
			icon_rect.texture = item.icon
			icon_rect.visible = true
		if fallback_name_label:
			fallback_name_label.visible = false
	else:
		if icon_rect:
			icon_rect.texture = null
			icon_rect.visible = false
		if fallback_name_label:
			fallback_name_label.text = item.name
			fallback_name_label.visible = true

func _update_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5

	if _is_selected:
		style.bg_color = Color(0.18, 0.08, 0.08, 0.9)
		style.border_color = Color(0.9, 0.35, 0.25, 1.0)
		style.set_border_width_all(2)
		if key_label:
			key_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3, 1.0))
	else:
		style.bg_color = Color(0.05, 0.05, 0.05, 0.65)
		style.border_color = Color(0.3, 0.3, 0.3, 0.45)
		style.set_border_width_all(1)
		if key_label:
			key_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.6))

	add_theme_stylebox_override("panel", style)
