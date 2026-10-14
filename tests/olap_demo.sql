SET NOCOUNT ON;

PRINT '=== 1. SLICE: produksi per material, tahun 2025 saja ===';
SELECT m.material_type, SUM(f.produced_volume) AS total_produksi
FROM fact.FactProduction f
JOIN dim.DimTime t ON f.time_key = t.time_key
JOIN dim.DimMaterial m ON f.material_key = m.material_key
WHERE t.[year] = 2025
GROUP BY m.material_type
ORDER BY m.material_type;

PRINT '=== 2. DICE: Gold dan Copper, kuartal 1 dan 2, tahun 2026 ===';
SELECT m.material_name, t.[quarter], SUM(f.produced_volume) AS total_produksi
FROM fact.FactProduction f
JOIN dim.DimTime t ON f.time_key = t.time_key
JOIN dim.DimMaterial m ON f.material_key = m.material_key
WHERE t.[year] = 2026 AND t.[quarter] IN (1, 2) AND m.material_name IN ('Gold', 'Copper')
GROUP BY m.material_name, t.[quarter]
ORDER BY m.material_name, t.[quarter];

PRINT '=== 3. ROLL-UP: tahun -> kuartal -> total ===';
SELECT t.[year], t.[quarter], SUM(f.produced_volume) AS total_produksi
FROM fact.FactProduction f
JOIN dim.DimTime t ON f.time_key = t.time_key
WHERE t.[year] BETWEEN 2026 AND 2027
GROUP BY ROLLUP (t.[year], t.[quarter])
ORDER BY t.[year], t.[quarter];

PRINT '=== 4. DRILL-DOWN: tahun 2025, kuartal 2, per bulan ===';
SELECT t.[year], t.[quarter], t.[month], t.month_name, SUM(f.produced_volume) AS total_produksi
FROM fact.FactProduction f
JOIN dim.DimTime t ON f.time_key = t.time_key
WHERE t.[year] = 2025 AND t.[quarter] = 2
GROUP BY t.[year], t.[quarter], t.[month], t.month_name
ORDER BY t.[month];

PRINT '=== 5. PIVOT: produksi per tahun (baris) x material (kolom) ===';
SELECT t.[year],
       SUM(CASE WHEN m.material_name = 'Copper' THEN f.produced_volume ELSE 0 END) AS Copper,
       SUM(CASE WHEN m.material_name = 'Gold'   THEN f.produced_volume ELSE 0 END) AS Gold,
       SUM(CASE WHEN m.material_name = 'Iron'   THEN f.produced_volume ELSE 0 END) AS Iron,
       SUM(CASE WHEN m.material_name = 'Nickel' THEN f.produced_volume ELSE 0 END) AS Nickel,
       SUM(CASE WHEN m.material_name = 'Coal'   THEN f.produced_volume ELSE 0 END) AS Coal
FROM fact.FactProduction f
JOIN dim.DimTime t ON f.time_key = t.time_key
JOIN dim.DimMaterial m ON f.material_key = m.material_key
GROUP BY t.[year]
ORDER BY t.[year];