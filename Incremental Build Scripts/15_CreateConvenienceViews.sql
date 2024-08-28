START TRANSACTION;

-- 
-- Database: `fbi_active_shooters`
-- 
USE `fbi_active_shooters`;

-- --------------------------------------------------------


-- --------------------------------------------------------
-- --------------------------------------------------------
-- --------------------------------------------------------
-- --------------------------------------------------------
-- 
-- 
--                        Views
-- 
-- 
-- --------------------------------------------------------
-- --------------------------------------------------------
-- --------------------------------------------------------
-- --------------------------------------------------------


-- --------------------------------------------------------

-- The First & Last years for which there is currently incident data

CREATE VIEW IncidentDataBounds AS
    SELECT MIN(`year`) AS firstDataYear,
           MAX(`year`) AS lastDataYear
      FROM Incident;


-- --------------------------------------------------------

-- One record per year, for the full range of years
-- 
-- This is used as a LEFT JOIN anchor to ensure a record for all years,
-- when pulling sparse data; such as incidents by state, since most
-- states do not have incidents every year.

CREATE VIEW AllDataYears AS
    -- We have population data for more years than we have shooter data, so trim the orphans.
    SELECT DISTINCT `year`
      FROM Population pop
      JOIN IncidentDataBounds db
        ON db.firstDataYear <= pop.`year` AND pop.`year` <= db.lastDataYear;


-- --------------------------------------------------------

-- Yearly whole country population

CREATE VIEW WholeCountryPopulation AS
    SELECT `year`,
           SUM(population)                         AS population,
           CAST(100000  AS DOUBLE)/SUM(population) AS per100Thousand,
           CAST(1000000 AS DOUBLE)/SUM(population) AS perMillion
      FROM Population pop
     GROUP BY pop.`year`
     ORDER BY pop.`year`;


-- --------------------------------------------------------

-- Yearly Casualty Statistics Per Capita (whole country population)
-- 
-- [Accurate Totals - No Data Duplication]
-- 
CREATE VIEW PerCapitaStats_Yearly AS
    WITH TrimmedPopYears AS (
        -- We have population data for more years than we have shooter data, so trim the orphans.
        SELECT pop.*
          FROM WholeCountryPopulation pop
          JOIN IncidentDataBounds db
            ON db.firstDataYear <= pop.`year` AND pop.`year` <= db.lastDataYear
    ),
    YearlyStats AS (
        SELECT inc.`year`,
               COUNT(distinct inc.id) AS Incidents,
               SUM(Deaths)            AS Deaths,
               SUM(Wounded)           AS Wounded,
               SUM(TotalCasualties)   AS TotalCasualties
          FROM Incident inc
         GROUP BY inc.`year`
    )
    SELECT pop.`year`,
           pop.population,
    
           IFNULL(ys.Incidents, 0)       AS Incidents,
           IFNULL(ys.Deaths, 0)          AS Deaths,
           IFNULL(ys.Wounded, 0)         AS Wounded,
           IFNULL(ys.TotalCasualties, 0) AS TotalCasualties,
           
           ROUND(IFNULL(ys.Incidents, 0)       * pop.perMillion, 4) AS IncidentsPerMillionPeople,
           ROUND(IFNULL(ys.Deaths, 0)          * pop.perMillion, 4) AS DeathsPerMillionPeople,
           ROUND(IFNULL(ys.Wounded, 0)         * pop.perMillion, 4) AS WoundedPerMillionPeople,
           ROUND(IFNULL(ys.TotalCasualties, 0) * pop.perMillion, 4) AS TotalCasualtiesPerMillionPeople
      FROM TrimmedPopYears pop
      LEFT JOIN YearlyStats ys
        ON ys.`year` = pop.`year`
     ORDER BY pop.`year`;



-- --------------------------------------------------------

-- Total Casualty Statistics Per Capita (whole country population) Across All Years
-- 
-- [Accurate Totals - No Data Duplication]

CREATE VIEW PerCapitaStats_Total AS
    SELECT
        CONCAT(MIN(`year`), '-', MAX(`year`)) AS `Years`,
        MAX(`year`) - MIN(`year`) + 1 AS NumYears, -- '+1' makes range inclusive of both endpoints
        AVG(population) AS AvgPopulationPerYear,
        
        SUM(Incidents)       AS Incidents,
        SUM(Deaths)          AS Deaths,
        SUM(Wounded)         AS Wounded,
        SUM(TotalCasualties) AS TotalCasualties,
        
        ROUND(CAST(SUM(Incidents)       AS DOUBLE)/SUM(population)*1000000, 4) AS IncidentsPerMillionPeople,
        ROUND(CAST(SUM(Deaths)          AS DOUBLE)/SUM(population)*1000000, 4) AS DeathsPerMillionPeople,
        ROUND(CAST(SUM(Wounded)         AS DOUBLE)/SUM(population)*1000000, 4) AS WoundedPerMillionPeople,
        ROUND(CAST(SUM(TotalCasualties) AS DOUBLE)/SUM(population)*1000000, 4) AS TotalCasualtiesPerMillionPeople
    FROM PerCapitaStats_Yearly
    ORDER BY DeathsPerMillionPeople DESC;



-- --------------------------------------------------------

-- Yearly Casualty Statistics By State Per Capita
--
-- Note: This query double counts multi-state incidents, by including
-- their casualty counts in both states.
-- 
-- This extra duplicated data accounts for about 1% of the total casualties data.
-- 
-- Incidents
--     W/Dups:   492
--     Actual:   484
--      Extra:     8 [1.65%]
-- 
-- Deaths
--     W/Dups: 1,313
--     Actual: 1,304
--     Extra:      9 [0.69%]
-- 
-- Wounded
--     W/Dups: 2,293
--     Actual: 2,268
--     Extra:     25 [1.10%]
-- 
-- TotalCasualties
--     W/Dups: 3,606
--     Actual: 3,572
--     Extra:     34 [0.95%]
-- 
CREATE VIEW PerCapitaStatsByState_Yearly AS
    WITH TrimmedPopYears AS (
        -- We have population data for more years than we have shooter data, so trim the orphans.
        SELECT pop.*
          FROM Population pop
          JOIN IncidentDataBounds db
            ON db.firstDataYear <= pop.`year` AND pop.`year` <= db.lastDataYear
    ),
    YearlyStats AS (
        SELECT inc.`year`,
               incState.stateId,
               COUNT(distinct inc.id) AS Incidents,
               SUM(Deaths)            AS Deaths,
               SUM(Wounded)           AS Wounded,
               SUM(TotalCasualties)   AS TotalCasualties
          FROM IncidentState incState
          JOIN Incident inc
            ON inc.id = incState.incidentId
         GROUP BY incState.stateId, inc.`year`
    )
    SELECT pop.`year`,
           stateLU.id   AS StateId,
           stateLU.name AS State,
           population,
           
           IFNULL(ys.Incidents, 0)       AS Incidents,
           IFNULL(ys.Deaths, 0)          AS Deaths,
           IFNULL(ys.Wounded, 0)         AS Wounded,
           IFNULL(ys.TotalCasualties, 0) AS TotalCasualties,
           
           ROUND(IFNULL(ys.Incidents, 0)       * pop.perMillion, 4) AS IncidentsPerMillionPeople,
           ROUND(IFNULL(ys.Deaths, 0)          * pop.perMillion, 4) AS DeathsPerMillionPeople,
           ROUND(IFNULL(ys.Wounded, 0)         * pop.perMillion, 4) AS WoundedPerMillionPeople,
           ROUND(IFNULL(ys.TotalCasualties, 0) * pop.perMillion, 4) AS TotalCasualtiesPerMillionPeople
      FROM TrimmedPopYears pop
      LEFT JOIN YearlyStats ys
        ON ys.stateId = pop.stateId
       AND ys.`year` = pop.`year`
      JOIN StateLookup stateLU
        ON stateLU.id = pop.stateId
     ORDER BY stateLU.name, pop.`year`;



-- --------------------------------------------------------

-- Total Casualty Statistics By State Per Capita Across All Years
--
-- Note: This query double counts multi-state incidents, by including
-- their casualty counts in both states.
-- 
-- See: YearlyCasualtiesPerCapita

CREATE VIEW PerCapitaStatsByState_Total AS
    SELECT
        CONCAT(MIN(`year`), '-', MAX(`year`)) AS `Years`,
        MAX(`year`) - MIN(`year`) + 1 AS NumYears, -- '+1' makes range inclusive of both endpoints
        StateId,
        State,
        AVG(population) AS AvgPopulationPerYear,
        
        SUM(Incidents)       AS Incidents,
        SUM(Deaths)          AS Deaths,
        SUM(Wounded)         AS Wounded,
        SUM(TotalCasualties) AS TotalCasualties,
        
        ROUND(CAST(SUM(Incidents)       AS DOUBLE)/SUM(population)*1000000, 4) AS IncidentsPerMillionPeople,
        ROUND(CAST(SUM(Deaths)          AS DOUBLE)/SUM(population)*1000000, 4) AS DeathsPerMillionPeople,
        ROUND(CAST(SUM(Wounded)         AS DOUBLE)/SUM(population)*1000000, 4) AS WoundedPerMillionPeople,
        ROUND(CAST(SUM(TotalCasualties) AS DOUBLE)/SUM(population)*1000000, 4) AS TotalCasualtiesPerMillionPeople
    FROM PerCapitaStatsByState_Yearly
    GROUP BY State
    ORDER BY DeathsPerMillionPeople DESC;



-- --------------------------------------------------------

-- Yearly Casualty Statistics By Location Type
-- 
-- [Accurate Totals - No Data Duplication]

CREATE VIEW CasualtiesByLocation_Yearly AS
    WITH YearlyStats AS (
        SELECT inc.`year`,
               locationType,
               COUNT(distinct inc.id) AS Incidents,
               SUM(Deaths)            AS Deaths,
               SUM(Wounded)           AS Wounded,
               SUM(TotalCasualties)   AS TotalCasualties
          FROM Incident inc
         GROUP BY locationType, inc.`year`
    )
    SELECT ay.`year`,
           locationType,
           IFNULL(ys.Incidents, 0)       AS Incidents,
           IFNULL(ys.Deaths, 0)          AS Deaths,
           IFNULL(ys.Wounded, 0)         AS Wounded,
           IFNULL(ys.TotalCasualties, 0) AS TotalCasualties
      FROM AllDataYears ay
      LEFT JOIN YearlyStats ys
        ON ys.`year` = ay.`year`
     ORDER BY ay.`year`, locationType;

-- --------------------------------------------------------

-- Total Casualty Statistics By Location Type Across All Years
-- 
-- [Accurate Totals - Data No Duplication]

CREATE VIEW CasualtiesByLocation_Total AS
    SELECT
        LocationType,
        COUNT(*)             AS Incidents,
        SUM(Deaths)          AS Deaths,
        SUM(Wounded)         AS Wounded,
        SUM(TotalCasualties) AS TotalCasualties
    FROM incident
    GROUP BY LocationType
    ORDER BY Incidents DESC;



-- --------------------------------------------------------

-- Yearly Casualty Statistics By Shooter Gender
-- 
-- Note: This query double counts multi-state incidents, by including
-- their casualty counts in both states.
-- 
-- This extra duplicated data accounts for about 1% of the total casualties data.
-- 
-- Incidents
--     W/Dups:   489
--     Actual:   484
--      Extra:     5 [1.03%]
-- 
-- Deaths
--     W/Dups: 1,342
--     Actual: 1,304
--     Extra:     38 [2.91%]
-- 
-- Wounded
--     W/Dups: 2,365
--     Actual: 2,268
--     Extra:     97 [4.28%]
-- 
-- TotalCasualties
--     W/Dups: 3,707
--     Actual: 3,572
--     Extra:    135 [3.78%]
-- 
CREATE VIEW CasualtiesByShooterGender_Yearly AS
    WITH YearlyStats AS (
        SELECT inc.`year`,
               sh.Gender,
               COUNT(distinct inc.id) AS Incidents,
               SUM(Deaths)            AS Deaths,
               SUM(Wounded)           AS Wounded,
               SUM(TotalCasualties)   AS TotalCasualties
          FROM Shooter sh
          JOIN Incident inc
            ON sh.incidentId = inc.id
         GROUP BY Gender, inc.`year`
    )
    SELECT ay.`year`,
           IFNULL(Gender, 'UNKNOWN')     AS Gender,
           IFNULL(ys.Incidents, 0)       AS Incidents,
           IFNULL(ys.Deaths, 0)          AS Deaths,
           IFNULL(ys.Wounded, 0)         AS Wounded,
           IFNULL(ys.TotalCasualties, 0) AS TotalCasualties
      FROM AllDataYears ay
      LEFT JOIN YearlyStats ys
        ON ys.`year` = ay.`year`
     ORDER BY ay.`year`, Gender;

-- --------------------------------------------------------

-- Total Casualty Statistics By Shooter Gender Across All Years
-- 
-- Note: This query double counts multi-state incidents, by including
-- their casualty counts in both states.
-- 
-- This extra duplicated data accounts for about 1% of the total casualties data.
-- 
-- Incidents
--     W/Dups:   489
--     Actual:   484
--      Extra:     5 [1.03%]
-- 
-- Deaths
--     W/Dups: 1,342
--     Actual: 1,304
--     Extra:     38 [2.91%]
-- 
-- Wounded
--     W/Dups: 2,365
--     Actual: 2,268
--     Extra:     97 [4.28%]
-- 
-- TotalCasualties
--     W/Dups: 3,707
--     Actual: 3,572
--     Extra:    135 [3.78%]
-- 
CREATE VIEW CasualtiesByShooterGender_Total AS
    SELECT
        Gender,
        SUM(Incidents)       AS Incidents,
        SUM(Deaths)          AS Deaths,
        SUM(Wounded)         AS Wounded,
        SUM(TotalCasualties) AS TotalCasualties
    FROM CasualtiesByShooterGender_Yearly
    GROUP BY Gender
    ORDER BY Incidents DESC;



-- --------------------------------------------------------

-- Yearly Casualty Statistics By Shooter Fate
-- 
-- Note: This query double counts multi-state incidents, by including
-- their casualty counts in both states.
-- 
-- This extra duplicated data accounts for about 1% of the total casualties data.
-- 
-- Incidents
--     W/Dups:   486
--     Actual:   484
--      Extra:     2 [0.41%]
-- 
-- Deaths
--     W/Dups: 1,342
--     Actual: 1,304
--     Extra:     38 [2.91%]
-- 
-- Wounded
--     W/Dups: 2,365
--     Actual: 2,268
--     Extra:     97 [4.28%]
-- 
-- TotalCasualties
--     W/Dups: 3,707
--     Actual: 3,572
--     Extra:    135 [3.78%]
-- 
CREATE VIEW CasualtiesByShooterFate_Yearly AS
    WITH YearlyStats AS (
        SELECT inc.`year`,
               sh.Fate,
               COUNT(distinct inc.id) AS Incidents,
               SUM(Deaths)            AS Deaths,
               SUM(Wounded)           AS Wounded,
               SUM(TotalCasualties)   AS TotalCasualties
          FROM Shooter sh
          JOIN Incident inc
            ON sh.incidentId = inc.id
         GROUP BY Fate, inc.`year`
    )
    SELECT ay.`year`,
           Fate,
           IFNULL(ys.Incidents, 0)       AS Incidents,
           IFNULL(ys.Deaths, 0)          AS Deaths,
           IFNULL(ys.Wounded, 0)         AS Wounded,
           IFNULL(ys.TotalCasualties, 0) AS TotalCasualties
      FROM AllDataYears ay
      LEFT JOIN YearlyStats ys
        ON ys.`year` = ay.`year`
     ORDER BY ay.`year`, Fate;

-- --------------------------------------------------------

-- Total Casualty Statistics By Shooter Fate Across All Years
-- 
-- Note: This query double counts multi-state incidents, by including
-- their casualty counts in both states.
-- 
-- This extra duplicated data accounts for about 1% of the total casualties data.
-- 
-- Incidents
--     W/Dups:   486
--     Actual:   484
--      Extra:     2 [0.41%]
-- 
-- Deaths
--     W/Dups: 1,342
--     Actual: 1,304
--     Extra:     38 [2.91%]
-- 
-- Wounded
--     W/Dups: 2,365
--     Actual: 2,268
--     Extra:     97 [4.28%]
-- 
-- TotalCasualties
--     W/Dups: 3,707
--     Actual: 3,572
--     Extra:    135 [3.78%]
-- 
CREATE VIEW CasualtiesByShooterFate_Total AS
    SELECT
        Fate,
        SUM(Incidents)       AS Incidents,
        SUM(Deaths)          AS Deaths,
        SUM(Wounded)         AS Wounded,
        SUM(TotalCasualties) AS TotalCasualties
    FROM CasualtiesByShooterFate_Yearly
    GROUP BY Fate
    ORDER BY Incidents DESC;



-- --------------------------------------------------------

-- Yearly Number of Shooters By Shooter Fate
-- 
-- [Accurate Totals - Data No Duplication]

CREATE VIEW ShootersByFate_Yearly AS
    WITH YearlyStats AS (
        SELECT inc.`year`,
               sh.Fate,
               COUNT(distinct sh.id) AS numShooters
          FROM Shooter sh
          JOIN Incident inc
            ON sh.incidentId = inc.id
         GROUP BY Fate, inc.`year`
    )
    SELECT ay.`year`,
           Fate,
           IFNULL(ys.numShooters, 0) AS numShooters
      FROM AllDataYears ay
      LEFT JOIN YearlyStats ys
        ON ys.`year` = ay.`year`
     ORDER BY ay.`year`, Fate;

-- --------------------------------------------------------

-- Total Number of Shooters By Shooter Fate Across All Years
-- 
-- [Accurate Totals - Data No Duplication]

CREATE VIEW ShootersByFate_Total AS
    SELECT
        Fate,
        SUM(numShooters) AS numShooters
    FROM ShootersByFate_Yearly
    GROUP BY Fate
    ORDER BY numShooters DESC;



-- --------------------------------------------------------

-- Yearly Number of Shooters by Gender
-- 
-- [Accurate Totals - Data No Duplication]

CREATE VIEW ShootersByGender_Yearly AS
    WITH YearlyStats AS (
        SELECT inc.`year`,
               sh.Gender,
               COUNT(distinct sh.id) AS numShooters
          FROM Shooter sh
          JOIN Incident inc
            ON sh.incidentId = inc.id
         GROUP BY Gender, inc.`year`
    )
    SELECT ay.`year`,
           IFNULL(Gender, 'UNKNOWN')     AS Gender,
           IFNULL(ys.numShooters, 0) AS numShooters
      FROM AllDataYears ay
      LEFT JOIN YearlyStats ys
        ON ys.`year` = ay.`year`
     ORDER BY ay.`year`, Gender;

-- --------------------------------------------------------

-- Total Number of Shooters by Gender Across All Years
-- 
-- [Accurate Totals - Data No Duplication]

CREATE VIEW ShootersByGender_Total AS
    SELECT
        Gender,
        SUM(numShooters) AS numShooters
    FROM ShootersByGender_Yearly
    GROUP BY Gender
    ORDER BY numShooters DESC;



-- --------------------------------------------------------

-- Yearly Number of Shooters by Age
-- 
-- [Accurate Totals - Data No Duplication]

CREATE VIEW ShootersByAge_Yearly AS
    WITH YearlyStats AS (
        SELECT inc.`year`,
               IFNULL(CONCAT(FLOOR(sh.age/10.0)*10, 's'), 'UNKNOWN') AS ageRange,
               COUNT(*) AS numShooters
          FROM Shooter sh
          JOIN Incident inc
            ON sh.incidentId = inc.id
         GROUP BY ageRange, inc.`year`
    )
    SELECT ay.`year`,
           ageRange,
           numShooters
      FROM AllDataYears ay
      LEFT JOIN YearlyStats ys
        ON ys.`year` = ay.`year`
     ORDER BY ay.`year`, ageRange;

-- --------------------------------------------------------

-- Total Number of Shooters by Age Across All Years
-- 
-- [Accurate Totals - Data No Duplication]

CREATE VIEW ShootersByAge_Total AS
    SELECT
        ageRange,
        SUM(numShooters) AS numShooters
    FROM ShootersByAge_Yearly
    GROUP BY ageRange
    ORDER BY numShooters DESC;



-- --------------------------------------------------------

-- Yearly Number of Shooters by Age (with age ranges as columns)
-- 
-- [Accurate Totals - Data No Duplication]

CREATE VIEW ShootersByAgeAsColumns_Yearly AS
    WITH YearlyStats AS (
        SELECT inc.`year`,
               COUNT(CASE WHEN                  sh.age < 20 THEN sh.id ELSE NULL END) AS under20,
               COUNT(CASE WHEN 20 <= sh.age AND sh.age < 30 THEN sh.id ELSE NULL END) AS _20s,
               COUNT(CASE WHEN 30 <= sh.age AND sh.age < 40 THEN sh.id ELSE NULL END) AS _30s,
               COUNT(CASE WHEN 40 <= sh.age AND sh.age < 50 THEN sh.id ELSE NULL END) AS _40s,
               COUNT(CASE WHEN 50 <= sh.age AND sh.age < 60 THEN sh.id ELSE NULL END) AS _50s,
               COUNT(CASE WHEN 60 <= sh.age AND sh.age < 70 THEN sh.id ELSE NULL END) AS _60s,
               COUNT(CASE WHEN 70 <= sh.age AND sh.age < 80 THEN sh.id ELSE NULL END) AS _70s,
               COUNT(CASE WHEN 80 <= sh.age                 THEN sh.id           END) AS _80AndOver,
               COUNT(CASE WHEN sh.age IS NULL               THEN sh.id           END) AS `UNKNOWN`
          FROM Shooter sh
          JOIN Incident inc
            ON sh.incidentId = inc.id
         GROUP BY inc.`year`
    )
    SELECT ay.`year`,
           IFNULL(under20, 0) AS under20,
           IFNULL(_20s, 0) AS _20s,
           IFNULL(_30s, 0) AS _30s,
           IFNULL(_40s, 0) AS _40s,
           IFNULL(_50s, 0) AS _50s,
           IFNULL(_60s, 0) AS _60s,
           IFNULL(_70s, 0) AS _70s,
           IFNULL(_80AndOver, 0) AS _80AndOver,
           IFNULL(`UNKNOWN`, 0) AS `UNKNOWN`
      FROM AllDataYears ay
      LEFT JOIN YearlyStats ys
        ON ys.`year` = ay.`year`
     ORDER BY ay.`year`;

-- --------------------------------------------------------

-- Total Number of Shooters by Age (with age ranges as columns) Across All Years
-- 
-- [Accurate Totals - Data No Duplication]

CREATE VIEW ShootersByAgeAsColumns_Total AS
    SELECT
        SUM(under20) AS under20,
        SUM(_20s) AS _20s,
        SUM(_30s) AS _30s,
        SUM(_40s) AS _40s,
        SUM(_50s) AS _50s,
        SUM(_60s) AS _60s,
        SUM(_70s) AS _70s,
        SUM(_80AndOver) AS _80AndOver,
        SUM(`UNKNOWN`) AS `UNKNOWN`
    FROM ShootersByAgeAsColumns_Yearly;



-- --------------------------------------------------------



-- --------------------------------------------------------

COMMIT;
