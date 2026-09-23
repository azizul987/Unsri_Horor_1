# 🕯️ Dokumentasi Resmi HorrorDialogue (Godot 4.x)

**HorrorDialogue** adalah addon sistem dialog, narasi cerita batin (*internal monologue*), dan pembaca dokumen lore yang dirancang khusus untuk **Game 3D Survival Horror** (seperti *Unsri Horor*, *Kupu-Kupu Malam*, atau game horor retro ala PS1/analog horror).

Addon ini memberikan atmosfer mencekam secara instan dengan efek mesin ketik (*typewriter*), efek teks bergetar (*shaking text*), surat usang, pilihan respon pemain, serta integrasi otomatis ke pergerakan karakter 3D.

---

## 📑 Daftar Isi
1. [Fitur Utama](#-fitur-utama)
2. [Struktur Folder](#-struktur-folder)
3. [Cara Cepat Mengaktifkan Plugin](#-cara-cepat-mengaktifkan-plugin)
4. [Cara Penggunaan 1: Lewat Kode GDScript (Paling Cepat)](#-cara-penggunaan-1-lewat-kode-gdscript-paling-cepat)
5. [Cara Penggunaan 2: Memasang di Dunia 3D (Tanpa Kode)](#-cara-penggunaan-2-memasang-di-dunia-3d-tanpa-kode)
   - [A. Memicu Narasi Otomatis saat Masuk Ruangan (`DialogueTrigger3D`)](#a-memicu-narasi-otomatis-saat-masuk-ruangan-dialoguetrigger3d)
   - [B. Berbicara dengan NPC atau Membaca Surat (`DialogueInteractable3D`)](#b-berbicara-dengan-npc-atau-membaca-surat-dialogueinteractable3d)
6. [Cara Penggunaan 3: Menggunakan Custom Resource (.tres)](#-cara-penggunaan-3-menggunakan-custom-resource-tres)
7. [Efek Teks Horor BBCode](#-efek-teks-horor-bbcode)
8. [Integrasi dengan EasyInventory](#-integrasi-dengan-easyinventory)
9. [Daftar Kontrol Tombol Pemain](#-daftar-kontrol-tombol-pemain)
10. [API Reference & Sinyal Event](#-api-reference--sinyal-event)

---

## 💀 Fitur Utama

- 🖤 **Atmospheric Horror UI:**
  - Bar hitam sinematik atas-bawah (*Cinematic Letterbox*).
  - Kotak dialog semi-transparan dengan aksen merah darah dan bayangan gelap.
  - Efek mesin ketik (*typewriter reveal*) dengan jeda otomatis pada tanda baca (`.`, `,`, `!`, `?`, `…`) untuk menciptakan ketegangan.
- 🔊 **Built-in Procedural Audio:**
  - Dilengkapi generator audio prosedural internal untuk suara ketukan mesin ketik, kertas surat usang, dan glitch radio tanpa perlu mengimpor file audio `.wav` tambahan. (Tetap mendukung file suara kustom/voiceover jika Anda memilikinya).
- 📜 **Horror Note & Lore Reader:**
  - Antarmuka khusus untuk membaca surat berdarah, diary lusuh, atau kliping koran dengan latar gelap dan panel kertas vintage yang bisa di-scroll.
- 🔀 **Pilihan Respon & Percabangan (*Branching Choices*):**
  - Pemain bisa memilih respon menggunakan klik mouse atau langsung menekan angka keyboard `[1]`, `[2]`, `[3]`.
  - Pilihan bisa dikunci jika pemain belum memiliki item tertentu di Inventory.
- 🚶 **Integrasi Otomatis Karakter 3D:**
  - Saat dialog penting berlangsung, pergerakan karakter dan rotasi kamera mouse otomatis dibekukan (*freeze*) agar pemain fokus, lalu kembali normal secara mulus saat dialog berakhir.
  - Tersedia opsi mode subtitle jalan (*walk-and-talk*) di mana pemain tetap bisa berjalan sambil teks narasi muncul di bawah.
- 📦 **Node 3D Khusus Editor:**
  - `DialogueTrigger3D`: Area3D yang menyala ketika pemain melangkah masuk (misal: saat menginjak genangan darah atau masuk koridor baru).
  - `DialogueInteractable3D`: Area3D interaktif untuk NPC atau meja dokumen yang bisa ditekan tombol `[E]` untuk berinteraksi.

---

## 🏗️ Struktur Folder

```text
res://addons/horror_dialogue/
├── plugin.cfg                         # Konfigurasi plugin editor Godot
├── plugin.gd                          # Pendaftaran Autoload 'HorrorDialogue' & tipe node 3D
├── resources/
│   ├── dialogue_line.gd               # Resource data 1 baris kalimat dialog
│   ├── dialogue_choice.gd             # Resource opsi pilihan jawaban
│   └── dialogue_data.gd               # Resource urutan dialog utuh
├── core/
│   ├── horror_dialogue_manager.gd     # Singleton Autoload pengendali sistem
│   └── horror_audio_synth.gd          # Sintesis audio ketikan & kertas otomatis
├── ui/
│   ├── dialogue_box.gd                # Skrip pengendali visual kotak dialog & typewriter
│   ├── dialogue_box.tscn              # Scene CanvasLayer UI kotak dialog
│   ├── note_reader_ui.gd              # Skrip pengendali pembaca dokumen surat
│   └── note_reader_ui.tscn            # Scene CanvasLayer UI pembaca surat
├── 3d/
│   ├── dialogue_trigger_3d.gd         # Node Area3D trigger otomatis
│   └── dialogue_interactable_3d.gd    # Node Area3D interaksi tombol [E]
├── examples/
│   ├── demo_horror_scene.tscn         # 🎮 SCENE CONTOH 3D SIAP JALAN (F6)
│   ├── demo_hud.gd                    # HUD crosshair & prompt interaksi demo
│   ├── dialogues/
│   │   ├── intro_monologue.tres       # Contoh monolog batin awal permainan
│   │   └── npc_encounter.tres         # Contoh dialog NPC dengan 3 pilihan jawaban
│   └── notes/
│       └── sample_letter.tres         # Contoh catatan surat lore
└── README.md                          # Panduan resmi ini
```

---

## 🎮 Cara Menjalankan Scene Demo 3D Langsung

Addon ini sudah dilengkapi dengan **scene contoh 3D interaktif** (`demo_horror_scene.tscn`) yang langsung bisa Anda jalankan di Godot Editor:

1. Di panel *FileSystem*, buka folder:
   `res://addons/horror_dialogue/examples/demo_horror_scene.tscn`
2. Klik dua kali scene tersebut untuk membukanya.
3. Tekan tombol **`F6`** (Run Current Scene) di keyboard Anda.
4. **Di dalam game demo:**
   - **Maju ke depan (tombol W):** Anda akan melewati garis collider `DialogueTrigger3D` yang memicu monolog batin awal secara otomatis.
   - **Dekati meja kayu di sebelah kiri:** Arahkan pandangan dan tekan tombol **`[E]`** untuk membaca surat usang lantai 3.
   - **Dekati sosok bayangan merah di depan:** Arahkan pandangan dan tekan tombol **`[E]`** untuk mengobrol dan mencoba 3 pilihan respon dialog (bisa diklik dengan mouse atau tekan angka `1`, `2`, `3`).

---

## 🚀 Cara Cepat Mengaktifkan Plugin

1. Buka menu Godot: **Project -> Project Settings -> Plugins**.
2. Cari plugin **HorrorDialogue**, lalu centang **Enable**.
3. Selesai! Godot otomatis mendaftarkan singleton global dengan nama **`HorrorDialogue`**.

---

## 💻 Cara Penggunaan 1: Lewat Kode GDScript (Paling Cepat)

Anda bisa memanggil narasi atau dialog dari script manapun tanpa perlu setup yang rumit:

### 1. Monolog Batin Karakter (Pikiran Pemain)
```gdscript
# Panggil rangkaian pikiran batin pemain (otomatis berurutan):
HorrorDialogue.start_monologue([
    "Tempat apa ini? Hawanya terasa sangat dingin...",
    "Baunya persis seperti bangkai binatang.",
    "Pintunya terkunci dari luar. Aku harus mencari jalan lain!"
])
```

### 2. Membaca Surat / Diary / Dokumen Horor
```gdscript
# Membuka layar dokumen lore:
HorrorDialogue.show_note(
    "SURAT DARI KAMAR 302",
    "14 Oktober 1999\n\nJika kau membaca ini, jangan pernah dekati koridor barat setelah jam 12 malam.\n\nAmir sudah bukan manusia lagi...",
    "Penghuni Lantai 3"
)
```

### 3. Peringatan Singkat / Dialog 1 Baris
```gdscript
# Menampilkan 1 pesan dengan nama pembicara:
HorrorDialogue.start_simple_dialogue("Amir", "AKU TAHU KAU ADA DI SANA!", Color.RED)
```

---

## 🌐 Cara Penggunaan 2: Memasang di Dunia 3D (Tanpa Kode)

Addon ini menyediakan 2 node 3D siap pakai di editor scene:

### A. Memicu Narasi Otomatis saat Masuk Ruangan (`DialogueTrigger3D`)
Cocok untuk: jumpscare suara, monolog batin saat melangkah ke area berdarah, atau komentar saat melihat pintu terkunci.

1. Buka scene 3D Anda (misal `main.tscn`).
2. Klik kanan pada node parent -> **Add Child Node** -> Cari **`DialogueTrigger3D`**.
3. Tambahkan anak node **`CollisionShape3D`** ke dalam `DialogueTrigger3D` (pilih bentuk `BoxShape3D` dan atur ukurannya selebar pintu atau lorong).
4. Di panel Inspector `DialogueTrigger3D`:
   - Centang **Use Quick Monologue**: `true`.
   - Masukkan nama pembicara di **Quick Speaker Name** (misal: `"Aku"`).
   - Di bagian **Quick Lines**, klik *Add Element* lalu tulis kalimat-kalimat yang ingin diucapkan saat pemain lewat.
   - Atur **Trigger Once** = `true` (agar narasi tidak berulang-ulang setiap pemain lewat).

### B. Berbicara dengan NPC atau Membaca Surat (`DialogueInteractable3D`)
Cocok untuk: Berinteraksi dengan NPC, mayat, lemari misterius, atau kertas surat yang tergeletak di atas meja.

1. Tambahkan node **`DialogueInteractable3D`** sebagai child dari NPC atau meja catatan Anda.
2. Tambahkan **`CollisionShape3D`** (misal `SphereShape3D` dengan radius 2 meter).
3. **Untuk Objek Surat/Catatan:**
   - Centang **Is Note** = `true`.
   - Isi **Note Title** (misal: `"Kliping Koran Kuno"`).
   - Isi **Note Content** dengan isi teks lore cerita Anda.
4. **Untuk Objek NPC / Percakapan:**
   - Biarkan **Is Note** = `false`.
   - Masukkan file resource dialog ke slot **Dialogue Data** (misal: `res://addons/horror_dialogue/examples/dialogues/npc_encounter.tres`).
5. Pemain tinggal mendekati objek tersebut lalu menekan tombol **`[E]`**!

---

## 🎨 Efek Teks Horor BBCode

Karena kotak dialog menggunakan Godot `RichTextLabel` dengan BBCode aktif, Anda dapat memperkaya teks dengan efek horor bawaan:

| Kode BBCode | Tampilan Efek | Contoh Pemakaian |
| :--- | :--- | :--- |
| `[shake rate=25.0 level=8]teks[/shake]` | Teks bergetar panik/ketakutan | `"Ada [shake rate=30 level=10]sesuatu[/shake] di belakangku!"` |
| `[wave amp=40.0 freq=5.0]teks[/wave]` | Teks bergelombang seperti bisikan hantu | `"Dengarkan [wave amp=50 freq=4]bisikan[/wave] itu..."` |
| `[color=red]teks[/color]` | Teks berwarna merah darah | `"Darah ini... masih [color=red]hangat[/color]."` |
| `[fade start=4 length=14]teks[/fade]` | Teks memudar perlahan | `"[fade start=2 length=10]Tolong aku...[/fade]"` |
| `[rainbow]teks[/rainbow]` | Efek glitch aneh / halusinasi | `"[rainbow freq=0.5]Kenapa dunia ini berputar?[/rainbow]"` |

---

## 🎒 Integrasi dengan EasyInventory

Addon ini secara otomatis mengenali jika proyek Anda menggunakan **EasyInventory**:

Jika Anda membuat pilihan jawaban (`DialogueChoice`), Anda dapat mengisi kolom **`Required Item Id`** (misal: `"room_key"` atau `"biscuit_adha"`):
- Jika pemain memiliki item tersebut di Inventory, tombol pilihan akan aktif dan bisa dipilih.
- Jika pemain **belum** memiliki item tersebut, tombol pilihan akan otomatis dinonaktifkan (*disabled*) dan menampilkan keterangan *(Butuh Item)*.

---

## 🎮 Daftar Kontrol Tombol Pemain

| Aksi Pemain | Tombol Keyboard / Mouse | Keterangan |
| :--- | :--- | :--- |
| **Mempercepat Teks** | `Space` / `E` / `Enter` / `Klik Kiri` | Menyelesaikan animasi typewriter baris aktif seketika |
| **Lanjut ke Baris Berikutnya** | `Space` / `E` / `Enter` / `Klik Kiri` | Melangkah ke baris dialog berikutnya saat teks selesai diketik |
| **Pilih Opsi Respon (Mouse)** | Klik Kiri pada tombol opsi | Memilih jawaban yang diinginkan |
| **Pilih Opsi Respon (Keyboard)**| Tombol Angka `[1]`, `[2]`, `[3]`, dst. | Pintasan cepat tanpa perlu menyentuh mouse |
| **Tutup Catatan / Surat** | `E` atau `ESC` | Menutup tampilan dokumen dan kembali bergerak |

---

## 📡 API Reference & Sinyal Event

Singleton **`HorrorDialogue`** memancarkan sinyal yang bisa Anda hubungkan ke script pintu, monster, atau tata cahaya:

```gdscript
func _ready() -> void:
    # Terhubung ke sinyal dialog:
    HorrorDialogue.dialogue_started.connect(_on_dialogue_started)
    HorrorDialogue.dialogue_event_triggered.connect(_on_dialogue_event)
    HorrorDialogue.dialogue_finished.connect(_on_dialogue_finished)

func _on_dialogue_started(dialogue_id: String) -> void:
    print("Dialog dimulai: ", dialogue_id)

func _on_dialogue_event(event_name: String) -> void:
    # Memeriksa event khusus dari baris dialog atau pilihan:
    match event_name:
        "lampu_mati":
            # Matikan lampu rusun seketika!
            $SpotLight3D.visible = false
        "suara_teriakan":
            $AudioScream.play()
        "spawn_amir":
            # Munculkan monster Amir di ujung lorong!
            $NPCChaser.visible = true

func _on_dialogue_finished(dialogue_id: String) -> void:
    print("Dialog selesai: ", dialogue_id)
```

---

## 💡 Tips Tambahan untuk Game Horor
1. **Jeda Antara Kalimat**: Gunakan tanda titik tiga (`...`) atau titik (`.`) di akhir kalimat. Addon ini otomatis memberi jeda hening sejenak agar percakapan terasa lebih dingin dan mencekam.
2. **Kombinasikan dengan Trigger Ruangan**: Letakkan `DialogueTrigger3D` di depan pintu yang terkunci dengan monolog batin seperti: *"Gembok ini berkarat... aku butuh kunci berkarat untuk membukanya."* Pemain akan langsung paham tujuan gameplay tanpa perlu tutorial kaku!
