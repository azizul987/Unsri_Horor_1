class_name DialogueChoice
extends Resource

## Resource untuk opsi pilihan jawaban percabangan dialog horor.

## Teks yang ditampilkan pada tombol pilihan (misal: "Tanyakan tentang kunci kamar")
@export var text: String = "Pilihan..."

## Dialog lanjutan jika pilihan ini dipilih (opsional)
@export var next_dialogue: Resource = null

## ID item yang dibutuhkan dari Inventory agar pilihan ini bisa dipilih (opsional)
@export var required_item_id: String = ""

## Teks penjelas jika pemain belum memiliki item yang dibutuhkan
@export var locked_hint: String = "(Membutuhkan Item)"

## Nama event sinyal yang dipancarkan saat pilihan ini diklik (misal: "give_key", "trigger_jumpscare")
@export var trigger_event: String = ""
