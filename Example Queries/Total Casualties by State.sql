-- Total Casualties by State
--
-- Note: This query double counts the Maryland-Delaware Incident Anomaly;
-- The casualties shown for Delaware are also included in the total for Maryland.
SELECT
    StateLookup.name AS STATE,
    NVL(Casualty_Counts.TotalCasualties, 0) AS TotalCasualties
FROM StateLookup
LEFT JOIN(
    SELECT stateId,
           SUM(TotalCasualties) AS TotalCasualties
    FROM IncidentState
    JOIN Incident on Incident.id = IncidentState.incidentId
    GROUP BY stateId
) Casualty_Counts
ON StateLookup.id = stateId
ORDER BY TotalCasualties DESC;
