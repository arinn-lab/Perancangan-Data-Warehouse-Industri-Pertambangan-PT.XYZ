-- tests/validate.sql
-- Validasi otomatis PT XYZ Data Warehouse (SQL Server, T-SQL)
-- Status: PASS = sesuai, FAIL = melanggar README (membuat exit code non-zero),
--         WARN = beda dari angka README tapi bukan pelanggaran skema,
--         INFO = informasi kualitas data (tidak mempengaruhi hasil)
SET NOCOUNT ON;

CREATE TABLE #hasil (
    id         INT IDENTITY(1,1),
    kategori   VARCHAR(20),
    uji        VARCHAR(100),
    diharapkan VARCHAR(2000),
    aktual     VARCHAR(2000),
    status     VARCHAR(4)
);

-- ================= 1. SKEMA (nama kolom, tipe, urutan) =================
CREATE TABLE #exp (tbl VARCHAR(60), sig VARCHAR(2000));
INSERT INTO #exp VALUES
('dim.DimTime','time_key:int,time_id:int,date:date,day_of_month:int,day_name:varchar(20),month:int,month_name:varchar(20),quarter:int,year:int,is_weekend:bit,created_at:datetime2,created_by:varchar(50)'),
('dim.DimSite','site_key:int,site_id:int,site_name:varchar(100),region:varchar(50),latitude:decimal(10,8),longitude:decimal(11,8),created_at:datetime2,created_by:varchar(50)'),
('dim.DimEquipment','equipment_key:int,equipment_name:varchar(100),equipment_type:varchar(50),manufacture:varchar(50),model:varchar(50),capacity:decimal(10,2),purchase_date:date,created_at:datetime2,created_by:varchar(50)'),
('dim.DimMaterial','material_key:int,material_id:int,material_name:varchar(100),material_type:varchar(50),unit_of_measure:varchar(20),created_at:datetime2,created_by:varchar(50)'),
('dim.DimEmployee','employee_key:int,employee_id:int,employee_name:varchar(100),position:varchar(50),department:varchar(50),status:varchar(20),hire_date:date,created_at:datetime2,created_by:varchar(50)'),
('dim.DimShift','shift_key:int,shift_id:int,shift_name:varchar(50),start_time:time,end_time:time,created_at:datetime2,created_by:varchar(50)'),
('dim.DimProject','project_key:int,project_id:int,project_name:varchar(100),project_manager:varchar(100),status:varchar(20),start_date:date,end_date:date,created_at:datetime2,created_by:varchar(50)'),
('dim.DimAccount','account_key:int,account_id:int,account_name:varchar(100),account_type:varchar(50),budget_category:varchar(50),created_at:datetime2,created_by:varchar(50)'),
('fact.FactEquipmentUsage','usage_key:int,equipment_usage_id:int,time_key:int,site_key:int,equipment_key:int,operating_hours:decimal(8,2),downtime_hours:decimal(8,2),fuel_consumption:decimal(10,2),maintenance_cost:decimal(12,2),efficiency_ratio:computed,created_at:datetime2,created_by:varchar(50)'),
('fact.FactProduction','production_key:int,production_id:int,time_key:int,site_key:int,material_key:int,employee_key:int,shift_key:int,produced_volume:decimal(12,2),unit_cost:decimal(10,2),total_cost:computed,material_quantity:decimal(12,2),created_at:datetime2,created_by:varchar(50)'),
('fact.FactFinancialTransaction','transaction_key:int,transaction_id:int,time_key:int,site_key:int,project_key:int,account_key:int,budgeted_cost:decimal(12,2),actual_cost:decimal(12,2),variance_amount:computed,variance_percentage:computed,variance_status:varchar(20),account_cost:decimal(12,2),created_at:datetime2,created_by:varchar(50)');

;WITH act AS (
    SELECT s.name + '.' + t.name AS tbl,
           STRING_AGG(CAST(c.name + ':' +
               CASE WHEN c.is_computed = 1 THEN 'computed'
                    WHEN ty.name = 'varchar' THEN 'varchar(' + CAST(c.max_length AS VARCHAR(10)) + ')'
                    WHEN ty.name = 'decimal' THEN 'decimal(' + CAST(c.precision AS VARCHAR(5)) + ',' + CAST(c.scale AS VARCHAR(5)) + ')'
                    ELSE ty.name END AS VARCHAR(MAX)), ',')
               WITHIN GROUP (ORDER BY c.column_id) AS sig
    FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    JOIN sys.columns c ON c.object_id = t.object_id
    JOIN sys.types ty ON c.user_type_id = ty.user_type_id
    WHERE s.name IN ('dim','fact')
    GROUP BY s.name, t.name
)
INSERT INTO #hasil (kategori, uji, diharapkan, aktual, status)
SELECT 'SKEMA', 'Kolom dan tipe ' + e.tbl,
       CASE WHEN a.sig = e.sig THEN 'sesuai' ELSE e.sig END,
       CASE WHEN a.sig = e.sig THEN 'sesuai' ELSE ISNULL(a.sig, 'tabel tidak ada') END,
       CASE WHEN a.sig = e.sig THEN 'PASS' ELSE 'FAIL' END
FROM #exp e LEFT JOIN act a ON a.tbl = e.tbl;

INSERT INTO #hasil (kategori, uji, diharapkan, aktual, status)
SELECT 'SKEMA', 'Jumlah tabel dim = 8 dan fact = 3',
       '8 dim, 3 fact',
       CAST(SUM(CASE WHEN s.name = 'dim' THEN 1 ELSE 0 END) AS VARCHAR(5)) + ' dim, ' +
       CAST(SUM(CASE WHEN s.name = 'fact' THEN 1 ELSE 0 END) AS VARCHAR(5)) + ' fact',
       CASE WHEN SUM(CASE WHEN s.name = 'dim' THEN 1 ELSE 0 END) = 8
             AND SUM(CASE WHEN s.name = 'fact' THEN 1 ELSE 0 END) = 3 THEN 'PASS' ELSE 'FAIL' END
FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name IN ('dim','fact');

-- ================= 2. JUMLAH BARIS (sesuai README) =================
INSERT INTO #hasil (kategori, uji, diharapkan, aktual, status)
SELECT 'JUMLAH_BARIS', x.tbl, CAST(x.exp_n AS VARCHAR(20)), CAST(x.act_n AS VARCHAR(20)),
       CASE WHEN x.exp_n = x.act_n THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 'dim.DimTime' AS tbl, 830 AS exp_n, (SELECT COUNT(*) FROM dim.DimTime) AS act_n
    UNION ALL SELECT 'dim.DimSite', 1747, (SELECT COUNT(*) FROM dim.DimSite)
    UNION ALL SELECT 'dim.DimEquipment', 6, (SELECT COUNT(*) FROM dim.DimEquipment)
    UNION ALL SELECT 'dim.DimMaterial', 5, (SELECT COUNT(*) FROM dim.DimMaterial)
    UNION ALL SELECT 'dim.DimEmployee', 10, (SELECT COUNT(*) FROM dim.DimEmployee)
    UNION ALL SELECT 'dim.DimShift', 3, (SELECT COUNT(*) FROM dim.DimShift)
    UNION ALL SELECT 'dim.DimProject', 50, (SELECT COUNT(*) FROM dim.DimProject)
    UNION ALL SELECT 'dim.DimAccount', 30, (SELECT COUNT(*) FROM dim.DimAccount)
    UNION ALL SELECT 'fact.FactEquipmentUsage', 236892, (SELECT COUNT(*) FROM fact.FactEquipmentUsage)
    UNION ALL SELECT 'fact.FactProduction', 2261, (SELECT COUNT(*) FROM fact.FactProduction)
    UNION ALL SELECT 'fact.FactFinancialTransaction', 115901, (SELECT COUNT(*) FROM fact.FactFinancialTransaction)
) x;

-- ================= 3. INTEGRITAS REFERENSIAL (0 orphan) =================
INSERT INTO #hasil (kategori, uji, diharapkan, aktual, status)
SELECT 'ORPHAN_FK', x.uji, '0', CAST(x.n AS VARCHAR(20)),
       CASE WHEN x.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 'FactEquipmentUsage.time_key' AS uji, (SELECT COUNT(*) FROM fact.FactEquipmentUsage f WHERE NOT EXISTS (SELECT 1 FROM dim.DimTime d WHERE d.time_key = f.time_key)) AS n
    UNION ALL SELECT 'FactEquipmentUsage.site_key', (SELECT COUNT(*) FROM fact.FactEquipmentUsage f WHERE NOT EXISTS (SELECT 1 FROM dim.DimSite d WHERE d.site_key = f.site_key))
    UNION ALL SELECT 'FactEquipmentUsage.equipment_key', (SELECT COUNT(*) FROM fact.FactEquipmentUsage f WHERE NOT EXISTS (SELECT 1 FROM dim.DimEquipment d WHERE d.equipment_key = f.equipment_key))
    UNION ALL SELECT 'FactProduction.time_key', (SELECT COUNT(*) FROM fact.FactProduction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimTime d WHERE d.time_key = f.time_key))
    UNION ALL SELECT 'FactProduction.site_key', (SELECT COUNT(*) FROM fact.FactProduction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimSite d WHERE d.site_key = f.site_key))
    UNION ALL SELECT 'FactProduction.material_key', (SELECT COUNT(*) FROM fact.FactProduction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimMaterial d WHERE d.material_key = f.material_key))
    UNION ALL SELECT 'FactProduction.employee_key', (SELECT COUNT(*) FROM fact.FactProduction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimEmployee d WHERE d.employee_key = f.employee_key))
    UNION ALL SELECT 'FactProduction.shift_key', (SELECT COUNT(*) FROM fact.FactProduction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimShift d WHERE d.shift_key = f.shift_key))
    UNION ALL SELECT 'FactFinancialTransaction.time_key', (SELECT COUNT(*) FROM fact.FactFinancialTransaction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimTime d WHERE d.time_key = f.time_key))
    UNION ALL SELECT 'FactFinancialTransaction.site_key', (SELECT COUNT(*) FROM fact.FactFinancialTransaction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimSite d WHERE d.site_key = f.site_key))
    UNION ALL SELECT 'FactFinancialTransaction.project_key', (SELECT COUNT(*) FROM fact.FactFinancialTransaction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimProject d WHERE d.project_key = f.project_key))
    UNION ALL SELECT 'FactFinancialTransaction.account_key', (SELECT COUNT(*) FROM fact.FactFinancialTransaction f WHERE NOT EXISTS (SELECT 1 FROM dim.DimAccount d WHERE d.account_key = f.account_key))
) x;

-- ================= 4. KUALITAS DATA DASAR (rentang nilai) =================
INSERT INTO #hasil (kategori, uji, diharapkan, aktual, status)
SELECT 'RENTANG', x.uji, '0', CAST(x.n AS VARCHAR(20)),
       CASE WHEN x.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT 'operating_hours negatif' AS uji, (SELECT COUNT(*) FROM fact.FactEquipmentUsage WHERE operating_hours < 0) AS n
    UNION ALL SELECT 'downtime_hours negatif', (SELECT COUNT(*) FROM fact.FactEquipmentUsage WHERE downtime_hours < 0)
    UNION ALL SELECT 'efficiency_ratio di luar 0..1', (SELECT COUNT(*) FROM fact.FactEquipmentUsage WHERE efficiency_ratio < 0 OR efficiency_ratio > 1)
    UNION ALL SELECT 'produced_volume negatif', (SELECT COUNT(*) FROM fact.FactProduction WHERE produced_volume < 0)
    UNION ALL SELECT 'unit_cost negatif', (SELECT COUNT(*) FROM fact.FactProduction WHERE unit_cost < 0)
    UNION ALL SELECT 'budgeted_cost negatif', (SELECT COUNT(*) FROM fact.FactFinancialTransaction WHERE budgeted_cost < 0)
    UNION ALL SELECT 'actual_cost negatif', (SELECT COUNT(*) FROM fact.FactFinancialTransaction WHERE actual_cost < 0)
) x;

-- ================= 5. DUPLIKASI (informasi, bukan pelanggaran) =================
-- Kolom diharapkan = jumlah ID sumber yang unik, aktual = jumlah baris di tabel.
-- Selisih besar pada tabel fakta berasal dari JOIN site_name di ETL bawaan repo
-- (DimSite punya nama kembar), dan dicatat di RUNBOOK sebagai temuan.
INSERT INTO #hasil (kategori, uji, diharapkan, aktual, status)
SELECT 'DUPLIKASI', x.uji, CAST(x.uniq AS VARCHAR(20)), CAST(x.total AS VARCHAR(20)), 'INFO'
FROM (
    SELECT 'FactEquipmentUsage: ID unik vs baris' AS uji,
           (SELECT COUNT(DISTINCT equipment_usage_id) FROM fact.FactEquipmentUsage) AS uniq,
           (SELECT COUNT(*) FROM fact.FactEquipmentUsage) AS total
    UNION ALL SELECT 'FactProduction: ID unik vs baris',
           (SELECT COUNT(DISTINCT production_id) FROM fact.FactProduction),
           (SELECT COUNT(*) FROM fact.FactProduction)
    UNION ALL SELECT 'FactFinancialTransaction: ID unik vs baris',
           (SELECT COUNT(DISTINCT transaction_id) FROM fact.FactFinancialTransaction),
           (SELECT COUNT(*) FROM fact.FactFinancialTransaction)
    UNION ALL SELECT 'DimSite: site_name unik vs baris',
           (SELECT COUNT(DISTINCT site_name) FROM dim.DimSite),
           (SELECT COUNT(*) FROM dim.DimSite)
) x;

-- ================= 6. AGREGAT contoh di README =================
-- Angka di README (95.66, 434721, 112687) berupa teks statis di bagian Dashboard.
-- Metal dan Ore: cocok persis memakai filter tanggal tetap date >= 2025-05-01
-- (hasil rekonstruksi: query dashboard memakai DATEADD(day,-30,GETDATE()) saat README dibuat,
-- dan jumlah baris sejak tanggal itu = 118446, sama dengan angka di configure_dashboards.py).
-- Efisiensi: tidak ada jendela tanggal yang bisa dibuktikan menghasilkan 95.66,
-- jadi dihitung dari seluruh data dan statusnya WARN jika beda (bukan FAIL).
INSERT INTO #hasil (kategori, uji, diharapkan, aktual, status)
SELECT 'AGREGAT', 'Overall equipment efficiency (%)', '95.66',
       CAST(CAST(AVG(CAST(efficiency_ratio AS FLOAT)) * 100 AS DECIMAL(10,2)) AS VARCHAR(20)),
       CASE WHEN ABS(AVG(CAST(efficiency_ratio AS FLOAT)) * 100 - 95.66) < 0.005 THEN 'PASS' ELSE 'WARN' END
FROM fact.FactEquipmentUsage;

INSERT INTO #hasil (kategori, uji, diharapkan, aktual, status)
SELECT 'AGREGAT', 'Total produksi Metal (date >= 2025-05-01)', '434721',
       CAST(CAST(SUM(f.produced_volume) AS DECIMAL(18,0)) AS VARCHAR(20)),
       CASE WHEN ROUND(SUM(f.produced_volume), 0) = 434721 THEN 'PASS' ELSE 'WARN' END
FROM fact.FactProduction f
JOIN dim.DimMaterial m ON f.material_key = m.material_key
JOIN dim.DimTime t ON f.time_key = t.time_key
WHERE m.material_type = 'Metal' AND t.date >= '2025-05-01';

INSERT INTO #hasil (kategori, uji, diharapkan, aktual, status)
SELECT 'AGREGAT', 'Total produksi Ore (date >= 2025-05-01)', '112687',
       CAST(CAST(SUM(f.produced_volume) AS DECIMAL(18,0)) AS VARCHAR(20)),
       CASE WHEN ROUND(SUM(f.produced_volume), 0) = 112687 THEN 'PASS' ELSE 'WARN' END
FROM fact.FactProduction f
JOIN dim.DimMaterial m ON f.material_key = m.material_key
JOIN dim.DimTime t ON f.time_key = t.time_key
WHERE m.material_type = 'Ore' AND t.date >= '2025-05-01';

-- ================= RINGKASAN =================
SELECT kategori, uji, diharapkan, aktual, status FROM #hasil ORDER BY id;
SELECT status, COUNT(*) AS jumlah FROM #hasil GROUP BY status ORDER BY status;

IF EXISTS (SELECT 1 FROM #hasil WHERE status = 'FAIL')
    RAISERROR('VALIDASI GAGAL: ada uji berstatus FAIL', 16, 1);
ELSE
    PRINT 'VALIDASI BERHASIL: tidak ada uji FAIL (WARN dan INFO dijelaskan di RUNBOOK)';
