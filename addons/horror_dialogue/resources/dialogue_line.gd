class_name DialogueLine
extends Resource

## Resource untuk satu baris kalimat dialog, monolog, atau narasi horor.

## Nama karakter atau entitas yang sedang berbicara (misal: "Aku", "Amir", "Radio Rusak", "Suara Misterius")
@export var speaker_name: String = ""

## Warna teks nama pembicara pada kotak dialog UI
@export var speaker_color: Color = Color(0.9, 0.25, 0.25, 1.0) # Merah horor default

## Foto / avatar pembicara (opsional)
@export var speaker_avatar: Texture2D = null

## Teks dialog. Mendukung format BBCode Godot seperti:
## [shake rate=20.0 level=5]teks bergetar[/shake]
## [wave amp=50.0 freq=5.0]teks bergelombang[/wave]
## [color=red]teks merah darah[/color]
@export_multiline var text: String = ""

## Kecepatan efek mesin ketik (dalam detik per karakter).
## Standar: 0.035s. Makin besar makin lambat/menegangkan.
@export_range(0.005, 0.2, 0.005) var typing_speed: float = 0.035

## Apakah pergerakan & kamera pemain dibekukan selama baris ini aktif?
## Set ke false jika ingin dialog menjadi subtitle ambient sambil pemain tetap bisa berjalan.
@export var freeze_player: bool = true

## Suara pengisi suara (voiceover) atau efek suara horor saat baris ini muncul (opsional)
@export var voice_audio: AudioStream = null

## Suara ketikan custom khusus untuk baris ini (jika kosong, memakai suara ketik default)
@export var custom_typing_sound: AudioStream = null

## Nama event khusus yang dipancarkan saat baris ini dimulai (misal: "lampu_mati", "jumpscare_bayangan")
@export var event_signal: String = ""

## Daftar pilihan respon jika baris ini membutuhkan jawaban dari pemain (DialogueChoice)
@export var choices: Array[DialogueChoice] = []
