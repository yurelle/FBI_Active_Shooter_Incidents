-- Total Incidents by State
--
-- Note: This query double counts the Maryland-Delaware Incident Anomaly;
-- The incident shown for Delaware is also included in the total for Maryland.
SELECT
    StateLookup.name AS STATE,
    NVL(Incident_Counts.Incidents, 0) AS Incidents
FROM StateLookup
LEFT JOIN(
    SELECT stateId,
           COUNT(*) AS Incidents
    FROM IncidentState
    GROUP BY stateId
) Incident_Counts
ON StateLookup.id = stateId
ORDER BY Incidents DESC;
