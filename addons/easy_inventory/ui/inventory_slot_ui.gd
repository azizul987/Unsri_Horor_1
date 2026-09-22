class_name InventorySlotUI
extends PanelContainer

## Komponen visual untuk satu kotak slot di HUD inventory.

@export var slot_index: int = 0

var icon_rect: TextureRect
var count_label: Label
var key_label: Label
var highlight_border: ReferenceRect

var _is_selected: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_setup_internal_nodes()
	_update_style()

func _setup_internal_nodes() -> void:
	# Jika node belum dibuat secara manual di scene, buat secara dinamis
	if get_node_or_null("Margin/Icon") != null:
		icon_rect = get_node("Margin/Icon") as TextureRect
		count_label = get_node_or_null("CountLabel") as Label
		key_label = get_node_or_null("KeyLabel") as Label
		return

	# Margin Container
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	# Icon Texture
	icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	margin.add_child(icon_rect)

	# Slot Hotkey Number Label (pojok kiri atas)
	key_label = Label.new()
	key_label.name = "KeyLabel"
	key_label.text = str(slot_index + 1)
	key_label.add_theme_font_size_override("font_size", 12)
	key_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
	key_label.position = Vector2(6, 4)
	add_child(key_label)

	# Quantity Label (pojok kanan bawah)
	count_label = Label.new()
	count_label.name = "CountLabel"
	count_label.text = ""
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 13)
	count_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 1.0))
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count_label.position = Vector2(36, 42)
	add_child(count_label)

## Mengupdate tampilan slot dari data InventorySlotData
func update_slot_display(slot_data: InventorySlotData, is_selected_slot: bool) -> void:
	_is_selected = is_selected_slot

	if key_label:
		key_label.text = str(slot_index + 1)

	if slot_data == null or slot_data.is_empty():
		if icon_rect:
			icon_rect.texture = null
		if count_label:
			count_label.text = ""
	else:
		if icon_rect:
			icon_rect.texture = slot_data.item_data.icon
		if count_label:
			count_label.text = str(slot_data.quantity) if slot_data.quantity > 1 else ""

	_update_style()

func _update_style() -> void:
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4

	if _is_selected:
		# Warna saat slot aktif dipilih (glow merah gelap/emas redup khas horor)
		style_box.bg_color = Color(0.18, 0.08, 0.08, 0.85)
		style_box.border_color = Color(0.9, 0.35, 0.25, 0.95)
		style_box.set_border_width_all(2)
		if key_label:
			key_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3, 1.0))
	else:
		# Warna saat tidak dipilih (hitam transparan minimalis)
		style_box.bg_color = Color(0.05, 0.05, 0.05, 0.6)
		style_box.border_color = Color(0.3, 0.3, 0.3, 0.4)
		style_box.set_border_width_all(1)
		if key_label:
			key_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.6))

	add_theme_stylebox_override("panel", style_box)
