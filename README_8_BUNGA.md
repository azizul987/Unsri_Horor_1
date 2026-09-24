# 🌸 Petunjuk Sistem Master 8 Bunga (Kupu-Kupu Malam)

Sistem **`FlowerPickup`** dirancang agar Anda bisa langsung menaruh ke-8 bunga di dalam map **tanpa harus pusing membuat 3D model sendiri sekarang**. 

Bunga ini sudah memiliki **Base Model prosedural**, **efek cahaya mistis (Glow)**, **debu partikel kupu-kupu melayang**, serta **animasi mengambang & berputar halus**. Kapan pun Anda punya model 3D sendiri nanti, Anda tinggal memasukkannya ke dalam slot yang disediakan!

---

## 🚀 1. Cara Pakai (Cukup 1 Scene untuk 8 Bunga)

1. Buka level Anda (misalnya `Scenes/main.tscn`).
2. Tarik (*drag & drop*) scene **`Scenes/flower_pickup.tscn`** ke lokasi puzzle yang Anda inginkan (misal di atas meja, bawah kasur, lantai dapur, dll).
3. Di panel **Inspector** sebelah kanan, cari opsi **`Flower Index`**:
   - Ganti angka **`1`** sampai **`8`**!
   - Seketika di 3D Editor: **Nama bunga, warna cahaya (glow), warna kelopak, warna partikel debu, dan teks interaksi HUD akan OTOMATIS BERUBAH** sesuai bunga yang Anda pilih!

---

## 🎨 2. Cara Memasukkan Model 3D Kustom Anda Nanti

Jika nanti Anda sudah membuat model 3D bunga di Blender / download model:

### Cara A: Lewat Inspector (`Custom Model`)
1. Pilih node `FlowerPickup` di scene Anda.
2. Pada Inspector, cari slot **`Custom Model`**.
3. Pasang file `.tscn`, `.fbx`, atau `.gltf` model bunga Anda ke slot tersebut.
4. **Model bawaan otomatis tersembunyi**, dan model Anda otomatis tampil dihiasi cahaya & partikel!

### Cara B: Drag & Drop Langsung ke Node
1. Buka hierarki `FlowerPickup`.
2. Buka `VisualRoot` -> klik kanan pada node **`CustomMeshSlot`** -> jadikan model Anda sebagai anak (*child*) di bawah node ini.
3. Selesai!

> 💡 **VFX Tetap Menyala:**
> Ada opsi **`Keep Vfx With Custom Model`** (default aktif). Artinya, meskipun Anda memakai model 3D buatan sendiri, efek pendaran cahaya (*OmniLight3D*), partikel debu spora, dan animasi melayang akan tetap membungkus model Anda dengan indah!

---

| Index | Nama Bunga | Bentuk 3D Uniknya | Lokasi Puzzle | Warna Glow | Efek Pasif di Tas |
|:---:|---|---|---|:---:|---|
| **1** | **Melati Rawa** | Batang ramping, kelopak bintang 5 sisi datar | Kamar Kosong (Bawah Kasur) | ⚪ Putih Kebiruan | Meredakan panik (-25%) |
| **2** | **Kembang Api Merah** | Kuncup prisma lancip berdiri mirip lidah api membara | Dapur (Lemari) | 🔴 Merah Bara | Stamina lari lebih awet |
| **3** | **Bunga Bangkai Kerdil** | Mangkuk ceper tebal di lantai dengan rongga ungu gelap | Ruang Bersama (Balik Lemari) | 🟣 Ungu Gelap | Bau manusia tersamarkan (-15%) |
| **4** | **Anggrek Kupu-kupu** | Batang miring, 2 sayap lebar membentang ke samping | Kamar Mahasiswa (Meja Laptop) | 🟡 Kuning Emas | Radar bahaya lebih peka (+5m) |
| **5** | **Teratai Abu** | 3 piringan kelopak berundak bertingkat dingin membeku | Sudut Tangga Rusun | ⚪ Perak Dingin | Cahaya senter lebih stabil |
| **6** | **Kantong Rawa** | Corong silinder kantong semar dengan bibir menyala & tutup | Area Luar Rusun | 🟢 Hijau Neon | Tahan hawa beracun luar |
| **7** | **Mawar Arang** | Batang kayu arang kasar, pecahan kristal hitam berurat bara | Tepi Hutan (Bukti Amir) | 🟠 Hitam Urat Oranye | Tahan panas kebakaran hutan |
| **8** | **Kupu-Kupu Induk** | Tubuh serangga mistis bersayap 4, antena, & jantung berdenyut | Kamar Amir (Final) | 🔮 Magenta Berdenyut | Kunci akhir ritual altar |

---

## 🎮 4. Alur Gameplay Interaksi Pemain

1. Pemain mendekati bunga -> Muncul notifikasi HUD: **`[E] Ambil [Nama Bunga]`**.
2. Pemain menekan **`E`**:
   - Jika tas penuh (sudah 4 item) -> Muncul peringatan: *"Tas penuh! Bawa bunga ke Altar Halaman Depan untuk disimpan!"*.
   - Jika ada slot -> Bunga terambil, suara *chime* kristal mistis berbunyi, bunga masuk ke inventory, counter di `StoryManager` bertambah otomatis (yang juga menaikkan fase agresivitas Amir), dan MC membatin monolog pendek tentang bunga tersebut.
3. Bawa bunga ke **`Scenes/flower_altar.tscn`** di halaman depan -> Tekan `E` untuk menaruhnya ke tanah ritual agar tas kosong kembali untuk mencari bunga berikutnya!
