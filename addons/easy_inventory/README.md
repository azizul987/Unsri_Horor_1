# 🎒 Dokumentasi Resmi EasyInventory (Godot 4.x)

Selamat datang di **EasyInventory**! Addon ini dirancang khusus untuk game bergenre **Survival Horror / Exploration** (seperti *Kupu-Kupu Malam*), di mana manajemen ruang terbatas (*slot-based*) dan fungsi mekanik benda menjadi kunci ketegangan permainan.

---

## 📑 Fitur Utama

- 📦 **Slot-Based Horror Inventory (Default 4 Slot):** Sesuai standar game survival horror, kapasitas inventory dibatasi untuk mencegah penimbunan barang (bisa diatur via Inspector).
- 🌸 **Mekanik Khusus 8 Bunga:** Mendukung identifikasi index bunga (1-8), sinyal perubahan jumlah bunga (`flower_count_changed`), dan parameter buff/perk pasif.
- 🍪 **Item Usable & Distraction System:** Mendukung item sekali pakai (baterai, obat, biskuit lempar) dengan konsumsi kuantitas otomatis.
- 🎯 **3D World Item Pickup (`ItemPickup3D`):** Node interaksi 3D dengan animasi melayang (*bobbing*) dan berputar (*rotation*) halus di dunia game.
- 🖥️ **Ready-to-use HUD UI (`InventoryUI`):** Tampilan HUD slot minimalis khas horor di bagian bawah layar dengan penomoran hotkey `[1]`, `[2]`, `[3]`, `[4]`, highlight slot aktif, panel info nama/deskripsi item, serta navigasi scroll mouse.
- 💾 **Plug & Play Serialization:** Fungsi bawaan `save_to_dictionary()` dan `load_from_dictionary()` yang kompatibel langsung dengan **EasySave**.

---

## 🏗️ Struktur Folder Addon

```text
res://addons/easy_inventory/
├── item_data.gd               # Resource class dasar semua item
├── inventory_slot_data.gd     # Data kuantitas & status tiap slot
├── inventory_manager.gd       # Singleton / Node pengelola inventory
├── item_pickup_3d.gd          # Komponen Area3D untuk objek pickup di dunia 3D
├── item_pickup_3d.tscn        # Preset scene pickup 3D siap pakai
├── ui/
│   ├── inventory_ui.gd        # Controller HUD, input keyboard 1-4, mouse wheel
│   ├── inventory_ui.tscn      # CanvasLayer HUD siap drag-and-drop
│   └── inventory_slot_ui.gd   # Komponen visual kotak per-slot
├── examples/
│   └── items/
│       ├── biscuit_adha.tres       # Contoh item distraction (Biskuit Adha)
│       ├── flashlight_battery.tres # Contoh item consumable (Baterai Senter)
│       ├── room_key.tres           # Contoh item key/kunci kamar
│       └── flower_01.tres          # Contoh Bunga 1 (Kuncup Putih)
├── plugin.cfg
├── plugin.gd
└── README.md
```

---

## 🚀 Cara Cepat Menggunakan (Quickstart)

### 1. Aktifkan Plugin
Buka **Project -> Project Settings -> Plugins** -> Centang status aktif untuk **EasyInventory**.
Addon ini otomatis mendaftarkan **`Inventory`** sebagai Autoload Singleton global.

### 2. Pasang UI HUD ke Level / Scene
Cukup drag-and-drop scene `res://addons/easy_inventory/ui/inventory_ui.tscn` ke dalam scene utama (`main.tscn`) atau scene level kamu.

### 3. Buat Item Baru (Custom Resource)
1. Di panel *FileSystem*, klik kanan -> **Create New -> Resource...**
2. Cari dan pilih **`ItemData`**.
3. Beri nama file, misal `biskuit_adha.tres`.
4. Atur properti di Inspector:
   - **ID:** `biscuit_adha`
   - **Name:** `Biskuit Adha`
   - **Description:** `Lempar untuk menghentikan Amir 3-5 detik.`
   - **Item Type:** `DISTRACTION`
   - **Max Stack:** `5`

### 4. Letakkan Item Pickup di Dunia 3D
1. Di scene 3D kamu, drag scene `res://addons/easy_inventory/item_pickup_3d.tscn` atau tambahkan node `ItemPickup3D`.
2. Di Inspector, masukkan file `.tres` item kamu ke slot **Item Data**.
3. Atur animasi melayang / berputar jika diinginkan.
4. Ketika interactor (Player) berinteraksi via raycast atau menyentuhnya, item otomatis masuk ke inventory!

---

## 🎮 Kontrol Default Pemain

| Aksi | Tombol Keyboard / Mouse | Keterangan |
| :--- | :--- | :--- |
| **Pilih Slot 1 – 4** | Angka `1`, `2`, `3`, `4` | Memilih slot aktif yang ingin digunakan/dipegang |
| **Ganti Slot Cepat** | Mouse Wheel Up / Down | Menggeser pilihan slot ke kiri/kanan |
| **Gunakan Item Aktif**| Tombol `F` | Memakai consumable (baterai, biskuit) atau memicu aksi item |
| **Buang Item ke Lantai** | Tombol `G` | Menjatuhkan 1 unit item yang dipilih ke depan kaki pemain |
| **Klik Slot UI** | Mouse Klik Kiri | Memilih slot langsung lewat kursor mouse |

---

## 💻 Contoh Kode Script (Integrasi dengan Player & Monster)

### A. Mengambil Bunga & Mendeteksi Agresivitas Amir
```gdscript
extends CharacterBody3D

func _ready() -> void:
	# Dengarkan sinyal saat jumlah bunga bertambah
	Inventory.flower_count_changed.connect(_on_flower_count_changed)

func _on_flower_count_changed(total_flowers: int) -> void:
	print("Pemain kini memegang: ", total_flowers, " bunga.")
	
	# Update fase AI Amir berdasarkan progres bunga
	if total_flowers >= 6:
		print("Amir Masuk FASE 3: Sangat Agresif!")
	elif total_flowers >= 3:
		print("Amir Masuk FASE 2: Patroli Koridor Aktif.")
	else:
		print("Amir FASE 1: Eksplorasi Aman.")
```

### B. Menangani Penggunaan Item (Misal: Lempar Biskuit atau Isi Baterai Senter)
```gdscript
extends CharacterBody3D

@export var flashlight: SpotLight3D

func _ready() -> void:
	Inventory.item_used.connect(_on_item_used)

func _on_item_used(item_data: ItemData, slot_index: int) -> void:
	match item_data.id:
		"biscuit_adha":
			_throw_biscuit_distraction()
		"battery":
			_recharge_flashlight(item_data.buff_value)

func _throw_biscuit_distraction() -> void:
	print("Melempar Biskuit Adha! Amir terpancing...")
	# Spawn proyektil biskuit di depan kamera

func _recharge_flashlight(amount: float) -> void:
	print("Baterai terisi sebesar: ", amount)
```

### C. Integrasi Interaksi Raycast Player ke Item Pickup
```gdscript
extends RayCast3D

func _process(_delta: float) -> void:
	if is_colliding():
		var collider: Object = get_collider()
		if collider is ItemPickup3D:
			# Tampilkan prompt interaksi di layar
			print(collider.get_interaction_prompt())
			
			# Jika menekan tombol interaksi E
			if Input.is_action_just_pressed("interact"):
				collider.interact(owner)
```

---

## 💾 Integrasi dengan EasySave

Simpan status inventory ke slot save hanya dengan satu baris:

```gdscript
# Saat Menyimpan Permainan
func save_game_state() -> void:
	var inventory_data: Dictionary = Inventory.save_to_dictionary()
	SaveSystem.set_value("player_inventory", inventory_data)
	SaveSystem.save_game(1)

# Saat Memuat Permainan
func load_game_state() -> void:
	var inventory_data: Dictionary = SaveSystem.get_value("player_inventory", {})
	if not inventory_data.is_empty():
		Inventory.load_from_dictionary(inventory_data)
```

---

## ⚙️ Referensi API `InventoryManager` (Autoload `Inventory`)

### Metode Utama:
- `add_item(item_data: ItemData, quantity: int = 1) -> bool`: Menambah item ke slot.
- `remove_item_at_slot(slot_index: int, quantity: int = 1) -> bool`: Mengurangi item di slot tertentu.
- `remove_item_by_id(item_id: String, quantity: int = 1) -> bool`: Menghapus item berdasarkan ID unik.
- `has_item(item_id: String, min_quantity: int = 1) -> bool`: Cek kepemilikan item.
- `get_item_count(item_id: String) -> int`: Menghitung total kuantitas item.
- `get_flower_count() -> int`: Menghitung berapa banyak bunga (1-8) yang saat ini dibawa.
- `has_flower(flower_index: int) -> bool`: Cek apakah bunga nomor tertentu sudah dipegang.
- `select_slot(slot_index: int) -> void`: Memilih slot tertentu (0 sampai `max_slots - 1`).
- `get_selected_item() -> ItemData`: Mendapatkan resource item di slot yang sedang aktif.
- `use_selected_item() -> void`: Memakai item yang dipilih.
- `drop_selected_item(origin: Vector3, forward: Vector3) -> void`: Membuang item aktif ke dunia 3D.
- `clear_inventory() -> void`: Mengosongkan seluruh slot.
