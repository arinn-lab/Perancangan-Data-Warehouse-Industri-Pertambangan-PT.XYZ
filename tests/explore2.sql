SET NOCOUNT ON;
SELECT 'A_stg_avg_ratio' AS metrik,
       CAST(AVG(CAST(operating_hours AS FLOAT)/NULLIF(operating_hours+downtime_hours,0))*100 AS DECIMAL(10,4)) AS nilai
FROM staging.EquipmentUsage
UNION ALL
SELECT 'B_stg_sum_jam',
       CAST(SUM(operating_hours)*100.0/NULLIF(SUM(operating_hours+downtime_hours),0) AS DECIMAL(10,4))
FROM staging.EquipmentUsage
UNION ALL
SELECT 'C_fact_avg_ratio_id_unik',
       CAST(AVG(r)*100 AS DECIMAL(10,4))
FROM (SELECT equipment_usage_id, MAX(CAST(efficiency_ratio AS FLOAT)) AS r
      FROM fact.FactEquipmentUsage GROUP BY equipment_usage_id) x
UNION ALL
SELECT 'D_fact_sum_jam_id_unik',
       CAST(SUM(oh)*100.0/NULLIF(SUM(oh+dh),0) AS DECIMAL(10,4))
FROM (SELECT equipment_usage_id, MAX(operating_hours) AS oh, MAX(downtime_hours) AS dh
      FROM fact.FactEquipmentUsage GROUP BY equipment_usage_id) y;

SELECT 'staging' AS sumber, material_type,
       SUM(produced_volume) AS sum_volume, SUM(quantity) AS sum_qty,
       COUNT(*) AS n_baris, COUNT(DISTINCT production_id) AS n_id
FROM staging.Production
GROUP BY material_type
ORDER BY material_type;

SELECT 'fact_id_unik' AS sumber, m.material_type,
       SUM(x.produced_volume) AS sum_volume, SUM(x.material_quantity) AS sum_qty,
       COUNT(*) AS n_baris
FROM (SELECT production_id, material_key,
             MAX(produced_volume) AS produced_volume,
             MAX(material_quantity) AS material_quantity
      FROM fact.FactProduction GROUP BY production_id, material_key) x
JOIN dim.DimMaterial m ON x.material_key = m.material_key
GROUP BY m.material_type
ORDER BY m.material_type;

SELECT (SELECT COUNT(DISTINCT equipment_usage_id) FROM fact.FactEquipmentUsage) AS id_unik_equipment,
       (SELECT COUNT(DISTINCT production_id) FROM fact.FactProduction) AS id_unik_production,
       (SELECT COUNT(DISTINCT transaction_id) FROM fact.FactFinancialTransaction) AS id_unik_transaksi;