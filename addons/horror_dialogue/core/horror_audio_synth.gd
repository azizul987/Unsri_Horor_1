class_name HorrorAudioSynth
extends RefCounted

## Utility penghasil audio prosedural untuk efek ketik mesin ketik, kertas, dan tensi horor
## tanpa ketergantungan pada file audio eksternal.

static var _cached_click: AudioStreamWAV = null
static var _cached_paper: AudioStreamWAV = null
static var _cached_glitch: AudioStreamWAV = null

## Menghasilkan suara ketukan mesin ketik / radio click atmosferik
static func get_typewriter_click() -> AudioStreamWAV:
	if _cached_click != null:
		return _cached_click

	var sample_rate: int = 22050
	var duration: float = 0.03 # 30 ms
	var sample_count: int = int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	for i in range(sample_count):
		var t: float = float(i) / float(sample_count)
		var envelope: float = (1.0 - t) * (1.0 - t) # Kurva decay cepat
		# Campuran noise mekanik + nada rendah perkusi
		var noise_val: float = randf_range(-0.4, 0.4)
		var thud: float = sin(t * 40.0) * 0.6
		var sample_val: float = (noise_val + thud) * envelope
		var val_s16: int = clampi(int(sample_val * 24000.0), -32768, 32767)
		bytes.encode_s16(i * 2, val_s16)

	_cached_click = AudioStreamWAV.new()
	_cached_click.format = AudioStreamWAV.FORMAT_16_BITS
	_cached_click.mix_rate = sample_rate
	_cached_click.stereo = false
	_cached_click.data = bytes
	return _cached_click

## Menghasilkan suara membuka/menutup kertas surat usang
static func get_paper_sound() -> AudioStreamWAV:
	if _cached_paper != null:
		return _cached_paper

	var sample_rate: int = 22050
	var duration: float = 0.12 # 120 ms
	var sample_count: int = int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	for i in range(sample_count):
		var t: float = float(i) / float(sample_count)
		var envelope: float = sin(t * PI) # Fade in lalu fade out lembut
		var sample_val: float = randf_range(-0.5, 0.5) * envelope * 0.6
		var val_s16: int = clampi(int(sample_val * 20000.0), -32768, 32767)
		bytes.encode_s16(i * 2, val_s16)

	_cached_paper = AudioStreamWAV.new()
	_cached_paper.format = AudioStreamWAV.FORMAT_16_BITS
	_cached_paper.mix_rate = sample_rate
	_cached_paper.stereo = false
	_cached_paper.data = bytes
	return _cached_paper

## Menghasilkan suara glitch / statis radio horor saat ada teks seram
static func get_glitch_sound() -> AudioStreamWAV:
	if _cached_glitch != null:
		return _cached_glitch

	var sample_rate: int = 22050
	var duration: float = 0.08
	var sample_count: int = int(sample_rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	for i in range(sample_count):
		var t: float = float(i) / float(sample_count)
		var envelope: float = (1.0 - t)
		var sample_val: float = (randf_range(-0.7, 0.7) + sin(t * 120.0) * 0.3) * envelope
		var val_s16: int = clampi(int(sample_val * 22000.0), -32768, 32767)
		bytes.encode_s16(i * 2, val_s16)

	_cached_glitch = AudioStreamWAV.new()
	_cached_glitch.format = AudioStreamWAV.FORMAT_16_BITS
	_cached_glitch.mix_rate = sample_rate
	_cached_glitch.stereo = false
	_cached_glitch.data = bytes
	return _cached_glitch
