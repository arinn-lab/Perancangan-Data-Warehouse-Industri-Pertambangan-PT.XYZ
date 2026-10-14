SET NOCOUNT ON;
SELECT 'efisiensi_avg_ratio' AS metrik,
       CAST(AVG(CAST(efficiency_ratio AS FLOAT))*100 AS DECIMAL(10,4)) AS nilai
FROM fact.FactEquipmentUsage
UNION ALL
SELECT 'efisiensi_sum_jam',
       CAST(SUM(operating_hours)*100.0/NULLIF(SUM(operating_hours+downtime_hours),0) AS DECIMAL(10,4))
FROM fact.FactEquipmentUsage;

SELECT m.material_type, m.material_name,
       SUM(f.produced_volume) AS sum_volume,
       SUM(f.material_quantity) AS sum_qty,
       COUNT(*) AS n_baris
FROM fact.FactProduction f
JOIN dim.DimMaterial m ON f.material_key = m.material_key
GROUP BY m.material_type, m.material_name
ORDER BY m.material_type, m.material_name;

SELECT m.material_type,
       SUM(f.produced_volume) AS sum_volume,
       SUM(f.material_quantity) AS sum_qty
FROM fact.FactProduction f
JOIN dim.DimMaterial m ON f.material_key = m.material_key
GROUP BY m.material_type
ORDER BY m.material_type;