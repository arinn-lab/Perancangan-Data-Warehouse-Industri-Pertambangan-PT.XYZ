SET NOCOUNT ON;

SELECT 'DimTime' AS sumber, MIN(date) AS tgl_min, MAX(date) AS tgl_max FROM dim.DimTime
UNION ALL
SELECT 'FactProduction', MIN(dt.date), MAX(dt.date)
FROM fact.FactProduction fp JOIN dim.DimTime dt ON fp.time_key = dt.time_key;

;WITH harian AS (
    SELECT dt.date AS tgl,
           SUM(CASE WHEN dm.material_type='Metal' THEN fp.produced_volume ELSE 0 END) AS metal,
           SUM(CASE WHEN dm.material_type='Ore'   THEN fp.produced_volume ELSE 0 END) AS ore
    FROM fact.FactProduction fp
    JOIN dim.DimTime dt ON fp.time_key = dt.time_key
    JOIN dim.DimMaterial dm ON fp.material_key = dm.material_key
    GROUP BY dt.date
), kum AS (
    SELECT tgl,
           SUM(metal) OVER (ORDER BY tgl DESC ROWS UNBOUNDED PRECEDING) AS metal_dari_akhir,
           SUM(ore)   OVER (ORDER BY tgl DESC ROWS UNBOUNDED PRECEDING) AS ore_dari_akhir,
           SUM(metal) OVER (ORDER BY tgl ASC  ROWS UNBOUNDED PRECEDING) AS metal_dari_awal,
           SUM(ore)   OVER (ORDER BY tgl ASC  ROWS UNBOUNDED PRECEDING) AS ore_dari_awal
    FROM harian
)
SELECT * FROM kum
WHERE metal_dari_akhir = 434721 OR ore_dari_akhir = 112687
   OR metal_dari_awal  = 434721 OR ore_dari_awal  = 112687;