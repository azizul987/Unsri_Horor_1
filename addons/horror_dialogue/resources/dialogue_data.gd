class_name DialogueData
extends Resource

## Resource kumpulan baris percakapan / narasi cerita horor utuh.

## ID unik untuk dialog ini (misal: "monolog_intro_kamar", "dialog_amir_koridor")
@export var dialogue_id: String = ""

## Urutan baris-baris percakapan yang akan dimainkan secara beruntun
@export var lines: Array[DialogueLine] = []

## Apakah percakapan ini bisa diulang kembali jika pemain memicu ulang?
## Jika false, trigger tidak akan menyala lagi setelah selesai pertama kali.
@export var repeatable: bool = true

## Nama event sinyal yang dipancarkan ke 'dialogue_event_triggered' setelah percakapan ini selesai seluruhnya
@export var on_finish_event: String = ""
