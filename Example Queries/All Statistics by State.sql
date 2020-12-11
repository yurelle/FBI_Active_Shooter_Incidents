-- All Statistics by State
--
-- Note: This query double counts the Maryland-Delaware Incident Anomaly;
-- The deaths shown for Delaware are also included in the total for Maryland.
SELECT
    StateLookup.name AS STATE,
    NVL(All_Counts.Incidents, 0) AS Incidents,
    NVL(All_Counts.Deaths, 0) AS Deaths,
    NVL(All_Counts.Wounded, 0) AS Wounded,
    NVL(All_Counts.TotalCasualties, 0) AS TotalCasualties
FROM StateLookup
LEFT JOIN(
    SELECT stateId,
           COUNT(*) AS Incidents,
           SUM(Deaths) AS Deaths,
           SUM(Wounded) AS Wounded,
           SUM(TotalCasualties) AS TotalCasualties
    FROM IncidentState
    JOIN Incident on Incident.id = IncidentState.incidentId
    GROUP BY stateId
) All_Counts
ON StateLookup.id = stateId
ORDER BY STATE ASC;
