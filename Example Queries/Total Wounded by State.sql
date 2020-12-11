-- Total Wounded by State
--
-- Note: This query double counts the Maryland-Delaware Incident Anomaly;
-- The wounded shown for Delaware are also included in the total for Maryland.
SELECT
    StateLookup.name AS STATE,
    NVL(Wounded_Counts.Wounded, 0) AS Wounded
FROM StateLookup
LEFT JOIN(
    SELECT stateId,
           SUM(Wounded) AS Wounded
    FROM IncidentState
    JOIN Incident on Incident.id = IncidentState.incidentId
    GROUP BY stateId
) Wounded_Counts
ON StateLookup.id = stateId
ORDER BY Wounded DESC;
