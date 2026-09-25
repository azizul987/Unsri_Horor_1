extends Node

## ============================================================================
## 🔊 HORROR SOUND MANAGER (AUTOLOAD ADDON)
## ============================================================================
## Mengelola audio global untuk game horor:
## - 3D Positional Audio (Pintu, Patah Tulang, Kepakan Sayap, Bunga)
## - 2D Audio (Jumpscare, Stinger, UI)
## - Ambience & BGM Crossfading
## - Otomatis mendeteksi file audio di res://Asset/Audio/
## ============================================================================

static var instance: Node = null

const AUDIO_DIR = "res://Asset/Audio/"

## Library pemetaan nama suara ke file audio
var sound_library: Dictionary = {
	"door_bang": "res://Asset/Audio/sfx_door_bang.wav",
	"door_open": "res://Asset/Audio/sfx_door_open.wav",
	"door_close": "res://Asset/Audio/sfx_door_close.wav",
	"door_locked": "res://Asset/Audio/sfx_door_locked.wav",
	"bone_crack": "res://Asset/Audio/sfx_bone_crack.wav",
	"amir_gasp": "res://Asset/Audio/sfx_amir_gasp.wav",
	"moth_flap": "res://Asset/Audio/sfx_moth_flap.wav",
	"moth_loop": "res://Asset/Audio/sfx_moth_loop.wav",
	"flower_bell": "res://Asset/Audio/sfx_flower_bell.wav",
	"jumpscare_hit": "res://Asset/Audio/sfx_jumpscare_hit.wav",
	"monster_screech": "res://Asset/Audio/sfx_monster_screech.wav",
	"forest_fire": "res://Asset/Audio/sfx_forest_fire.wav",
	"creepy_rattle": "res://Asset/Audio/sfx_creepy_rattle.wav",
	"horror_scream": "res://Asset/Audio/sfx_horror_scream.wav",
	"ambience_drone": "res://Asset/Audio/ambience_rusun_drone.wav",
	"bgm_tomb": "res://Arya of Terror - FREE Horror Soundtracks Vol. 1/2021_HSV1_Tomb_of_the_Forgotten.wav"
}

# Pemutar musik dan ambience global
var _bgm_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer

# Cache resource audio
var _loaded_streams: Dictionary = {}

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Siapkan channel BGM & Ambience
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = &"Master"
	add_child(_bgm_player)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	_ambience_player.bus = &"Master"
	add_child(_ambience_player)

func _exit_tree() -> void:
	if instance == self:
		instance = null

# ============================================================================
# 🎯 3D POSITIONAL SFX (PINTU, MONSTER, BUNGA, TULANG PATAH)
# ============================================================================

## Memutar suara 3D di koordinat global tertentu dan otomatis dibersihkan saat selesai
func play_sfx_3d(sound: Variant, global_pos: Vector3, max_dist: float = 25.0, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer3D:
	var stream: AudioStream = _resolve_stream(sound)
	if stream == null:
		return null

	var player = AudioStreamPlayer3D.new()
	player.stream = stream
	player.global_position = global_pos
	player.max_distance = max_dist
	player.unit_size = 3.5
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.attenuation_filter_cutoff_hz = 6000.0

	# Tambahkan ke root scene agar tidak terhapus jika node pemanggil hilang
	var target_parent = get_tree().current_scene if get_tree().current_scene else self
	target_parent.add_child(player)

	player.play()
	player.finished.connect(player.queue_free)
	return player

# ============================================================================
# 🔊 2D GLOBAL SFX (JUMPSCARE, UI, STINGER)
# ============================================================================

## Memutar suara 2D global tanpa posisi (jumpscare atau klik)
func play_sfx_2d(sound: Variant, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var stream: AudioStream = _resolve_stream(sound)
	if stream == null:
		return null

	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	add_child(player)

	player.play()
	player.finished.connect(player.queue_free)
	return player

## Memainkan jumpscare mendadak (mengecilkan BGM sementara lalu memulihkannya)
func play_jumpscare(sound: Variant = "jumpscare_hit", duck_duration: float = 2.5) -> void:
	play_sfx_2d(sound, 3.0)

	# Redam BGM sejenak (ducking)
	if _bgm_player.playing:
		var current_vol: float = _bgm_player.volume_db
		var tween = create_tween()
		tween.tween_property(_bgm_player, ^"volume_db", current_vol - 18.0, 0.1)
		tween.tween_interval(duck_duration)
		tween.tween_property(_bgm_player, ^"volume_db", current_vol, 1.2)

# ============================================================================
# 🎶 BGM & AMBIENCE CONTROLLER
# ============================================================================

func play_ambience(sound: Variant = "ambience_drone", fade_in: float = 2.0, target_vol: float = 0.0) -> void:
	var stream: AudioStream = _resolve_stream(sound)
	if stream == null:
		return

	if _ambience_player.playing and _ambience_player.stream == stream:
		return

	var tween = create_tween()
	if _ambience_player.playing:
		tween.tween_property(_ambience_player, ^"volume_db", -40.0, fade_in * 0.5)

	tween.tween_callback(func():
		_ambience_player.stream = stream
		_ambience_player.volume_db = -40.0
		_ambience_player.play()
	)
	tween.tween_property(_ambience_player, ^"volume_db", target_vol, fade_in)

func stop_ambience(fade_out: float = 2.0) -> void:
	if not _ambience_player.playing:
		return
	var tween = create_tween()
	tween.tween_property(_ambience_player, ^"volume_db", -40.0, fade_out)
	tween.tween_callback(_ambience_player.stop)

func play_music(sound: Variant = "bgm_tomb", fade_in: float = 2.0, target_vol: float = -6.0) -> void:
	var stream: AudioStream = _resolve_stream(sound)
	if stream == null:
		return

	if _bgm_player.playing and _bgm_player.stream == stream:
		return

	var tween = create_tween()
	if _bgm_player.playing:
		tween.tween_property(_bgm_player, ^"volume_db", -40.0, fade_in * 0.5)

	tween.tween_callback(func():
		_bgm_player.stream = stream
		_bgm_player.volume_db = -40.0
		_bgm_player.play()
	)
	tween.tween_property(_bgm_player, ^"volume_db", target_vol, fade_in)

func stop_music(fade_out: float = 2.0) -> void:
	if not _bgm_player.playing:
		return
	var tween = create_tween()
	tween.tween_property(_bgm_player, ^"volume_db", -40.0, fade_out)
	tween.tween_callback(_bgm_player.stop)

# ============================================================================
# 🔍 RESOLVER & PROCEDURAL FALLBACK
# ============================================================================

func _resolve_stream(sound: Variant) -> AudioStream:
	if sound is AudioStream:
		return sound

	if sound is String:
		# Cek apakah nama terdaftar di library
		var path: String = sound_library.get(sound, sound)

		# Cek cache
		if _loaded_streams.has(path):
			return _loaded_streams[path]

		# Cek apakah file ada di disk
		if ResourceLoader.exists(path):
			var res = load(path) as AudioStream
			if res:
				_loaded_streams[path] = res
				return res

		# Coba cari di folder Asset/Audio/
		var fallback_path = AUDIO_DIR + sound + ".wav"
		if ResourceLoader.exists(fallback_path):
			var res = load(fallback_path) as AudioStream
			if res:
				_loaded_streams[fallback_path] = res
				return res

		var fallback_mp3 = AUDIO_DIR + sound + ".mp3"
		if ResourceLoader.exists(fallback_mp3):
			var res = load(fallback_mp3) as AudioStream
			if res:
				_loaded_streams[fallback_mp3] = res
				return res

		# Fallback ke nada sintetis prosedural jika file belum ada
		return _generate_fallback_sfx(sound)

	return null

## Menghasilkan nada prosedural darurat agar game tidak crash jika ada audio yang belum ada
func _generate_fallback_sfx(sound_name: String) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.2
	var freq: float = 440.0

	if "door" in sound_name:
		freq = 120.0
		duration = 0.35
	elif "bone" in sound_name:
		freq = 250.0
		duration = 0.15
	elif "bell" in sound_name or "chime" in sound_name:
		freq = 880.0
		duration = 0.5
	elif "jumpscare" in sound_name:
		freq = 80.0
		duration = 0.8

	var sample_count: int = int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	for i in range(sample_count):
		var t: float = float(i) / float(sample_rate)
		var progress: float = float(i) / float(sample_count)
		var envelope: float = (1.0 - progress) * (1.0 - progress)
		var sample_val: float = sin(t * TAU * freq) * envelope
		var val_s16: int = clampi(int(sample_val * 20000.0), -32768, 32767)
		bytes.encode_s16(i * 2, val_s16)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream
