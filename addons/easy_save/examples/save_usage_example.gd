class_name SaveUsageExample
extends Node

## Contoh implementasi penggunaan addon EasySave pada sebuah scene gameplay atau UI.
## File ini dapat dijadikan referensi saat kamu memasang addon ini di project lain.

func _ready() -> void:
	# Hubungkan sinyal jika ingin menampilkan notifikasi di UI (misal: ikon "Saving...")
	SaveSystem.save_started.connect(_on_save_started)
	SaveSystem.save_completed.connect(_on_save_completed)


## Contoh alur saat memulai game dari Main Menu:
func demo_start_game(slot_id: int) -> void:
	# 1. Pilih slot
	SaveSystem.set_slot(slot_id)

	# 2. Jika slot belum ada di disk, buat slot baru
	if not SaveSystem.slot_exists(slot_id):
		SaveSystem.create_slot(slot_id, "Pemain Baru")

	# 3. Muat data dari file slot
	SaveSystem.load_game()

	# 4. Ambil data yang tersimpan (dengan fallback default jika data baru)
	var coins: int = int(SaveSystem.get_value("coins", 100))
	var player_name: String = str(SaveSystem.get_value("player_name", "Hero"))
	print("Game dimuat! Nama:", player_name, "Koin:", coins)

	# 5. Aktifkan auto-save berkala saat bermain
	SaveSystem.set_autosave_enabled(true)


## Contoh alur saat menyimpan game di tengah permainan (checkpoint / tombol save):
func demo_save_checkpoint(current_coins: int, inventory_items: Array) -> void:
	# 1. Simpan variabel bebas (Key-Value)
	SaveSystem.set_value("coins", current_coins)
	SaveSystem.set_value("last_checkpoint_pos", Vector3(10.0, 0.0, -5.0))

	# 2. Simpan Resource collection (misal: daftar item inventory / upgrade / skill)
	# Cukup sebutkan property id-nya (misal "id" atau "item_name")
	if not inventory_items.is_empty():
		SaveSystem.save_resource_collection(
			"inventory",
			inventory_items,
			"id",
			["quantity", "durability", "is_equipped"]
		)

	# 3. Simpan semua node yang ada di scene (opsional, jika pakai group "saveable")
	SaveSystem.save_nodes_in_group("saveable")

	# 4. Tulis ke file disk!
	SaveSystem.save_game()


## Handler sinyal UI:
func _on_save_started(_slot: int) -> void:
	# Tampilkan animasi atau ikon "Menyimpan data..."
	pass

func _on_save_completed(_slot: int) -> void:
	# Sembunyikan ikon setelah selesai
	pass
