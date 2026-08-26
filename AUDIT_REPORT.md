# AUDIT_REPORT — FABIZO POS

Audit teknis atas project FABIZO POS: web admin panel (`web-panel/`), dev/super-admin panel (`dev-panel/`), aplikasi mobile Flutter (`pos_ugt_mart/`), dan skema database Supabase (`supabase/`).

---

## 1. Struktur & Arsitektur

Cakupan bagian ini: struktur folder/file, konsistensi state management Flutter, cara aplikasi terhubung ke Supabase (efisiensi query), environment variables & secrets, dan dependency yang dipakai.

### Ringkasan Temuan

| # | Temuan | Severity |
|---|--------|----------|
| 1 | `delete_toko_complete` bisa dipanggil siapa saja yang login (`authenticated`), tanpa cek kepemilikan toko | **Critical** |
| 2 | RPC admin dev-panel diotorisasi pakai username yang dikirim client, bukan sesi terverifikasi — bisa impersonasi admin | **Critical** |
| 3 | Realtime callback memicu reload SEMUA data untuk perubahan 1 baris di tabel manapun | **High** |
| 4 | State global (`dummy*`) di luar Provider/ChangeNotifier — rawan tidak sinkron dengan UI | **High** |
| 5 | Fungsi DB inti (`aktivasi_premium`, definisi asli `delete_toko_complete`) tidak ada di migration yang ter-track | **High** |
| 6 | `AppProvider` jadi "God Object" — 1 class isi semua domain aplikasi | **Medium** |
| 7 | N+1 query saat simpan pembelian (insert per-item berurutan, tidak di-batch) | **Medium** |
| 8 | Query tanpa `.limit()` di beberapa tempat (produk, member) | **Medium** |
| 9 | 38 file migration SQL tanpa penomoran/urutan yang jelas | **Medium** |
| 10 | Beberapa dependency Flutter tertinggal 1–2 major version | **Medium** |
| 11 | CDN dependency di web-panel ada yang tidak dikunci versi (`lucide@latest`) | **Medium** |
| 12 | File monolitik terlalu besar (>1000 baris) di beberapa tempat | **Low** |
| 13 | Kredensial Supabase (URL + anon key) di-hardcode langsung di source, bukan lewat build config | **Low** |

---

### 🔴 CRITICAL

#### 1.1 `delete_toko_complete` bisa dipanggil oleh akun toko biasa mana pun, untuk menghapus toko LAIN

**Lokasi:** `supabase/migration_delete_toko.sql:101`, dipanggil dari `dev-panel/supabase-config.js:85-91` (`devHapusToko`).

```sql
GRANT EXECUTE ON FUNCTION delete_toko_complete(bigint) TO authenticated;
```

`delete_toko_complete(p_id_toko)` menghapus **seluruh data toko secara permanen dan tidak bisa dibatalkan** (transaksi, produk, profiles, pembayaran, retur, dst — lihat `migration_delete_toko.sql:32-50`). Fungsi ini `SECURITY DEFINER` dan **tidak memverifikasi bahwa pemanggil adalah pemilik/admin toko yang di-hapus** — parameter `p_id_toko` diterima mentah-mentah tanpa dicocokkan ke identitas pemanggil.

Karena di-GRANT ke role `authenticated` (bukan cuma `anon`), dan **setiap akun kasir/owner toko biasa yang login lewat app mobile atau web-panel otomatis punya sesi `authenticated`** (lihat `db_service.dart:validateLogin` yang memanggil `_sb.auth.signInWithPassword`) — maka **akun toko mana pun** (termasuk akun gratis hasil daftar sendiri) bisa memanggil RPC ini langsung lewat Supabase client (tanpa lewat UI dev-panel sama sekali) dengan `id_toko` toko LAIN (id-nya bigint kecil berurutan, gampang ditebak/dienumerasi) dan **menghapus total data toko orang lain**.

**Dampak:** kehancuran data permanen lintas-tenant, dieksploitasi tanpa privilege khusus — cuma butuh 1 akun toko biasa yang aktif.

**Saran perbaikan:**
- Tambahkan pengecekan otorisasi DI DALAM fungsi itu sendiri (bukan cuma di wrapper `dev_hapus_toko_checked`) — verifikasi pemanggil punya role dev-admin lewat sesi Supabase Auth yang sah, bukan berdasar parameter/string dari client.
- Cabut grant `TO authenticated` — ganti jadi tanpa grant publik sama sekali; hanya bisa dipanggil lewat wrapper yang sudah tervalidasi (`dev_hapus_toko_checked`), dan JANGAN grant `delete_toko_complete` mentahnya ke role manapun selain lewat `SECURITY DEFINER` internal call.

---

#### 1.2 RPC admin dev-panel diotorisasi berdasarkan string dari client, bukan sesi terautentikasi

**Lokasi:** `supabase/migration_dev_panel_role_lockout.sql:23-42` (`_dev_require_admin`), dipakai oleh `dev_hapus_toko_checked`, `dev_aktivasi_premium_checked`, `dev_approve_lisensi`, `dev_decline_lisensi`, `dev_set_user_aktif`, `dev_create_user` (baris 232-269).

```sql
CREATE OR REPLACE FUNCTION _dev_require_admin(p_username text) ...
  SELECT nama, role, aktif INTO v_nama, v_role, v_aktif
  FROM dev_users WHERE username = p_username;
  ...
  IF v_role <> 'admin' THEN RAISE EXCEPTION 'Aksi ini khusus untuk admin'; END IF;
```

Login dev-panel (`dev-panel/script.js:52-59`, `devValidateLogin`) **tidak pernah membuat sesi Supabase Auth** — cuma cek password lewat RPC lalu simpan hasilnya di `localStorage` polos. Jadi tidak ada JWT/sesi yang benar-benar mengikat "siapa yang sedang login" ke server.

Semua RPC privileged di atas menerima `p_by_username` sebagai **parameter teks biasa dari client**, lalu `_dev_require_admin` cuma mengecek "apakah user dengan username ini ADA dan role-nya admin" — bukan "apakah pemanggil SEKARANG benar-benar user itu". Ditambah lagi, `dev_list_users()` (baris 263) di-GRANT ke `anon` dan mengembalikan **daftar lengkap username & role semua dev_users**.

**Skenario eksploitasi:** siapa pun yang punya anon key publik (ada di `dev-panel/supabase-config.js:4`, `web-panel/supabase-config.js:3`, `pos_ugt_mart/lib/config.dart:4` — semuanya ter-commit di repo) bisa:
1. Panggil `dev_list_users()` untuk dapat username admin asli.
2. Panggil `dev_hapus_toko_checked(p_id_toko, p_by_username: '<username_admin_asli>')` langsung lewat Supabase REST/RPC — **tanpa password, tanpa sesi, tanpa login sama sekali** — dan berhasil, karena servernya cuma percaya string username yang dikirim.

Sama berlaku untuk aktivasi Premium gratis, approve/decline lisensi, bikin akun dev-admin baru, nonaktifkan admin lain.

**Saran perbaikan:**
- Ganti pola otorisasi total: dev-panel harus login lewat Supabase Auth beneran (`signInWithPassword`) supaya ada JWT sah, lalu semua RPC privileged verifikasi identitas dari `auth.uid()`/`auth.jwt()`, bukan dari parameter yang dikirim client.
- Cabut GRANT `dev_list_users()` dari `anon` — minimal wajib sesi admin yang valid.
- Ini butuh perombakan alur auth dev-panel, bukan tambal di level RPC saja.

---

### 🟠 HIGH

#### 1.3 Realtime subscription memicu reload SEMUA data untuk 1 perubahan kecil

**Lokasi mobile:** `pos_ugt_mart/lib/providers/app_provider.dart` (dipanggil dari `login()`, lihat callback `DbService.setupRealtime`), diteruskan ke `db_service.dart:23-108` yang subscribe ke 6 tabel (`produk`, `transaksi`, `member`, `kas_log`, `shift`, `pembelian`, `pembayaran`) dengan SATU callback yang sama:
```dart
DbService.setupRealtime(() async {
  await DbService.loadAll();               // fetch ULANG semua produk + member + 100 transaksi terakhir
  activeShift = await DbService.getActiveShift();
  await DbService.loadKasLog(activeShift?.id);
  notifyListeners();
});
```

**Lokasi web:** `web-panel/supabase-config.js:19-41` — subscribe ke 8 tabel, semuanya trigger `_scheduleReload()` yang memanggil `dbLoadAll()` (5 query paralel) **DAN** `dbLoadAllExtra()` (12 query, dijalankan berurutan satu-satu, tidak di-`Promise.all`) — total ~17 query untuk **1 baris berubah di tabel manapun**.

**Dampak:** kalau ada 1 kasir mencatat kas masuk Rp5.000, semua device yang terhubung (mobile + web-panel semua toko yang subscribe) langsung fetch ulang seluruh produk, member, 100-500 transaksi terakhir, dst. Ini akan terasa berat & boros kuota Supabase begitu jumlah toko/transaksi bertambah — bukan cuma soal performa, tapi juga biaya (Supabase charge berdasarkan jumlah request/bandwidth).

**Saran perbaikan:** pisahkan callback per tabel — hanya reload data yang benar-benar relevan dengan tabel yang berubah (mis. `kas_log` berubah → cuma `loadKasLog()`, bukan `loadAll()`). Untuk web-panel, jalankan `dbLoadAllExtra()` dengan `Promise.all` bukan sekuensial.

---

#### 1.4 State global (`dummy*`) di luar sistem Provider — rawan tidak sinkron

**Lokasi:** `pos_ugt_mart/lib/models/transaction.dart:71,73`, `product.dart:40,42`, `purchase.dart:65,67`, `member.dart:29`.

```dart
final List<Transaction> dummyHistory = [];
final List<KasLog> dummyKasLog = [];
final List<String> dummyKategori = [];
final List<Product> dummyProducts = [];
List<Supplier> dummySuppliers = [];
List<Purchase> dummyPurchases = [];
final List<Member> dummyMembers = [];
```

Tujuh list mutable ini adalah **variabel top-level di file model**, bukan field di dalam `AppProvider`. Nama `dummy*` menunjukkan ini awalnya data mock sebelum terhubung ke Supabase, dan tidak pernah direfaktor. `DbService` dan `AppProvider` sama-sama memutasi list ini langsung (`dummyProducts.clear()`, `.add()`, dst) dari banyak tempat berbeda.

**Risiko konkret:** karena list ini BUKAN bagian dari `ChangeNotifier`, widget yang membaca isinya HANYA rebuild kalau ada kode lain yang (secara manual, terpisah) memanggil `notifyListeners()` pada instance `AppProvider` setelah list-nya dimutasi. Kalau ada path kode baru yang lupa memanggil `notifyListeners()` setelah memutasi salah satu `dummy*` list ini, UI akan diam-diam menampilkan data basi tanpa error apa pun — bug seperti ini sudah beberapa kali muncul di sesi kerja sebelumnya (mis. `dummyKasLog` yang datanya benar tapi UI belum ke-refresh).

**Saran perbaikan:** pindahkan ketujuh list ini jadi field private di dalam `AppProvider` (atau provider terpisah per domain — lihat temuan 1.6), dengan getter read-only ke luar, supaya SETIAP mutasi wajib lewat method `AppProvider` yang otomatis memanggil `notifyListeners()` — tidak ada jalur mutasi "diam-diam" lagi.

---

#### 1.5 Fungsi database inti tidak tercatat di migration manapun di repo

**Lokasi:** komentar eksplisit di `supabase/migration_dev_panel_role_lockout.sql:229-231`:
> "Fungsi asli (`aktivasi_premium`, `delete_toko_complete`) TIDAK diubah karena didefinisikan di luar file migrasi yang terlacak di repo ini."

`aktivasi_premium` — fungsi yang mengaktifkan langganan Premium — **tidak punya `CREATE FUNCTION` di manapun di folder `supabase/`**. Artinya definisi aslinya cuma ada di database production (dibuat langsung lewat SQL Editor Supabase), tidak pernah di-commit.

**Dampak:** skema database yang sebenarnya berjalan di production **tidak bisa direkonstruksi ulang dari repo**. Kalau perlu disaster-recovery (bikin ulang project Supabase dari nol), audit keamanan menyeluruh, atau code review atas fungsi krusial ini, tidak ada satu pun sumber kebenaran di git — harus tarik manual dari dashboard Supabase.

**Saran perbaikan:** dump seluruh skema & fungsi Supabase saat ini (`supabase db dump` atau via SQL Editor `pg_get_functiondef`) dan commit sebagai baseline migration, lalu mulai disiplin: setiap perubahan skema WAJIB lewat file migration baru, tidak lagi ad-hoc di SQL Editor.

---

### 🟡 MEDIUM

#### 1.6 `AppProvider` adalah "God Object" — satu class untuk semua domain

**Lokasi:** `pos_ugt_mart/lib/providers/app_provider.dart` — 1.101 baris.

Satu `ChangeNotifier` ini menangani: auth/login, cart & checkout, pembayaran, piutang, shift kasir & rekonsiliasi kas, pengaturan toko (alamat, foto, QRIS, rekening bank), manajemen produk, member, kategori, supplier, pembelian — nyaris seluruh aplikasi. Setiap `notifyListeners()` di sini berpotensi rebuild widget mana pun yang `watch<AppProvider>()`, walau perubahannya cuma di domain yang tidak relevan buat widget itu (mis. update `qrisImageUrl` bisa ikut rebuild widget yang cuma butuh `cart`).

**Saran perbaikan:** pecah jadi beberapa provider per domain (mis. `AuthProvider`, `CartProvider`, `ShiftProvider`, `SettingsProvider`) yang di-compose lewat `MultiProvider`, atau migrasi ke solusi state management yang punya selector granular (Riverpod dengan provider terpisah per concern). Tidak mendesak untuk skala aplikasi sekarang, tapi akan makin menyulitkan maintenance seiring fitur bertambah.

#### 1.7 N+1 query saat menyimpan pembelian

**Lokasi:** `pos_ugt_mart/lib/services/db_service.dart:752-768` (`_savePurchaseAsync`).

```dart
for (final item in purchase.items) {
  await _db.from('pembelian_item').insert({...});   // 1 round-trip per item
  if (item.productId.isNotEmpty) {
    await _db.from('produk').update({'stok': ...}).eq('id', ...);  // 1 round-trip lagi
  }
}
```

Untuk pembelian dengan N item, ini melakukan sampai 2N round-trip Supabase **berurutan** (bukan paralel). Bandingkan dengan `_saveTransactionAsync` (baris ~464) yang sudah benar pakai `Future.wait(trx.cartItems.map(...))` untuk insert item transaksi secara paralel.

**Saran perbaikan:** ganti jadi satu `insert()` batch untuk semua `pembelian_item` sekaligus (Supabase mendukung insert banyak baris dalam satu call), dan paralelkan update stok dengan `Future.wait`.

#### 1.8 Query tanpa `.limit()` di beberapa tempat

**Lokasi:** `db_service.dart:190-196` (`_loadProducts`), `:356-361` (`_loadMembers`) — fetch SEMUA baris untuk toko tsb, tanpa batas. Wajar untuk toko kecil sekarang, tapi begitu jumlah produk/member bertambah (ribuan baris), ini akan makin lambat dan boros — apalagi terpicu ulang tiap ada perubahan realtime (lihat temuan 1.3).

**Saran perbaikan:** tambahkan pagination atau `.limit()` yang masuk akal, atau load on-demand (mis. search server-side) alih-alih fetch semua ke memori klien.

#### 1.9 38 file migration SQL tanpa urutan/penomoran yang jelas

**Lokasi:** folder `supabase/` — 38 file `migration_*.sql` dengan nama deskriptif bebas (`migration_p0_auth_fix.sql`, `migration_v1_1_fix.sql`, `migration_fix_cicilan_rpc.sql`, dst), tidak ada prefix angka/timestamp yang menjamin urutan eksekusi.

**Dampak:** kalau perlu setup database dari nol (env baru, disaster recovery), tidak ada cara pasti untuk tahu urutan yang benar menjalankan 38 file ini — beberapa saling bergantung (mis. migration yang nge-`DROP FUNCTION` lalu `CREATE OR REPLACE` versi baru).

**Saran perbaikan:** pertimbangkan pindah ke Supabase CLI migration tooling (`supabase migration new`, otomatis prefix timestamp) atau minimal beri prefix angka urut manual (`0001_`, `0002_`, dst) dan definisikan urutan tersebut di `schema.sql`/README.

#### 1.10 Beberapa dependency Flutter tertinggal jauh dari versi terbaru

Hasil `flutter pub outdated`:

| Package | Terpasang | Terbaru | Gap |
|---|---|---|---|
| `google_fonts` | 6.3.3 | 8.2.1 | 2 major |
| `device_info_plus` | 11.5.0 | 13.2.0 | 2 major |
| `flutter_lints` (dev) | 4.0.0 | 6.0.0 | 2 major |
| `flutter_slidable` | 3.1.2 | 4.0.3 | 1 major |
| `mobile_scanner` | 6.0.11 | 7.4.0 | 1 major |
| `intl` | 0.19.0 | 0.20.3 | minor |
| `supabase_flutter` | 2.16.0 | 2.17.2 | minor |

Tidak ada yang eksplisit "deprecated", tapi gap 2 major version (terutama `google_fonts`, `device_info_plus`) berarti kehilangan bug fix & patch keamanan yang terakumulasi cukup lama.

**Saran perbaikan:** upgrade bertahap dimulai dari yang gap-nya kecil (`supabase_flutter`, `intl`), lalu major-version bump satu-satu sambil test regresi — jangan upgrade semua sekaligus.

#### 1.11 CDN dependency web-panel ada yang tidak dikunci versi

**Lokasi:** `web-panel/index.html:12-15`.

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<script src="https://unpkg.com/lucide@latest/dist/umd/lucide.js"></script>
<script src="https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js"></script>
```

`lucide@latest` sama sekali tidak dikunci versi — setiap kali halaman dimuat, browser ambil versi TERBARU apa pun yang ada saat itu. `@supabase/supabase-js@2` cuma dikunci ke major version, bukan versi persis. Kalau salah satu paket ini kena supply-chain attack atau rilis breaking change, itu langsung tayang di production tanpa ada yang sadar atau bisa rollback gampang.

**Saran perbaikan:** kunci semua CDN script ke versi persis (seperti `chart.js@4.4.0` dan `qrcodejs@1.0.0` yang sudah benar), idealnya tambahkan atribut `integrity` (Subresource Integrity) supaya browser menolak file yang isinya berubah dari yang diharapkan.

---

### 🟢 LOW

#### 1.12 Beberapa file jauh melebihi ukuran wajar

| File | Baris |
|---|---|
| `pos_ugt_mart/lib/screens/product_screen.dart` | 1.497 |
| `web-panel/script.js` | 3.668 |
| `web-panel/supabase-config.js` | 1.100 |
| `pos_ugt_mart/lib/services/db_service.dart` | 1.143 |
| `pos_ugt_mart/lib/providers/app_provider.dart` | 1.101 |
| `pos_ugt_mart/lib/screens/payment_screen.dart` | 1.066 |

`web-panel/script.js` khususnya berisi routing, rendering tiap halaman, dan seluruh business logic dalam SATU file tanpa modul (tidak ada bundler/ES modules — semua fungsi jadi global). Bukan bug, tapi menyulitkan navigasi & meningkatkan risiko merge conflict saat lebih dari satu orang mengerjakan file yang sama (sudah pernah terjadi di riwayat commit terbaru project ini).

**Saran perbaikan (opsional, tidak mendesak):** pertimbangkan pisah `script.js` per modul (mis. `js/produk.js`, `js/kas.js`, `js/dashboard.js`) memakai ES modules, meski ini perubahan besar dan sebaiknya direncanakan terpisah, bukan sekadar refactor cepat.

#### 1.13 Kredensial Supabase di-hardcode langsung di source

**Lokasi:** `pos_ugt_mart/lib/config.dart:3-4`, `web-panel/supabase-config.js:2-3`, `dev-panel/supabase-config.js:3-4` — ketiganya berisi URL + anon key yang sama persis, di-commit ke git.

Ini **bukan** kebocoran kritikal — anon key Supabase memang didesain untuk publik/ter-embed di client, keamanan data sebenarnya ada di Row Level Security. Tapi hardcode langsung di source (bukan lewat `--dart-define`, file `.env` yang di-gitignore, atau build-time config) berarti:
- Ganti environment (dev/staging/prod) = ganti kode + rebuild, bukan ganti config.
- Rotasi key (kalau suatu saat perlu, mis. karena insiden) butuh code change + redeploy ke semua platform, bukan cuma update env var.

**Saran perbaikan:** pindahkan ke `--dart-define-from-file` (Flutter) dan file `.env` yang di-gitignore + di-load lewat build step sederhana (web-panel/dev-panel bisa generate `supabase-config.js` dari template saat deploy).

---

*Bagian selanjutnya (jika diperlukan): audit fitur, UI/UX, dan area lain di luar struktur & arsitektur — belum dicakup laporan ini sesuai permintaan.*
