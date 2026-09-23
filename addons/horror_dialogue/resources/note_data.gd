class_name NoteData
extends Resource

## Resource untuk dokumen, surat usang, kliping berita, atau catatan diary horor.

## Judul dokumen yang muncul di bagian atas kertas
@export var title: String = "Catatan Misterius"

## Nama penulis atau tanggal surat (opsional, misal: "12 Oktober 1999" atau "Penghuni Kamar 302")
@export var author: String = ""

## Isi teks catatan lore. Mendukung BBCode Godot seperti [b]tebal[/b], [i]miring[/i], dan [color=red]warna[/color].
@export_multiline var content: String = ""
