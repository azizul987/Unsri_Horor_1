class_name SaveResourceSerializer
extends RefCounted

## Utility class untuk serialisasi dan deserialisasi Resource Godot 4 secara otomatis ke Dictionary/JSON.
## Menghilangkan keharusan menulis fungsi save/load manual untuk setiap Resource baru.

const EXCLUDED_PROPERTIES: PackedStringArray = [
	"resource_local_to_scene",
	"resource_path",
	"resource_name",
	"script",
	"metadata"
]

## Mengonversi tipe data bawaan Godot (Vector, Color, dll) menjadi bentuk yang aman disimpan ke JSON.
static func encode_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2:
			var v2: Vector2 = value as Vector2
			return {"__type__": "Vector2", "x": v2.x, "y": v2.y}
		TYPE_VECTOR2I:
			var v2i: Vector2i = value as Vector2i
			return {"__type__": "Vector2i", "x": v2i.x, "y": v2i.y}
		TYPE_VECTOR3:
			var v3: Vector3 = value as Vector3
			return {"__type__": "Vector3", "x": v3.x, "y": v3.y, "z": v3.z}
		TYPE_VECTOR3I:
			var v3i: Vector3i = value as Vector3i
			return {"__type__": "Vector3i", "x": v3i.x, "y": v3i.y, "z": v3i.z}
		TYPE_VECTOR4:
			var v4: Vector4 = value as Vector4
			return {"__type__": "Vector4", "x": v4.x, "y": v4.y, "z": v4.z, "w": v4.w}
		TYPE_VECTOR4I:
			var v4i: Vector4i = value as Vector4i
			return {"__type__": "Vector4i", "x": v4i.x, "y": v4i.y, "z": v4i.z, "w": v4i.w}
		TYPE_COLOR:
			var c: Color = value as Color
			return {"__type__": "Color", "r": c.r, "g": c.g, "b": c.b, "a": c.a}
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(value)
		TYPE_ARRAY:
			var encoded_array: Array = []
			for item in (value as Array):
				encoded_array.append(encode_variant(item))
			return encoded_array
		TYPE_DICTIONARY:
			var encoded_dict: Dictionary = {}
			var dict: Dictionary = value as Dictionary
			for k in dict.keys():
				encoded_dict[str(k)] = encode_variant(dict[k])
			return encoded_dict
		TYPE_OBJECT:
			if value is Resource:
				return serialize_resource(value as Resource)
			return null
		_:
			return value

## Mengembalikan representasi Dictionary/Array menjadi tipe data asli Godot (Vector, Color, dll).
static func decode_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var dict: Dictionary = value as Dictionary
		if dict.has("__type__"):
			match str(dict["__type__"]):
				"Vector2":
					return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
				"Vector2i":
					return Vector2i(int(dict.get("x", 0)), int(dict.get("y", 0)))
				"Vector3":
					return Vector3(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)), float(dict.get("z", 0.0)))
				"Vector3i":
					return Vector3i(int(dict.get("x", 0)), int(dict.get("y", 0)), int(dict.get("z", 0)))
				"Vector4":
					return Vector4(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)), float(dict.get("z", 0.0)), float(dict.get("w", 0.0)))
				"Vector4i":
					return Vector4i(int(dict.get("x", 0)), int(dict.get("y", 0)), int(dict.get("z", 0)), int(dict.get("w", 0)))
				"Color":
					return Color(float(dict.get("r", 0.0)), float(dict.get("g", 0.0)), float(dict.get("b", 0.0)), float(dict.get("a", 1.0)))

		var decoded_dict: Dictionary = {}
		for k in dict.keys():
			decoded_dict[k] = decode_variant(dict[k])
		return decoded_dict

	elif value is Array:
		var decoded_array: Array = []
		for item in (value as Array):
			decoded_array.append(decode_variant(item))
		return decoded_array

	return value

## Mendeteksi semua nama property yang layak disimpan dari sebuah Resource.
static func get_savable_property_names(
	resource: Resource,
	properties_to_exclude: PackedStringArray = []
) -> PackedStringArray:
	var result: PackedStringArray = []
	if resource == null:
		return result

	var prop_list: Array[Dictionary] = resource.get_property_list()
	for p: Dictionary in prop_list:
		var p_name: String = str(p.get("name", ""))
		var p_usage: int = int(p.get("usage", 0))
		var p_type: int = int(p.get("type", 0))

		if p_name.begins_with("_"):
			continue
		if EXCLUDED_PROPERTIES.has(p_name):
			continue
		if properties_to_exclude.has(p_name):
			continue

		var is_storage: bool = bool(p_usage & PROPERTY_USAGE_STORAGE)
		var is_script_var: bool = bool(p_usage & PROPERTY_USAGE_SCRIPT_VARIABLE)
		if not (is_storage or is_script_var):
			continue

		# Jangan simpan aset binary non-data seperti tekstur, suara, atau model 3D
		if p_type == TYPE_OBJECT:
			var val = resource.get(p_name)
			if val is Texture or val is AudioStream or val is Mesh or val is PackedScene:
				continue

		result.append(p_name)

	return result

## Mengisi property pada Resource secara aman dengan dukungan konversi tipe otomatis.
static func set_resource_property(resource: Resource, prop_name: String, raw_val: Variant) -> void:
	if resource == null:
		return

	var current_val = resource.get(prop_name)
	var decoded = decode_variant(raw_val)

	if current_val is Vector2 and decoded is Dictionary:
		var d: Dictionary = decoded as Dictionary
		resource.set(prop_name, Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0))))
	elif current_val is Vector2i and decoded is Dictionary:
		var d: Dictionary = decoded as Dictionary
		resource.set(prop_name, Vector2i(int(d.get("x", 0)), int(d.get("y", 0))))
	elif current_val is Vector3 and decoded is Dictionary:
		var d: Dictionary = decoded as Dictionary
		resource.set(prop_name, Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0))))
	elif current_val is Vector3i and decoded is Dictionary:
		var d: Dictionary = decoded as Dictionary
		resource.set(prop_name, Vector3i(int(d.get("x", 0)), int(d.get("y", 0)), int(d.get("z", 0))))
	elif current_val is Color and decoded is Dictionary:
		var d: Dictionary = decoded as Dictionary
		resource.set(prop_name, Color(float(d.get("r", 0.0)), float(d.get("g", 0.0)), float(d.get("b", 0.0)), float(d.get("a", 1.0))))
	elif current_val is int and decoded is float:
		resource.set(prop_name, int(decoded))
	elif current_val is float and decoded is int:
		resource.set(prop_name, float(decoded))
	else:
		resource.set(prop_name, decoded)

## Mengekstrak data dari sebuah Resource menjadi Dictionary yang siap disimpan.
static func serialize_resource(
	resource: Resource,
	properties_to_save: PackedStringArray = [],
	properties_to_exclude: PackedStringArray = []
) -> Dictionary:
	var data: Dictionary = {}
	if resource == null:
		return data

	var target_props: PackedStringArray = properties_to_save
	if target_props.is_empty():
		target_props = get_savable_property_names(resource, properties_to_exclude)

	for p_name: String in target_props:
		var val = resource.get(p_name)
		data[p_name] = encode_variant(val)

	return data

## Memulihkan data Dictionary ke dalam Resource target.
static func deserialize_resource(resource: Resource, data: Dictionary) -> void:
	if resource == null or data.is_empty():
		return

	for p_name: String in data.keys():
		set_resource_property(resource, p_name, data[p_name])

## Menyimpan daftar Resource (Array of Resource) berdasarkan property identifier unik (seperti "id", "name", dsb).
static func serialize_resource_collection(
	resources: Array,
	id_property: String = "id",
	properties_to_save: PackedStringArray = [],
	properties_to_exclude: PackedStringArray = []
) -> Dictionary:
	var result: Dictionary = {}
	for item in resources:
		if not (item is Resource):
			continue
		var res: Resource = item as Resource
		var id_val = res.get(id_property)
		if id_val == null:
			continue
		var id_str: String = str(id_val)
		result[id_str] = serialize_resource(res, properties_to_save, properties_to_exclude)
	return result

## Memulihkan daftar Resource (Array of Resource) dari data yang tersimpan.
## Jika reset_clean_fallback bernilai true, resource yang tidak ditemukan di save data
## akan dikembalikan ke nilai awal file .tres agar tidak terkontaminasi perubahan runtime.
static func deserialize_resource_collection(
	resources: Array,
	saved_data: Dictionary,
	id_property: String = "id",
	reset_clean_fallback: bool = true
) -> void:
	if saved_data.is_empty() and not reset_clean_fallback:
		return

	for item in resources:
		if not (item is Resource):
			continue
		var res: Resource = item as Resource
		var id_val = res.get(id_property)
		if id_val == null:
			continue
		var id_str: String = str(id_val)

		if saved_data.has(id_str):
			var item_data: Variant = saved_data[id_str]
			if item_data is Dictionary:
				deserialize_resource(res, item_data as Dictionary)
		elif reset_clean_fallback and not res.resource_path.is_empty():
			var clean_res: Resource = ResourceLoader.load(
				res.resource_path,
				"",
				ResourceLoader.CACHE_MODE_IGNORE
			)
			if clean_res != null:
				var clean_props: PackedStringArray = get_savable_property_names(clean_res)
				for p: String in clean_props:
					res.set(p, clean_res.get(p))
