-- Initiate ETL
CALL fbi_active_shooters.parseRawRecords();

-- Set Raw Description Incident IDs
UPDATE fbi_active_shooters.rawIncidentDescriptions raw_desc
   SET incidentId = (
        SELECT inc.id
          FROM fbi_active_shooters.incident inc
          JOIN fbi_active_shooters.dataSourceFile dataSource
            ON inc.dataSourceId = dataSource.id
         WHERE raw_desc.incidentName = inc.name
           AND raw_desc.dataSourceId = dataSource.id   
   );

-- Convert Population Table State Names to State IDs
UPDATE fbi_active_shooters.population pop SET pop.stateId = (
    	SELECT stateLU.id
    	  FROM fbi_active_shooters.stateLookup stateLU
    	 WHERE pop.stateName = stateLU.name
    );

-- Drop temporary column StateName
ALTER TABLE fbi_active_shooters.population DROP COLUMN stateName;
