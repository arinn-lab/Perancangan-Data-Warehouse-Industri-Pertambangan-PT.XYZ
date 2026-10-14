SET NOCOUNT ON;

SELECT m.material_type, SUM(f.produced_volume) AS total_produksi
FROM fact.FactProduction f
JOIN dim.DimTime t ON f.time_key = t.time_key
JOIN dim.DimMaterial m ON f.material_key = m.material_key
WHERE t.date >= '2025-05-01'
GROUP BY m.material_type
ORDER BY m.material_type;

SELECT CASE WHEN t.date >= '2025-05-01' THEN 'sejak_2025-05-01' ELSE 'sebelum_2025-05-01' END AS periode,
       CAST(AVG(CAST(f.efficiency_ratio AS FLOAT))*100 AS DECIMAL(10,4)) AS efisiensi_avg_ratio,
       CAST(SUM(f.operating_hours)*100.0/NULLIF(SUM(f.operating_hours+f.downtime_hours),0) AS DECIMAL(10,4)) AS efisiensi_sum_jam,
       COUNT(*) AS n_baris
FROM fact.FactEquipmentUsage f
JOIN dim.DimTime t ON f.time_key = t.time_key
GROUP BY CASE WHEN t.date >= '2025-05-01' THEN 'sejak_2025-05-01' ELSE 'sebelum_2025-05-01' END;