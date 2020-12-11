-- All Statistics by Location
SELECT
    LocationType,
    COUNT(*) AS Incidents,
    SUM(Deaths) AS Deaths,
    SUM(Wounded) AS Wounded,
    SUM(TotalCasualties) AS TotalCasualties
FROM incident
GROUP BY LocationType
ORDER BY Incidents DESC;
