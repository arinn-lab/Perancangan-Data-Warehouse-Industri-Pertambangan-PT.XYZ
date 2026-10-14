\## 3. Bukti Hasil



\### 3.1 Hasil validasi otomatis



Dijalankan dengan satu perintah (juga otomatis di langkah 4 `run\_all.ps1`):



```

docker compose -f docker-compose.lite.yml exec -T sqlserver bash -c '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $MSSQL\_SA\_PASSWORD -C -N -d PTXYZ\_DataWarehouse -b -W -i /tests/validate.sql'

```



Ringkasan: \*\*44 PASS, 1 WARN, 4 INFO, 0 FAIL\*\*. Output lengkap ada di `logs/bukti\_validasi.txt`.



| Kategori | Yang diuji | Hasil |

|----------|-----------|-------|

| Skema | nama kolom, tipe, dan urutan 11 tabel (8 dim, 3 fact) | 12 PASS |

| Jumlah baris | 11 tabel dibandingkan dengan angka di README | 11 PASS |

| Integritas | 12 foreign key di 3 tabel fakta, jumlah orphan | 12 PASS, 0 orphan |

| Rentang nilai | jam operasi, downtime, efficiency\_ratio, volume, biaya | 7 PASS |

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



\### 3.2 Hasil agregat dibanding README



| Metrik di README | Nilai README | Hasil kami | Status |

|------------------|-------------:|-----------:|--------|

| Produksi Metal (`date >= 2025-05-01`) | 434.721 | 434.721 | PASS |

| Produksi Ore (`date >= 2025-05-01`) | 112.687 | 112.687 | PASS |

| Overall equipment efficiency | 95,66% | 95,60% | WARN |



Penjelasan ada di bagian 4.



\### 3.3 Query OLAP



File: `tests/olap\_demo.sql`, output di `logs/bukti\_olap.txt`. Semua memakai FactProduction

yang digabung dengan DimTime dan DimMaterial.



1\. \*\*Slice\*\* (tahun 2025): Metal 94.465 dan Ore 16.506.

2\. \*\*Dice\*\* (Gold dan Copper, kuartal 1 dan 2, tahun 2026): Copper Q1 7.742, Copper Q2 6.806, Gold Q1 4.439, Gold Q2 9.190.

3\. \*\*Roll-up\*\* (tahun 2026 dan 2027, tahun ke kuartal ke total): 2026 = 150.218, 2027 = 197.957, total = 348.175.

4\. \*\*Drill-down\*\* (tahun 2025, kuartal 2, per bulan): Mei 15.640 dan Juni 15.507.

5\. \*\*Pivot\*\* (tahun dan material):



| Tahun | Copper | Gold | Iron | Nickel | Coal |

|------:|-------:|-----:|-----:|-------:|-----:|

| 2022 | 13.253 | 11.482 | 12.526 | 5.855 | 5.676 |

| 2025 | 26.429 | 25.629 | 22.104 | 20.303 | 16.506 |

| 2026 | 29.501 | 29.231 | 28.297 | 34.890 | 28.299 |

| 2027 | 41.412 | 45.165 | 29.917 | 39.981 | 41.482 |

| 2028 | 17.320 | 20.443 | 10.672 | 13.427 | 26.400 |



Hasil roll-up dan pivot saling cocok: jumlah satu baris tahun di pivot sama dengan subtotal tahun

yang sama di roll-up (2026 = 150.218 dan 2027 = 197.957).



\### 3.4 Log ETL



`logs/etl\_execution.log` mencatat 4 tahap (staging, dimensi, fakta, data quality check) dan

berakhir dengan "Complete ETL Pipeline Successfully Executed". Run dari nol lewat `run\_all.ps1`

selesai dengan exit code 0 dan menghasilkan angka yang sama dengan run sebelumnya.



\## 4. Kendala dan Solusi



\*\*1. Memakai compose versi lite.\*\* README memakai stack penuh (Airflow, PostgreSQL, Redis,

Grafana, Superset, Metabase, Jupyter). Kami membuat `docker-compose.lite.yml` yang hanya berisi

SQL Server, inisialisasi skema, dan ETL. Alasannya: \stack penuh di README butuh sekitar 5 sampai 10 menit untuk start serta minimal 8 GB RAM dan 20 GB disk, sedangkan yang dinilai di tugas ini adalah skema, ETL, dan validasi otomatis. Dengan versi lite, seluruh proses bisa dijalankan dari nol dengan satu perintah dan selesai dalam beberapa menit. Dampaknya hanya di orkestrasi,

skema dan logika ETL tidak diubah, dan jumlah baris semua tabel sama dengan README.



\*\*2. Angka efisiensi 95,66% tidak bisa direproduksi.\*\* Angka ini hanya muncul sebagai teks di

bagian Dashboard README tanpa query. Hasil kami dari seluruh data adalah 95,60% (rata-rata

`efficiency\_ratio`), dan 95,61% kalau dihitung per ID unik. Query dashboard di

`configure\_dashboards.py` memakai jendela 7 hari dengan `GETDATE()`, sehingga hasilnya

bergantung tanggal eksekusi. Kami mencoba beberapa tanggal awal jendela (2025-05-15 sampai

2025-05-30) dan nilainya bervariasi dari 95,38 sampai 95,89, jadi tidak ada tanggal yang bisa

dibuktikan sebagai asal angka README. Kami tidak memilih tanggal hanya supaya angkanya pas.

Statusnya dibiarkan WARN (bukan FAIL), dengan selisih 0,06 poin.



\*\*3. Angka produksi README ternyata memakai filter tanggal.\*\* Total penuh kami (Metal 477.837

dan Ore 118.363) berbeda dari README. Setelah dicari, Metal dan Ore sama-sama cocok persis

(434.721 dan 112.687) dengan filter `date >= 2025-05-01`. Jumlah baris EquipmentUsage sejak

tanggal itu juga 118.446, sama dengan komentar "118,446 rows (last 30 days)" di

`configure\_dashboards.py`. Jadi uji agregat di `validate.sql` memakai tanggal tetap itu supaya

hasilnya reproducible. Catatan: ini hasil rekonstruksi kami, bukan logika yang tertulis di README.



\*\*4. Jumlah baris fakta jauh lebih besar dari ID unik.\*\* FactEquipmentUsage punya 236.892 baris

untuk 1.150 ID unik, FactProduction 2.261 untuk 1.150, dan FactFinancialTransaction 115.901

untuk 1.150. Jumlah baris ini sama persis dengan README, jadi kami anggap itu perilaku bawaan

ETL repo. Dugaan kami penyebabnya join ke DimSite (1.747 baris untuk hanya 26 nama unik), tapi

logika ETL bersifat normatif sehingga tidak kami ubah. Di `validate.sql` dicatat sebagai INFO.



\*\*5. Rentang tanggal data contoh tidak lazim.\*\* DimTime berisi 2022-01-02 sampai 2028-06-23

(termasuk tanggal masa depan) dan data produksi tidak ada di tahun 2023 dan 2024. Data dipakai

apa adanya sesuai aturan tugas, sehingga query OLAP memakai tahun 2025 sampai 2027.



\*\*6. Kendala teknis saat eksekusi.\*\*

\- SQL yang di-paste langsung ke PowerShell menghasilkan banyak error. Solusi: SQL disimpan ke

&#x20; file di folder `tests/` lalu dijalankan lewat `sqlcmd -i`.

\- File `run\_all.ps1` sempat belum tersimpan di folder repo sehingga `-File` gagal. Solusi: file

&#x20; dibuat ulang lalu di-commit ke Git.

\- Run pertama terpotong karena window PowerShell terganggu saat `docker compose up`. Solusi:

&#x20; jalankan ulang dan biarkan sampai prompt kembali. SQL Server butuh sekitar 1 menit untuk

&#x20; healthy, lalu ETL sekitar 1 sampai 3 menit.

\- Teks error merah `NativeCommandError` saat `docker compose` jalan adalah efek samping

&#x20; PowerShell karena Docker menulis progress ke stderr, bukan kegagalan.



\*\*7. Keterbatasan.\*\* Layanan dashboard (Grafana, Superset, Metabase) dan Airflow tidak dijalankan.

Fungsinya digantikan query OLAP langsung ke SQL Server dan `run\_etl.py`.

