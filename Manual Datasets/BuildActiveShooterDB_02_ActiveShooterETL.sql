DELIMITER //
CREATE PROCEDURE fbi_active_shooters_2000_2018.parseRawRecords()
BEGIN
	DECLARE incident_id INT DEFAULT null;
	DECLARE incident_state_id INT DEFAULT null;
	DECLARE shooter_id INT DEFAULT null;
	DECLARE shooterFate_id INT DEFAULT null;
	DECLARE state_id INT DEFAULT null;
	
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
			ShootersFate,
			SurrenderedDuringIncident
		FROM `FBI_ACTIVE_SHOOTERS_2000_2018`.`RawRecords`
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
			raw_SurrenderedDuringIncident;
		
		-- Loop Termination
		IF done THEN
		  LEAVE read_loop;
		END IF;
		
		-- Incident
		INSERT INTO `FBI_ACTIVE_SHOOTERS_2000_2018`.`Incident`
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
			TotalCasualties
		)
		VALUES (
			raw_IncidentName,
			STR_TO_DATE(raw_Date,'%d-%b-%y'),
			STR_TO_DATE(raw_Time,'%h:%i %p'),
			raw_LocationType,
			CAST(raw_Rifles AS SIGNED),
			CAST(raw_Shotguns AS SIGNED),
			CAST(raw_Handguns AS SIGNED),
			CAST(raw_Deaths AS SIGNED),
			CAST(raw_Wounded AS SIGNED),
			CAST(raw_Deaths AS SIGNED) + CAST(raw_Wounded AS SIGNED)
		);
		-- Get Incident id
		SET incident_id = null;
		SET incident_id = LAST_INSERT_ID();
		
		-- Get State ID From Lookup Table
		SET state_id = null;
		SET state_id = (
			SELECT id
			  FROM StateLookup
			 WHERE name = raw_State
		);
		
		-- Incident State
		INSERT INTO `FBI_ACTIVE_SHOOTERS_2000_2018`.`IncidentState`
		(
			IncidentId,
			StateId
		)
		VALUES (
			incident_id,
			state_id
		);
		
		-- Shooter
		INSERT INTO `FBI_ACTIVE_SHOOTERS_2000_2018`.`Shooter`
		(
			IncidentId,
			Name,
			Gender,
			Age,
			TerminatingEvent,
			ShooterFate,
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
	END LOOP;
	
	CLOSE iterator;
	
	-- --------------------------------------------------------
	--
	-- Process Multi-State Incident
	--
	
	-- Pull Incident ID
	SET incident_id = null;
	SET incident_id = (
		SELECT Id
		  FROM `FBI_ACTIVE_SHOOTERS_2000_2018`.`Incident`
		 WHERE Name='Advanced Granite Solutions and 28th Street Auto Sales and Service'
	);
	
	--
	-- Maryland
	--
	
	-- Pull Maryland State ID
	SET state_id = null;
	SET state_id = (
		SELECT Id
		  FROM `FBI_ACTIVE_SHOOTERS_2000_2018`.`StateLookup`
		 WHERE name='Maryland'
	);
	
	-- Check If Maryland Exists
	--
	-- Depending upon how the database handles enum partials, it may or may not
	-- have truncated "Maryland & Delaware" to "Maryland", and created the record.
	SET incident_state_id = null;
	SET incident_state_id = (
		SELECT Id
		  FROM `FBI_ACTIVE_SHOOTERS_2000_2018`.`IncidentState`
		 WHERE incidentId=incident_id
		   AND StateId=state_id
	);
	
	-- Create Maryland Records
	IF (incident_state_id IS NULL) THEN
		INSERT INTO IncidentState (IncidentId, StateId)
		VALUES (incident_id, state_id);
	END IF;
	
	--
	-- Delaware
	--
		
	-- Pull Delaware State ID
	SET state_id = null;
	SET state_id = (
		SELECT Id
		  FROM `FBI_ACTIVE_SHOOTERS_2000_2018`.`StateLookup`
		 WHERE name='Delaware'
	);
	
	-- Check If Delaware Exists
	SET incident_state_id = null;
	SET incident_state_id = (
		SELECT Id
		  FROM `FBI_ACTIVE_SHOOTERS_2000_2018`.`IncidentState`
		 WHERE incidentId=incident_id
		   AND StateId=state_id
	);
	
	-- Create Delaware Records
	IF (incident_state_id IS NULL) THEN
		INSERT INTO IncidentState (IncidentId, StateId)
		VALUES (incident_id, state_id);
	END IF;
	
	
	-- --------------------------------------------------------
	--
	-- Process Multi-Shooter Incidents
	--
	
	--
	-- Jacob Carl England & Alvin Lee Watts
	--
	
	-- Pull Shooter ID
	SET shooter_id = null;
	SET shooter_id = (
		SELECT id
		  FROM `FBI_ACTIVE_SHOOTERS_2000_2018`.`SHOOTER`
		 WHERE Name='Jacob Carl England & Alvin Lee Watts'
	);
	
	-- Pull Incident ID
	SET incident_id = null;
	SET incident_id = (
		SELECT IncidentId
		  FROM `FBI_ACTIVE_SHOOTERS_2000_2018`.`SHOOTER`
		 WHERE id=shooter_id
	);

	-- Fix First Shooter's record, and ensure gender is correct
	UPDATE Shooter
	   SET Gender = 'MALE',
	       Name = 'Jacob Carl England'
	 WHERE id=shooter_id;

	
	-- Add Second Shooter
	INSERT INTO SHOOTER (
		IncidentId,
		Name,
		Gender,
		Age,
		TerminatingEvent,
		ShooterFate,
		SurrenderedDuringIncident
	)
	VALUES (
		incident_id,
		'Alvin Lee Watts',
		'MALE',
		32,
		'Fled the scene',
		'Escaped (Arrested Later)',
		'NO'
	);


	--
	-- Jerad Dwain Miller & Amanda Renee Miller (Husband & Wife)
	--
	
	-- Pull Shooter ID
	SET shooter_id = null;
	SET shooter_id = (
		SELECT id
		  FROM `FBI_ACTIVE_SHOOTERS_2000_2018`.`SHOOTER`
		 WHERE Name='Jerad Dwain Miller & Amanda Renee Miller (Husband & Wife)'
	);
	
	-- Pull Incident ID
	SET incident_id = null;
	SET incident_id = (
		SELECT IncidentId
		  FROM `FBI_ACTIVE_SHOOTERS_2000_2018`.`SHOOTER`
		 WHERE id=shooter_id
	);

	-- Fix First Shooter's record, and ensure gender is correct
	UPDATE Shooter
	   SET Gender = 'MALE',
	       Name = 'Jerad Dwain Miller',
	       TerminatingEvent='Shot by police (Killed)',
	       ShooterFate='Killed'
	 WHERE id=shooter_id;
	
	-- Add Second Shooter
	INSERT INTO SHOOTER (
		IncidentId,
		Name,
		Gender,
		Age,
		TerminatingEvent,
		ShooterFate,
		SurrenderedDuringIncident
	)
	VALUES (
		incident_id,
		'Amanda Renee Miller',
		'FEMALE',
		22,
		'Suicide after engaging police',
		'Suicide',
		'NO'
	);
	
	--
	-- Syed Rizwan Farook & Tashfeen Malik (Husband & Wife)
	--
	
	-- Pull Shooter ID
	SET shooter_id = null;
	SET shooter_id = (
		SELECT id
		  FROM `FBI_ACTIVE_SHOOTERS_2000_2018`.`SHOOTER`
		 WHERE Name='Syed Rizwan Farook & Tashfeen Malik (Husband & Wife)'
	);
	
	-- Pull Incident ID
	SET incident_id = null;
	SET incident_id = (
		SELECT IncidentId
		  FROM `FBI_ACTIVE_SHOOTERS_2000_2018`.`SHOOTER`
		 WHERE id=shooter_id
	);

	-- Fix First Shooter's record, and ensure gender is correct
	UPDATE Shooter
	   SET Gender = 'MALE',
	       Name = 'Syed Rizwan Farook'
	 WHERE id=shooter_id;

	
	-- Add Second Shooter
	INSERT INTO SHOOTER (
		IncidentId,
		Name,
		Gender,
		Age,
		TerminatingEvent,
		ShooterFate,
		SurrenderedDuringIncident
	)
	VALUES (
		incident_id,
		'Tashfeen Malik',
		'FEMALE',
		29,
		'Fled the scene; Shot by police (Killed)',
		'Killed',
		'NO'
	);
END //
DELIMITER ;

CALL fbi_active_shooters_2000_2018.parseRawRecords();
