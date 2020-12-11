-- All Statistics by Year
SELECT
    YEAR(Date) AS Year,
    COUNT(*) AS Incidents,
    SUM(Deaths) AS Deaths,
    SUM(Wounded) AS Wounded,
    SUM(TotalCasualties) AS TotalCasualties
FROM incident
GROUP BY Year
ORDER BY Year ASC;
