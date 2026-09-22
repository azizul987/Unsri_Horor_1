class_name SaveSystem
extends Node

## Sistem penyimpanan (Save System) modular berbasis slot, key-value data store,
## dan auto-serializer Resource untuk Godot 4.x.
## Dapat langsung digunakan di berbagai project game tanpa perlu memodifikasi kode inti.

signal save_started(slot: int)
signal save_completed(slot: int)
signal load_started(slot: int)
signal load_completed(slot: int)
signal slot_changed(new_slot: int, old_slot: int)
signal slot_created(slot: int)
signal slot_deleted(slot: int)
signal autosaved(slot: int)

@export_group("Slot Configuration")
## Direktori tempat file save disimpan (misal: "user://saves/").
@export_dir var save_directory: String = "user://saves/"
## Format nama file slot (wajib berisi %d untuk nomor slot).
@export var file_prefix: String = "save_slot_%d.json"
## Slot default saat pertama kali dijalankan.
@export var default_slot: int = 1
## Batas maksimum slot yang ditampilkan (0 = tanpa batas).
@export var max_slots: int = 10

@export_group("Autosave")
## Mengaktifkan auto-save otomatis berkala.
@export var autosave_enabled: bool = false
## Interval waktu auto-save dalam detik.
@export_range(1.0, 3600.0, 1.0) var autosave_interval: float = 15.0

@export_group("Format & Security")
## Password enkripsi opsional. Jika diisi, file akan dienkripsi dengan password ini.
@export var encryption_password: String = ""
## Gunakan format JSON rapi (indentasi) untuk mempermudah inspect/debugging.
@export var pretty_json: bool = true

static var instance: SaveSystem

## Slot yang sedang aktif (-1 jika belum memilih slot).
var current_slot: int = -1

var _active_data: Dictionary = {}
var _active_metadata: Dictionary = {}
var _autosave_timer: Timer


func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	_ensure_save_directory()
	_setup_autosave_timer()

func _exit_tree() -> void:
	if instance == self:
		instance = null


## ============================================================================
## 1. SLOT MANAGEMENT
## ============================================================================

## Menentukan slot aktif untuk operasi save/load berikutnya.
func set_slot(slot: int) -> void:
	var old_slot: int = current_slot
	current_slot = slot
	slot_changed.emit(current_slot, old_slot)

## Mengembalikan nomor slot yang sedang aktif.
func get_slot() -> int:
	return current_slot

## Memeriksa apakah ada slot yang sedang aktif dipilih.
func has_active_slot() -> bool:
	return current_slot >= 1

## Mereset pilihan slot aktif (misal saat kembali ke Main Menu).
func clear_active_slot() -> void:
	current_slot = -1
	_active_data.clear()
	_active_metadata.clear()
	if _autosave_timer != null:
		_autosave_timer.stop()

## Mengembalikan path lengkap file save untuk nomor slot tertentu (atau slot aktif jika parameter -1).
func get_save_path(slot: int = -1) -> String:
	var target_slot: int = current_slot if slot < 0 else slot
	var base_dir: String = save_directory
	if not base_dir.ends_with("/"):
		base_dir += "/"
	return base_dir + (file_prefix % target_slot)

## Memeriksa apakah file save untuk nomor slot tertentu sudah ada di disk.
func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot))

## Mendapatkan daftar semua nomor slot yang sudah tersimpan di disk.
func get_all_used_slots() -> Array[int]:
	var slots: Array[int] = []
	_ensure_save_directory()
	var dir: DirAccess = DirAccess.open(save_directory)
	if dir == null:
		return slots

	var prefix_parts: PackedStringArray = file_prefix.split("%d")
	var prefix_start: String = prefix_parts[0]
	var prefix_end: String = prefix_parts[1] if prefix_parts.size() > 1 else ""

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.begins_with(prefix_start) and (prefix_end.is_empty() or file_name.ends_with(prefix_end)):
				var num_str: String = file_name.trim_prefix(prefix_start)
				if not prefix_end.is_empty():
					num_str = num_str.trim_suffix(prefix_end)
				if num_str.is_valid_int():
					slots.append(int(num_str))
		file_name = dir.get_next()
	dir.list_dir_end()
	slots.sort()
	return slots

## Mencari nomor slot terkecil yang masih kosong.
func get_next_available_slot() -> int:
	var used: Array[int] = get_all_used_slots()
	var next_slot: int = 1
	while used.has(next_slot):
		next_slot += 1
	return next_slot

## Membuat slot baru beserta metadata awalnya.
func create_slot(slot: int, slot_name: String = "", initial_data: Dictionary = {}) -> bool:
	if slot < 1:
		push_warning("SaveSystem: Nomor slot harus >= 1.")
		return false

	_ensure_save_directory()
	var path: String = get_save_path(slot)
	var final_name: String = slot_name if not slot_name.is_empty() else ("Slot %d" % slot)
	var now_unix: int = int(Time.get_unix_time_from_system())
	var now_str: String = Time.get_datetime_string_from_system(false, true)

	var meta: Dictionary = {
		"slot_id": slot,
		"slot_name": final_name,
		"created_at_unix": now_unix,
		"created_date_str": now_str,
		"saved_at_unix": now_unix,
		"saved_date_str": now_str
	}

	var payload: Dictionary = {
		"_metadata": meta,
		"data": initial_data
	}

	var file: FileAccess = _open_file(path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(payload, "\t" if pretty_json else ""))
	file.close()

	slot_created.emit(slot)
	return true

## Menghapus file save dari slot tertentu.
func delete_slot(slot: int) -> bool:
	var path: String = get_save_path(slot)
	if FileAccess.file_exists(path):
		var err: Error = DirAccess.remove_absolute(path)
		if err == OK:
			if slot == current_slot:
				clear_active_slot()
			slot_deleted.emit(slot)
			return true
	return false

## Menghapus semua slot save data yang ada di direktori save.
func delete_all_slots() -> void:
	stop_autosave()
	for s: int in get_all_used_slots():
		delete_slot(s)
	clear_active_slot()


## ============================================================================
## 2. METADATA MANAGEMENT
## ============================================================================

## Mengubah metadata pada session aktif saat ini (misal: "player_name", "progress_pct").
func set_metadata(key: String, value: Variant) -> void:
	_active_metadata[key] = SaveResourceSerializer.encode_variant(value)

## Mengambil metadata dari session aktif.
func get_metadata(key: String, default: Variant = null) -> Variant:
	if _active_metadata.has(key):
		return SaveResourceSerializer.decode_variant(_active_metadata[key])
	return default

## Membaca metadata dari sebuah slot di disk tanpa me-load seluruh data game-nya.
func get_slot_metadata(slot: int) -> Dictionary:
	var path: String = get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = _open_file(path, FileAccess.READ)
	if file == null:
		return {}

	var content: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if parsed is Dictionary:
		var dict: Dictionary = parsed as Dictionary
		if dict.has("_metadata") and dict["_metadata"] is Dictionary:
			return dict["_metadata"] as Dictionary
		return {
			"slot_id": slot,
			"slot_name": dict.get("slot_name", "Slot %d" % slot)
		}
	return {}

## Mengambil nama tampilan slot.
func get_slot_name(slot: int) -> String:
	var meta: Dictionary = get_slot_metadata(slot)
	return str(meta.get("slot_name", "Slot %d" % slot))

## Mengubah nama tampilan slot di disk.
func set_slot_name(slot: int, new_name: String) -> bool:
	var path: String = get_save_path(slot)
	if not FileAccess.file_exists(path):
		return false

	var file: FileAccess = _open_file(path, FileAccess.READ)
	if file == null:
		return false
	var content: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if not (parsed is Dictionary):
		return false

	var dict: Dictionary = parsed as Dictionary
	if dict.has("_metadata") and dict["_metadata"] is Dictionary:
		dict["_metadata"]["slot_name"] = new_name
	else:
		dict["slot_name"] = new_name

	var write_file: FileAccess = _open_file(path, FileAccess.WRITE)
	if write_file == null:
		return false
	write_file.store_string(JSON.stringify(dict, "\t" if pretty_json else ""))
	write_file.close()

	if slot == current_slot:
		_active_metadata["slot_name"] = new_name
	return true


## ============================================================================
## 3. KEY-VALUE DATA STORE
## ============================================================================

## Menyimpan nilai ke memori aktif dengan kunci tertentu.
func set_value(key: String, value: Variant) -> void:
	_active_data[key] = SaveResourceSerializer.encode_variant(value)

## Mengambil nilai dari memori aktif.
func get_value(key: String, default: Variant = null) -> Variant:
	if _active_data.has(key):
		return SaveResourceSerializer.decode_variant(_active_data[key])
	return default

## Memeriksa apakah kunci data ada di memori aktif.
func has_value(key: String) -> bool:
	return _active_data.has(key)

## Menghapus data dari memori aktif berdasarkan kuncinya.
func remove_value(key: String) -> void:
	_active_data.erase(key)

## Mengambil salinan seluruh data aktif dalam memori.
func get_all_data() -> Dictionary:
	return _active_data.duplicate(true)

## Mengosongkan data aktif dalam memori.
func clear_all_data() -> void:
	_active_data.clear()


## ============================================================================
## 4. GENERIC RESOURCE SERIALIZER API
## ============================================================================

## Menyimpan Resource tunggal ke dalam data aktif.
## Jika properties_to_save kosong, semua variabel @export akan otomatis disimpan.
func save_resource(key: String, resource: Resource, properties_to_save: PackedStringArray = []) -> void:
	if resource == null:
		return
	var res_data: Dictionary = SaveResourceSerializer.serialize_resource(resource, properties_to_save)
	_active_data[key] = res_data

## Memulihkan data Resource tunggal dari data aktif.
func load_resource(key: String, resource: Resource) -> void:
	if resource == null:
		return
	if _active_data.has(key) and _active_data[key] is Dictionary:
		SaveResourceSerializer.deserialize_resource(resource, _active_data[key] as Dictionary)

## Menyimpan koleksi Resource (Array of Resource) berdasarkan property identifier unik (seperti "id", "name").
func save_resource_collection(
	key: String,
	resources: Array,
	id_property: String = "id",
	properties_to_save: PackedStringArray = []
) -> void:
	var col_data: Dictionary = SaveResourceSerializer.serialize_resource_collection(
		resources,
		id_property,
		properties_to_save
	)
	_active_data[key] = col_data

## Memulihkan koleksi Resource (Array of Resource) dari data aktif.
func load_resource_collection(
	key: String,
	resources: Array,
	id_property: String = "id",
	reset_clean_fallback: bool = true
) -> void:
	if _active_data.has(key) and _active_data[key] is Dictionary:
		SaveResourceSerializer.deserialize_resource_collection(
			resources,
			_active_data[key] as Dictionary,
			id_property,
			reset_clean_fallback
		)


## ============================================================================
## 5. NODE GROUP API (Saveable Nodes)
## ============================================================================

## Menyimpan seluruh node dalam group tertentu (default "saveable").
## Setiap node yang mengimplementasikan get_save_data() -> Dictionary akan disimpan.
func save_nodes_in_group(group_name: String = "saveable") -> void:
	var nodes_data: Dictionary = {}
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	for node: Node in nodes:
		if node.has_method("get_save_data"):
			var key: String = str(node.get_path())
			nodes_data[key] = node.call("get_save_data")
	_active_data["_nodes_" + group_name] = nodes_data

## Memulihkan seluruh node dalam group tertentu.
## Node yang memiliki load_save_data(data: Dictionary) akan menerima kembali datanya.
func load_nodes_in_group(group_name: String = "saveable") -> void:
	var key: String = "_nodes_" + group_name
	if not _active_data.has(key) or not (_active_data[key] is Dictionary):
		return
	var nodes_data: Dictionary = _active_data[key] as Dictionary
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
	for node: Node in nodes:
		var node_key: String = str(node.get_path())
		if nodes_data.has(node_key) and node.has_method("load_save_data"):
			node.call("load_save_data", nodes_data[node_key])


## ============================================================================
## 6. FILE DISK I/O (SAVE & LOAD)
## ============================================================================

## Menulis seluruh memori aktif (metadata + data) ke file slot aktif di disk.
func save_game() -> bool:
	if current_slot < 1:
		push_warning("SaveSystem: Tidak dapat menyimpan, current_slot belum ditentukan.")
		return false

	save_started.emit(current_slot)
	_ensure_save_directory()

	var now_unix: int = int(Time.get_unix_time_from_system())
	var now_str: String = Time.get_datetime_string_from_system(false, true)

	_active_metadata["slot_id"] = current_slot
	_active_metadata["saved_at_unix"] = now_unix
	_active_metadata["saved_date_str"] = now_str
	if not _active_metadata.has("slot_name"):
		_active_metadata["slot_name"] = "Slot %d" % current_slot

	var payload: Dictionary = {
		"_metadata": _active_metadata,
		"data": _active_data
	}

	var path: String = get_save_path(current_slot)
	var file: FileAccess = _open_file(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: Gagal membuka file save untuk ditulis: %s" % path)
		return false

	file.store_string(JSON.stringify(payload, "\t" if pretty_json else ""))
	file.close()

	save_completed.emit(current_slot)
	return true

## Membaca file slot aktif dari disk ke dalam memori.
func load_game() -> bool:
	if current_slot < 1:
		push_warning("SaveSystem: Tidak dapat me-load, current_slot belum ditentukan.")
		return false

	var path: String = get_save_path(current_slot)
	if not FileAccess.file_exists(path):
		return false

	load_started.emit(current_slot)

	var file: FileAccess = _open_file(path, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: Gagal membaca file save: %s" % path)
		return false

	var content: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if not (parsed is Dictionary):
		push_error("SaveSystem: Isi file save bukan Dictionary valid: %s" % path)
		return false

	var dict: Dictionary = parsed as Dictionary
	if dict.has("data") and dict["data"] is Dictionary:
		_active_data = dict["data"] as Dictionary
		_active_metadata = dict.get("_metadata", {}) as Dictionary
	else:
		_active_data = dict
		_active_metadata = {}

	load_completed.emit(current_slot)
	return true


## ============================================================================
## 7. AUTOSAVE
## ============================================================================

## Mengaktifkan atau menonaktifkan auto-save.
func set_autosave_enabled(enabled: bool) -> void:
	autosave_enabled = enabled
	if _autosave_timer != null:
		if enabled and current_slot >= 1:
			_autosave_timer.start(autosave_interval)
		else:
			_autosave_timer.stop()

## Mengatur interval auto-save (dalam detik).
func set_autosave_interval(seconds: float) -> void:
	autosave_interval = maxf(1.0, seconds)
	if _autosave_timer != null:
		_autosave_timer.wait_time = autosave_interval
		if autosave_enabled and current_slot >= 1:
			_autosave_timer.start()

## Memulai timer auto-save secara eksplisit.
func start_autosave() -> void:
	set_autosave_enabled(true)

## Menghentikan timer auto-save.
func stop_autosave() -> void:
	set_autosave_enabled(false)


## ============================================================================
## 8. INTERNAL HELPERS
## ============================================================================

func _setup_autosave_timer() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.name = "AutosaveTimer"
	_autosave_timer.wait_time = autosave_interval
	_autosave_timer.one_shot = false
	_autosave_timer.autostart = false
	_autosave_timer.timeout.connect(_on_autosave_timeout)
	add_child(_autosave_timer)

func _on_autosave_timeout() -> void:
	if not autosave_enabled or current_slot < 1:
		return
	if not slot_exists(current_slot):
		return
	save_game()
	autosaved.emit(current_slot)

func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(save_directory):
		DirAccess.make_dir_recursive_absolute(save_directory)

func _open_file(path: String, mode: FileAccess.ModeFlags) -> FileAccess:
	if encryption_password.is_empty():
		return FileAccess.open(path, mode)
	return FileAccess.open_encrypted_with_pass(path, mode, encryption_password)
