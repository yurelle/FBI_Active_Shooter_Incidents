-- All Statistics For All Years
SELECT
    'All Years' AS Year,
    COUNT(*) AS Incidents,
    SUM(Deaths) AS Deaths,
    SUM(Wounded) AS Wounded,
    SUM(TotalCasualties) AS TotalCasualties
FROM incident
GROUP BY Year;
