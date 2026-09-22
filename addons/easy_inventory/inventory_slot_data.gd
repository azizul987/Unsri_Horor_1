class_name InventorySlotData
extends Resource

## Data untuk satu slot di inventory, menyimpan referensi ItemData dan jumlah kuantitas.

@export var item_data: ItemData = null
@export var quantity: int = 0

## Mengecek apakah slot kosong
func is_empty() -> bool:
	return item_data == null or quantity <= 0

## Mengecek apakah slot dapat menerima penambahan kuantitas dari item tertentu
func can_stack_with(other_item: ItemData) -> bool:
	if is_empty():
		return true
	if item_data.id == other_item.id and quantity < item_data.max_stack:
		return true
	return false

## Mengosongkan data slot ini
func clear() -> void:
	item_data = null
	quantity = 0

## Menyimpan data slot ke Dictionary untuk sistem Save Game
func to_dict() -> Dictionary:
	if is_empty():
		return {}
	return {
		"item_id": item_data.id,
		"resource_path": item_data.resource_path,
		"quantity": quantity
	}

## Memuat data slot dari Dictionary
func from_dict(data: Dictionary) -> void:
	if data.is_empty() or not data.has("resource_path"):
		clear()
		return
	
	var res_path: String = data.get("resource_path", "")
	if ResourceLoader.exists(res_path):
		var loaded_res: Resource = load(res_path)
		if loaded_res is ItemData:
			item_data = loaded_res
			quantity = int(data.get("quantity", 1))
			return
	clear()
