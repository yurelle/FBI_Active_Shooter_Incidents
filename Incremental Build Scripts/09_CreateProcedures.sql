DELIMITER //

-- 
-- Insert Incident State Record
-- 
CREATE PROCEDURE fbi_active_shooters.insertIncidentStateRecord(
    IN incidentId_in INT,
    IN stateStr_in VARCHAR(250)
)
BEGIN
	DECLARE state_id INT DEFAULT null;
    
    -- Get State ID From Lookup Table
    SET state_id = null;
    SET state_id = (
        SELECT id
          FROM StateLookup
         WHERE name = stateStr_in
    );

    -- Incident State
    INSERT INTO `FBI_ACTIVE_SHOOTERS`.`IncidentState`
    (
        IncidentId,
        StateId
    )
    VALUES (
        incidentId_in,
        state_id
    );
END //

-- 
-- Count Number of Occurrences In String
-- 
CREATE PROCEDURE fbi_active_shooters.countOccurrencesInString(
    IN containingStr_in VARCHAR(250),
    IN segmentStr_in VARCHAR(250),
    OUT numTimes_out INT
)
BEGIN
    SET numTimes_out = null;
    SET numTimes_out = (
        SELECT ROUND(
                (
                    LENGTH(containingStr_in)
                    - LENGTH( REPLACE(containingStr_in, segmentStr_in, "") )
                )
                / LENGTH(segmentStr_in)
            )
          FROM dual
    );
END //

-- 
-- Split String By Delimiter
-- 
CREATE PROCEDURE fbi_active_shooters.splitStringByDelimiter(
    IN containingStr_in VARCHAR(250),
    IN delimiterStr_in VARCHAR(250),
    OUT numChunks_out INT
)
BEGIN
    -- Declare Vars
    DECLARE delimLen INT;
    DECLARE splitIndex INT;
    DECLARE chunkStr VARCHAR(250);
    DECLARE remainderStr VARCHAR(250);
    
    -- Reset Temp Table
    DROP TEMPORARY TABLE IF EXISTS split_chunks_temp_table;
    CREATE TEMPORARY TABLE split_chunks_temp_table (
        idx INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
        value varchar(250)
    );
    
    -- Init Vars
    SET delimLen = LENGTH(delimiterStr_in);
    SET splitIndex = 0;
    SET chunkStr = NULL;
    SET remainderStr = containingStr_in;
    
    -- Loop
    parsingLoop: LOOP
        -- Get index of delimiter
        SET splitIndex = POSITION(delimiterStr_in IN remainderStr);
        
        IF splitIndex > 0 THEN -- Found
            -- From Start to delimiter => chunk var
            SET chunkStr = SUBSTRING(remainderStr, 1, splitIndex-1);
            
            -- Overwrite remainderStr with everything after delimiter
            SET remainderStr = SUBSTRING(remainderStr, splitIndex + delimLen);
            
            -- Store chunk in temp table
            INSERT INTO split_chunks_temp_table (value) VALUES (chunkStr);
            
            -- Continue LOOP
            ITERATE parsingLoop;
        ELSE -- Not Found
            LEAVE parsingLoop;
        END IF;
    END LOOP parsingLoop;
    
    -- Add remainder as last chunk
    INSERT INTO split_chunks_temp_table (value) VALUES (remainderStr);
    
    -- Output Num Chunks    
    SET numChunks_out = (
        SELECT COUNT(*) FROM split_chunks_temp_table
    );
END //

-- 
-- ETL - Parse Raw Records
-- 
CREATE PROCEDURE fbi_active_shooters.parseRawRecords()
BEGIN
	DECLARE incident_id INT DEFAULT null;
	DECLARE incident_state_id INT DEFAULT null;
	DECLARE shooter_id INT DEFAULT null;
	DECLARE shooterFate_id INT DEFAULT null;
	DECLARE state_id INT DEFAULT null;
	DECLARE dataSourceFile_id char(15) DEFAULT null;
	
	DECLARE raw_ID VARCHAR(250);
	DECLARE raw_IncidentName VARCHAR(250);
	DECLARE raw_Date VARCHAR(250);
	DECLARE raw_Time VARCHAR(250);
	DECLARE raw_State VARCHAR(250);
	DECLARE raw_LocationType VARCHAR(250);
	DECLARE raw_ShooterName VARCHAR(250);
	DECLARE raw_ShooterGender VARCHAR(250);
	DECLARE raw_ShooterAge VARCHAR(250);
	DECLARE raw_Rifles VARCHAR(250);
	DECLARE raw_Shotguns VARCHAR(250);
	DECLARE raw_Handguns VARCHAR(250);
	DECLARE raw_Deaths VARCHAR(250);
	DECLARE raw_Wounded VARCHAR(250);
	DECLARE raw_TotalCalculated VARCHAR(250);
	DECLARE raw_TerminatingEvent VARCHAR(250);
	DECLARE raw_ShooterFate VARCHAR(250);
	DECLARE raw_SurrenderedDuringIncident VARCHAR(250);
	DECLARE raw_DataSourceId CHAR(15);
    
    DECLARE delimiterStr VARCHAR(250);
    DECLARE tmpStr VARCHAR(250);
    DECLARE tmpInt INT;
	
    
	DECLARE done INT DEFAULT FALSE;
	DECLARE iterator CURSOR FOR
		SELECT
			ID,
			IncidentName,
			Date,
			Time,
			State,
			Location,
			ShooterName,
			ShooterGender,
			ShooterAge,
			Rifles,
			Shotguns,
			Handguns,
			Deaths,
			Wounded,
			`Total(Calculated)`,
			TerminatingEvent,
			ShooterFate,
			SurrenderedDuringIncident,
            DataSourceId
		FROM `FBI_ACTIVE_SHOOTERS`.`RawRecords`
		ORDER BY ID;
	
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
	
	OPEN iterator;
	
	read_loop: LOOP
		FETCH iterator INTO
			raw_ID,
			raw_IncidentName,
			raw_Date,
			raw_Time,
			raw_State,
			raw_LocationType,
			raw_ShooterName,
			raw_ShooterGender,
			raw_ShooterAge,
			raw_Rifles,
			raw_Shotguns,
			raw_Handguns,
			raw_Deaths,
			raw_Wounded,
			raw_TotalCalculated,
			raw_TerminatingEvent,
			raw_ShooterFate,
			raw_SurrenderedDuringIncident,
            raw_DataSourceId;
		
		-- Loop Termination
		IF done THEN
		  LEAVE read_loop;
		END IF;
		
		-- Get Data Source File ID From Lookup Table
		SET dataSourceFile_id = raw_DataSourceId;
		
		-- Incident
		INSERT INTO `FBI_ACTIVE_SHOOTERS`.`Incident`
		(
			Name,
			Date,
			Time,
			LocationType,
			Rifles,
			Shotguns,
			Handguns,
			Deaths,
			Wounded,
			TotalCasualties,
            DataSourceID
		)
		VALUES (
			raw_IncidentName,
			STR_TO_DATE(raw_Date,'%d-%b-%y'), -- '[day of month (01 to 31)]-[Abreviated month name ("Jan" to "Dec")]-[2 digit year]'
			STR_TO_DATE(raw_Time,'%h:%i %p'), -- '[Hour (00 to 12)]-[minutes] [am/pm]'
			raw_LocationType,
			CAST(raw_Rifles AS SIGNED),
			CAST(raw_Shotguns AS SIGNED),
			CAST(raw_Handguns AS SIGNED),
			CAST(raw_Deaths AS SIGNED),
			CAST(raw_Wounded AS SIGNED),
			CAST(raw_Deaths AS SIGNED) + CAST(raw_Wounded AS SIGNED),
            dataSourceFile_id
		);
		-- Get Incident id
		SET incident_id = null;
		SET incident_id = LAST_INSERT_ID();
        
        -- 
        -- State
        -- 
        
        -- Check for Multi-State
        --
        -- Max in the data is 2 States
        IF raw_State LIKE '% & %' THEN
            SET delimiterStr = ' & ';
            
            -- First State
            -- 
            -- Begining of string to first occurrance
            SET tmpStr = NULL;
            SET tmpStr = SUBSTRING_INDEX(raw_State, delimiterStr, 1);
            
            CALL fbi_active_shooters.insertIncidentStateRecord(
                -- incidentId_in
                incident_id,
                
                -- stateStr_in
                tmpStr
            );
            
            -- Second State
            -- 
            -- End of string to last occurrance
            SET tmpStr = NULL;
            SET tmpStr = SUBSTRING_INDEX(raw_State, delimiterStr, -1);
            
            CALL fbi_active_shooters.insertIncidentStateRecord(
                -- incidentId_in
                incident_id,
                
                -- stateStr_in
                tmpStr
            );
        ELSE
            CALL fbi_active_shooters.insertIncidentStateRecord(
                -- incidentId_in
                incident_id,
                
                -- stateStr_in
                raw_State
            );
        END IF;
		
        
        -- 
        -- Shooter
        -- 
        -- Drop " (Husband & Wife)" suffix if present.
        SET raw_ShooterName = REPLACE(raw_ShooterName, ' (Husband & Wife)', '');

        -- Check for Multi-Shooter
        --
        -- Max in the data is 3 shooters
        IF raw_ShooterName LIKE '% & %' THEN
            SET delimiterStr = ' & ';
            
            -- 
            -- Name
            -- 
            
            -- Split Name
            CALL fbi_active_shooters.splitStringByDelimiter(
                -- containingStr_in
                raw_ShooterName,
                
                -- delimiterStr_in
                delimiterStr,
                
                -- numChunks_out
                tmpInt
            );
            
            -- Save Name Chunks
            DROP TEMPORARY TABLE IF EXISTS shooter_name_chunks_temp_table;
            CREATE TEMPORARY TABLE shooter_name_chunks_temp_table
                SELECT * FROM split_chunks_temp_table;
            
            -- 
            -- Age
            -- 
            
            -- Split Age
            CALL fbi_active_shooters.splitStringByDelimiter(
                -- containingStr_in
                raw_ShooterAge,
                
                -- delimiterStr_in
                delimiterStr,
                
                -- numChunks_out
                tmpInt
            );
            
            -- Save Age Chunks
            DROP TEMPORARY TABLE IF EXISTS shooter_age_chunks_temp_table;
            CREATE TEMPORARY TABLE shooter_age_chunks_temp_table
                SELECT * FROM split_chunks_temp_table;
            
            -- 
            -- Gender
            -- 
            
            -- Split Gender
            CALL fbi_active_shooters.splitStringByDelimiter(
                -- containingStr_in
                raw_ShooterGender,
                
                -- delimiterStr_in
                delimiterStr,
                
                -- numChunks_out
                tmpInt
            );
            
            -- Save Gender Chunks
            DROP TEMPORARY TABLE IF EXISTS shooter_gender_chunks_temp_table;
            CREATE TEMPORARY TABLE shooter_gender_chunks_temp_table
                SELECT * FROM split_chunks_temp_table;
            
            -- 
            -- Terminating Event
            -- 
            
            -- Split Terminating Event
            CALL fbi_active_shooters.splitStringByDelimiter(
                -- containingStr_in
                raw_TerminatingEvent,
                
                -- delimiterStr_in
                delimiterStr,
                
                -- numChunks_out
                tmpInt
            );
            
            -- Save Terminating Event Chunks
            DROP TEMPORARY TABLE IF EXISTS shooter_terminating_event_chunks_temp_table;
            CREATE TEMPORARY TABLE shooter_terminating_event_chunks_temp_table
                SELECT * FROM split_chunks_temp_table;
            
            -- 
            -- Fate
            -- 
            
            -- Split Fate
            CALL fbi_active_shooters.splitStringByDelimiter(
                -- containingStr_in
                raw_ShooterFate,
                
                -- delimiterStr_in
                delimiterStr,
                
                -- numChunks_out
                tmpInt
            );
            
            -- Save Fate Chunks
            DROP TEMPORARY TABLE IF EXISTS shooter_fate_chunks_temp_table;
            CREATE TEMPORARY TABLE shooter_fate_chunks_temp_table
                SELECT * FROM split_chunks_temp_table;
            
            -- 
            -- Surrendered
            -- 
            
            -- Split Surrendered
            CALL fbi_active_shooters.splitStringByDelimiter(
                -- containingStr_in
                raw_SurrenderedDuringIncident,
                
                -- delimiterStr_in
                delimiterStr,
                
                -- numChunks_out
                tmpInt
            );
            
            -- Save Surrendered Chunks
            DROP TEMPORARY TABLE IF EXISTS shooter_surrendered_chunks_temp_table;
            CREATE TEMPORARY TABLE shooter_surrendered_chunks_temp_table
                SELECT * FROM split_chunks_temp_table;
            
            -- 
            -- Loop
            -- 
            -- At start of loop, tmpInt = max row's index. So, we count backwards UNTIL
            -- We hit zero. The indexes are 1-based, so terminate before processing 0.
            processLoop: LOOP
                -- Insert Row
                INSERT INTO `FBI_ACTIVE_SHOOTERS`.`Shooter`
                (
                    IncidentId,
                    Name,
                    Gender,
                    Age,
                    TerminatingEvent,
                    Fate,
                    SurrenderedDuringIncident
                )
                VALUES (
                    incident_id,
                    (SELECT CASE t_name.value WHEN '?' THEN null ELSE value END AS value FROM shooter_name_chunks_temp_table t_name WHERE idx = tmpInt),
                    (SELECT CASE t_gender.value WHEN '?' THEN null ELSE value END AS value FROM shooter_gender_chunks_temp_table t_gender WHERE idx = tmpInt),
                    CAST((SELECT CASE t_age.value WHEN '?' THEN null ELSE value END AS value FROM shooter_age_chunks_temp_table t_age WHERE idx = tmpInt) AS SIGNED),
                    (SELECT value FROM shooter_terminating_event_chunks_temp_table WHERE idx = tmpInt),
                    (SELECT value FROM shooter_fate_chunks_temp_table WHERE idx = tmpInt),
                    (SELECT value FROM shooter_surrendered_chunks_temp_table WHERE idx = tmpInt)
                );
                    
                -- Decrement tmpInt
                SET tmpInt = tmpInt - 1;
                
                -- Evaluate Loop Condition
                IF tmpInt > 0 THEN -- More Rows Remaining
                    -- Continue LOOP
                    ITERATE processLoop;
                ELSE -- No Rows Remaining
                    -- Exit Loop
                    LEAVE processLoop;
                END IF;
            END LOOP processLoop;
            
        ELSE -- 1 Shooter
            INSERT INTO `FBI_ACTIVE_SHOOTERS`.`Shooter`
            (
                IncidentId,
                Name,
                Gender,
                Age,
                TerminatingEvent,
                Fate,
                SurrenderedDuringIncident
            )
            VALUES (
                incident_id,
                raw_ShooterName,
                raw_ShooterGender,
                CAST(raw_ShooterAge AS SIGNED),
                raw_TerminatingEvent,
                raw_ShooterFate,
                raw_SurrenderedDuringIncident
            );
        END IF;
	END LOOP;
	
	CLOSE iterator;
END //


DELIMITER ;

