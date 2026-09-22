class_name ItemData
extends Resource

## Data resource dasar untuk semua item dalam game (Kupu-Kupu Malam).
## Mendukung consumable, perk pasif bunga, puzzle key, dan distraction item.

enum ItemType {
	MISC,
	CONSUMABLE,
	KEY,
	FLOWER,
	DISTRACTION,
	TOOL
}

@export_group("Basic Info")
## ID unik untuk identifikasi item (contoh: "biscuit_adha", "flower_01", "room_key")
@export var id: String = "item_id"
## Nama item yang ditampilkan di layar/HUD
@export var name: String = "Nama Item"
## Deskripsi detail atau lore item
@export_multiline var description: String = "Deskripsi item..."
## Icon yang ditampilkan pada slot inventory UI
@export var icon: Texture2D

@export_group("Item Properties")
## Kategori jenis item
@export var item_type: ItemType = ItemType.MISC
## Jumlah maksimal item dalam satu slot
@export_range(1, 99) var max_stack: int = 1
## Apakah item ini bisa digunakan (tombol Use / klik)
@export var is_usable: bool = true
## Apakah item ini bisa dibuang/dilepas ke lantai
@export var is_droppable: bool = true

@export_group("Flower Mechanic (Khusus 8 Bunga)")
## Index bunga (1 sampai 8). Beri nilai 0 jika bukan item bunga.
@export_range(0, 8) var flower_index: int = 0
## Identifier efek pasif bunga (misal: "distorsi_reducer", "heat_source", "flower_radar", dll)
@export var passive_buff_id: String = ""
## Nilai parameter efek pasif
@export var buff_value: float = 0.0

@export_group("World Mesh")
## PackedScene model 3D saat item dijatuhkan ke dunia (opsional)
@export var world_mesh_scene: PackedScene

@export_group("Custom Data")
## Properti tambahan dinamis jika dibutuhkan
@export var custom_properties: Dictionary = {}

## Mengecek apakah item ini merupakan salah satu dari 8 bunga mistis
func is_flower() -> bool:
	return item_type == ItemType.FLOWER or flower_index > 0
