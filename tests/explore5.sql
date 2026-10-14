SET NOCOUNT ON;
;WITH batas AS (
    SELECT DATEADD(day, n, CAST('2025-05-15' AS date)) AS tgl
    FROM (SELECT TOP 30 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n FROM sys.objects) x
)
SELECT b.tgl AS date_mulai,
       CAST(AVG(CAST(f.operating_hours AS FLOAT) / NULLIF(f.operating_hours + f.downtime_hours,0) * 100) AS DECIMAL(10,4)) AS efisiensi,
       COUNT(*) AS n_baris
FROM batas b
JOIN dim.DimTime t ON t.date >= b.tgl
JOIN fact.FactEquipmentUsage f ON f.time_key = t.time_key
GROUP BY b.tgl
ORDER BY b.tgl;