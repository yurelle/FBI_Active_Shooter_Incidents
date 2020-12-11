-- Total Deaths by State
--
-- Note: This query double counts the Maryland-Delaware Incident Anomaly;
-- The deaths shown for Delaware are also included in the total for Maryland.
SELECT
    StateLookup.name AS STATE,
    NVL(Death_Counts.Deaths, 0) AS Deaths
FROM StateLookup
LEFT JOIN(
    SELECT stateId,
           SUM(Deaths) AS Deaths
    FROM IncidentState
    JOIN Incident on Incident.id = IncidentState.incidentId
    GROUP BY stateId
) Death_Counts
ON StateLookup.id = stateId
ORDER BY Deaths DESC;
