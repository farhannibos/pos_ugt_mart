-- ═══════════════════════════════════════════════════════
--  POS UGT MART — Supabase Schema + Seed Data
--  Paste & run this entire file in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════

-- ── TABLES ──────────────────────────────────────────────

create table if not exists kategori (
    id          text        primary key,
    nama        text        not null,
    deskripsi   text        default '',
    status      text        not null default 'Aktif',
    created_at  timestamptz default now()
);

create table if not exists barang (
    id          text    primary key,
    nama        text    not null,
    kategori    text    not null,
    satuan      text    not null default 'Pcs',
    harga_beli  integer not null default 0,
    harga_jual  integer not null default 0,
    stok        integer not null default 0,
    stok_min    integer not null default 10,
    barcode     text    default '',
    status      text    not null default 'Aktif',
    created_at  timestamptz default now()
);

create table if not exists supplier (
    id          text    primary key,
    nama        text    not null,
    kontak      text    default '',
    alamat      text    default '',
    email       text    default '',
    status      text    not null default 'Aktif',
    created_at  timestamptz default now()
);

create table if not exists member (
    id              text    primary key,
    nama            text    not null,
    hp              text    default '',
    email           text    default '',
    total_belanja   integer not null default 0,
    poin            integer not null default 0,
    status          text    not null default 'Aktif',
    created_at      timestamptz default now()
);

-- NOTE: passwords stored in plain text for demo only.
-- Use Supabase Auth or bcrypt hashing before production.
create table if not exists users (
    id            text    primary key,
    nama          text    not null,
    username      text    not null unique,
    password      text    not null,
    role          text    not null default 'Kasir',
    status        text    not null default 'Aktif',
    last_login    timestamptz,
    avatar        text    default '',
    avatar_color  text    default '#16A34A',
    created_at    timestamptz default now()
);

create table if not exists penjualan (
    id          text        primary key,
    tanggal     date        not null default current_date,
    jam         text        not null default '00:00',
    kasir       text        not null,
    pelanggan   text        not null default 'Umum',
    metode      text        not null,
    subtotal    integer     not null default 0,
    diskon      integer     not null default 0,
    total       integer     not null default 0,
    status      text        not null default 'Lunas',
    catatan     text        default '',
    created_at  timestamptz default now()
);

create table if not exists penjualan_item (
    id              uuid    default gen_random_uuid() primary key,
    penjualan_id    text    not null references penjualan(id) on delete cascade,
    barang_id       text    default '',
    nama_barang     text    not null,
    harga           integer not null,
    qty             integer not null,
    subtotal        integer not null
);

create table if not exists kas_log (
    id          uuid    default gen_random_uuid() primary key,
    keterangan  text    not null,
    jam         text    not null,
    nominal     integer not null,
    tipe        text    not null,
    kasir       text    default '',
    tanggal     date    default current_date,
    created_at  timestamptz default now()
);

-- ── INDEXES ─────────────────────────────────────────────
create index if not exists idx_barang_kategori    on barang(kategori);
create index if not exists idx_barang_status      on barang(status);
create index if not exists idx_penjualan_tanggal  on penjualan(tanggal desc);
create index if not exists idx_penjualan_status   on penjualan(status);
create index if not exists idx_item_trx           on penjualan_item(penjualan_id);
create index if not exists idx_member_nama        on member(nama);

-- ── ROW LEVEL SECURITY ──────────────────────────────────────────
alter table kategori       enable row level security;
alter table barang         enable row level security;
alter table supplier       enable row level security;
alter table member         enable row level security;
alter table users          enable row level security;
alter table penjualan      enable row level security;
alter table penjualan_item enable row level security;
alter table kas_log        enable row level security;

-- Drop lama jika ada (idempotent)
do $$ begin
  drop policy if exists allow_anon on kategori;
  drop policy if exists allow_anon on barang;
  drop policy if exists allow_anon on supplier;
  drop policy if exists allow_anon on member;
  drop policy if exists allow_anon on users;
  drop policy if exists allow_anon on penjualan;
  drop policy if exists allow_anon on penjualan_item;
  drop policy if exists allow_anon on kas_log;
end $$;

-- ── users: TIDAK ada akses langsung dari anon ────────────────────
-- Login ditangani lewat fungsi validate_login() (SECURITY DEFINER)

-- ── kategori: baca + tulis (admin panel kelola kategori) ─────────
create policy "kategori_select" on kategori for select using (true);
create policy "kategori_insert" on kategori for insert with check (true);
create policy "kategori_update" on kategori for update using (true) with check (true);

-- ── barang: baca + tulis (kasir update stok, admin kelola produk) ─
create policy "barang_select" on barang for select using (true);
create policy "barang_insert" on barang for insert with check (true);
create policy "barang_update" on barang for update using (true) with check (true);

-- ── supplier: baca + tulis (admin kelola supplier) ───────────────
create policy "supplier_select" on supplier for select using (true);
create policy "supplier_insert" on supplier for insert with check (true);
create policy "supplier_update" on supplier for update using (true) with check (true);

-- ── member: baca + tulis (kasir update poin & total_belanja) ─────
create policy "member_select" on member for select using (true);
create policy "member_insert" on member for insert with check (true);
create policy "member_update" on member for update using (true) with check (true);

-- ── penjualan: baca + insert + update status (lunas piutang) ─────
-- DELETE diblokir: riwayat transaksi tidak boleh dihapus via anon
create policy "penjualan_select" on penjualan for select using (true);
create policy "penjualan_insert" on penjualan for insert with check (true);
create policy "penjualan_update" on penjualan for update using (true) with check (true);

-- ── penjualan_item: baca + insert saja ───────────────────────────
create policy "item_select" on penjualan_item for select using (true);
create policy "item_insert" on penjualan_item for insert with check (true);

-- ── kas_log: baca + insert saja ──────────────────────────────────
create policy "kas_select" on kas_log for select using (true);
create policy "kas_insert" on kas_log for insert with check (true);

-- ── FUNGSI LOGIN ─────────────────────────────────────────────────
-- SECURITY DEFINER: fungsi berjalan dengan hak pemilik (bypasses RLS)
-- sehingga bisa baca tabel users, tapi pemanggil (anon) tidak bisa.
create or replace function validate_login(p_username text, p_password text)
returns table(nama text, role text, avatar_color text)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select u.nama, u.role, u.avatar_color
  from users u
  where u.username = p_username
    and u.password = p_password
    and u.status   = 'Aktif'
  limit 1;
end;
$$;

grant execute on function validate_login(text, text) to anon;

-- ── SEED DATA ────────────────────────────────────────────

insert into kategori (id, nama, deskripsi, status) values
  ('KT-001', 'Sembako',               'Kebutuhan pokok sehari-hari',    'Aktif'),
  ('KT-002', 'Minuman',               'Berbagai jenis minuman kemasan', 'Aktif'),
  ('KT-003', 'Snack & Makanan Ringan','Camilan dan makanan ringan',     'Aktif'),
  ('KT-004', 'Toiletries',            'Produk perawatan diri',          'Aktif'),
  ('KT-005', 'Kebersihan',            'Produk kebersihan rumah',        'Aktif'),
  ('KT-006', 'Bumbu Masak',           'Aneka bumbu dan rempah',         'Aktif'),
  ('KT-007', 'Produk Beku',           'Makanan beku dan frozen food',   'Non-aktif')
on conflict (id) do nothing;

insert into barang (id, nama, kategori, satuan, harga_beli, harga_jual, stok, stok_min, barcode, status) values
  ('BRG-001', 'Indomie Goreng 85g',       'Snack & Makanan Ringan', 'Pcs',    2800,  3500,  240, 50,  '8998866200011', 'Aktif'),
  ('BRG-002', 'Beras Ramos 5kg',           'Sembako',               'Karung', 62000, 65000, 32,  10,  '8991002100025', 'Aktif'),
  ('BRG-003', 'Minyak Goreng Sania 2L',    'Sembako',               'Botol',  36000, 38500, 45,  15,  '8992222100031', 'Aktif'),
  ('BRG-004', 'Sabun Lifebuoy 85g',        'Toiletries',            'Pcs',    3500,  5000,  120, 20,  '8999999030040', 'Aktif'),
  ('BRG-005', 'Aqua 600ml',                'Minuman',               'Botol',  2500,  4000,  300, 60,  '8886008101053', 'Aktif'),
  ('BRG-006', 'Teh Pucuk Harum 350ml',     'Minuman',               'Botol',  3800,  4500,  180, 30,  '8992760125062', 'Aktif'),
  ('BRG-007', 'Gula Pasir Gulaku 1kg',     'Sembako',               'Kg',     13500, 15500, 8,   15,  '8991002200071', 'Aktif'),
  ('BRG-008', 'Kopi Kapal Api 165g',       'Minuman',               'Pcs',    11000, 12500, 75,  20,  '8991002310088', 'Aktif'),
  ('BRG-009', 'Sampo Clear 160ml',         'Toiletries',            'Botol',  22000, 24500, 6,   10,  '8999999040097', 'Aktif'),
  ('BRG-010', 'Susu Ultra Full Cream 1L',  'Minuman',               'Box',    17000, 19500, 11,  12,  '8998009040116', 'Aktif'),
  ('BRG-011', 'Deterjen Rinso 800g',       'Kebersihan',            'Pcs',    20000, 22500, 35,  10,  '8999999050122', 'Aktif'),
  ('BRG-012', 'Telur Ayam 1kg',            'Sembako',               'Kg',     26000, 28000, 24,  10,  '8991002400133', 'Aktif'),
  ('BRG-013', 'Saos Sambal ABC 135ml',     'Bumbu Masak',           'Botol',  7000,  9000,  35,  15,  '8991234560099', 'Aktif'),
  ('BRG-014', 'Nugget Fiesta 500g',        'Produk Beku',           'Pcs',    25000, 30000, 0,   5,   '8991234560100', 'Non-aktif')
on conflict (id) do nothing;

insert into supplier (id, nama, kontak, alamat, email, status) values
  ('SUP-001', 'PT Indofood Sukses Makmur',  '021-12345678', 'Jl. Sudirman No.1, Jakarta',      'order@indofood.com',       'Aktif'),
  ('SUP-002', 'CV Maju Bersama',            '0271-567890',  'Jl. Veteran No.45, Solo',          'cv.majubersama@email.com', 'Aktif'),
  ('SUP-003', 'UD Sukses Makmur',           '031-678901',   'Jl. Raya Darmo No.12, Surabaya',  'ud.sukses@email.com',      'Aktif'),
  ('SUP-004', 'PT Aqua Golden Mississippi', '021-23456789', 'Jl. HR Rasuna Said, Jakarta',      'aqua@danone.com',          'Aktif'),
  ('SUP-005', 'CV Sumber Rejeki',           '0274-345678',  'Jl. Malioboro No.5, Yogyakarta',  'sumber.rejeki@email.com',  'Non-aktif')
on conflict (id) do nothing;

insert into member (id, nama, hp, email, total_belanja, poin, status) values
  ('MBR-001', 'Budi Santoso',   '0812-3344-5566', 'budi@email.com',   4820000, 1250, 'Aktif'),
  ('MBR-002', 'Siti Aminah',    '0857-9911-2233', 'siti@email.com',   2140000, 640,  'Aktif'),
  ('MBR-003', 'Andi Wijaya',    '0813-7788-1010', 'andi@email.com',   6390000, 1810, 'Aktif'),
  ('MBR-004', 'Dewi Lestari',   '0821-4455-6677', 'dewi@email.com',   720000,  180,  'Aktif'),
  ('MBR-005', 'Rahmat Hidayat', '0895-2233-8899', '',                 1650000, 520,  'Aktif')
on conflict (id) do nothing;

insert into users (id, nama, username, password, role, status, avatar, avatar_color) values
  ('USR-001', 'Administrator', 'admin',   'admin123', 'Super Admin', 'Aktif', 'A', '#16A34A'),
  ('USR-002', 'Rani Pratiwi',  'kasir01', 'kasir123', 'Kasir',       'Aktif', 'R', '#3B82F6'),
  ('USR-003', 'Kasir 1',       'kasir1',  '12345',    'Kasir',       'Aktif', 'K', '#8B5CF6'),
  ('USR-004', 'Kasir 2',       'kasir2',  '12345',    'Kasir',       'Aktif', 'K', '#F59E0B'),
  ('USR-005', 'Gudang',        'gudang1', '12345',    'Gudang',      'Aktif', 'G', '#EF4444')
on conflict (id) do nothing;

-- Sample transactions
insert into penjualan (id, tanggal, jam, kasir, pelanggan, metode, subtotal, diskon, total, status) values
  ('TRX-20260727-009', '2026-07-27', '08:33', 'Rani Pratiwi', 'Umum',         'Tunai',    118500, 0, 118500, 'Lunas'),
  ('TRX-20260727-010', '2026-07-27', '08:55', 'Rani Pratiwi', 'Siti Aminah',  'Voucher',  62000,  0, 62000,  'Piutang'),
  ('TRX-20260727-011', '2026-07-27', '09:18', 'Rani Pratiwi', 'Umum',         'Tunai',    27000,  0, 27000,  'Lunas'),
  ('TRX-20260727-012', '2026-07-27', '09:41', 'Rani Pratiwi', 'Andi Wijaya',  'EDC BCA',  342500, 0, 342500, 'Lunas'),
  ('TRX-20260727-013', '2026-07-27', '10:02', 'Rani Pratiwi', 'Umum',         'QRIS',     156000, 0, 156000, 'Lunas'),
  ('TRX-20260727-014', '2026-07-27', '10:24', 'Rani Pratiwi', 'Budi Santoso', 'Tunai',    84600,  0, 84600,  'Lunas')
on conflict (id) do nothing;

insert into penjualan_item (penjualan_id, barang_id, nama_barang, harga, qty, subtotal) values
  ('TRX-20260727-009', 'BRG-002', 'Beras Ramos 5kg',          65000, 1, 65000),
  ('TRX-20260727-009', 'BRG-010', 'Susu Ultra Full Cream 1L', 19500, 2, 39000),
  ('TRX-20260727-009', 'BRG-005', 'Aqua 600ml',               4000,  3, 12000),
  ('TRX-20260727-009', 'BRG-001', 'Indomie Goreng 85g',       3500,  2, 7000 ),
  ('TRX-20260727-010', 'BRG-003', 'Minyak Goreng Sania 2L',   38500, 1, 38500),
  ('TRX-20260727-010', 'BRG-004', 'Sabun Lifebuoy 85g',       5000,  2, 10000),
  ('TRX-20260727-010', 'BRG-006', 'Teh Pucuk Harum 350ml',    4500,  3, 13500),
  ('TRX-20260727-011', 'BRG-008', 'Kopi Kapal Api 165g',      12500, 1, 12500),
  ('TRX-20260727-011', 'BRG-007', 'Gula Pasir Gulaku 1kg',    15500, 1, 15500),
  ('TRX-20260727-012', 'BRG-002', 'Beras Ramos 5kg',          65000, 2, 130000),
  ('TRX-20260727-012', 'BRG-003', 'Minyak Goreng Sania 2L',   38500, 3, 115500),
  ('TRX-20260727-012', 'BRG-012', 'Telur Ayam 1kg',           28000, 2, 56000),
  ('TRX-20260727-012', 'BRG-011', 'Deterjen Rinso 800g',      22500, 1, 22500),
  ('TRX-20260727-012', 'BRG-010', 'Susu Ultra Full Cream 1L', 19500, 1, 19500),
  ('TRX-20260727-013', 'BRG-002', 'Beras Ramos 5kg',          65000, 1, 65000),
  ('TRX-20260727-013', 'BRG-010', 'Susu Ultra Full Cream 1L', 19500, 2, 39000),
  ('TRX-20260727-013', 'BRG-008', 'Kopi Kapal Api 165g',      12500, 2, 25000),
  ('TRX-20260727-013', 'BRG-006', 'Teh Pucuk Harum 350ml',    4500,  2, 9000 ),
  ('TRX-20260727-013', 'BRG-005', 'Aqua 600ml',               4000,  3, 12000),
  ('TRX-20260727-013', 'BRG-001', 'Indomie Goreng 85g',       3500,  4, 14000),
  ('TRX-20260727-014', 'BRG-001', 'Indomie Goreng 85g',       3500,  2, 7000 ),
  ('TRX-20260727-014', 'BRG-003', 'Minyak Goreng Sania 2L',   38500, 2, 77000);
