# RUNBOOK: Data Warehouse Pertambangan PT XYZ

Tugas Datawarehouse, replikasi repo Perancangan-Data-Warehouse-Industri-Pertambangan-PT.XYZ.
Dikerjakan di Windows (PowerShell) dengan Docker Desktop.

## 1. Ringkasan Arsitektur

Seluruh pipeline jalan di Docker Compose (`docker-compose.lite.yml`) dan dipicu satu perintah
lewat `run_all.ps1`. Kredensial tidak ditulis di kode, semuanya dibaca dari file `.env`
(contoh isinya ada di `.env.example`).

```
 .env  --->  run_all.ps1
                 |
                 v
        docker compose up
                 |
   +-------------+-----------------+
   |             |                 |
   v             v                 v
sqlserver     db_init           ptxyz_etl
(SQL Server)  (jalankan         (python: run_etl.py
 container     init-scripts,     -> standalone_etl.py)
 ptxyz_        buat skema)
 sqlserver
   |_____________|_________________|
                 |
                 v
     database PTXYZ_DataWarehouse
     staging  ->  dim (8 tabel)  ->  fact (3 tabel)
                 |
                 v
      tests/validate.sql  (skema, jumlah baris, orphan FK,
                           rentang nilai, duplikasi, agregat)
                 |
                 v
        logs/etl_execution.log
```

### Alur ETL (sesuai log `etl_execution.log`)

1. **Staging**: data sumber (`data/*.csv`) dimuat ke tabel `staging.EquipmentUsage`,
   `staging.Production`, dan `staging.FinancialTransaction` (masing-masing 1.150 baris).
2. **Dimensi**: memuat DimTime, DimSite, DimEquipment, DimMaterial, DimEmployee, DimShift,
   DimProject, DimAccount.
3. **Fakta**: memuat FactEquipmentUsage, FactProduction, FactFinancialTransaction.
4. **Data quality check**: menghitung jumlah baris tiap tabel dan dicatat ke log.

### Skema

| Schema | Tabel | Jumlah |
|---|---|---|
| staging | EquipmentUsage, Production, FinancialTransaction | 3 |
| dim | DimTime, DimSite, DimEquipment, DimMaterial, DimEmployee, DimShift, DimProject, DimAccount | 8 |
| fact | FactEquipmentUsage, FactProduction, FactFinancialTransaction | 3 |

Kolom `efficiency_ratio`, `total_cost`, `variance_amount`, dan `variance_percentage` adalah
computed column, sesuai README. Container `db_init` mencatat 17 baris daftar tabel saat
inisialisasi skema selesai.

## 2. Pemetaan Langkah README ke Perintah

Urutan di bawah mengikuti bagian Quick Start dan Testing & Validation di README.

| No | Langkah di README | Perintah yang dijalankan | Keterangan |
|----|-------------------|--------------------------|------------|
| 1 | Environment setup (`ls -la .env`, atau `cp .env.example .env`) | `run_all.ps1` langkah 0 | Otomatis menyalin `.env.example` ke `.env` kalau belum ada, lalu mengecek `MSSQL_SA_PASSWORD` terisi. Kredensial tidak ditulis di kode. |
| 2 | Clean environment (`docker system prune -af --volumes`) | `docker compose -f docker-compose.lite.yml down -v --remove-orphans` (langkah 1) | Padanan. Hasilnya sama (mulai dari lingkungan bersih), tapi hanya menghapus container dan volume milik proyek ini, tidak semua isi Docker di laptop. |
| 3 | Start services (`docker compose up -d`, `docker compose ps`) | `docker compose -f docker-compose.lite.yml up -d` lalu `docker ps -a` (langkah 2) | Memakai compose versi lite. Alasannya ada di bagian 4. |
| 4 | Buat skema | container `ptxyz_db_init` menjalankan `init-scripts/create-schema.sql` | Skema `staging`, `dim`, dan `fact` terbentuk. |
| 5 | Jalankan ETL (`python standalone_etl.py`) | container `ptxyz_etl` menjalankan `run_etl.py` yang memanggil `standalone_etl.py` | Memuat data dari `data/*.csv` (data contoh dari README, dipakai apa adanya). Log ada di `logs/etl_execution.log`. |
| 6 | Testing dan validasi (`test.sh`, `check_schema.py`) | `tests/validate.sql` lewat `sqlcmd` (langkah 4) | Mengecek skema, jumlah baris, orphan FK, rentang nilai, duplikasi, dan agregat. |
| 7 | Akses dashboard (Grafana, Superset, Metabase) | `tests/olap_demo.sql` | Layanan dashboard tidak dijalankan. Diganti query OLAP langsung ke SQL Server, buktinya di bagian 3. |

Semua langkah di atas dijalankan sekaligus dengan satu perintah:

```
powershell -ExecutionPolicy Bypass -File .\run_all.ps1
```

### Padanan alat

| Di README | Di versi ini | Dampak ke hasil |
|-----------|--------------|-----------------|
| Airflow (DAG loader) | `run_etl.py` dan `standalone_etl.py` | Tidak ada. Jumlah baris semua tabel sama dengan README. |
| SQL Server | SQL Server 2022 (sama) | Tidak ada. |
| PostgreSQL, Redis | Tidak dijalankan | Hanya untuk metadata Airflow. |
| Grafana, Superset, Metabase | Query SQL (`olap_demo.sql`) | Hasil agregat sama, tampilannya bukan grafik. |

## 3. Bukti Hasil

### 3.1 Hasil validasi otomatis

Dijalankan dengan satu perintah (juga otomatis di langkah 4 `run_all.ps1`):

```
docker compose -f docker-compose.lite.yml exec -T sqlserver bash -c '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $MSSQL_SA_PASSWORD -C -N -d PTXYZ_DataWarehouse -b -W -i /tests/validate.sql'
```

Ringkasan: **44 PASS, 1 WARN, 4 INFO, 0 FAIL**. Output lengkap ada di `logs/bukti_validasi.txt`.

| Kategori | Yang diuji | Hasil |
|----------|-----------|-------|
| Skema | nama kolom, tipe, dan urutan 11 tabel (8 dim, 3 fact) | 12 PASS |
| Jumlah baris | 11 tabel dibandingkan dengan angka di README | 11 PASS |
| Integritas | 12 foreign key di 3 tabel fakta, jumlah orphan | 12 PASS, 0 orphan |
| Rentang nilai | jam operasi, downtime, efficiency_ratio, volume, biaya | 7 PASS |
| Agregat | efisiensi, produksi Metal, produksi Ore | 2 PASS, 1 WARN |
| Duplikasi | ID unik dibanding jumlah baris | 4 INFO |

Jumlah baris tiap tabel sama persis dengan README:

| Tabel | Baris | Tabel | Baris |
|-------|------:|-------|------:|
| DimTime | 830 | DimProject | 50 |
| DimSite | 1.747 | DimAccount | 30 |
| DimEquipment | 6 | FactEquipmentUsage | 236.892 |
| DimMaterial | 5 | FactProduction | 2.261 |
| DimEmployee | 10 | FactFinancialTransaction | 115.901 |
| DimShift | 3 | | |

### 3.2 Hasil agregat dibanding README

| Metrik di README | Nilai README | Hasil kami | Status |
|------------------|-------------:|-----------:|--------|
| Produksi Metal (`date >= 2025-05-01`) | 434.721 | 434.721 | PASS |
| Produksi Ore (`date >= 2025-05-01`) | 112.687 | 112.687 | PASS |
| Overall equipment efficiency | 95,66% | 95,60% | WARN |

Penjelasan ada di bagian 4.

### 3.3 Query OLAP

File: `tests/olap_demo.sql`, output di `logs/bukti_olap.txt`. Semua memakai FactProduction
yang digabung dengan DimTime dan DimMaterial.

1. **Slice** (tahun 2025): Metal 94.465 dan Ore 16.506.
2. **Dice** (Gold dan Copper, kuartal 1 dan 2, tahun 2026): Copper Q1 7.742, Copper Q2 6.806, Gold Q1 4.439, Gold Q2 9.190.
3. **Roll-up** (tahun 2026 dan 2027, tahun ke kuartal ke total): 2026 = 150.218, 2027 = 197.957, total = 348.175.
4. **Drill-down** (tahun 2025, kuartal 2, per bulan): Mei 15.640 dan Juni 15.507.
5. **Pivot** (tahun dan material):

| Tahun | Copper | Gold | Iron | Nickel | Coal |
|------:|-------:|-----:|-----:|-------:|-----:|
| 2022 | 13.253 | 11.482 | 12.526 | 5.855 | 5.676 |
| 2025 | 26.429 | 25.629 | 22.104 | 20.303 | 16.506 |
| 2026 | 29.501 | 29.231 | 28.297 | 34.890 | 28.299 |
| 2027 | 41.412 | 45.165 | 29.917 | 39.981 | 41.482 |
| 2028 | 17.320 | 20.443 | 10.672 | 13.427 | 26.400 |

Hasil roll-up dan pivot saling cocok: jumlah satu baris tahun di pivot sama dengan subtotal
tahun yang sama di roll-up (2026 = 150.218 dan 2027 = 197.957).

### 3.4 Log ETL

`logs/etl_execution.log` mencatat 4 tahap (staging, dimensi, fakta, data quality check) dan
berakhir dengan "Complete ETL Pipeline Successfully Executed". Run dari nol lewat `run_all.ps1`
selesai tanpa error dan menghasilkan angka yang sama dengan run sebelumnya.

## 4. Kendala dan Solusi

**1. Memakai compose versi lite.** README memakai stack penuh (Airflow, PostgreSQL, Redis,
Grafana, Superset, Metabase, Jupyter). Kami membuat `docker-compose.lite.yml` yang hanya berisi
SQL Server, inisialisasi skema, dan ETL. Alasannya: stack penuh di README butuh sekitar 5 sampai
10 menit untuk start serta minimal 8 GB RAM dan 20 GB disk, sedangkan yang dinilai di tugas ini
adalah skema, ETL, dan validasi otomatis. Dengan versi lite, seluruh proses bisa dijalankan dari
nol dengan satu perintah dan selesai dalam beberapa menit. Dampaknya hanya di orkestrasi, skema
dan logika ETL tidak diubah, dan jumlah baris semua tabel sama dengan README.

**2. Angka efisiensi 95,66% tidak bisa direproduksi.** Angka ini hanya muncul sebagai teks di
bagian Dashboard README tanpa query. Hasil kami dari seluruh data adalah 95,60% (rata-rata
`efficiency_ratio`), dan 95,61% kalau dihitung per ID unik. Query dashboard di
`configure_dashboards.py` memakai jendela 7 hari dengan `GETDATE()`, sehingga hasilnya
bergantung tanggal eksekusi. Kami mencoba beberapa tanggal awal jendela (2025-05-15 sampai
2025-05-30) dan nilainya bervariasi dari 95,38 sampai 95,89, jadi tidak ada tanggal yang bisa
dibuktikan sebagai asal angka README. Kami tidak memilih tanggal hanya supaya angkanya pas.
Statusnya dibiarkan WARN (bukan FAIL), dengan selisih 0,06 poin.

**3. Angka produksi README ternyata memakai filter tanggal.** Total penuh kami (Metal 477.837
dan Ore 118.363) berbeda dari README. Setelah dicari, Metal dan Ore sama-sama cocok persis
(434.721 dan 112.687) dengan filter `date >= 2025-05-01`. Jumlah baris EquipmentUsage sejak
tanggal itu juga 118.446, sama dengan komentar "118,446 rows (last 30 days)" di
`configure_dashboards.py`. Jadi uji agregat di `validate.sql` memakai tanggal tetap itu supaya
hasilnya reproducible. Catatan: ini hasil rekonstruksi kami, bukan logika yang tertulis di README.

**4. Jumlah baris fakta jauh lebih besar dari ID unik.** FactEquipmentUsage punya 236.892 baris
untuk 1.150 ID unik, FactProduction 2.261 untuk 1.150, dan FactFinancialTransaction 115.901
untuk 1.150. Jumlah baris ini sama persis dengan README, jadi kami anggap itu perilaku bawaan
ETL repo. Dugaan kami penyebabnya join ke DimSite (1.747 baris untuk hanya 26 nama unik), tapi
logika ETL bersifat normatif sehingga tidak kami ubah. Di `validate.sql` dicatat sebagai INFO.

**5. Rentang tanggal data contoh tidak lazim.** DimTime berisi 2022-01-02 sampai 2028-06-23
(termasuk tanggal masa depan) dan data produksi tidak ada di tahun 2023 dan 2024. Data dipakai
apa adanya sesuai aturan tugas, sehingga query OLAP memakai tahun 2025 sampai 2027.

**6. Kendala teknis saat eksekusi.**

- SQL yang di-paste langsung ke PowerShell menghasilkan banyak error. Solusi: SQL disimpan ke
  file di folder `tests/` lalu dijalankan lewat `sqlcmd -i`.
- File `run_all.ps1` sempat belum tersimpan di folder repo sehingga `-File` gagal. Solusi: file
  dibuat ulang lalu di-commit ke Git.
- Salah satu run `run_all.ps1` sempat berhenti di tengah (container ETL masih berstatus
  Created). Solusi: dijalankan ulang dari awal dan dibiarkan sampai selesai. SQL Server butuh
  sekitar 1 menit untuk healthy, lalu ETL sekitar 1 sampai 3 menit.
- Teks error merah `NativeCommandError` saat `docker compose` jalan adalah efek samping
  PowerShell karena Docker menulis progress ke stderr, bukan kegagalan.

**7. Keterbatasan.** Layanan dashboard (Grafana, Superset, Metabase) dan Airflow tidak dijalankan.
Fungsinya digantikan query OLAP langsung ke SQL Server dan `run_etl.py`.