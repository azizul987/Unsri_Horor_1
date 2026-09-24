# 🔥 Petunjuk Efek Api Kebakaran Hutan (Forest Fire VFX)

Sistem efek api kebakaran hutan ini dibuat modular dengan **slot pohon kosong (`TreeSlot`)** sehingga Anda dapat bebas memasukkan model pohon (FBX, GLTF, `.tscn`, atau Mesh 3D) kapan saja Anda siap.

---

## 🌲 1. Cara Memasukkan Pohon Anda Nanti

Anda memiliki 2 cara mudah untuk memasukkan pohon ke dalam scene api ini:

### Cara A: Drag & Drop Langsung di Scene Tree (Paling Praktis)
1. Buka scene `res://Scenes/forest_fire_tree.tscn` (atau jadikan instance di dalam level / `main.tscn`).
2. Klik kanan pada node **`TreeSlot`**, lalu pilih **Add Child Node...** (atau langsung drag file model pohon 3D Anda dari panel *FileSystem* dan jatuhkan sebagai anak (*child*) di bawah node `TreeSlot`).
3. Selesai! Pohon Anda sekarang otomatis berada di tengah kobaran api.

### Cara B: Lewat Inspector (`Tree Scene`)
1. Pilih root node **`ForestFireTree`**.
2. Pada panel **Inspector** di sebelah kanan, cari grup **Pohon (Tree Slot)**.
3. Drag file scene pohon (`.tscn`) Anda ke slot **Tree Scene**.
4. Scene pohon akan otomatis di-spawn ke dalam `TreeSlot`.

> 💡 **Info Panduan Editor (Editor Preview):**
> Saat `TreeSlot` masih kosong, Anda akan melihat siluet transparan pohon (batang silinder & dedaunan bola) di 3D Editor untuk memudahkan Anda melihat posisi dan skala api. Panduan ini **otomatis disembunyikan** saat game dijalankan (*runtime*) atau saat Anda sudah memasukkan model pohon Anda sendiri.

---

## ⚙️ 2. Pengaturan Otomatis di Inspector

Root node `ForestFireTree` dilengkapi fitur dinamis `@tool` yang langsung menyesuaikan bentuk api di viewport 3D ketika Anda mengubah nilai di Inspector:

| Parameter | Fungsi |
|---|---|
| **`Tree Height`** | Mengatur ketinggian pohon (contoh: 6 meter). Mengubah nilai ini akan **otomatis menggeser posisi api dedaunan (kanopi), asal kepulan asap hitam, dan tinggi lampu** secara proporsional. |
| **`Trunk Radius`** | Mengatur radius ketebalan batang pohon agar sebaran api di pangkal membungkus pohon dengan pas. |
| **`Is Burning`** | Menyalakan / memadamkan seluruh sistem api, asap, bara, cahaya, dan suara. |
| **`Fire Intensity`** | Skala besar kobaran lidah api (0.1 = api kecil, 1.0 = normal, 2.5 = kebakaran dahsyat). |
| **`Smoke Density`** | Mengatur ketebalan dan skala kolom asap hitam yang membubung tinggi. |
| **`Wind Direction`** | Arah tiupan angin yang menggerakkan asap dan percikan bara melayang. |
| **`Enable Light`** | Menyalakan lampu api dengan efek goyangan alami (*fire flicker*). |
| **`Enable Heat Damage`** | Memberi efek damage panas berkala jika pemain terlalu dekat dengan pohon yang terbakar. |
| **`Fire Sound`** | Tempat menaruh file suara kobaran api / kayu terbakar (`AudioStream`). |

---

## 💻 3. Kontrol Lewat GDScript (Contoh Kode)

Jika dalam game Anda ingin memadamkan api, menyalakan api lewat event cerita, atau mendeteksi pemain terbakar:

```gdscript
# Mengambil referensi pohon
@onready var pohon_api: ForestFireTree = $ForestFireTree

func _ready() -> void:
    # Sambungkan sinyal saat pemain masuk ke zona panas
    pohon_api.player_entered_fire_zone.connect(_on_player_masuk_api)
    pohon_api.player_exited_fire_zone.connect(_on_player_keluar_api)

# Memadamkan api (misal kena hujan atau pemadam)
func padamkan_pohon():
    pohon_api.set_fire_active(false)

# Menyalakan api kembali
func nyalakan_pohon():
    pohon_api.set_fire_active(true)

# Mengubah tinggi pohon via script
func ubah_ukuran():
    pohon_api.tree_height = 8.0 # Otomatis update posisi partikel kanopi & asap

func _on_player_masuk_api(player: Node3D):
    print("Pemain terlalu dekat dengan pohon terbakar!")
```

---

## 📂 4. Daftar File yang Dibuat

1. **`res://Scenes/forest_fire_tree.tscn`**: Scene satu pohon terbakar (individual / hero tree).
2. **`res://Scenes/forest_fire_zone.tscn`**: Scene generator satu zona hutan terbakar (otomatis puluhan pohon).
3. **`res://Skrip/forest_fire_tree.gd`**: Skrip pengatur sistem api pohon, skala, flickering, dan slot pohon.
4. **`res://Skrip/forest_fire_zone.gd`**: Skrip generator zona hutan terbakar dengan optimasi performa.
5. **`res://Shaders/forest_fire_flame.gdshader`**: Shader lidah api berkobar dengan efek ombak api dan gradasi warna.
6. **`res://Shaders/forest_smoke.gdshader`**: Shader asap tebal khas kebakaran hutan dengan soft particles.
7. **`res://Shaders/forest_ember.gdshader`**: Shader percikan bara api (*embers/sparks*) dengan efek pendaran glow.

---

## 🌲🔥 5. Cara Membuat Satu Hutan Terbakar (Skala Hutan Penuh)

Untuk membuat area hutan kebakaran yang luas, Anda punya 2 metode:

### Metode 1: Menggunakan Generator Otomatis (`forest_fire_zone.tscn`) — Direkomendasikan
1. Buka scene level Anda (misalnya `main.tscn`).
2. Tarik (*drag & drop*) **`Scenes/forest_fire_zone.tscn`** ke dalam level Anda.
3. Di panel **Inspector**:
   - Atur **`Zone Size`** (misal `50, 50` meter untuk area 50x50m).
   - Atur **`Tree Count`** (misal 20 atau 30 pohon).
   - Centang **`Generate Forest Now`**! Puluhan pohon terbakar akan langsung ter-spawn secara acak dengan variasi tinggi dan rotasi alami!
   - Pasang file model pohon Anda di slot **`Tree Model`** kapan saja, dan semua pohon di zona tersebut akan otomatis terisi model pohon Anda!

> ⚡ **Optimasi Performa Otomatis (Anti-Lag):**
> Generator ini memiliki fitur **`Max Active Lights`** (default 4). Artinya, meski Anda menaruh 50 pohon terbakar, hanya 4 pohon utama yang menyalakan lampu (`OmniLight3D`), sehingga game tetap berjalan sangat lancar dan stabil pada 60+ FPS tanpa drop!

### Metode 2: Susun Manual di Level Editor (Level Design Manual)
1. Tarik **`forest_fire_tree.tscn`** ke dalam level Anda.
2. Duplikasi dengan menekan **`Ctrl + D`**.
3. Geser posisinya, putar sedikit rotasi Y pohon, dan variasikan nilai **`Tree Height`** (misal pohon A tinggi 5m, pohon B tinggi 7.5m) agar tampak organik dan realistis seperti hutan sungguhan.
4. Matikan centang **`Enable Light`** pada sebagian besar pohon, sisakan 2-3 pohon saja yang menyalakan lampu agar performa tetap ringan.
