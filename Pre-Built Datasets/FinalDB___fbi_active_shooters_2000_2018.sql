START TRANSACTION;

--
-- Database: `fbi_active_shooters_2000_2018`
--
CREATE DATABASE `fbi_active_shooters_2000_2018`;
USE `fbi_active_shooters_2000_2018`;

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `parseRawRecords` ()  BEGIN
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
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `incident`
--

CREATE TABLE `incident` (
  `Id` int(11) NOT NULL,
  `Name` varchar(250) NOT NULL,
  `Date` date NOT NULL,
  `Time` time NOT NULL,
  `LocationType` enum('Commerce','Education','Government','Health Care','House of Worship','Open Space','Other','Residence') NOT NULL,
  `Rifles` int(11) DEFAULT NULL,
  `Shotguns` int(11) DEFAULT NULL,
  `Handguns` int(11) DEFAULT NULL,
  `Deaths` int(11) NOT NULL,
  `Wounded` int(11) NOT NULL,
  `TotalCasualties` int(11) NOT NULL
);

--
-- Dumping data for table `incident`
--

INSERT INTO `incident` (`Id`, `Name`, `Date`, `Time`, `LocationType`, `Rifles`, `Shotguns`, `Handguns`, `Deaths`, `Wounded`, `TotalCasualties`) VALUES
(1, 'Edgewater Technology, Inc.', '2000-12-26', '11:15:00', 'Commerce', 1, 1, 1, 7, 0, 7),
(2, 'Amko Trading Store', '2001-01-09', '12:00:00', 'Commerce', 0, 0, 2, 4, 0, 4),
(3, 'Navistar International Corporation Factory', '2001-02-05', '09:40:00', 'Commerce', 2, 1, 1, 4, 4, 8),
(4, 'Santana High School', '2001-03-05', '09:20:00', 'Education', 0, 0, 1, 2, 13, 15),
(5, 'Granite Hills High School', '2001-03-22', '12:55:00', 'Education', 0, 1, 1, 0, 5, 5),
(6, 'Laidlaw Transit Services Maintenance Yard', '2001-04-23', '06:00:00', 'Commerce', 0, 0, 1, 1, 3, 4),
(7, 'Nu-Wood Decorative Millwork Plant', '2001-12-06', '14:31:00', 'Commerce', 0, 1, 0, 1, 6, 7),
(8, 'Appalachian School of Law', '2002-01-16', '13:15:00', 'Education', 0, 0, 1, 3, 3, 6),
(9, 'Bertrand Products, Inc.', '2002-03-22', '08:15:00', 'Commerce', 1, 1, 0, 4, 5, 9),
(10, 'Tom Bradley International Terminal at Los Angeles International Airport', '2002-07-04', '11:30:00', 'Government', 0, 0, 2, 2, 2, 4),
(11, '18 Miles of U.S. Route 64 from Sallisaw to Roland, Oklahoma', '2002-10-26', '17:00:00', 'Open Space', 0, 1, 0, 2, 8, 10),
(12, 'Labor Ready, Inc.', '2003-02-25', '06:25:00', 'Commerce', 0, 0, 1, 4, 1, 5),
(13, 'Red Lion Junior High School', '2003-04-24', '07:34:00', 'Education', 0, 0, 3, 1, 0, 1),
(14, 'Case Western Reserve University, Weatherhead School of Management', '2003-05-09', '15:55:00', 'Education', 1, 0, 1, 1, 2, 3),
(15, 'Modine Manufacturing Company', '2003-07-01', '22:28:00', 'Commerce', 0, 0, 1, 3, 5, 8),
(16, 'Lockheed Martin Subassembly Plant', '2003-07-08', '09:30:00', 'Commerce', 1, 1, 0, 6, 8, 14),
(17, 'Kanawha County Board of Education', '2003-07-17', '19:00:00', 'Education', 2, 0, 2, 0, 1, 1),
(18, 'Gold Leaf Nursery', '2003-07-28', '11:40:00', 'Commerce', 0, 0, 1, 3, 0, 3),
(19, 'Andover Industries', '2003-08-19', '08:20:00', 'Commerce', 0, 0, 4, 1, 2, 3),
(20, 'Windy City Core Supply, Inc.', '2003-08-27', '08:30:00', 'Commerce', 0, 0, 1, 6, 0, 6),
(21, 'Rocori High School', '2003-09-24', '11:35:00', 'Education', 0, 0, 1, 2, 0, 2),
(22, 'Watkins Motor Lines', '2003-11-06', '09:57:00', 'Commerce', 0, 0, 2, 2, 3, 5),
(23, 'Columbia High School', '2004-02-09', '10:30:00', 'Education', 0, 1, 0, 0, 1, 1),
(24, 'ConAgra Plant', '2004-07-02', '17:00:00', 'Commerce', 0, 0, 1, 6, 2, 8),
(25, 'Radio Shack in Gateway Mall', '2004-11-18', '18:45:00', 'Commerce', 0, 0, 1, 2, 1, 3),
(26, 'Private Property near Meteor, Wisconsin', '2004-11-21', '12:00:00', 'Open Space', 1, 0, 0, 6, 2, 8),
(27, 'DaimlerChrysler’s Toledo North Assembly Plant', '2005-01-26', '20:34:00', 'Commerce', 0, 1, 0, 1, 2, 3),
(28, 'Best Buy in Hudson Valley Mall', '2005-02-13', '15:15:00', 'Commerce', 1, 0, 0, 0, 2, 2),
(29, 'Living Church of God', '2005-03-12', '12:51:00', 'House of Worship', 0, 0, 1, 7, 4, 11),
(30, 'Red Lake High School and Residence', '2005-03-21', '14:49:00', 'Education', 0, 1, 2, 9, 6, 15),
(31, 'California Auto Specialist and Apartment Complex', '2005-08-08', '14:40:00', 'Commerce', 0, 0, 1, 3, 3, 6),
(32, 'Parking Lots in Philadelphia, Pennsylvania', '2005-10-07', '10:13:00', 'Open Space', 0, 0, 1, 2, 0, 2),
(33, 'Campbell County Comprehensive High School', '2005-11-08', '14:14:00', 'Education', 0, 0, 1, 1, 2, 3),
(34, 'Tacoma Mall', '2005-11-20', '12:00:00', 'Commerce', 1, 0, 1, 0, 6, 6),
(35, 'Burger King and Huddle House', '2005-11-22', '06:10:00', 'Commerce', 1, 0, 0, 1, 2, 3),
(36, 'Santa Barbara U.S. Postal Processing and Distribution Center', '2006-01-30', '19:15:00', 'Government', 0, 0, 1, 6, 0, 6),
(37, 'Pine Middle School', '2006-03-14', '09:00:00', 'Education', 0, 0, 1, 0, 2, 2),
(38, 'Residence in Capitol Hill Neighborhood, Seattle, Washington', '2006-03-25', '07:03:00', 'Residence', 1, 1, 1, 6, 2, 8),
(39, 'Safeway Warehouse', '2006-06-25', '15:03:00', 'Commerce', 0, 0, 1, 1, 5, 6),
(40, 'Jewish Federation of Greater Seattle', '2006-07-28', '16:00:00', 'House of Worship', 0, 0, 2, 1, 5, 6),
(41, 'Essex Elementary School and Two Residences', '2006-08-24', '13:55:00', 'Education', 0, 0, 1, 2, 2, 4),
(42, 'Orange High School and Residence', '2006-08-30', '13:00:00', 'Education', 2, 1, 0, 1, 2, 3),
(43, 'Weston High School', '2006-09-29', '08:00:00', 'Education', 1, 0, 1, 1, 0, 1),
(44, 'West Nickel Mines School', '2006-10-02', '10:30:00', 'Education', 1, 1, 1, 5, 5, 10),
(45, 'Memorial Middle School', '2006-10-09', '07:40:00', 'Education', 1, 0, 1, 0, 0, 0),
(46, 'Trolley Square Mall', '2007-02-12', '18:45:00', 'Commerce', 0, 1, 1, 5, 4, 9),
(47, 'ZigZag Net, Inc.', '2007-02-12', '20:00:00', 'Commerce', 1, 0, 1, 3, 1, 4),
(48, 'Kenyon Press', '2007-03-05', '09:00:00', 'Commerce', 0, 0, 1, 0, 3, 3),
(49, 'Virginia Polytechnic Institute and State University', '2007-04-16', '07:15:00', 'Education', 0, 0, 2, 32, 17, 49),
(50, 'Target Store', '2007-04-29', '15:25:00', 'Commerce', 1, 0, 0, 2, 8, 10),
(51, 'Residence, Latah County Courthouse, and First Presbyterian Church', '2007-05-19', '23:00:00', 'Government', 2, 0, 0, 3, 3, 6),
(52, 'Liberty Transportation', '2007-08-08', '15:15:00', 'Commerce', 2, 0, 2, 2, 0, 2),
(53, 'Co-op City Apartment Building’s Leasing Office', '2007-08-30', '07:50:00', 'Commerce', 0, 0, 1, 1, 2, 3),
(54, 'Giordano and Giordano Law Office', '2007-10-04', '14:00:00', 'Commerce', 0, 0, 1, 2, 3, 5),
(55, 'Residence in Crandon, Wisconsin', '2007-10-07', '02:45:00', 'Residence', 1, 0, 0, 6, 1, 7),
(56, 'Am-Pac Tire Pros', '2007-10-08', '07:30:00', 'Commerce', 0, 0, 1, 1, 2, 3),
(57, 'SuccessTech Academy', '2007-10-10', '13:02:00', 'Education', 0, 0, 2, 0, 4, 4),
(58, 'Von Maur in Westroads Mall', '2007-12-05', '13:42:00', 'Commerce', 1, 0, 0, 8, 4, 12),
(59, 'Youth with a Mission Training Center/New Life Church', '2007-12-09', '00:29:00', 'House of Worship', 1, 0, 2, 4, 5, 9),
(60, 'Kirkwood City Hall', '2008-02-07', '19:00:00', 'Government', 0, 0, 2, 6, 0, 6),
(61, 'Louisiana Technical College', '2008-02-08', '08:35:00', 'Education', 0, 0, 1, 2, 0, 2),
(62, 'Cole Hall Auditorium, Northern Illinois University', '2008-02-14', '15:00:00', 'Education', 0, 1, 3, 5, 16, 21),
(63, 'Wendy’s Fast Food Restaurant', '2008-03-03', '12:15:00', 'Commerce', 0, 0, 1, 1, 4, 5),
(64, 'Player’s Bar and Grill', '2008-05-25', '02:25:00', 'Commerce', 0, 0, 1, 2, 2, 4),
(65, 'Atlantis Plastics Factory', '2008-06-25', '00:00:00', 'Commerce', 0, 0, 1, 5, 1, 6),
(66, 'Tennessee Valley Unitarian Universalist Church', '2008-07-27', '10:18:00', 'House of Worship', 0, 1, 0, 2, 7, 9),
(67, 'Interstate 5 in Skagit County, Washington', '2008-09-02', '14:15:00', 'Open Space', 1, 0, 0, 6, 4, 10),
(68, 'The Zone', '2009-01-24', '22:37:00', 'Commerce', 0, 0, 1, 2, 7, 9),
(69, 'Coffee and Geneva Counties, Alabama', '2009-03-10', '16:00:00', 'Open Space', 1, 0, 0, 10, 1, 11),
(70, 'Pinelake Health and Rehabilitation Center', '2009-03-29', '10:00:00', 'Health Care', 1, 1, 1, 8, 3, 11),
(71, 'American Civic Association Center', '2009-04-03', '10:31:00', 'Commerce', 0, 0, 2, 13, 4, 17),
(72, 'Kkottongnae Retreat Camp', '2009-04-07', '19:23:00', 'House of Worship', 0, 0, 1, 1, 2, 3),
(73, 'Harkness Hall at Hampton University', '2009-04-26', '00:57:00', 'Education', 0, 0, 3, 0, 2, 2),
(74, 'Larose-Cut Off Middle School', '2009-05-18', '09:00:00', 'Education', 0, 0, 1, 0, 0, 0),
(75, 'U.S. Army Recruiting Center', '2009-06-01', '10:19:00', 'Government', 2, 0, 1, 1, 1, 2),
(76, 'United States Holocaust Memorial Museum', '2009-06-10', '12:52:00', 'Government', 1, 0, 0, 1, 0, 1),
(77, 'Family Dental Care', '2009-07-01', '10:30:00', 'Commerce', 1, 0, 0, 1, 4, 5),
(78, 'Club LT Tranz', '2009-07-25', '04:40:00', 'Commerce', NULL, NULL, NULL, 1, 2, 3),
(79, 'LA Fitness', '2009-08-04', '19:56:00', 'Commerce', 0, 0, 3, 3, 9, 12),
(80, 'Multiple Locations in Owosso, Michigan', '2009-09-11', '07:20:00', 'Open Space', 0, 0, 3, 2, 0, 2),
(81, 'Fort Hood Soldier Readiness Processing Center', '2009-11-05', '13:20:00', 'Government', 0, 0, 2, 13, 32, 45),
(82, 'Reynolds, Smith and Hills', '2009-11-06', '11:44:00', 'Commerce', 0, 0, 1, 1, 5, 6),
(83, 'Sandbar Sports Grill', '2009-11-07', '19:28:00', 'Commerce', 0, 0, 1, 1, 3, 4),
(84, 'Legacy Metrolab', '2009-11-10', '11:49:00', 'Commerce', 1, 1, 1, 1, 2, 3),
(85, 'Forza Coffee Shop', '2009-11-29', '08:15:00', 'Commerce', 0, 0, 1, 4, 0, 4),
(86, 'Grady Crawford Construction Company', '2009-12-23', '13:50:00', 'Commerce', 0, 0, 1, 2, 1, 3),
(87, 'Lloyd D. George U.S. Courthouse and Federal Building', '2010-01-04', '08:02:00', 'Government', 0, 1, 0, 1, 1, 2),
(88, 'ABB Plant', '2010-01-07', '06:30:00', 'Commerce', 1, 1, 2, 3, 5, 8),
(89, 'Penske Truck Rental', '2010-01-12', '14:00:00', 'Commerce', 0, 0, 2, 3, 2, 5),
(90, 'Residence in Brooksville, Florida', '2010-01-14', '14:59:00', 'Residence', 0, 0, 1, 3, 2, 5),
(91, 'Farm King Store', '2010-02-03', '12:45:00', 'Commerce', 1, 0, 0, 0, 0, 0),
(92, 'Inskip Elementary School', '2010-02-10', '12:49:00', 'Education', 0, 0, 1, 0, 2, 2),
(93, 'Shelby Center, University of Alabama', '2010-02-12', '16:00:00', 'Education', 0, 0, 1, 3, 3, 6),
(94, 'Deer Creek Middle School', '2010-02-23', '15:10:00', 'Education', 1, 0, 0, 0, 2, 2),
(95, 'The Pentagon', '2010-03-04', '18:36:00', 'Government', 0, 0, 1, 0, 2, 2),
(96, 'The Ohio State University, Maintenance Building', '2010-03-09', '03:30:00', 'Education', 0, 0, 2, 1, 1, 2),
(97, 'Publix Super Market', '2010-03-30', '12:00:00', 'Commerce', 0, 0, 1, 1, 0, 1),
(98, 'Parkwest Medical Center', '2010-04-19', '16:30:00', 'Health Care', 0, 0, 1, 1, 2, 3),
(99, 'Blue Sky Carnival', '2010-05-07', '22:22:00', 'Open Space', 0, 0, 1, 0, 1, 1),
(100, 'Boulder Stove and Flooring', '2010-05-17', '11:05:00', 'Commerce', 0, 0, 1, 2, 0, 2),
(101, 'AT&T Cellular', '2010-05-27', '13:00:00', 'Commerce', 0, 0, 1, 0, 1, 1),
(102, 'Yoyito Café', '2010-06-06', '22:00:00', 'Commerce', 0, 0, 1, 4, 3, 7),
(103, 'Emcore Corporation', '2010-07-12', '09:30:00', 'Commerce', 0, 0, 1, 2, 4, 6),
(104, 'Hartford Beer Distribution Center', '2010-08-03', '07:00:00', 'Commerce', 0, 0, 2, 8, 2, 10),
(105, 'Kraft Foods Factory', '2010-09-09', '20:35:00', 'Commerce', 0, 0, 1, 2, 1, 3),
(106, 'Fort Bliss Convenience Store', '2010-09-20', '15:00:00', 'Government', 0, 0, 1, 1, 1, 2),
(107, 'AmeriCold Logistics', '2010-09-22', '21:54:00', 'Commerce', 0, 0, 1, 0, 3, 3),
(108, 'Gainesville, Florida', '2010-10-04', '16:00:00', 'Open Space', 0, 0, 1, 1, 5, 6),
(109, 'Kelly Elementary School', '2010-10-08', '12:10:00', 'Education', 0, 0, 1, 0, 2, 2),
(110, 'Washington, D.C. Department of Public Works', '2010-10-13', '06:14:00', 'Government', 0, 0, 1, 1, 1, 2),
(111, 'Walmart', '2010-10-29', '08:57:00', 'Commerce', 0, 0, 2, 0, 3, 3),
(112, 'Panama City School Board Meeting', '2010-12-14', '14:14:00', 'Education', 0, 0, 1, 0, 0, 0),
(113, 'Millard South High School', '2011-01-05', '12:44:00', 'Education', 0, 0, 1, 1, 1, 2),
(114, 'Safeway Grocery', '2011-01-08', '10:10:00', 'Open Space', 0, 0, 1, 6, 13, 19),
(115, 'Minaret Temple 174', '2011-04-08', '23:27:00', 'Commerce', 0, 0, 1, 2, 8, 10),
(116, 'Copley Township Neighborhood, Ohio', '2011-08-07', '10:55:00', 'Residence', 0, 0, 2, 7, 1, 8),
(117, 'House Party in South Jamaica, New York', '2011-08-27', '00:40:00', 'Residence', 0, 0, 2, 0, 11, 11),
(118, 'International House of Pancakes', '2011-09-06', '08:58:00', 'Commerce', 1, 0, 0, 4, 7, 11),
(119, 'Crawford County Courthouse', '2011-09-13', '15:37:00', 'Government', 1, 0, 3, 0, 1, 1),
(120, 'Lehigh Southwest Cement Plant', '2011-10-05', '04:15:00', 'Commerce', 2, 1, 1, 3, 7, 10),
(121, 'Salon Meritage', '2011-10-12', '13:20:00', 'Commerce', 0, 0, 3, 7, 1, 8),
(122, 'Southern California Edison Corporate Office Building', '2011-12-16', '13:30:00', 'Commerce', 0, 0, 1, 2, 2, 4),
(123, 'McBride Lumber Company', '2012-01-13', '06:10:00', 'Commerce', 0, 1, 0, 3, 1, 4),
(124, 'Middletown City Court', '2012-02-08', '09:05:00', 'Government', 0, 1, 0, 0, 1, 1),
(125, 'Chardon High School', '2012-02-27', '07:30:00', 'Education', 0, 0, 1, 3, 3, 6),
(126, 'University of Pittsburgh Medical Center, Western Psychiatric Institute and Clinic', '2012-03-08', '13:40:00', 'Education', 0, 0, 2, 1, 7, 8),
(127, 'J.T. Tire', '2012-03-23', '15:02:00', 'Commerce', 0, 0, 1, 2, 2, 4),
(128, 'Oikos University', '2012-04-02', '10:30:00', 'Education', 0, 0, 1, 7, 3, 10),
(129, 'Streets of Tulsa, Oklahoma', '2012-04-06', '01:03:00', 'Open Space', 0, 0, 2, 3, 2, 5),
(130, 'Café Racer', '2012-05-30', '10:52:00', 'Commerce', 0, 0, 2, 5, 0, 5),
(131, 'Copper Top Bar', '2012-07-17', '00:29:00', 'Commerce', 1, 0, 0, 0, 18, 18),
(132, 'Cinemark Century 16', '2012-07-20', '00:30:00', 'Commerce', 1, 1, 1, 12, 58, 70),
(133, 'Sikh Temple of Wisconsin', '2012-08-05', '10:25:00', 'House of Worship', 0, 0, 1, 6, 4, 10),
(134, 'Perry Hall High School', '2012-08-27', '10:45:00', 'Education', 0, 1, 0, 0, 1, 1),
(135, 'Pathmark Supermarket', '2012-08-31', '04:00:00', 'Commerce', 1, 0, 1, 2, 0, 2),
(136, 'Accent Signage Systems', '2012-09-27', '16:35:00', 'Commerce', 0, 0, 1, 6, 2, 8),
(137, 'Las Dominicanas M&M Hair Salon', '2012-10-18', '11:04:00', 'Commerce', 0, 0, 1, 3, 1, 4),
(138, 'Azana Day Salon', '2012-10-21', '11:09:00', 'Commerce', 0, 0, 1, 3, 4, 7),
(139, 'Valley Protein', '2012-11-06', '08:15:00', 'Commerce', 0, 0, 1, 2, 2, 4),
(140, 'Clackamas Town Center Mall', '2012-12-11', '15:25:00', 'Commerce', 1, 0, 0, 2, 1, 3),
(141, 'Sandy Hook Elementary School and Residence', '2012-12-14', '09:30:00', 'Education', 1, 0, 2, 27, 2, 29),
(142, 'St. Vincent’s Hospital', '2012-12-15', '04:00:00', 'Health Care', 0, 0, 1, 0, 3, 3),
(143, 'Frankstown Township, Pennsylvania', '2012-12-21', '08:59:00', 'Open Space', 0, 0, 2, 3, 3, 6),
(144, 'Taft Union High School', '2013-01-10', '08:59:00', 'Education', 0, 1, 0, 0, 2, 2),
(145, 'Osborn Maledon Law Firm', '2013-01-30', '10:45:00', 'Commerce', 0, 0, 1, 2, 1, 3),
(146, 'John’s Barbershop and Gaffey’s Clean Car Center', '2013-03-13', '09:30:00', 'Commerce', 0, 1, 0, 4, 2, 6),
(147, 'New River Community College, Satellite Campus', '2013-04-12', '13:55:00', 'Education', 0, 1, 0, 0, 2, 2),
(148, 'Pinewood Village Apartments', '2013-04-21', '21:30:00', 'Residence', 0, 1, 1, 4, 0, 4),
(149, 'Brady, Texas and Jacksonville, North Carolina', '2013-05-26', '04:30:00', 'Open Space', 1, 0, 1, 2, 5, 7),
(150, 'Santa Monica College and Residence', '2013-06-07', '11:52:00', 'Education', 0, 0, 1, 5, 4, 9),
(151, 'Parking Lots for Kellum Law Firm and Walmart', '2013-06-21', '11:44:00', 'Open Space', 0, 1, 0, 0, 4, 4),
(152, 'Hialeah Apartment Building', '2013-07-26', '18:30:00', 'Residence', 0, 0, 1, 6, 0, 6),
(153, 'Pennsylvania Municipal Building', '2013-08-05', '19:19:00', 'Government', 1, 0, 1, 3, 2, 5),
(154, 'Lake Butler, Florida', '2013-08-24', '09:20:00', 'Open Space', 1, 1, 0, 2, 2, 4),
(155, 'Washington Navy Yard Building 197', '2013-09-16', '08:16:00', 'Government', 0, 1, 1, 12, 7, 19),
(156, 'Sparks Middle School', '2013-10-21', '07:16:00', 'Education', 0, 0, 1, 1, 2, 3),
(157, 'Albuquerque, New Mexico', '2013-10-26', '11:20:00', 'Open Space', 2, 0, 3, 0, 4, 4),
(158, 'Los Angeles International Airport', '2013-11-01', '09:18:00', 'Government', 1, 0, 0, 1, 3, 4),
(159, 'Arapahoe High School', '2013-12-13', '12:30:00', 'Education', 0, 1, 0, 1, 0, 1),
(160, 'Renown Regional Medical Center', '2013-12-17', '14:00:00', 'Health Care', 0, 1, 2, 1, 2, 3),
(161, 'Berrendo Middle School', '2014-01-14', '07:30:00', 'Education', 0, 1, 0, 0, 3, 3),
(162, 'Martin’s Supermarket', '2014-01-15', '22:09:00', 'Commerce', 0, 0, 1, 2, 0, 2),
(163, 'The Mall in Columbia', '2014-01-25', '11:15:00', 'Commerce', 0, 1, 0, 2, 5, 7),
(164, 'Cedarville Rancheria Tribal Office', '2014-02-20', '15:30:00', 'Government', 0, 0, 1, 4, 2, 6),
(165, 'Fort Hood Army Base', '2014-04-02', '16:00:00', 'Government', 0, 0, 1, 3, 12, 15),
(166, 'Jewish Community Center of Greater Kansas City and Village Shalom Retirement Community', '2014-04-13', '13:00:00', 'House of Worship', 0, 1, 2, 3, 0, 3),
(167, 'Federal Express', '2014-04-29', '05:50:00', 'Commerce', 0, 1, 0, 0, 6, 6),
(168, 'Residence and Construction Site in Jonesboro, Arkansas', '2014-05-03', '13:00:00', 'Residence', 0, 0, 1, 3, 4, 7),
(169, 'Multiple Locations in Isla Vista, California', '2014-05-23', '21:27:00', 'Open Space', 0, 0, 1, 6, 14, 20),
(170, 'Seattle Pacific University', '2014-06-05', '15:25:00', 'Education', 0, 1, 0, 1, 3, 4),
(171, 'Forsyth County Courthouse', '2014-06-06', '10:00:00', 'Government', 1, 0, 3, 0, 1, 1),
(172, 'Cici’s Pizza and Walmart', '2014-06-08', '11:20:00', 'Commerce', 0, 1, 2, 3, 0, 3),
(173, 'Reynolds High School', '2014-06-10', '08:05:00', 'Education', 1, 0, 1, 1, 1, 2),
(174, 'Sister Marie Lenahan Wellness Center', '2014-07-24', '14:20:00', 'Health Care', 0, 0, 1, 1, 1, 2),
(175, 'Hon-Dah Resort Casino and Conference Center', '2014-08-02', '18:38:00', 'Commerce', 1, 0, 0, 0, 2, 2),
(176, 'United Parcel Service', '2014-09-23', '09:20:00', 'Commerce', 0, 0, 1, 2, 0, 2),
(177, 'Marysville-Pilchuck High School', '2014-10-24', '10:39:00', 'Education', 0, 0, 1, 4, 3, 7),
(178, 'Florida State University', '2014-11-20', '00:00:00', 'Education', 0, 0, 1, 0, 3, 3),
(179, 'Neighborhood in Tallahassee, Florida', '2014-11-22', '10:15:00', 'Residence', 0, 0, 1, 1, 1, 2),
(180, 'Government Buildings in Austin, Texas', '2014-11-28', '02:21:00', 'Government', 1, 0, 1, 0, 0, 0),
(181, 'Multiple Locations in Moscow, Idaho', '2015-01-10', '14:31:00', 'Open Space', NULL, NULL, NULL, 3, 1, 4),
(182, 'Melbourne Square Mall', '2015-01-17', '09:31:00', 'Commerce', 0, 0, 3, 1, 1, 2),
(183, 'New Hope City Hall', '2015-01-26', '19:15:00', 'Government', 0, 1, 0, 0, 4, 4),
(184, 'Monroeville Mall', '2015-02-07', '19:33:00', 'Commerce', 0, 0, 1, 0, 3, 3),
(185, 'Sioux Steel Pro∙Tec', '2015-02-12', '14:00:00', 'Commerce', 0, 0, 1, 1, 2, 3),
(186, 'Dad’s Sing Along Club', '2015-03-14', '02:00:00', 'Commerce', 0, 0, 1, 0, 2, 2),
(187, 'Multiple Locations in Mesa, Arizona', '2015-03-18', '08:39:00', 'Open Space', 0, 0, 1, 1, 5, 6),
(188, 'Residence in Panama City Beach, Florida', '2015-03-28', '00:53:00', 'Residence', 0, 0, 1, 0, 7, 7),
(189, 'North Milwaukee Avenue, Chicago', '2015-04-19', '23:50:00', 'Open Space', 0, 0, 1, 0, 0, 0),
(190, 'Trestle Trail Bridge, Wisconsin', '2015-05-03', '19:30:00', 'Open Space', 0, 0, 2, 3, 1, 4),
(191, 'Walmart Supercenter', '2015-05-26', '01:00:00', 'Commerce', 0, 0, 1, 1, 1, 2),
(192, 'Emanuel African Methodist Episcopal Church', '2015-06-17', '21:00:00', 'House of Worship', 1, 0, 0, 9, 0, 9),
(193, 'Omni Austin Hotel Downtown', '2015-07-05', '04:48:00', 'Commerce', 1, 0, 0, 1, 0, 1),
(194, 'Two Military Centers in Chattanooga, Tennessee', '2015-07-16', '10:51:00', 'Government', 1, 0, 0, 5, 2, 7),
(195, 'Grand 16 Theatre', '2015-07-23', '19:15:00', 'Commerce', 0, 0, 1, 2, 9, 11),
(196, 'Umpqua Community College', '2015-10-01', '10:38:00', 'Education', 1, 0, 3, 9, 7, 16),
(197, 'Syverud Law Office and Miller-Meier Limb and Brace, Inc.', '2015-10-26', '13:56:00', 'Commerce', 0, 0, 1, 0, 2, 2),
(198, 'Neighborhood in Colorado Springs, Colorado', '2015-10-31', '08:55:00', 'Open Space', 1, 0, 2, 3, 0, 3),
(199, 'Planned Parenthood – Colorado Springs Westside Health Center', '2015-11-27', '11:38:00', 'Health Care', 1, 0, 0, 3, 9, 12),
(200, 'Inland Regional Center', '2015-12-02', '11:30:00', 'Commerce', 2, 0, 2, 14, 22, 36),
(201, 'Multiple Locations in Kalamazoo, Michigan', '2016-02-20', '17:40:00', 'Open Space', 0, 0, 1, 6, 2, 8),
(202, 'Excel Industries and Newton and Hesston, Kansas', '2016-02-25', '16:57:00', 'Commerce', 1, 0, 1, 3, 14, 17),
(203, 'Madison Junior/Senior High School', '2016-02-29', '11:30:00', 'Education', 0, 0, 1, 0, 4, 4),
(204, 'Prince George’s County Police Department District 3 Station', '2016-03-13', '16:30:00', 'Government', 0, 0, 1, 1, 0, 1),
(205, 'Antigo High School', '2016-04-23', '23:02:00', 'Education', 1, 0, 0, 0, 2, 2),
(206, 'Knight Transportation Building', '2016-05-04', '08:45:00', 'Commerce', 0, 1, 1, 1, 2, 3),
(207, 'Arizona State Route 87', '2016-05-24', '20:30:00', 'Open Space', 1, 0, 0, 0, 2, 2),
(208, 'Memorial Tire and Auto', '2016-05-29', '10:15:00', 'Commerce', 1, 0, 1, 1, 6, 7),
(209, 'Pulse Nightclub', '2016-06-12', '02:02:00', 'Commerce', 1, 0, 1, 49, 53, 102),
(210, 'Days Inn and Volunteer Parkway', '2016-07-07', '02:18:00', 'Open Space', 1, 0, 1, 1, 3, 4),
(211, 'Protest in Dallas, Texas', '2016-07-07', '21:00:00', 'Open Space', 2, 0, 1, 5, 11, 16),
(212, 'Benny’s Car Wash, Oil Change & B-Quik and Hair Crown Beauty Supply', '2016-07-17', '08:40:00', 'Open Space', 2, 0, 1, 3, 3, 6),
(213, 'House Party in Mukilteo, Washington', '2016-07-30', '00:07:00', 'Residence', 1, 0, 0, 3, 1, 4),
(214, 'Multiple Locations in Joplin, Missouri', '2016-08-13', '05:08:00', 'Open Space', 1, 0, 1, 0, 5, 5),
(215, 'Multiple Locations in Philadelphia, Pennsylvania', '2016-09-16', '23:15:00', 'Open Space', 0, 0, 1, 1, 5, 6),
(216, 'Cascade Mall', '2016-09-23', '18:52:00', 'Commerce', 1, 0, 0, 5, 0, 5),
(217, 'Law Street in Houston, Texas', '2016-09-26', '06:30:00', 'Open Space', 0, 0, 1, 0, 9, 9),
(218, 'Townville Elementary School', '2016-09-28', '13:45:00', 'Education', 0, 0, 1, 2, 3, 5),
(219, 'FreightCar America', '2016-10-25', '06:00:00', 'Commerce', 0, 0, 1, 1, 3, 4),
(220, 'H-E-B Grocery Store', '2016-11-28', '03:15:00', 'Commerce', 0, 0, 1, 1, 3, 4),
(221, 'Fort Lauderdale-Hollywood International Airport', '2017-01-06', '13:15:00', 'Government', 0, 0, 1, 5, 8, 13),
(222, 'West Liberty-Salem High School', '2017-01-20', '07:36:00', 'Education', 0, 1, 0, 0, 2, 2),
(223, 'Marathon Savings Bank and Tlusty, Kennedy & Dirks, S.C.', '2017-03-22', '12:27:00', 'Commerce', 1, 0, 1, 4, 0, 4),
(224, 'Las Vegas Bus', '2017-03-25', '10:45:00', 'Other', 0, 0, 1, 1, 1, 2),
(225, 'Residence and Bus Stop in Sanford, Florida', '2017-03-27', '06:20:00', 'Open Space', 1, 0, 0, 2, 4, 6),
(226, 'The Cooler', '2017-04-15', '21:30:00', 'Commerce', 0, 0, 1, 0, 4, 4),
(227, 'Multiple Locations in Fresno, California', '2017-04-18', '10:45:00', 'Open Space', 0, 0, 1, 3, 0, 3),
(228, 'Group Home in Topeka, Kansas', '2017-04-30', '15:50:00', 'Health Care', 0, 0, 1, 3, 1, 4),
(229, 'La Jolla Crossroads Apartment Complex', '2017-04-30', '18:00:00', 'Residence', 0, 0, 1, 1, 7, 8),
(230, 'Pine Kirk Care Center', '2017-05-12', '07:30:00', 'Health Care', 0, 1, 1, 3, 0, 3),
(231, 'Fiamma Inc.', '2017-06-05', '08:00:00', 'Commerce', 0, 0, 1, 5, 0, 5),
(232, 'Weis Supermarket', '2017-06-08', '01:00:00', 'Commerce', 0, 2, 0, 3, 0, 3),
(233, 'Eugene Simpson Stadium Park', '2017-06-14', '07:15:00', 'Open Space', 1, 0, 1, 0, 4, 4),
(234, 'UPS Customer Center', '2017-06-14', '08:55:00', 'Commerce', 0, 0, 2, 3, 5, 8),
(235, 'Bronx-Lebanon Hospital Center', '2017-06-30', '14:50:00', 'Health Care', 1, 0, 0, 1, 6, 7),
(236, 'Highway 141 in Gateway, Colorado', '2017-07-30', '16:15:00', 'Open Space', 0, 0, 1, 0, 0, 0),
(237, 'Clovis-Carver Public Library', '2017-08-28', '16:15:00', 'Government', 0, 0, 1, 2, 4, 6),
(238, 'Freeman High School', '2017-09-13', '10:00:00', 'Education', 1, 0, 1, 1, 3, 4),
(239, 'Burnette Chapel Church of Christ', '2017-09-24', '11:15:00', 'House of Worship', 0, 0, 2, 1, 7, 8),
(240, 'Route 91 Harvest Festival', '2017-10-01', '22:08:00', 'Open Space', 4, 0, 0, 58, 489, 547),
(241, 'Advanced Granite Solutions and 28th Street Auto Sales and Service', '2017-10-18', '08:58:00', 'Commerce', 0, 0, 1, 3, 3, 6),
(242, 'Multiple Locations in Clearlake Oaks, California', '2017-10-23', '11:23:00', 'Commerce', 0, 1, 1, 2, 3, 5),
(243, 'Walmart in Thornton, Colorado', '2017-11-01', '18:10:00', 'Commerce', 0, 0, 1, 3, 0, 3),
(244, 'First Baptist Church in Sutherland Springs, Texas', '2017-11-05', '11:20:00', 'House of Worship', 1, 0, 0, 26, 20, 46),
(245, 'Rancho Tehama Elementary School and Multiple Locations in Tehama County, California', '2017-11-14', '07:53:00', 'Education', 1, 0, 2, 5, 14, 19),
(246, 'Dollar General Store', '2017-11-14', '14:45:00', 'Commerce', 2, 0, 0, 0, 1, 1),
(247, 'Schlenker Automotive', '2017-11-17', '16:30:00', 'Commerce', 0, 0, 1, 1, 1, 2),
(248, 'Aztec High School', '2017-12-07', '08:00:00', 'Education', 0, 0, 1, 2, 0, 2),
(249, 'Multiple Locations in Baltimore, Maryland', '2017-12-15', '14:55:00', 'Open Space', 1, 0, 1, 0, 3, 3),
(250, 'University of Cincinnati Medical Center', '2017-12-20', '14:00:00', 'Health Care', 0, 0, 2, 0, 1, 1),
(251, 'Marshall County High School', '2018-01-23', '07:57:00', 'Education', 0, 0, 1, 2, 21, 23),
(252, 'Marjory Stoneman Douglas High School', '2018-02-14', '14:30:00', 'Education', 1, 0, 0, 17, 17, 34),
(253, 'City Grill Café', '2018-03-07', '06:30:00', 'Commerce', 1, 0, 0, 2, 2, 4),
(254, 'YouTube Headquarters', '2018-04-03', '12:45:00', 'Commerce', 0, 0, 1, 0, 4, 4),
(255, 'Waffle House', '2018-04-22', '03:30:00', 'Commerce', 1, 0, 0, 4, 4, 8),
(256, 'Highway 365 Near Whitehall Road in Gainesville, Georgia', '2018-05-04', '11:58:00', 'Open Space', 0, 0, 1, 0, 3, 3),
(257, 'Dixon High School', '2018-05-16', '08:00:00', 'Education', 1, 0, 0, 0, 0, 0),
(258, 'Santa Fe High School', '2018-05-18', '07:30:00', 'Education', 0, 1, 1, 10, 12, 22),
(259, 'Louie’s Lakeside Eatery', '2018-05-24', '18:30:00', 'Commerce', 0, 0, 1, 0, 4, 4),
(260, 'Noblesville West Middle School', '2018-05-25', '09:06:00', 'Education', 0, 0, 2, 0, 2, 2),
(261, 'Highway 509 Near Seattle-Tacoma International Airport', '2018-06-13', '13:42:00', 'Open Space', NULL, NULL, NULL, 0, 0, 0),
(262, 'Capital Gazette', '2018-06-29', '14:34:00', 'Commerce', 0, 1, 0, 5, 2, 7),
(263, 'Ben E. Keith Gulf Coast', '2018-08-20', '02:00:00', 'Commerce', 0, 0, 1, 1, 1, 2),
(264, 'GLHF Game Bar', '2018-08-26', '13:34:00', 'Commerce', 0, 0, 2, 2, 11, 13),
(265, 'Fifth Third Center', '2018-09-06', '09:10:00', 'Commerce', 0, 0, 1, 3, 2, 5),
(266, 'T & T Trucking, Inc. and a Residence', '2018-09-12', '17:20:00', 'Commerce', 0, 0, 1, 5, 0, 5),
(267, 'WTS Paradigm', '2018-09-19', '10:30:00', 'Commerce', 0, 0, 1, 0, 4, 4),
(268, 'Masontown Borough Municipal Center', '2018-09-19', '14:00:00', 'Government', 0, 0, 1, 0, 4, 4),
(269, 'Rite Aid Perryman Distribution Center’s Liberty Support Center', '2018-09-20', '09:06:00', 'Commerce', 0, 0, 1, 3, 3, 6),
(270, 'Kroger Grocery Store in Jeffersontown, Kentucky', '2018-10-24', '15:00:00', 'Commerce', 0, 0, 1, 2, 0, 2),
(271, 'Tree of Life Synagogue', '2018-10-27', '09:45:00', 'House of Worship', 1, 0, 3, 11, 6, 17),
(272, 'Hot Yoga Tallahassee', '2018-11-02', '17:37:00', 'Commerce', 0, 0, 1, 2, 5, 7),
(273, 'Helen Vine Recovery Center', '2018-11-05', '01:30:00', 'Health Care', 0, 0, 1, 1, 2, 3),
(274, 'Borderline Bar and Grill', '2018-11-07', '23:20:00', 'Commerce', 0, 0, 1, 12, 16, 28),
(275, 'Ben E. Keith Albuquerque', '2018-11-12', '18:56:00', 'Commerce', 0, 0, 1, 0, 3, 3),
(276, 'Mercy Hospital & Medical Center', '2018-11-19', '15:20:00', 'Health Care', 0, 0, 1, 3, 0, 3),
(277, 'Motel 6 in Albuquerque, New Mexico', '2018-12-24', '11:00:00', 'Commerce', 1, 0, 0, 0, 0, 0);

-- --------------------------------------------------------

--
-- Table structure for table `incidentstate`
--

CREATE TABLE `incidentstate` (
  `Id` int(11) NOT NULL,
  `incidentId` int(11) NOT NULL,
  `stateId` int(11) NOT NULL
);

--
-- Dumping data for table `incidentstate`
--

INSERT INTO `incidentstate` (`Id`, `incidentId`, `stateId`) VALUES
(1, 1, 22),
(2, 2, 44),
(3, 3, 14),
(4, 4, 5),
(5, 5, 5),
(6, 6, 5),
(7, 7, 15),
(8, 8, 47),
(9, 9, 15),
(10, 10, 5),
(11, 11, 37),
(12, 12, 1),
(13, 13, 39),
(14, 14, 36),
(15, 15, 26),
(16, 16, 25),
(17, 17, 49),
(18, 18, 10),
(19, 19, 36),
(20, 20, 14),
(21, 21, 24),
(22, 22, 36),
(23, 23, 33),
(24, 24, 17),
(25, 25, 10),
(26, 26, 50),
(27, 27, 36),
(28, 28, 33),
(29, 29, 50),
(30, 30, 24),
(31, 31, 5),
(32, 32, 39),
(33, 33, 43),
(34, 34, 48),
(35, 35, 41),
(36, 36, 5),
(37, 37, 29),
(38, 38, 48),
(39, 39, 6),
(40, 40, 48),
(41, 41, 46),
(42, 42, 34),
(43, 43, 50),
(44, 44, 39),
(45, 45, 26),
(46, 46, 45),
(47, 47, 39),
(48, 48, 5),
(49, 49, 47),
(50, 50, 26),
(51, 51, 13),
(52, 52, 36),
(53, 53, 33),
(54, 54, 19),
(55, 55, 50),
(56, 56, 5),
(57, 57, 36),
(58, 58, 28),
(59, 59, 6),
(60, 60, 26),
(61, 61, 19),
(62, 62, 14),
(63, 63, 10),
(64, 64, 29),
(65, 65, 18),
(66, 66, 43),
(67, 67, 48),
(68, 68, 38),
(69, 69, 1),
(70, 70, 34),
(71, 71, 33),
(72, 72, 5),
(73, 73, 47),
(74, 74, 19),
(75, 75, 4),
(76, 76, 9),
(77, 77, 5),
(78, 78, 44),
(79, 79, 39),
(80, 80, 23),
(81, 81, 44),
(82, 82, 10),
(83, 83, 6),
(84, 84, 38),
(85, 85, 48),
(86, 86, 19),
(87, 87, 29),
(88, 88, 26),
(89, 89, 11),
(90, 90, 10),
(91, 91, 14),
(92, 92, 43),
(93, 93, 1),
(94, 94, 6),
(95, 95, 47),
(96, 96, 36),
(97, 97, 10),
(98, 98, 43),
(99, 99, 31),
(100, 100, 6),
(101, 101, 33),
(102, 102, 10),
(103, 103, 32),
(104, 104, 7),
(105, 105, 39),
(106, 106, 44),
(107, 107, 28),
(108, 108, 10),
(109, 109, 5),
(110, 110, 9),
(111, 111, 29),
(112, 112, 10),
(113, 113, 28),
(114, 114, 3),
(115, 115, 39),
(116, 116, 36),
(117, 117, 33),
(118, 118, 29),
(119, 119, 17),
(120, 120, 5),
(121, 121, 5),
(122, 122, 5),
(123, 123, 34),
(124, 124, 33),
(125, 125, 36),
(126, 126, 39),
(127, 127, 34),
(128, 128, 5),
(129, 129, 37),
(130, 130, 48),
(131, 131, 1),
(132, 132, 6),
(133, 133, 50),
(134, 134, 21),
(135, 135, 31),
(136, 136, 24),
(137, 137, 10),
(138, 138, 50),
(139, 139, 5),
(140, 140, 38),
(141, 141, 7),
(142, 142, 1),
(143, 143, 39),
(144, 144, 5),
(145, 145, 3),
(146, 146, 33),
(147, 147, 47),
(148, 148, 48),
(149, 149, 44),
(150, 150, 5),
(151, 151, 34),
(152, 152, 10),
(153, 153, 39),
(154, 154, 10),
(155, 155, 48),
(156, 156, 29),
(157, 157, 32),
(158, 158, 5),
(159, 159, 6),
(160, 160, 29),
(161, 161, 32),
(162, 162, 15),
(163, 163, 21),
(164, 164, 5),
(165, 165, 44),
(166, 166, 17),
(167, 167, 11),
(168, 168, 4),
(169, 169, 5),
(170, 170, 48),
(171, 171, 11),
(172, 172, 29),
(173, 173, 38),
(174, 174, 39),
(175, 175, 3),
(176, 176, 1),
(177, 177, 48),
(178, 178, 10),
(179, 179, 10),
(180, 180, 44),
(181, 181, 13),
(182, 182, 10),
(183, 183, 24),
(184, 184, 39),
(185, 185, 42),
(186, 186, 44),
(187, 187, 3),
(188, 188, 10),
(189, 189, 14),
(190, 190, 50),
(191, 191, 35),
(192, 192, 41),
(193, 193, 44),
(194, 194, 43),
(195, 195, 19),
(196, 196, 38),
(197, 197, 16),
(198, 198, 6),
(199, 199, 6),
(200, 200, 5),
(201, 201, 23),
(202, 202, 17),
(203, 203, 36),
(204, 204, 21),
(205, 205, 50),
(206, 206, 44),
(207, 207, 3),
(208, 208, 44),
(209, 209, 10),
(210, 210, 43),
(211, 211, 44),
(212, 212, 19),
(213, 213, 48),
(214, 214, 26),
(215, 215, 39),
(216, 216, 48),
(217, 217, 44),
(218, 218, 41),
(219, 219, 47),
(220, 220, 44),
(221, 221, 10),
(222, 222, 36),
(223, 223, 50),
(224, 224, 29),
(225, 225, 10),
(226, 226, 14),
(227, 227, 5),
(228, 228, 17),
(229, 229, 5),
(230, 230, 36),
(231, 231, 10),
(232, 232, 39),
(233, 233, 47),
(234, 234, 5),
(235, 235, 33),
(236, 236, 6),
(237, 237, 32),
(238, 238, 48),
(239, 239, 43),
(240, 240, 29),
(241, 241, 21),
(242, 242, 5),
(243, 243, 6),
(244, 244, 44),
(245, 245, 5),
(246, 246, 33),
(247, 247, 10),
(248, 248, 32),
(249, 249, 21),
(250, 250, 36),
(251, 251, 18),
(252, 252, 10),
(253, 253, 1),
(254, 254, 5),
(255, 255, 43),
(256, 256, 11),
(257, 257, 14),
(258, 258, 44),
(259, 259, 37),
(260, 260, 15),
(261, 261, 48),
(262, 262, 21),
(263, 263, 44),
(264, 264, 10),
(265, 265, 36),
(266, 266, 5),
(267, 267, 50),
(268, 268, 39),
(269, 269, 21),
(270, 270, 18),
(271, 271, 39),
(272, 272, 10),
(273, 273, 5),
(274, 274, 5),
(275, 275, 32),
(276, 276, 14),
(277, 277, 32),
(278, 241, 8);

-- --------------------------------------------------------

--
-- Table structure for table `rawrecords`
--

CREATE TABLE `rawrecords` (
  `Id` int(11) NOT NULL,
  `IncidentName` varchar(250) NOT NULL,
  `Date` varchar(250) NOT NULL,
  `Time` varchar(250) NOT NULL,
  `State` varchar(250) NOT NULL,
  `Location` varchar(250) NOT NULL,
  `ShooterName` varchar(250) DEFAULT NULL,
  `ShooterGender` varchar(250) DEFAULT NULL,
  `ShooterAge` varchar(250) DEFAULT NULL,
  `Rifles` varchar(250) DEFAULT NULL,
  `Shotguns` varchar(250) DEFAULT NULL,
  `Handguns` varchar(250) DEFAULT NULL,
  `Deaths` varchar(250) NOT NULL,
  `Wounded` varchar(250) NOT NULL,
  `Total(Calculated)` varchar(250) NOT NULL,
  `TerminatingEvent` varchar(250) NOT NULL,
  `ShootersFate` varchar(250) NOT NULL,
  `SurrenderedDuringIncident` varchar(250) NOT NULL
);

--
-- Dumping data for table `rawrecords`
--

INSERT INTO `rawrecords` (`Id`, `IncidentName`, `Date`, `Time`, `State`, `Location`, `ShooterName`, `ShooterGender`, `ShooterAge`, `Rifles`, `Shotguns`, `Handguns`, `Deaths`, `Wounded`, `Total(Calculated)`, `TerminatingEvent`, `ShootersFate`, `SurrenderedDuringIncident`) VALUES
(1, 'Edgewater Technology, Inc.', '26-Dec-00', '11:15 AM', 'Massachusetts', 'Commerce', 'Michael M. McDermott', 'MALE', '42', '1', '1', '1', '7', '0', '7', 'Shooter completed goal and stopped', 'Arrested', 'YES'),
(2, 'Amko Trading Store', '9-Jan-01', '12:00 PM', 'Texas', 'Commerce', 'Ki Yung Park', 'MALE', '54', '0', '0', '2', '4', '0', '4', 'Suicide when police arrived', 'Suicide', 'NO'),
(3, 'Navistar International Corporation Factory', '5-Feb-01', '9:40 AM', 'Illinois', 'Commerce', 'William Daniel Baker', 'MALE', '57', '2', '1', '1', '4', '4', '8', 'Suicide before police arrived', 'Suicide', 'NO'),
(4, 'Santana High School', '5-Mar-01', '9:20 AM', 'California', 'Education', 'Charles Andrew Williams Jr', 'MALE', '15', '0', '0', '1', '2', '13', '15', 'Surrendered to Police', 'Arrested', 'YES'),
(5, 'Granite Hills High School', '22-Mar-01', '12:55 PM', 'California', 'Education', 'Jason Anthony Hoffman', 'MALE', '18', '0', '1', '1', '0', '5', '5', 'Shot by police (Survived)', 'Arrested', 'NO'),
(6, 'Laidlaw Transit Services Maintenance Yard', '23-Apr-01', '6:00 AM', 'California', 'Commerce', 'Cathline Repunte', 'FEMALE', '36', '0', '0', '1', '1', '3', '4', 'Physical intervention by civilian', 'Arrested', 'NO'),
(7, 'Nu-Wood Decorative Millwork Plant', '6-Dec-01', '2:31 PM', 'Indiana', 'Commerce', 'Robert L. Wissman', 'MALE', '36', '0', '1', '0', '1', '6', '7', 'Suicide before police arrived', 'Suicide', 'NO'),
(8, 'Appalachian School of Law', '16-Jan-02', '1:15 PM', 'Virginia', 'Education', 'Peter Odighizuma', 'MALE', '43', '0', '0', '1', '3', '3', '6', 'Physical intervention by civilian & off-duty police', 'Arrested', 'NO'),
(9, 'Bertrand Products, Inc.', '22-Mar-02', '8:15 AM', 'Indiana', 'Commerce', 'William Lockey', 'MALE', '54', '1', '1', '0', '4', '5', '9', 'Suicide after engaging police', 'Suicide', 'NO'),
(10, 'Tom Bradley International Terminal at Los Angeles International Airport', '4-Jul-02', '11:30 AM', 'California', 'Government', 'Hesham Mohamed Ali Hadayet', 'MALE', '43', '0', '0', '2', '2', '2', '4', 'Shot by security guard (Killed)', 'Killed', 'NO'),
(11, '18 Miles of U.S. Route 64 from Sallisaw to Roland, Oklahoma', '26-Oct-02', '5:00 PM', 'Oklahoma', 'Open Space', 'Daniel Hawke Fears', 'MALE', '18', '0', '1', '0', '2', '8', '10', 'Automobile crash into police blockade', 'Arrested', 'NO'),
(12, 'Labor Ready, Inc.', '25-Feb-03', '6:25 AM', 'Alabama', 'Commerce', 'Emanuel Burl Patterson', 'MALE', '23', '0', '0', '1', '4', '1', '5', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(13, 'Red Lion Junior High School', '24-Apr-03', '7:34 AM', 'Pennsylvania', 'Education', 'James Sheets', 'MALE', '14', '0', '0', '3', '1', '0', '1', 'Suicide before police arrived', 'Suicide', 'NO'),
(14, 'Case Western Reserve University, Weatherhead School of Management', '9-May-03', '3:55 PM', 'Ohio', 'Education', 'Biswanath A. Halder', 'MALE', '62', '1', '0', '1', '1', '2', '3', 'Shot by police (Survived)', 'Arrested', 'NO'),
(15, 'Modine Manufacturing Company', '1-Jul-03', '10:28 PM', 'Missouri', 'Commerce', 'Jonathon W. Russell', 'MALE', '25', '0', '0', '1', '3', '5', '8', 'Suicide after engaging police', 'Suicide', 'NO'),
(16, 'Lockheed Martin Subassembly Plant', '8-Jul-03', '9:30 AM', 'Mississippi', 'Commerce', 'Douglas Paul Williams', 'MALE', '48', '1', '1', '0', '6', '8', '14', 'Suicide before police arrived', 'Suicide', 'NO'),
(17, 'Kanawha County Board of Education', '17-Jul-03', '7:00 PM', 'West Virginia', 'Education', 'Richard Dean Bright', 'MALE', '58', '2', '0', '2', '0', '1', '1', 'Physical intervention by civilian', 'Arrested', 'NO'),
(18, 'Gold Leaf Nursery', '28-Jul-03', '11:40 AM', 'Florida', 'Commerce', 'Agustin Casarubias-Dominguez (aka Andres Casarrubias)', 'MALE', '45', '0', '0', '1', '3', '0', '3', 'Physical intervention by civilian', 'Arrested', 'NO'),
(19, 'Andover Industries', '19-Aug-03', '8:20 AM', 'Ohio', 'Commerce', 'Richard Wayne Shadle', 'MALE', '32', '0', '0', '4', '1', '2', '3', 'Suicide before police arrived', 'Suicide', 'NO'),
(20, 'Windy City Core Supply, Inc.', '27-Aug-03', '8:30 AM', 'Illinois', 'Commerce', 'Salvador Tapia Solis', 'MALE', '36', '0', '0', '1', '6', '0', '6', 'Shot by police (Killed)', 'Killed', 'NO'),
(21, 'Rocori High School', '24-Sep-03', '11:35 AM', 'Minnesota', 'Education', 'John Jason McLaughlin', 'MALE', '15', '0', '0', '1', '2', '0', '2', 'Verbal intervention by civilian', 'Arrested', 'YES'),
(22, 'Watkins Motor Lines', '6-Nov-03', '9:57 AM', 'Ohio', 'Commerce', 'Joseph John Eschenbrenner, III (aka Tom West)', 'MALE', '50', '0', '0', '2', '2', '3', '5', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(23, 'Columbia High School', '9-Feb-04', '10:30 AM', 'New York', 'Education', 'Jon William Romano', 'MALE', '16', '0', '1', '0', '0', '1', '1', 'Physical intervention by civilian', 'Arrested', 'NO'),
(24, 'ConAgra Plant', '2-Jul-04', '5:00 PM', 'Kansas', 'Commerce', 'Elijah J. Brown', 'MALE', '21', '0', '0', '1', '6', '2', '8', 'Suicide before police arrived', 'Suicide', 'NO'),
(25, 'Radio Shack in Gateway Mall', '18-Nov-04', '6:45 PM', 'Florida', 'Commerce', 'Justin Michael Cudar', 'MALE', '25', '0', '0', '1', '2', '1', '3', 'Suicide before police arrived', 'Suicide', 'NO'),
(26, 'Private Property near Meteor, Wisconsin', '21-Nov-04', '12:00 PM', 'Wisconsin', 'Open Space', 'Chai Soua Vang', 'MALE', '36', '1', '0', '0', '6', '2', '8', 'Fled the scene', 'Arrested', 'NO'),
(27, 'DaimlerChrysler’s Toledo North Assembly Plant', '26-Jan-05', '8:34 PM', 'Ohio', 'Commerce', 'Myles Wesley Meyers', 'MALE', '54', '0', '1', '0', '1', '2', '3', 'Suicide before police arrived', 'Suicide', 'NO'),
(28, 'Best Buy in Hudson Valley Mall', '13-Feb-05', '3:15 PM', 'New York', 'Commerce', 'Robert Charles Bonelli Jr.', 'MALE', '25', '1', '0', '0', '0', '2', '2', 'Physical Intervention by Civilian', 'Arrested', 'NO'),
(29, 'Living Church of God', '12-Mar-05', '12:51 PM', 'Wisconsin', 'House of Worship', 'Terry M. Ratzmann', 'MALE', '44', '0', '0', '1', '7', '4', '11', 'Suicide before police arrived', 'Suicide', 'NO'),
(30, 'Red Lake High School and Residence', '21-Mar-05', '2:49 PM', 'Minnesota', 'Education', 'Jeffery James Weise', 'MALE', '16', '0', '1', '2', '9', '6', '15', 'Suicide after engaging police', 'Suicide', 'NO'),
(31, 'California Auto Specialist and Apartment Complex', '8-Aug-05', '2:40 PM', 'California', 'Commerce', 'Louis Mitchell Jr.', 'MALE', '35', '0', '0', '1', '3', '3', '6', 'Shot by police (Survived); fled the scene', 'Escaped (Arrested Later)', 'NO'),
(32, 'Parking Lots in Philadelphia, Pennsylvania', '7-Oct-05', '10:13 AM', 'Pennsylvania', 'Open Space', 'Alexander Elkin', 'MALE', '45', '0', '0', '1', '2', '0', '2', 'Suicide after engaging police', 'Suicide', 'NO'),
(33, 'Campbell County Comprehensive High School', '8-Nov-05', '2:14 PM', 'Tennessee', 'Education', 'Kenneth S. Bartley', 'MALE', '14', '0', '0', '1', '1', '2', '3', 'Physical intervention by civilian', 'Arrested', 'NO'),
(34, 'Tacoma Mall', '20-Nov-05', '12:00 PM', 'Washington', 'Commerce', 'Dominick Sergil Maldonado', 'MALE', '20', '1', '0', '1', '0', '6', '6', 'Verbal intervention by civilian', 'Arrested', 'YES'),
(35, 'Burger King and Huddle House', '22-Nov-05', '6:10 AM', 'South Carolina', 'Commerce', NULL, 'MALE', NULL, '1', '0', '0', '1', '2', '3', 'Fled the scene', 'Escaped (Never Caught)', 'NO'),
(36, 'Santa Barbara U.S. Postal Processing and Distribution Center', '30-Jan-06', '7:15 PM', 'California', 'Government', 'Jennifer San Marco', 'FEMALE', '44', '0', '0', '1', '6', '0', '6', 'Suicide before police arrived', 'Suicide', 'NO'),
(37, 'Pine Middle School', '14-Mar-06', '9:00 AM', 'Nevada', 'Education', 'James Scott Newman', 'MALE', '14', '0', '0', '1', '0', '2', '2', 'Physical intervention by civilian', 'Arrested', 'NO'),
(38, 'Residence in Capitol Hill Neighborhood, Seattle, Washington', '25-Mar-06', '7:03 AM', 'Washington', 'Residence', 'Kyle Aaron Huff', 'MALE', '28', '1', '1', '1', '6', '2', '8', 'Suicide when police arrived', 'Suicide', 'NO'),
(39, 'Safeway Warehouse', '25-Jun-06', '3:03 PM', 'Colorado', 'Commerce', 'Michael Julius Ford', 'MALE', '22', '0', '0', '1', '1', '5', '6', 'Shot by police (Killed)', 'Killed', 'NO'),
(40, 'Jewish Federation of Greater Seattle', '28-Jul-06', '4:00 PM', 'Washington', 'House of Worship', 'Naveed Afzal Haq', 'MALE', '30', '0', '0', '2', '1', '5', '6', 'Surrendered to Police', 'Arrested', 'YES'),
(41, 'Essex Elementary School and Two Residences', '24-Aug-06', '1:55 PM', 'Vermont', 'Education', 'Christopher Williams', 'MALE', '26', '0', '0', '1', '2', '2', '4', 'Attempted Suicide (Survived)', 'Arrested', 'NO'),
(42, 'Orange High School and Residence', '30-Aug-06', '1:00 PM', 'North Carolina', 'Education', 'Alvaro Castillo', 'MALE', '19', '2', '1', '0', '1', '2', '3', 'Physical intervention by police', 'Arrested', 'NO'),
(43, 'Weston High School', '29-Sep-06', '8:00 AM', 'Wisconsin', 'Education', 'Eric Jordan Hainstock', 'MALE', '15', '1', '0', '1', '1', '0', '1', 'Physical intervention by civilian', 'Arrested', 'NO'),
(44, 'West Nickel Mines School', '2-Oct-06', '10:30 AM', 'Pennsylvania', 'Education', 'Charles Carl Roberts', 'MALE', '32', '1', '1', '1', '5', '5', '10', 'Suicide when police arrived', 'Suicide', 'NO'),
(45, 'Memorial Middle School', '9-Oct-06', '7:40 AM', 'Missouri', 'Education', 'Thomas White', 'MALE', '13', '1', '0', '1', '0', '0', '0', 'Verbal intervention by civilian', 'Arrested', 'YES'),
(46, 'Trolley Square Mall', '12-Feb-07', '6:45 PM', 'Utah', 'Commerce', 'Sulejman Talovic', 'MALE', '18', '0', '1', '1', '5', '4', '9', 'Shot by police (Killed)', 'Killed', 'NO'),
(47, 'ZigZag Net, Inc.', '12-Feb-07', '8:00 PM', 'Pennsylvania', 'Commerce', 'Vincent Dortch', 'MALE', '44', '1', '0', '1', '3', '1', '4', 'Suicide after engaging police', 'Suicide', 'NO'),
(48, 'Kenyon Press', '5-Mar-07', '9:00 AM', 'California', 'Commerce', 'Alonso Jose Mendez', 'MALE', '68', '0', '0', '1', '0', '3', '3', 'Suicide before police arrived', 'Suicide', 'NO'),
(49, 'Virginia Polytechnic Institute and State University', '16-Apr-07', '7:15 AM', 'Virginia', 'Education', 'Seung Hui Cho', 'MALE', '23', '0', '0', '2', '32', '17', '49', 'Suicide when police arrived', 'Suicide', 'NO'),
(50, 'Target Store', '29-Apr-07', '3:25 PM', 'Missouri', 'Commerce', 'David Wayne Logsdon', 'MALE', '51', '1', '0', '0', '2', '8', '10', 'Shot by police (Killed)', 'Killed', 'NO'),
(51, 'Residence, Latah County Courthouse, and First Presbyterian Church', '19-May-07', '11:00 PM', 'Idaho', 'Government', 'Jason Kenneth Hamilton', 'MALE', '36', '2', '0', '0', '3', '3', '6', 'Suicide when police arrived', 'Suicide', 'NO'),
(52, 'Liberty Transportation', '8-Aug-07', '3:15 PM', 'Ohio', 'Commerce', 'Calvin Coolidge Neyland Jr.', 'MALE', '43', '2', '0', '2', '2', '0', '2', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(53, 'Co-op City Apartment Building’s Leasing Office', '30-Aug-07', '7:50 AM', 'New York', 'Commerce', 'Paulino Valenzuela', 'MALE', '44', '0', '0', '1', '1', '2', '3', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(54, 'Giordano and Giordano Law Office', '4-Oct-07', '2:00 PM', 'Louisiana', 'Commerce', 'John Chester Ashley', 'MALE', '63', '0', '0', '1', '2', '3', '5', 'Shot by police (Killed)', 'Killed', 'NO'),
(55, 'Residence in Crandon, Wisconsin', '7-Oct-07', '2:45 AM', 'Wisconsin', 'Residence', 'Tyler Peterson', 'MALE', '20', '1', '0', '0', '6', '1', '7', 'Suicide after engaging police', 'Suicide', 'NO'),
(56, 'Am-Pac Tire Pros', '8-Oct-07', '7:30 AM', 'California', 'Commerce', 'Robert Becerra', 'MALE', '29', '0', '0', '1', '1', '2', '3', 'Suicide before police arrived', 'Suicide', 'NO'),
(57, 'SuccessTech Academy', '10-Oct-07', '1:02 PM', 'Ohio', 'Education', 'Asa Halley Coon', 'MALE', '14', '0', '0', '2', '0', '4', '4', 'Suicide before police arrived', 'Suicide', 'NO'),
(58, 'Von Maur in Westroads Mall', '5-Dec-07', '1:42 PM', 'Nebraska', 'Commerce', 'Robert Arthur Hawkins', 'MALE', '19', '1', '0', '0', '8', '4', '12', 'Suicide before police arrived', 'Suicide', 'NO'),
(59, 'Youth with a Mission Training Center/New Life Church', '9-Dec-07', '12:29 AM', 'Colorado', 'House of Worship', 'Matthew John Murray', 'MALE', '24', '1', '0', '2', '4', '5', '9', 'Shot by security guard, then committed suicided', 'Suicide', 'NO'),
(60, 'Kirkwood City Hall', '7-Feb-08', '7:00 PM', 'Missouri', 'Government', 'Charles Lee Thornton', 'MALE', '52', '0', '0', '2', '6', '0', '6', 'Shot by police (Killed)', 'Killed', 'NO'),
(61, 'Louisiana Technical College', '8-Feb-08', '8:35 AM', 'Louisiana', 'Education', 'Latina Williams', 'FEMALE', '23', '0', '0', '1', '2', '0', '2', 'Suicide before police arrived', 'Suicide', 'NO'),
(62, 'Cole Hall Auditorium, Northern Illinois University', '14-Feb-08', '3:00 PM', 'Illinois', 'Education', 'Steven Phillip Kazmierczak', 'MALE', '27', '0', '1', '3', '5', '16', '21', 'Suicide before police arrived', 'Suicide', 'NO'),
(63, 'Wendy’s Fast Food Restaurant', '3-Mar-08', '12:15 PM', 'Florida', 'Commerce', 'Alburn Edward Blake', 'MALE', '60', '0', '0', '1', '1', '4', '5', 'Suicide before police arrived', 'Suicide', 'NO'),
(64, 'Player’s Bar and Grill', '25-May-08', '2:25 AM', 'Nevada', 'Commerce', 'Ernesto Villagomez', 'MALE', '30', '0', '0', '1', '2', '2', '4', 'Shot by civilian (Killed)', 'Killed', 'NO'),
(65, 'Atlantis Plastics Factory', '25-Jun-08', '12:00 AM', 'Kentucky', 'Commerce', 'Wesley Neal Higdon', 'MALE', '25', '0', '0', '1', '5', '1', '6', 'Suicide before police arrived', 'Suicide', 'NO'),
(66, 'Tennessee Valley Unitarian Universalist Church', '27-Jul-08', '10:18 AM', 'Tennessee', 'House of Worship', 'Jim David Adkisson', 'MALE', '58', '0', '1', '0', '2', '7', '9', 'Physical intervention by civilian', 'Arrested', 'NO'),
(67, 'Interstate 5 in Skagit County, Washington', '2-Sep-08', '2:15 PM', 'Washington', 'Open Space', 'Isaac Lee Zamora', 'MALE', '28', '1', '0', '0', '6', '4', '10', 'Fled the scene', 'Escaped (Turned self in)', 'NO'),
(68, 'The Zone', '24-Jan-09', '10:37 PM', 'Oregon', 'Commerce', 'Erik Salvador Ayala', 'MALE', '24', '0', '0', '1', '2', '7', '9', 'Attempted Suicide (Survived)', 'Arrested', 'NO'),
(69, 'Coffee and Geneva Counties, Alabama', '10-Mar-09', '4:00 PM', 'Alabama', 'Open Space', 'Michael Kenneth McLendon', 'MALE', '28', '1', '0', '0', '10', '1', '11', 'Suicide after engaging police', 'Suicide', 'NO'),
(70, 'Pinelake Health and Rehabilitation Center', '29-Mar-09', '10:00 AM', 'North Carolina', 'Health Care', 'Robert Kenneth Stewart', 'MALE', '45', '1', '1', '1', '8', '3', '11', 'Shot by police (Survived)', 'Arrested', 'NO'),
(71, 'American Civic Association Center', '3-Apr-09', '10:31 AM', 'New York', 'Commerce', 'Linh Phat Voong', 'MALE', '41', '0', '0', '2', '13', '4', '17', 'Suicide before police arrived', 'Suicide', 'NO'),
(72, 'Kkottongnae Retreat Camp', '7-Apr-09', '7:23 PM', 'California', 'House of Worship', 'John Suchan Chong', 'MALE', '69', '0', '0', '1', '1', '2', '3', 'Physical intervention by civilian', 'Arrested', 'NO'),
(73, 'Harkness Hall at Hampton University', '26-Apr-09', '12:57 AM', 'Virginia', 'Education', 'Odane Greg Maye', 'MALE', '18', '0', '0', '3', '0', '2', '2', 'Attempted Suicide (Survived)', 'Arrested', 'NO'),
(74, 'Larose-Cut Off Middle School', '18-May-09', '9:00 AM', 'Louisiana', 'Education', 'Justin Doucet', 'MALE', '15', '0', '0', '1', '0', '0', '0', 'Attempted Suicide (Survived)', 'Arrested', 'NO'),
(75, 'U.S. Army Recruiting Center', '1-Jun-09', '10:19 AM', 'Arkansas', 'Government', 'Carlos Leon Bledsoe', 'MALE', '23', '2', '0', '1', '1', '1', '2', 'Fled the scene; Surrendered when caught', 'Arrested', 'NO'),
(76, 'United States Holocaust Memorial Museum', '10-Jun-09', '12:52 PM', 'District of Columbia', 'Government', 'James Wenneker von Brunn', 'MALE', '88', '1', '0', '0', '1', '0', '1', 'Shot by police (Survived)', 'Arrested', 'NO'),
(77, 'Family Dental Care', '1-Jul-09', '10:30 AM', 'California', 'Commerce', 'Jaime Paredes', 'MALE', '30', '1', '0', '0', '1', '4', '5', 'Surrendered to Police', 'Arrested', 'NO'),
(78, 'Club LT Tranz', '25-Jul-09', '4:40 AM', 'Texas', 'Commerce', NULL, NULL, NULL, NULL, NULL, NULL, '1', '2', '3', 'Fled the scene', 'Escaped (Never Caught)', 'NO'),
(79, 'LA Fitness', '4-Aug-09', '7:56 PM', 'Pennsylvania', 'Commerce', 'George Sodini', 'MALE', '48', '0', '0', '3', '3', '9', '12', 'Suicide before police arrived', 'Suicide', 'NO'),
(80, 'Multiple Locations in Owosso, Michigan', '11-Sep-09', '7:20 AM', 'Michigan', 'Open Space', 'Harlan James Drake', 'MALE', '33', '0', '0', '3', '2', '0', '2', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(81, 'Fort Hood Soldier Readiness Processing Center', '5-Nov-09', '1:20 PM', 'Texas', 'Government', 'Nidal Malik Hasan', 'MALE', '39', '0', '0', '2', '13', '32', '45', 'Shot by police (Survived)', 'Arrested', 'NO'),
(82, 'Reynolds, Smith and Hills', '6-Nov-09', '11:44 AM', 'Florida', 'Commerce', 'Jason Samuel Rodriguez', 'MALE', '40', '0', '0', '1', '1', '5', '6', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(83, 'Sandbar Sports Grill', '7-Nov-09', '7:28 PM', 'Colorado', 'Commerce', 'Richard Allan Moreau', 'MALE', '63', '0', '0', '1', '1', '3', '4', 'Shooter completed goal and stopped', 'Arrested', 'YES'),
(84, 'Legacy Metrolab', '10-Nov-09', '11:49 AM', 'Oregon', 'Commerce', 'Robert Beiser', 'MALE', '39', '1', '1', '1', '1', '2', '3', 'Suicide before police arrived', 'Suicide', 'NO'),
(85, 'Forza Coffee Shop', '29-Nov-09', '8:15 AM', 'Washington', 'Commerce', 'Maurice Clemmons', 'MALE', '37', '0', '0', '1', '4', '0', '4', 'Shot by police (Killed)', 'Killed', 'NO'),
(86, 'Grady Crawford Construction Company', '23-Dec-09', '1:50 PM', 'Louisiana', 'Commerce', 'Richard Matthews', 'MALE', '53', '0', '0', '1', '2', '1', '3', 'Physical intervention by civilian', 'Arrested', 'NO'),
(87, 'Lloyd D. George U.S. Courthouse and Federal Building', '4-Jan-10', '8:02 AM', 'Nevada', 'Government', 'Johnny Lee Wicks Jr', 'MALE', '66', '0', '1', '0', '1', '1', '2', 'Shot by police (Killed)', 'Killed', 'NO'),
(88, 'ABB Plant', '7-Jan-10', '6:30 AM', 'Missouri', 'Commerce', 'Timothy Hendron', 'MALE', '51', '1', '1', '2', '3', '5', '8', 'Suicide before police arrived', 'Suicide', 'NO'),
(89, 'Penske Truck Rental', '12-Jan-10', '2:00 PM', 'Georgia', 'Commerce', 'Jesse James Warren', 'MALE', '60', '0', '0', '2', '3', '2', '5', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(90, 'Residence in Brooksville, Florida', '14-Jan-10', '2:59 PM', 'Florida', 'Residence', 'John William Kalisz', 'MALE', '55', '0', '0', '1', '3', '2', '5', 'Shot by pollice (Survived)', 'Arrested', 'NO'),
(91, 'Farm King Store', '3-Feb-10', '12:45 PM', 'Illinois', 'Commerce', 'Jonathan Joseph Labbe', 'MALE', '19', '1', '0', '0', '0', '0', '0', 'Suicide when police arrived', 'Suicide', 'NO'),
(92, 'Inskip Elementary School', '10-Feb-10', '12:49 PM', 'Tennessee', 'Education', 'Mark Stephen Foster', 'MALE', '48', '0', '0', '1', '0', '2', '2', 'Fled the scene', 'Arrested', 'NO'),
(93, 'Shelby Center, University of Alabama', '12-Feb-10', '4:00 PM', 'Alabama', 'Education', 'Amy Bishop Anderson', 'FEMALE', '44', '0', '0', '1', '3', '3', '6', 'Surrendered to Police', 'Arrested', 'NO'),
(94, 'Deer Creek Middle School', '23-Feb-10', '3:10 PM', 'Colorado', 'Education', 'Bruco Strongeagle Eastwood', 'MALE', '32', '1', '0', '0', '0', '2', '2', 'Physical intervention by civilian', 'Arrested', 'NO'),
(95, 'The Pentagon', '4-Mar-10', '6:36 PM', 'Virginia', 'Government', 'John Patrick Bedell', 'MALE', '36', '0', '0', '1', '0', '2', '2', 'Shot by police (Killed)', 'Killed', 'NO'),
(96, 'The Ohio State University, Maintenance Building', '9-Mar-10', '3:30 AM', 'Ohio', 'Education', 'Nathaniel Alvin Brown', 'MALE', '50', '0', '0', '2', '1', '1', '2', 'Suicide before police arrived', 'Suicide', 'NO'),
(97, 'Publix Super Market', '30-Mar-10', '12:00 PM', 'Florida', 'Commerce', 'Arunya Rouch', 'FEMALE', '41', '0', '0', '1', '1', '0', '1', 'Shot by police (Survived)', 'Arrested', 'NO'),
(98, 'Parkwest Medical Center', '19-Apr-10', '4:30 PM', 'Tennessee', 'Health Care', 'Abdo Ibssa', 'MALE', '38', '0', '0', '1', '1', '2', '3', 'Suicide before police arrived', 'Suicide', 'NO'),
(99, 'Blue Sky Carnival', '7-May-10', '10:22 PM', 'New Jersey', 'Open Space', 'Rasheed Cherry', 'MALE', '17', '0', '0', '1', '0', '1', '1', 'Shot by police (Survived)', 'Arrested', 'NO'),
(100, 'Boulder Stove and Flooring', '17-May-10', '11:05 AM', 'Colorado', 'Commerce', 'Robert Phillip Montgomery', 'MALE', '53', '0', '0', '1', '2', '0', '2', 'Suicide before police arrived', 'Suicide', 'NO'),
(101, 'AT&T Cellular', '27-May-10', '1:00 PM', 'New York', 'Commerce', 'Abraham Dickan', 'MALE', '79', '0', '0', '1', '0', '1', '1', 'Shot by off-duty police (Killed)', 'Killed', 'NO'),
(102, 'Yoyito Café', '6-Jun-10', '10:00 PM', 'Florida', 'Commerce', 'Gerardo Regalado', 'MALE', '37', '0', '0', '1', '4', '3', '7', 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(103, 'Emcore Corporation', '12-Jul-10', '9:30 AM', 'New Mexico', 'Commerce', 'Robert Reza', 'MALE', '37', '0', '0', '1', '2', '4', '6', 'Suicide when police arrived', 'Suicide', 'NO'),
(104, 'Hartford Beer Distribution Center', '3-Aug-10', '7:00 AM', 'Connecticut', 'Commerce', 'Omar Sheriff Thornton', 'MALE', '34', '0', '0', '2', '8', '2', '10', 'Suicide when police arrived', 'Suicide', 'NO'),
(105, 'Kraft Foods Factory', '9-Sep-10', '8:35 PM', 'Pennsylvania', 'Commerce', 'Yvonne Hiller', 'FEMALE', '43', '0', '0', '1', '2', '1', '3', 'Surrendered to Police', 'Arrested', 'YES'),
(106, 'Fort Bliss Convenience Store', '20-Sep-10', '3:00 PM', 'Texas', 'Government', 'Steven Jay Kropf', 'MALE', '63', '0', '0', '1', '1', '1', '2', 'Shot by police (Killed)', 'Killed', 'NO'),
(107, 'AmeriCold Logistics', '22-Sep-10', '9:54 PM', 'Nebraska', 'Commerce', 'Akouch Kashoual', 'MALE', '26', '0', '0', '1', '0', '3', '3', 'Suicide before police arrived', 'Suicide', 'NO'),
(108, 'Gainesville, Florida', '4-Oct-10', '4:00 PM', 'Florida', 'Open Space', 'Clifford Louis Miller Jr', 'MALE', '24', '0', '0', '1', '1', '5', '6', 'Suicide before police arrived', 'Suicide', 'NO'),
(109, 'Kelly Elementary School', '8-Oct-10', '12:10 PM', 'California', 'Education', 'Brendan O’Rourke (aka Brandon O’Rourke)', 'MALE', '41', '0', '0', '1', '0', '2', '2', 'Physical intervention by civilian', 'Arrested', 'NO'),
(110, 'Washington, D.C. Department of Public Works', '13-Oct-10', '6:14 AM', 'District of Columbia', 'Government', NULL, NULL, NULL, '0', '0', '1', '1', '1', '2', 'Fled the scene', 'Escaped (Never Caught)', 'NO'),
(111, 'Walmart', '29-Oct-10', '8:57 AM', 'Nevada', 'Commerce', 'John Dennis Gillane', 'MALE', '45', '0', '0', '2', '0', '3', '3', 'Surrendered to Police', 'Arrested', 'YES'),
(112, 'Panama City School Board Meeting', '14-Dec-10', '2:14 PM', 'Florida', 'Education', 'Clay Allen Duke', 'MALE', '56', '0', '0', '1', '0', '0', '0', 'Suicide after engaging police', 'Suicide', 'NO'),
(113, 'Millard South High School', '5-Jan-11', '12:44 PM', 'Nebraska', 'Education', 'Richard L. Butler Jr', 'MALE', '17', '0', '0', '1', '1', '1', '2', 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(114, 'Safeway Grocery', '8-Jan-11', '10:10 AM', 'Arizona', 'Open Space', 'Jared Lee Loughner', 'MALE', '22', '0', '0', '1', '6', '13', '19', 'Physical intervention by civilian', 'Arrested', 'NO'),
(115, 'Minaret Temple 174', '8-Apr-11', '11:27 PM', 'Pennsylvania', 'Commerce', 'Kanai Daniel Avery', 'MALE', '16', '0', '0', '1', '2', '8', '10', 'Physical Intervention by security guard', 'Arrested', 'NO'),
(116, 'Copley Township Neighborhood, Ohio', '7-Aug-11', '10:55 AM', 'Ohio', 'Residence', 'Michael Edward Hance', 'MALE', '51', '0', '0', '2', '7', '1', '8', 'Shot by police (Killed)', 'Killed', 'NO'),
(117, 'House Party in South Jamaica, New York', '27-Aug-11', '12:40 AM', 'New York', 'Residence', 'Tyrone Miller', 'MALE', '22', '0', '0', '2', '0', '11', '11', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(118, 'International House of Pancakes', '6-Sep-11', '8:58 AM', 'Nevada', 'Commerce', 'Eduardo Sencion (aka Eduardo Perez-Gonzalez)', 'MALE', '32', '1', '0', '0', '4', '7', '11', 'Suicide before police arrived', 'Suicide', 'NO'),
(119, 'Crawford County Courthouse', '13-Sep-11', '3:37 PM', 'Kansas', 'Government', 'Jesse Ray Palmer', 'MALE', '48', '1', '0', '3', '0', '1', '1', 'Shot by police (Killed)', 'Killed', 'NO'),
(120, 'Lehigh Southwest Cement Plant', '5-Oct-11', '4:15 AM', 'California', 'Commerce', 'Frank William Allman (aka Shareef Allman)', 'MALE', '49', '2', '1', '1', '3', '7', '10', 'Fled the scene; Shot by police (Killed)', 'Killed', 'NO'),
(121, 'Salon Meritage', '12-Oct-11', '1:20 PM', 'California', 'Commerce', 'Scott Evans Dekraai', 'MALE', '41', '0', '0', '3', '7', '1', '8', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(122, 'Southern California Edison Corporate Office Building', '16-Dec-11', '1:30 PM', 'California', 'Commerce', 'Andre Turner', 'MALE', '51', '0', '0', '1', '2', '2', '4', 'Suicide before police arrived', 'Suicide', 'NO'),
(123, 'McBride Lumber Company', '13-Jan-12', '6:10 AM', 'North Carolina', 'Commerce', 'Ronald Dean Davis', 'MALE', '50', '0', '1', '0', '3', '1', '4', 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(124, 'Middletown City Court', '8-Feb-12', '9:05 AM', 'New York', 'Government', 'Timothy Patrick Mulqueen', 'MALE', '43', '0', '1', '0', '0', '1', '1', 'Shot by police (Killed)', 'Killed', 'NO'),
(125, 'Chardon High School', '27-Feb-12', '7:30 AM', 'Ohio', 'Education', 'Thomas Michael Lane, III', 'MALE', '17', '0', '0', '1', '3', '3', '6', 'Physical intervention by civilian; fled the scene', 'Escaped (Arrested Later)', 'NO'),
(126, 'University of Pittsburgh Medical Center, Western Psychiatric Institute and Clinic', '8-Mar-12', '1:40 PM', 'Pennsylvania', 'Education', 'John Schick', 'MALE', '30', '0', '0', '2', '1', '7', '8', 'Shot by police (Killed)', 'Killed', 'NO'),
(127, 'J.T. Tire', '23-Mar-12', '3:02 PM', 'North Carolina', 'Commerce', 'O’Brian McNeil White', 'MALE', '24', '0', '0', '1', '2', '2', '4', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(128, 'Oikos University', '2-Apr-12', '10:30 AM', 'California', 'Education', 'Su Nam Ko (aka One L. Goh)', 'MALE', '43', '0', '0', '1', '7', '3', '10', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(129, 'Streets of Tulsa, Oklahoma', '6-Apr-12', '1:03 AM', 'Oklahoma', 'Open Space', 'Jacob Carl England & Alvin Lee Watts', 'MALE & MALE', '19 & 32', '0', '0', '2', '3', '2', '5', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(130, 'Café Racer', '30-May-12', '10:52 AM', 'Washington', 'Commerce', 'Ian Lee Stawicki', 'MALE', '40', '0', '0', '2', '5', '0', '5', 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(131, 'Copper Top Bar', '17-Jul-12', '12:29 AM', 'Alabama', 'Commerce', 'Nathan Van Wilkins', 'MALE', '44', '1', '0', '0', '0', '18', '18', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(132, 'Cinemark Century 16', '20-Jul-12', '12:30 AM', 'Colorado', 'Commerce', 'James Eagan Holmes', 'MALE', '24', '1', '1', '1', '12', '58', '70', 'Surrendered to Police', 'Arrested', 'YES'),
(133, 'Sikh Temple of Wisconsin', '5-Aug-12', '10:25 AM', 'Wisconsin', 'House of Worship', 'Wade Michael Page', 'MALE', '40', '0', '0', '1', '6', '4', '10', 'Suicide after engaging police', 'Suicide', 'NO'),
(134, 'Perry Hall High School', '27-Aug-12', '10:45 AM', 'Maryland', 'Education', 'Robert Wayne Gladden Jr.', 'MALE', '15', '0', '1', '0', '0', '1', '1', 'Physical intervention by civilian', 'Arrested', 'NO'),
(135, 'Pathmark Supermarket', '31-Aug-12', '4:00 AM', 'New Jersey', 'Commerce', 'Terence Tyler', 'MALE', '23', '1', '0', '1', '2', '0', '2', 'Suicide before police arrived', 'Suicide', 'NO'),
(136, 'Accent Signage Systems', '27-Sep-12', '4:35 PM', 'Minnesota', 'Commerce', 'Andrew John Engeldinger', 'MALE', '36', '0', '0', '1', '6', '2', '8', 'Suicide before police arrived', 'Suicide', 'NO'),
(137, 'Las Dominicanas M&M Hair Salon', '18-Oct-12', '11:04 AM', 'Florida', 'Commerce', 'Bradford Ramon Baumet', 'MALE', '36', '0', '0', '1', '3', '1', '4', 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(138, 'Azana Day Salon', '21-Oct-12', '11:09 AM', 'Wisconsin', 'Commerce', 'Radcliffe Franklin Haughton', 'MALE', '45', '0', '0', '1', '3', '4', '7', 'Suicide before police arrived', 'Suicide', 'NO'),
(139, 'Valley Protein', '6-Nov-12', '8:15 AM', 'California', 'Commerce', 'Lawrence Jones', 'MALE', '42', '0', '0', '1', '2', '2', '4', 'Suicide before police arrived', 'Suicide', 'NO'),
(140, 'Clackamas Town Center Mall', '11-Dec-12', '3:25 PM', 'Oregon', 'Commerce', 'Jacob Tyler Roberts', 'MALE', '22', '1', '0', '0', '2', '1', '3', 'Suicide before police arrived', 'Suicide', 'NO'),
(141, 'Sandy Hook Elementary School and Residence', '14-Dec-12', '9:30 AM', 'Connecticut', 'Education', 'Adam Lanza', 'MALE', '20', '1', '0', '2', '27', '2', '29', 'Suicide when police arrived', 'Suicide', 'NO'),
(142, 'St. Vincent’s Hospital', '15-Dec-12', '4:00 AM', 'Alabama', 'Health Care', 'Jason Heath Letts', 'MALE', '38', '0', '0', '1', '0', '3', '3', 'Shot by police (Killed)', 'Killed', 'NO'),
(143, 'Frankstown Township, Pennsylvania', '21-Dec-12', '8:59 AM', 'Pennsylvania', 'Open Space', 'Jeffrey Lee Michael', 'MALE', '44', '0', '0', '2', '3', '3', '6', 'Shot by police (Killed)', 'Killed', 'NO'),
(144, 'Taft Union High School', '10-Jan-13', '8:59 AM', 'California', 'Education', 'Bryan Oliver', 'MALE', '16', '0', '1', '0', '0', '2', '2', 'Verbal intervention by civilian', 'Arrested', 'NO'),
(145, 'Osborn Maledon Law Firm', '30-Jan-13', '10:45 AM', 'Arizona', 'Commerce', 'Arthur Douglas Harmon, III', 'MALE', '70', '0', '0', '1', '2', '1', '3', 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(146, 'John’s Barbershop and Gaffey’s Clean Car Center', '13-Mar-13', '9:30 AM', 'New York', 'Commerce', 'Kurt Myers', 'MALE', '64', '0', '1', '0', '4', '2', '6', 'Fled the scene; Shot by police (Killed)', 'Killed', 'NO'),
(147, 'New River Community College, Satellite Campus', '12-Apr-13', '1:55 PM', 'Virginia', 'Education', 'Neil Allen MacInnis', 'MALE', '22', '0', '1', '0', '0', '2', '2', 'Physical Intervention by security guard', 'Arrested', 'NO'),
(148, 'Pinewood Village Apartments', '21-Apr-13', '9:30 PM', 'Washington', 'Residence', 'Dennis Clark III', 'MALE', '27', '0', '1', '1', '4', '0', '4', 'Shot by police (Killed)', 'Killed', 'NO'),
(149, 'Brady, Texas and Jacksonville, North Carolina', '26-May-13', '4:30 AM', 'Texas', 'Open Space', 'Esteban Jimenez Smith', 'MALE', '23', '1', '0', '1', '2', '5', '7', 'Shot by police (Killed)', 'Killed', 'NO'),
(150, 'Santa Monica College and Residence', '7-Jun-13', '11:52 AM', 'California', 'Education', 'John Zawahri', 'MALE', '23', '0', '0', '1', '5', '4', '9', 'Shot by police (Killed)', 'Killed', 'NO'),
(151, 'Parking Lots for Kellum Law Firm and Walmart', '21-Jun-13', '11:44 AM', 'North Carolina', 'Open Space', 'Lakin Anthony Faust', 'MALE', '23', '0', '1', '0', '0', '4', '4', 'Shot by police (Survived)', 'Arrested', 'NO'),
(152, 'Hialeah Apartment Building', '26-Jul-13', '6:30 PM', 'Florida', 'Residence', 'Pedro Alberto Vargas', 'MALE', '42', '0', '0', '1', '6', '0', '6', 'Shot by police (Killed)', 'Killed', 'NO'),
(153, 'Pennsylvania Municipal Building', '5-Aug-13', '7:19 PM', 'Pennsylvania', 'Government', 'Rockne Warren Newell', 'MALE', '59', '1', '0', '1', '3', '2', '5', 'Physical intervention by civilian', 'Arrested', 'NO'),
(154, 'Lake Butler, Florida', '24-Aug-13', '9:20 AM', 'Florida', 'Open Space', 'Hubert Allen Jr.', 'MALE', '72', '1', '1', '0', '2', '2', '4', 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(155, 'Washington Navy Yard Building 197', '16-Sep-13', '8:16 AM', 'Washington', 'Government', 'Aaron Alexis', 'MALE', '34', '0', '1', '1', '12', '7', '19', 'Shot by police (Killed)', 'Killed', 'NO'),
(156, 'Sparks Middle School', '21-Oct-13', '7:16 AM', 'Nevada', 'Education', 'Jose Reyes', 'MALE', '12', '0', '0', '1', '1', '2', '3', 'Suicide before police arrived', 'Suicide', 'NO'),
(157, 'Albuquerque, New Mexico', '26-Oct-13', '11:20 AM', 'New Mexico', 'Open Space', 'Christopher Thomas Chase', 'MALE', '35', '2', '0', '3', '0', '4', '4', 'Shot by police (Killed)', 'Killed', 'NO'),
(158, 'Los Angeles International Airport', '1-Nov-13', '9:18 AM', 'California', 'Government', 'Paul Anthony Ciancia', 'MALE', '23', '1', '0', '0', '1', '3', '4', 'Shot by police (Survived)', 'Arrested', 'NO'),
(159, 'Arapahoe High School', '13-Dec-13', '12:30 PM', 'Colorado', 'Education', 'Karl Halverson Pierson', 'MALE', '18', '0', '1', '0', '1', '0', '1', 'Suicide when police arrived', 'Suicide', 'NO'),
(160, 'Renown Regional Medical Center', '17-Dec-13', '2:00 PM', 'Nevada', 'Health Care', 'Alan Oliver Frazier', 'MALE', '51', '0', '1', '2', '1', '2', '3', 'Suicide when police arrived', 'Suicide', 'NO'),
(161, 'Berrendo Middle School', '14-Jan-14', '7:30 AM', 'New Mexico', 'Education', 'Mason Andrew Campbell', 'MALE', '12', '0', '1', '0', '0', '3', '3', 'Verbal intervention by civilian', 'Arrested', 'NO'),
(162, 'Martin’s Supermarket', '15-Jan-14', '10:09 PM', 'Indiana', 'Commerce', 'Shawn Walter Bair', 'MALE', '22', '0', '0', '1', '2', '0', '2', 'Shot by police (Killed)', 'Killed', 'NO'),
(163, 'The Mall in Columbia', '25-Jan-14', '11:15 AM', 'Maryland', 'Commerce', 'Darion Marcus Aguilar', 'MALE', '19', '0', '1', '0', '2', '5', '7', 'Suicide before police arrived', 'Suicide', 'NO'),
(164, 'Cedarville Rancheria Tribal Office', '20-Feb-14', '3:30 PM', 'California', 'Government', 'Cherie Louise Rhoades', 'FEMALE', '44', '0', '0', '1', '4', '2', '6', 'Physical intervention by civilian', 'Arrested', 'NO'),
(165, 'Fort Hood Army Base', '2-Apr-14', '4:00 PM', 'Texas', 'Government', 'Ivan Antonio Lopez-Lopez', 'MALE', '34', '0', '0', '1', '3', '12', '15', 'Suicide when police arrived', 'Suicide', 'NO'),
(166, 'Jewish Community Center of Greater Kansas City and Village Shalom Retirement Community', '13-Apr-14', '1:00 PM', 'Kansas', 'House of Worship', 'Frazier Glenn Miller, Jr.', 'MALE', '73', '0', '1', '2', '3', '0', '3', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(167, 'Federal Express', '29-Apr-14', '5:50 AM', 'Georgia', 'Commerce', 'Geddy Lee Kramer', 'MALE', '19', '0', '1', '0', '0', '6', '6', 'Suicide before police arrived', 'Suicide', 'NO'),
(168, 'Residence and Construction Site in Jonesboro, Arkansas', '3-May-14', '1:00 PM', 'Arkansas', 'Residence', 'Porfirio Sayago-Hernandez', 'MALE', '40', '0', '0', '1', '3', '4', '7', 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(169, 'Multiple Locations in Isla Vista, California', '23-May-14', '9:27 PM', 'California', 'Open Space', 'Elliot Rodger', 'MALE', '22', '0', '0', '1', '6', '14', '20', 'Suicide after engaging police', 'Suicide', 'NO'),
(170, 'Seattle Pacific University', '5-Jun-14', '3:25 PM', 'Washington', 'Education', 'Aaron Rey Ybarra', 'MALE', '26', '0', '1', '0', '1', '3', '4', 'Physical intervention by civilian', 'Arrested', 'NO'),
(171, 'Forsyth County Courthouse', '6-Jun-14', '10:00 AM', 'Georgia', 'Government', 'Dennis Ronald Marx', 'MALE', '48', '1', '0', '3', '0', '1', '1', 'Shot by police (Killed)', 'Killed', 'NO'),
(172, 'Cici’s Pizza and Walmart', '8-Jun-14', '11:20 AM', 'Nevada', 'Commerce', 'Jerad Dwain Miller & Amanda Renee Miller (Husband & Wife)', 'MALE & FEMALE', '31 & 22', '0', '1', '2', '3', '0', '3', 'Shot by police (Killed); Suicide after engaging police', 'Killed & Suicide', 'NO'),
(173, 'Reynolds High School', '10-Jun-14', '8:05 AM', 'Oregon', 'Education', 'Jared Michael Padgett', 'MALE', '15', '1', '0', '1', '1', '1', '2', 'Suicide when police arrived', 'Suicide', 'NO'),
(174, 'Sister Marie Lenahan Wellness Center', '24-Jul-14', '2:20 PM', 'Pennsylvania', 'Health Care', 'Richard Steven Plotts', 'MALE', '49', '0', '0', '1', '1', '1', '2', 'Shot by civilian (Survived)', 'Arrested', 'NO'),
(175, 'Hon-Dah Resort Casino and Conference Center', '2-Aug-14', '6:38 PM', 'Arizona', 'Commerce', 'Justin Joe Armstrong', 'MALE', '28', '1', '0', '0', '0', '2', '2', 'Shot by police (Killed)', 'Killed', 'NO'),
(176, 'United Parcel Service', '23-Sep-14', '9:20 AM', 'Alabama', 'Commerce', 'Kerry Joe Tesney', 'MALE', '45', '0', '0', '1', '2', '0', '2', 'Suicide before police arrived', 'Suicide', 'NO'),
(177, 'Marysville-Pilchuck High School', '24-Oct-14', '10:39 AM', 'Washington', 'Education', 'Jaylen Ray Fryberg', 'MALE', '15', '0', '0', '1', '4', '3', '7', 'Verbal intervention by civilian; Suicide before police arrived', 'Suicide', 'NO'),
(178, 'Florida State University', '20-Nov-14', '12:00 AM', 'Florida', 'Education', 'Myron May', 'MALE', '31', '0', '0', '1', '0', '3', '3', 'Shot by police (Killed)', 'Killed', 'NO'),
(179, 'Neighborhood in Tallahassee, Florida', '22-Nov-14', '10:15 AM', 'Florida', 'Residence', 'Curtis Wade Holley', 'MALE', '53', '0', '0', '1', '1', '1', '2', 'Shot by off-duty police (Killed)', 'Killed', 'NO'),
(180, 'Government Buildings in Austin, Texas', '28-Nov-14', '2:21 AM', 'Texas', 'Government', 'Larry Steven McQuilliams', 'MALE', '49', '1', '0', '1', '0', '0', '0', 'Shot by police (Killed)', 'Killed', 'NO'),
(181, 'Multiple Locations in Moscow, Idaho', '10-Jan-15', '2:31 PM', 'Idaho', 'Open Space', 'John Lee (aka Kane Grzebielski)', 'MALE', '29', NULL, NULL, NULL, '3', '1', '4', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(182, 'Melbourne Square Mall', '17-Jan-15', '9:31 AM', 'Florida', 'Commerce', 'Jose Garcia-Rodriguez', 'MALE', '57', '0', '0', '3', '1', '1', '2', 'Suicide before police arrived', 'Suicide', 'NO'),
(183, 'New Hope City Hall', '26-Jan-15', '7:15 PM', 'Minnesota', 'Government', 'Raymond Kenneth Kmetz', 'MALE', '68', '0', '1', '0', '0', '4', '4', 'Shot by police (Killed)', 'Killed', 'NO'),
(184, 'Monroeville Mall', '7-Feb-15', '7:33 PM', 'Pennsylvania', 'Commerce', 'Tarod Tyrell Thornhill', 'MALE', '17', '0', '0', '1', '0', '3', '3', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(185, 'Sioux Steel Pro∙Tec', '12-Feb-15', '2:00 PM', 'South Dakota', 'Commerce', 'Jeffrey Scott DeZeeuw', 'MALE', '51', '0', '0', '1', '1', '2', '3', 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(186, 'Dad’s Sing Along Club', '14-Mar-15', '2:00 AM', 'Texas', 'Commerce', 'Richard Castilleja', 'MALE', '29', '0', '0', '1', '0', '2', '2', 'Shot by police (Killed)', 'Killed', 'NO'),
(187, 'Multiple Locations in Mesa, Arizona', '18-Mar-15', '8:39 AM', 'Arizona', 'Open Space', 'Ryan Elliot Giroux', 'MALE', '41', '0', '0', '1', '1', '5', '6', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(188, 'Residence in Panama City Beach, Florida', '28-Mar-15', '12:53 AM', 'Florida', 'Residence', 'David Jamichael Daniels', 'MALE', '21', '0', '0', '1', '0', '7', '7', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(189, 'North Milwaukee Avenue, Chicago', '19-Apr-15', '11:50 PM', 'Illinois', 'Open Space', 'Everardo Custodio', 'MALE', '21', '0', '0', '1', '0', '0', '0', 'Shot by civilian', 'Arrested', 'NO'),
(190, 'Trestle Trail Bridge, Wisconsin', '3-May-15', '7:30 PM', 'Wisconsin', 'Open Space', 'Sergio Daniel Valencia Del Toro', 'MALE', '27', '0', '0', '2', '3', '1', '4', 'Suicide before police arrived', 'Suicide', 'NO'),
(191, 'Walmart Supercenter', '26-May-15', '1:00 AM', 'North Dakota', 'Commerce', 'Marcell Travon Willis', 'MALE', '21', '0', '0', '1', '1', '1', '2', 'Suicide before police arrived', 'Suicide', 'NO'),
(192, 'Emanuel African Methodist Episcopal Church', '17-Jun-15', '9:00 PM', 'South Carolina', 'House of Worship', 'Dylann Storm Roof', 'MALE', '21', '1', '0', '0', '9', '0', '9', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(193, 'Omni Austin Hotel Downtown', '5-Jul-15', '4:48 AM', 'Texas', 'Commerce', 'Michael Holt', 'MALE', '35', '1', '0', '0', '1', '0', '1', 'Shot by police (Killed)', 'Killed', 'NO'),
(194, 'Two Military Centers in Chattanooga, Tennessee', '16-Jul-15', '10:51 AM', 'Tennessee', 'Government', 'Mohammad Youssuf Abdulazeez', 'MALE', '24', '1', '0', '0', '5', '2', '7', 'Shot by police (Killed)', 'Killed', 'NO'),
(195, 'Grand 16 Theatre', '23-Jul-15', '7:15 PM', 'Louisiana', 'Commerce', 'John Russell Houser', 'MALE', '59', '0', '0', '1', '2', '9', '11', 'Suicide when police arrived', 'Suicide', 'NO'),
(196, 'Umpqua Community College', '1-Oct-15', '10:38 AM', 'Oregon', 'Education', 'Christopher Sean Harper-Mercer', 'MALE', '26', '1', '0', '3', '9', '7', '16', 'Suicide after engaging police', 'Suicide', 'NO'),
(197, 'Syverud Law Office and Miller-Meier Limb and Brace, Inc.', '26-Oct-15', '1:56 PM', 'Iowa', 'Commerce', 'Robert Lee Mayes, Jr.', 'MALE', '40', '0', '0', '1', '0', '2', '2', 'Suicide when police arrived', 'Suicide', 'NO'),
(198, 'Neighborhood in Colorado Springs, Colorado', '31-Oct-15', '8:55 AM', 'Colorado', 'Open Space', 'Noah Jacob Harpham', 'MALE', '33', '1', '0', '2', '3', '0', '3', 'Shot by police (Killed)', 'Killed', 'NO'),
(199, 'Planned Parenthood – Colorado Springs Westside Health Center', '27-Nov-15', '11:38 AM', 'Colorado', 'Health Care', 'Robert Lewis Dear, Jr.', 'MALE', '57', '1', '0', '0', '3', '9', '12', 'Surrendered to Police', 'Arrested', 'YES'),
(200, 'Inland Regional Center', '2-Dec-15', '11:30 AM', 'California', 'Commerce', 'Syed Rizwan Farook & Tashfeen Malik (Husband & Wife)', 'MALE & FEMALE', '28 & 29', '2', '0', '2', '14', '22', '36', 'Fled the scene; Shot by police (Killed)', 'Killed', 'NO'),
(201, 'Multiple Locations in Kalamazoo, Michigan', '20-Feb-16', '5:40 PM', 'Michigan', 'Open Space', 'Jason Brian Dalton', 'MALE', '45', '0', '0', '1', '6', '2', '8', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(202, 'Excel Industries and Newton and Hesston, Kansas', '25-Feb-16', '4:57 PM', 'Kansas', 'Commerce', 'Cedric Larry Ford', 'MALE', '38', '1', '0', '1', '3', '14', '17', 'Shot by police (Killed)', 'Killed', 'NO'),
(203, 'Madison Junior/Senior High School', '29-Feb-16', '11:30 AM', 'Ohio', 'Education', 'James Austin Hancock', 'MALE', '14', '0', '0', '1', '0', '4', '4', 'Surrendered to Police', 'Arrested', 'YES'),
(204, 'Prince George’s County Police Department District 3 Station', '13-Mar-16', '4:30 PM', 'Maryland', 'Government', 'Michael Ford', 'MALE', '22', '0', '0', '1', '1', '0', '1', 'Shot by the police (Survived)', 'Arrested', 'NO'),
(205, 'Antigo High School', '23-Apr-16', '11:02 PM', 'Wisconsin', 'Education', 'Jakob Edward Wagner', 'MALE', '18', '1', '0', '0', '0', '2', '2', 'Shot by police (Killed)', 'Killed', 'NO'),
(206, 'Knight Transportation Building', '4-May-16', '8:45 AM', 'Texas', 'Commerce', 'Marion Guy Williams', 'MALE', '65', '0', '1', '1', '1', '2', '3', 'Suicide when police arrived', 'Suicide', 'NO'),
(207, 'Arizona State Route 87', '24-May-16', '8:30 PM', 'Arizona', 'Open Space', 'James David Walker', 'MALE', '36', '1', '0', '0', '0', '2', '2', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(208, 'Memorial Tire and Auto', '29-May-16', '10:15 AM', 'Texas', 'Commerce', 'Dionisio Agustine Garza III', 'MALE', '25', '1', '0', '1', '1', '6', '7', 'Shot at by Civilian (Missed); Shot by police (Killed)', 'Killed', 'NO'),
(209, 'Pulse Nightclub', '12-Jun-16', '2:02 AM', 'Florida', 'Commerce', 'Omar Mir Seddique Mateen', 'MALE', '29', '1', '0', '1', '49', '53', '102', 'Shot by police (Killed)', 'Killed', 'NO'),
(210, 'Days Inn and Volunteer Parkway', '7-Jul-16', '2:18 AM', 'Tennessee', 'Open Space', 'Lakeem Keon Scott', 'MALE', '37', '1', '0', '1', '1', '3', '4', 'Shot by police (Survived)', 'Arrested', 'NO'),
(211, 'Protest in Dallas, Texas', '7-Jul-16', '9:00 PM', 'Texas', 'Open Space', 'Micah Xavier Johnson', 'MALE', '25', '2', '0', '1', '5', '11', '16', 'Killed by police controlled bomb carying robot', 'Killed', 'NO'),
(212, 'Benny’s Car Wash, Oil Change & B-Quik and Hair Crown Beauty Supply', '17-Jul-16', '8:40 AM', 'Louisiana', 'Open Space', 'Gavin Eugene Long', 'MALE', '29', '2', '0', '1', '3', '3', '6', 'Shot by police (Killed)', 'Killed', 'NO'),
(213, 'House Party in Mukilteo, Washington', '30-Jul-16', '12:07 AM', 'Washington', 'Residence', 'Allen Christopher Ivanov', 'MALE', '19', '1', '0', '0', '3', '1', '4', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(214, 'Multiple Locations in Joplin, Missouri', '13-Aug-16', '5:08 AM', 'Missouri', 'Open Space', 'Tom Stanley Mourning II', 'MALE', '26', '1', '0', '1', '0', '5', '5', 'Unclear', 'Arrested', 'Unclear'),
(215, 'Multiple Locations in Philadelphia, Pennsylvania', '16-Sep-16', '11:15 PM', 'Pennsylvania', 'Open Space', 'Nicholas N. Glenn', 'MALE', '25', '0', '0', '1', '1', '5', '6', 'Shot by police (Killed)', 'Killed', 'NO'),
(216, 'Cascade Mall', '23-Sep-16', '6:52 PM', 'Washington', 'Commerce', 'Arcan Cetin', 'MALE', '20', '1', '0', '0', '5', '0', '5', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(217, 'Law Street in Houston, Texas', '26-Sep-16', '6:30 AM', 'Texas', 'Open Space', 'Nathan Desai', 'MALE', '46', '0', '0', '1', '0', '9', '9', 'Shot by police (Killed)', 'Killed', 'NO'),
(218, 'Townville Elementary School', '28-Sep-16', '1:45 PM', 'South Carolina', 'Education', 'Jesse Dewitt Osborne', 'MALE', '14', '0', '0', '1', '2', '3', '5', 'Armed intervention by civilian (no shots fired)', 'Arrested', 'NO'),
(219, 'FreightCar America', '25-Oct-16', '6:00 AM', 'Virginia', 'Commerce', 'Getachew Tereda Fekede', 'MALE', '53', '0', '0', '1', '1', '3', '4', 'Suicide before police arrived', 'Suicide', 'NO'),
(220, 'H-E-B Grocery Store', '28-Nov-16', '3:15 AM', 'Texas', 'Commerce', 'Raul Lopez Saenz', 'MALE', '25', '0', '0', '1', '1', '3', '4', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(221, 'Fort Lauderdale-Hollywood International Airport', '6-Jan-17', '1:15 PM', 'Florida', 'Government', 'Esteban Santiago-Ruiz', 'MALE', '26', '0', '0', '1', '5', '8', '13', 'Surrendered to Police', 'Arrested', 'YES'),
(222, 'West Liberty-Salem High School', '20-Jan-17', '7:36 AM', 'Ohio', 'Education', 'Ely Ray Serna', 'MALE', '17', '0', '1', '0', '0', '2', '2', 'Physical intervention by civilian', 'Arrested', 'NO'),
(223, 'Marathon Savings Bank and Tlusty, Kennedy & Dirks, S.C.', '22-Mar-17', '12:27 PM', 'Wisconsin', 'Commerce', 'Nengmy Vang', 'MALE', '45', '1', '0', '1', '4', '0', '4', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(224, 'Las Vegas Bus', '25-Mar-17', '10:45 AM', 'Nevada', 'Other', 'Rolando Bueno Cardenas', 'MALE', '55', '0', '0', '1', '1', '1', '2', 'Surrendered to Police', 'Arrested', 'YES'),
(225, 'Residence and Bus Stop in Sanford, Florida', '27-Mar-17', '6:20 AM', 'Florida', 'Open Space', 'Allen Dion Cashe', 'MALE', '31', '1', '0', '0', '2', '4', '6', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(226, 'The Cooler', '15-Apr-17', '9:30 PM', 'Illinois', 'Commerce', 'Seth Thomas Wallace', 'MALE', '32', '0', '0', '1', '0', '4', '4', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(227, 'Multiple Locations in Fresno, California', '18-Apr-17', '10:45 AM', 'California', 'Open Space', 'Kori Ali Muhammad', 'MALE', '39', '0', '0', '1', '3', '0', '3', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(228, 'Group Home in Topeka, Kansas', '30-Apr-17', '3:50 PM', 'Kansas', 'Health Care', 'Joshua James Ray Gueary', 'MALE', '25', '0', '0', '1', '3', '1', '4', 'Suicide before police arrived', 'Suicide', 'NO'),
(229, 'La Jolla Crossroads Apartment Complex', '30-Apr-17', '6:00 PM', 'California', 'Residence', 'Peter Raymond Selis', 'MALE', '49', '0', '0', '1', '1', '7', '8', 'Shot by police (Killed)', 'Killed', 'NO'),
(230, 'Pine Kirk Care Center', '12-May-17', '7:30 AM', 'Ohio', 'Health Care', 'Thomas Harry Hartless', 'MALE', '43', '0', '1', '1', '3', '0', '3', 'Suicide before police arrived', 'Suicide', 'NO'),
(231, 'Fiamma Inc.', '5-Jun-17', '8:00 AM', 'Florida', 'Commerce', 'John Robert Neumann Jr', 'MALE', '45', '0', '0', '1', '5', '0', '5', 'Suicide before police arrived', 'Suicide', 'NO'),
(232, 'Weis Supermarket', '8-Jun-17', '1:00 AM', 'Pennsylvania', 'Commerce', 'Randy Robert Stair', 'MALE', '24', '0', '2', '0', '3', '0', '3', 'Suicide before police arrived', 'Suicide', 'NO'),
(233, 'Eugene Simpson Stadium Park', '14-Jun-17', '7:15 AM', 'Virginia', 'Open Space', 'James Thomas Hodgkinson', 'MALE', '66', '1', '0', '1', '0', '4', '4', 'Shot by police (Killed)', 'Killed', 'NO'),
(234, 'UPS Customer Center', '14-Jun-17', '8:55 AM', 'California', 'Commerce', 'Jimmy Chanh Lam', 'MALE', '38', '0', '0', '2', '3', '5', '8', 'Suicide when police arrived', 'Suicide', 'NO'),
(235, 'Bronx-Lebanon Hospital Center', '30-Jun-17', '2:50 PM', 'New York', 'Health Care', 'Dr. Henry Michael Bello', 'MALE', '45', '1', '0', '0', '1', '6', '7', 'Suicide before police arrived', 'Suicide', 'NO'),
(236, 'Highway 141 in Gateway, Colorado', '30-Jul-17', '4:15 PM', 'Colorado', 'Open Space', 'Rick Whited', 'MALE', '54', '0', '0', '1', '0', '0', '0', 'Fled the scene after engaging security guards', 'Escaped (Arrested Later)', 'NO'),
(237, 'Clovis-Carver Public Library', '28-Aug-17', '4:15 PM', 'New Mexico', 'Government', 'Nathaniel Ray Jouett', 'MALE', '16', '0', '0', '1', '2', '4', '6', 'Surrendered to Police', 'Arrested', 'YES'),
(238, 'Freeman High School', '13-Sep-17', '10:00 AM', 'Washington', 'Education', 'Caleb Sharpe', 'MALE', '15', '1', '0', '1', '1', '3', '4', 'Verbal & Physical intervention by civilian', 'Arrested', 'YES'),
(239, 'Burnette Chapel Church of Christ', '24-Sep-17', '11:15 AM', 'Tennessee', 'House of Worship', 'Emanuel Kidega Samson', 'MALE', '25', '0', '0', '2', '1', '7', '8', 'Armed intervention by civilian (no shots fired)', 'Arrested', 'NO'),
(240, 'Route 91 Harvest Festival', '1-Oct-17', '10:08 PM', 'Nevada', 'Open Space', 'Stephen Craig Paddock', 'MALE', '64', '4', '0', '0', '58', '489', '547', 'Suicide before police arrived', 'Suicide', 'NO'),
(241, 'Advanced Granite Solutions and 28th Street Auto Sales and Service', '18-Oct-17', '8:58 AM', 'Maryland', 'Commerce', 'Radee Labeeb Prince', 'MALE', '37', '0', '0', '1', '3', '3', '6', 'Fled the scene', 'Escaped (Arrested Later)', 'NO');
INSERT INTO `rawrecords` (`Id`, `IncidentName`, `Date`, `Time`, `State`, `Location`, `ShooterName`, `ShooterGender`, `ShooterAge`, `Rifles`, `Shotguns`, `Handguns`, `Deaths`, `Wounded`, `Total(Calculated)`, `TerminatingEvent`, `ShootersFate`, `SurrenderedDuringIncident`) VALUES
(242, 'Multiple Locations in Clearlake Oaks, California', '23-Oct-17', '11:23 AM', 'California', 'Commerce', 'Alan Ashmore', 'MALE', '61', '0', '1', '1', '2', '3', '5', 'Shot at by Civilian (Missed); Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(243, 'Walmart in Thornton, Colorado', '1-Nov-17', '6:10 PM', 'Colorado', 'Commerce', 'Scott Allen Ostrem', 'MALE', '47', '0', '0', '1', '3', '0', '3', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(244, 'First Baptist Church in Sutherland Springs, Texas', '5-Nov-17', '11:20 AM', 'Texas', 'House of Worship', 'Devin Patrick Kelley', 'MALE', '26', '1', '0', '0', '26', '20', '46', 'Shot by civilan (survived); committed suicide before police arrived', 'Suicide', 'NO'),
(245, 'Rancho Tehama Elementary School and Multiple Locations in Tehama County, California', '14-Nov-17', '7:53 AM', 'California', 'Education', 'Kevin Janson Neal', 'MALE', '44', '1', '0', '2', '5', '14', '19', 'Suicide after engaging police', 'Suicide', 'NO'),
(246, 'Dollar General Store', '14-Nov-17', '2:45 PM', 'New York', 'Commerce', 'Travis Green', 'MALE', '29', '2', '0', '0', '0', '1', '1', 'Civilian intervention with automobile; Physical intervention by police', 'Arrested', 'NO'),
(247, 'Schlenker Automotive', '17-Nov-17', '4:30 PM', 'Florida', 'Commerce', 'Robert Lorenzo Bailey, Jr', 'MALE', '28', '0', '0', '1', '1', '1', '2', 'Shot by civilian (Survived)', 'Arrested', 'NO'),
(248, 'Aztec High School', '7-Dec-17', '8:00 AM', 'New Mexico', 'Education', 'William Edward Atchison', 'MALE', '21', '0', '0', '1', '2', '0', '2', 'Suicide before police arrived', 'Suicide', 'NO'),
(249, 'Multiple Locations in Baltimore, Maryland', '15-Dec-17', '2:55 PM', 'Maryland', 'Open Space', 'Mausean Vittorio Quran Carter', 'MALE', '30', '1', '0', '1', '0', '3', '3', 'Physical intervention by civilian', 'Arrested', 'NO'),
(250, 'University of Cincinnati Medical Center', '20-Dec-17', '2:00 PM', 'Ohio', 'Health Care', 'Isaiah Currie', 'MALE', '20', '0', '0', '2', '0', '1', '1', 'Suicide when police arrived', 'Suicide', 'NO'),
(251, 'Marshall County High School', '23-Jan-18', '7:57 AM', 'Kentucky', 'Education', 'Gabriel Ross Parker', 'MALE', '15', '0', '0', '1', '2', '21', '23', 'Surrendered to Police', 'Arrested', 'YES'),
(252, 'Marjory Stoneman Douglas High School', '14-Feb-18', '2:30 PM', 'Florida', 'Education', 'Nikolas Jacob Cruz', 'MALE', '19', '1', '0', '0', '17', '17', '34', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(253, 'City Grill Café', '7-Mar-18', '6:30 AM', 'Alabama', 'Commerce', 'Walter Frank Thomas', 'MALE', '64', '1', '0', '0', '2', '2', '4', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(254, 'YouTube Headquarters', '3-Apr-18', '12:45 PM', 'California', 'Commerce', 'Nasim Najafi Aghdam', 'FEMALE', '39', '0', '0', '1', '0', '4', '4', 'Suicide before police arrived', 'Suicide', 'NO'),
(255, 'Waffle House', '22-Apr-18', '3:30 AM', 'Tennessee', 'Commerce', 'Travis Jeffrey Reinking', 'MALE', '29', '1', '0', '0', '4', '4', '8', 'Physical intervention by civilian; fled the scene', 'Escaped (Arrested Later)', 'NO'),
(256, 'Highway 365 Near Whitehall Road in Gainesville, Georgia', '4-May-18', '11:58 AM', 'Georgia', 'Open Space', 'Rex Whitmire Harbour', 'MALE', '26', '0', '0', '1', '0', '3', '3', 'Suicide when police arrived', 'Suicide', 'NO'),
(257, 'Dixon High School', '16-May-18', '8:00 AM', 'Illinois', 'Education', 'Matthew A. Milby Jr.', 'MALE', '19', '1', '0', '0', '0', '0', '0', 'Shot by police (Survived)', 'Arrested', 'NO'),
(258, 'Santa Fe High School', '18-May-18', '7:30 AM', 'Texas', 'Education', 'Dimitrios Pagourtzis', 'MALE', '17', '0', '1', '1', '10', '12', '22', 'Surrendered to Police', 'Arrested', 'NO'),
(259, 'Louie’s Lakeside Eatery', '24-May-18', '6:30 PM', 'Oklahoma', 'Commerce', 'Alexander C. Tilghman', 'MALE', '28', '0', '0', '1', '0', '4', '4', 'Shot by civilian (Killed)', 'Killed', 'NO'),
(260, 'Noblesville West Middle School', '25-May-18', '9:06 AM', 'Indiana', 'Education', NULL, 'MALE', '13', '0', '0', '2', '0', '2', '2', 'Physical intervention by civilian', 'Arrested', 'NO'),
(261, 'Highway 509 Near Seattle-Tacoma International Airport', '13-Jun-18', '1:42 PM', 'Washington', 'Open Space', NULL, NULL, NULL, NULL, NULL, NULL, '0', '0', '0', 'Fled the scene', 'Escaped (Never Caught)', 'NO'),
(262, 'Capital Gazette', '29-Jun-18', '2:34 PM', 'Maryland', 'Commerce', 'Jarrod Warren Ramos', 'MALE', '38', '0', '1', '0', '5', '2', '7', 'Surrendered to Police', 'Arrested', 'YES'),
(263, 'Ben E. Keith Gulf Coast', '20-Aug-18', '2:00 AM', 'Texas', 'Commerce', 'Kristine Peralez', 'FEMALE', '38', '0', '0', '1', '1', '1', '2', 'Suicide when police arrived', 'Suicide', 'NO'),
(264, 'GLHF Game Bar', '26-Aug-18', '1:34 PM', 'Florida', 'Commerce', 'David Bennett Katz', 'MALE', '24', '0', '0', '2', '2', '11', '13', 'Suicide before police arrived', 'Suicide', 'NO'),
(265, 'Fifth Third Center', '6-Sep-18', '9:10 AM', 'Ohio', 'Commerce', 'Omar Enrique Santa Perez', 'MALE', '29', '0', '0', '1', '3', '2', '5', 'Shot by police (Killed)', 'Killed', 'NO'),
(266, 'T & T Trucking, Inc. and a Residence', '12-Sep-18', '5:20 PM', 'California', 'Commerce', 'Javier Casarez', 'MALE', '54', '0', '0', '1', '5', '0', '5', 'Fled the scene; Suicide when police arrived', 'Suicide', 'NO'),
(267, 'WTS Paradigm', '19-Sep-18', '10:30 AM', 'Wisconsin', 'Commerce', 'Anthony Yente Tong', 'MALE', '43', '0', '0', '1', '0', '4', '4', 'Shot by police (Killed)', 'Killed', 'NO'),
(268, 'Masontown Borough Municipal Center', '19-Sep-18', '2:00 PM', 'Pennsylvania', 'Government', 'Patrick Shaun Dowdell', 'MALE', '61', '0', '0', '1', '0', '4', '4', 'Shot by police (Killed)', 'Killed', 'NO'),
(269, 'Rite Aid Perryman Distribution Center’s Liberty Support Center', '20-Sep-18', '9:06 AM', 'Maryland', 'Commerce', 'Snochia Moseley', 'FEMALE', '26', '0', '0', '1', '3', '3', '6', 'Suicide before police arrived', 'Suicide', 'NO'),
(270, 'Kroger Grocery Store in Jeffersontown, Kentucky', '24-Oct-18', '3:00 PM', 'Kentucky', 'Commerce', 'Gregory Alan Bush', 'MALE', '51', '0', '0', '1', '2', '0', '2', 'Shot at by civilian (missed); Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(271, 'Tree of Life Synagogue', '27-Oct-18', '9:45 AM', 'Pennsylvania', 'House of Worship', 'Robert Gregory Bowers', 'MALE', '46', '1', '0', '3', '11', '6', '17', 'Shot by police (Survived)', 'Arrested', 'NO'),
(272, 'Hot Yoga Tallahassee', '2-Nov-18', '5:37 PM', 'Florida', 'Commerce', 'Scott Paul Beierle', 'MALE', '40', '0', '0', '1', '2', '5', '7', 'Suicide before police arrived', 'Suicide', 'NO'),
(273, 'Helen Vine Recovery Center', '5-Nov-18', '1:30 AM', 'California', 'Health Care', 'Davance Lamar Reed', 'MALE', '37', '0', '0', '1', '1', '2', '3', 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(274, 'Borderline Bar and Grill', '7-Nov-18', '11:20 PM', 'California', 'Commerce', 'Ian David Long', 'MALE', '28', '0', '0', '1', '12', '16', '28', 'Suicide after engaging police', 'Suicide', 'NO'),
(275, 'Ben E. Keith Albuquerque', '12-Nov-18', '6:56 PM', 'New Mexico', 'Commerce', 'Waid Anthony Melton', 'MALE', '30', '0', '0', '1', '0', '3', '3', 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(276, 'Mercy Hospital & Medical Center', '19-Nov-18', '3:20 PM', 'Illinois', 'Health Care', 'Juan Lopez', 'MALE', '32', '0', '0', '1', '3', '0', '3', 'Suicide after engaging police', 'Suicide', 'NO'),
(277, 'Motel 6 in Albuquerque, New Mexico', '24-Dec-18', '11:00 AM', 'New Mexico', 'Commerce', 'Abdias Ucdiel Flores-Corado', 'MALE', '35', '1', '0', '0', '0', '0', '0', 'Shot by police (Killed)', 'Killed', 'NO');

-- --------------------------------------------------------

--
-- Table structure for table `shooter`
--

CREATE TABLE `shooter` (
  `id` int(11) NOT NULL,
  `IncidentId` int(11) NOT NULL,
  `Name` varchar(250) DEFAULT NULL,
  `Gender` enum('MALE','FEMALE') DEFAULT NULL,
  `Age` int(11) DEFAULT NULL,
  `TerminatingEvent` varchar(250) NOT NULL,
  `ShooterFate` enum('Arrested','Escaped (Arrested Later)','Escaped (Never Caught)','Escaped (Turned self in)','Killed','Suicide') NOT NULL,
  `SurrenderedDuringIncident` enum('YES','NO','UNCLEAR') NOT NULL
);

--
-- Dumping data for table `shooter`
--

INSERT INTO `shooter` (`id`, `IncidentId`, `Name`, `Gender`, `Age`, `TerminatingEvent`, `ShooterFate`, `SurrenderedDuringIncident`) VALUES
(1, 1, 'Michael M. McDermott', 'MALE', 42, 'Shooter completed goal and stopped', 'Arrested', 'YES'),
(2, 2, 'Ki Yung Park', 'MALE', 54, 'Suicide when police arrived', 'Suicide', 'NO'),
(3, 3, 'William Daniel Baker', 'MALE', 57, 'Suicide before police arrived', 'Suicide', 'NO'),
(4, 4, 'Charles Andrew Williams Jr', 'MALE', 15, 'Surrendered to Police', 'Arrested', 'YES'),
(5, 5, 'Jason Anthony Hoffman', 'MALE', 18, 'Shot by police (Survived)', 'Arrested', 'NO'),
(6, 6, 'Cathline Repunte', 'FEMALE', 36, 'Physical intervention by civilian', 'Arrested', 'NO'),
(7, 7, 'Robert L. Wissman', 'MALE', 36, 'Suicide before police arrived', 'Suicide', 'NO'),
(8, 8, 'Peter Odighizuma', 'MALE', 43, 'Physical intervention by civilian & off-duty police', 'Arrested', 'NO'),
(9, 9, 'William Lockey', 'MALE', 54, 'Suicide after engaging police', 'Suicide', 'NO'),
(10, 10, 'Hesham Mohamed Ali Hadayet', 'MALE', 43, 'Shot by security guard (Killed)', 'Killed', 'NO'),
(11, 11, 'Daniel Hawke Fears', 'MALE', 18, 'Automobile crash into police blockade', 'Arrested', 'NO'),
(12, 12, 'Emanuel Burl Patterson', 'MALE', 23, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(13, 13, 'James Sheets', 'MALE', 14, 'Suicide before police arrived', 'Suicide', 'NO'),
(14, 14, 'Biswanath A. Halder', 'MALE', 62, 'Shot by police (Survived)', 'Arrested', 'NO'),
(15, 15, 'Jonathon W. Russell', 'MALE', 25, 'Suicide after engaging police', 'Suicide', 'NO'),
(16, 16, 'Douglas Paul Williams', 'MALE', 48, 'Suicide before police arrived', 'Suicide', 'NO'),
(17, 17, 'Richard Dean Bright', 'MALE', 58, 'Physical intervention by civilian', 'Arrested', 'NO'),
(18, 18, 'Agustin Casarubias-Dominguez (aka Andres Casarrubias)', 'MALE', 45, 'Physical intervention by civilian', 'Arrested', 'NO'),
(19, 19, 'Richard Wayne Shadle', 'MALE', 32, 'Suicide before police arrived', 'Suicide', 'NO'),
(20, 20, 'Salvador Tapia Solis', 'MALE', 36, 'Shot by police (Killed)', 'Killed', 'NO'),
(21, 21, 'John Jason McLaughlin', 'MALE', 15, 'Verbal intervention by civilian', 'Arrested', 'YES'),
(22, 22, 'Joseph John Eschenbrenner, III (aka Tom West)', 'MALE', 50, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(23, 23, 'Jon William Romano', 'MALE', 16, 'Physical intervention by civilian', 'Arrested', 'NO'),
(24, 24, 'Elijah J. Brown', 'MALE', 21, 'Suicide before police arrived', 'Suicide', 'NO'),
(25, 25, 'Justin Michael Cudar', 'MALE', 25, 'Suicide before police arrived', 'Suicide', 'NO'),
(26, 26, 'Chai Soua Vang', 'MALE', 36, 'Fled the scene', 'Arrested', 'NO'),
(27, 27, 'Myles Wesley Meyers', 'MALE', 54, 'Suicide before police arrived', 'Suicide', 'NO'),
(28, 28, 'Robert Charles Bonelli Jr.', 'MALE', 25, 'Physical Intervention by Civilian', 'Arrested', 'NO'),
(29, 29, 'Terry M. Ratzmann', 'MALE', 44, 'Suicide before police arrived', 'Suicide', 'NO'),
(30, 30, 'Jeffery James Weise', 'MALE', 16, 'Suicide after engaging police', 'Suicide', 'NO'),
(31, 31, 'Louis Mitchell Jr.', 'MALE', 35, 'Shot by police (Survived); fled the scene', 'Escaped (Arrested Later)', 'NO'),
(32, 32, 'Alexander Elkin', 'MALE', 45, 'Suicide after engaging police', 'Suicide', 'NO'),
(33, 33, 'Kenneth S. Bartley', 'MALE', 14, 'Physical intervention by civilian', 'Arrested', 'NO'),
(34, 34, 'Dominick Sergil Maldonado', 'MALE', 20, 'Verbal intervention by civilian', 'Arrested', 'YES'),
(35, 35, NULL, 'MALE', NULL, 'Fled the scene', 'Escaped (Never Caught)', 'NO'),
(36, 36, 'Jennifer San Marco', 'FEMALE', 44, 'Suicide before police arrived', 'Suicide', 'NO'),
(37, 37, 'James Scott Newman', 'MALE', 14, 'Physical intervention by civilian', 'Arrested', 'NO'),
(38, 38, 'Kyle Aaron Huff', 'MALE', 28, 'Suicide when police arrived', 'Suicide', 'NO'),
(39, 39, 'Michael Julius Ford', 'MALE', 22, 'Shot by police (Killed)', 'Killed', 'NO'),
(40, 40, 'Naveed Afzal Haq', 'MALE', 30, 'Surrendered to Police', 'Arrested', 'YES'),
(41, 41, 'Christopher Williams', 'MALE', 26, 'Attempted Suicide (Survived)', 'Arrested', 'NO'),
(42, 42, 'Alvaro Castillo', 'MALE', 19, 'Physical intervention by police', 'Arrested', 'NO'),
(43, 43, 'Eric Jordan Hainstock', 'MALE', 15, 'Physical intervention by civilian', 'Arrested', 'NO'),
(44, 44, 'Charles Carl Roberts', 'MALE', 32, 'Suicide when police arrived', 'Suicide', 'NO'),
(45, 45, 'Thomas White', 'MALE', 13, 'Verbal intervention by civilian', 'Arrested', 'YES'),
(46, 46, 'Sulejman Talovic', 'MALE', 18, 'Shot by police (Killed)', 'Killed', 'NO'),
(47, 47, 'Vincent Dortch', 'MALE', 44, 'Suicide after engaging police', 'Suicide', 'NO'),
(48, 48, 'Alonso Jose Mendez', 'MALE', 68, 'Suicide before police arrived', 'Suicide', 'NO'),
(49, 49, 'Seung Hui Cho', 'MALE', 23, 'Suicide when police arrived', 'Suicide', 'NO'),
(50, 50, 'David Wayne Logsdon', 'MALE', 51, 'Shot by police (Killed)', 'Killed', 'NO'),
(51, 51, 'Jason Kenneth Hamilton', 'MALE', 36, 'Suicide when police arrived', 'Suicide', 'NO'),
(52, 52, 'Calvin Coolidge Neyland Jr.', 'MALE', 43, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(53, 53, 'Paulino Valenzuela', 'MALE', 44, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(54, 54, 'John Chester Ashley', 'MALE', 63, 'Shot by police (Killed)', 'Killed', 'NO'),
(55, 55, 'Tyler Peterson', 'MALE', 20, 'Suicide after engaging police', 'Suicide', 'NO'),
(56, 56, 'Robert Becerra', 'MALE', 29, 'Suicide before police arrived', 'Suicide', 'NO'),
(57, 57, 'Asa Halley Coon', 'MALE', 14, 'Suicide before police arrived', 'Suicide', 'NO'),
(58, 58, 'Robert Arthur Hawkins', 'MALE', 19, 'Suicide before police arrived', 'Suicide', 'NO'),
(59, 59, 'Matthew John Murray', 'MALE', 24, 'Shot by security guard, then committed suicided', 'Suicide', 'NO'),
(60, 60, 'Charles Lee Thornton', 'MALE', 52, 'Shot by police (Killed)', 'Killed', 'NO'),
(61, 61, 'Latina Williams', 'FEMALE', 23, 'Suicide before police arrived', 'Suicide', 'NO'),
(62, 62, 'Steven Phillip Kazmierczak', 'MALE', 27, 'Suicide before police arrived', 'Suicide', 'NO'),
(63, 63, 'Alburn Edward Blake', 'MALE', 60, 'Suicide before police arrived', 'Suicide', 'NO'),
(64, 64, 'Ernesto Villagomez', 'MALE', 30, 'Shot by civilian (Killed)', 'Killed', 'NO'),
(65, 65, 'Wesley Neal Higdon', 'MALE', 25, 'Suicide before police arrived', 'Suicide', 'NO'),
(66, 66, 'Jim David Adkisson', 'MALE', 58, 'Physical intervention by civilian', 'Arrested', 'NO'),
(67, 67, 'Isaac Lee Zamora', 'MALE', 28, 'Fled the scene', 'Escaped (Turned self in)', 'NO'),
(68, 68, 'Erik Salvador Ayala', 'MALE', 24, 'Attempted Suicide (Survived)', 'Arrested', 'NO'),
(69, 69, 'Michael Kenneth McLendon', 'MALE', 28, 'Suicide after engaging police', 'Suicide', 'NO'),
(70, 70, 'Robert Kenneth Stewart', 'MALE', 45, 'Shot by police (Survived)', 'Arrested', 'NO'),
(71, 71, 'Linh Phat Voong', 'MALE', 41, 'Suicide before police arrived', 'Suicide', 'NO'),
(72, 72, 'John Suchan Chong', 'MALE', 69, 'Physical intervention by civilian', 'Arrested', 'NO'),
(73, 73, 'Odane Greg Maye', 'MALE', 18, 'Attempted Suicide (Survived)', 'Arrested', 'NO'),
(74, 74, 'Justin Doucet', 'MALE', 15, 'Attempted Suicide (Survived)', 'Arrested', 'NO'),
(75, 75, 'Carlos Leon Bledsoe', 'MALE', 23, 'Fled the scene; Surrendered when caught', 'Arrested', 'NO'),
(76, 76, 'James Wenneker von Brunn', 'MALE', 88, 'Shot by police (Survived)', 'Arrested', 'NO'),
(77, 77, 'Jaime Paredes', 'MALE', 30, 'Surrendered to Police', 'Arrested', 'NO'),
(78, 78, NULL, NULL, NULL, 'Fled the scene', 'Escaped (Never Caught)', 'NO'),
(79, 79, 'George Sodini', 'MALE', 48, 'Suicide before police arrived', 'Suicide', 'NO'),
(80, 80, 'Harlan James Drake', 'MALE', 33, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(81, 81, 'Nidal Malik Hasan', 'MALE', 39, 'Shot by police (Survived)', 'Arrested', 'NO'),
(82, 82, 'Jason Samuel Rodriguez', 'MALE', 40, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(83, 83, 'Richard Allan Moreau', 'MALE', 63, 'Shooter completed goal and stopped', 'Arrested', 'YES'),
(84, 84, 'Robert Beiser', 'MALE', 39, 'Suicide before police arrived', 'Suicide', 'NO'),
(85, 85, 'Maurice Clemmons', 'MALE', 37, 'Shot by police (Killed)', 'Killed', 'NO'),
(86, 86, 'Richard Matthews', 'MALE', 53, 'Physical intervention by civilian', 'Arrested', 'NO'),
(87, 87, 'Johnny Lee Wicks Jr', 'MALE', 66, 'Shot by police (Killed)', 'Killed', 'NO'),
(88, 88, 'Timothy Hendron', 'MALE', 51, 'Suicide before police arrived', 'Suicide', 'NO'),
(89, 89, 'Jesse James Warren', 'MALE', 60, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(90, 90, 'John William Kalisz', 'MALE', 55, 'Shot by pollice (Survived)', 'Arrested', 'NO'),
(91, 91, 'Jonathan Joseph Labbe', 'MALE', 19, 'Suicide when police arrived', 'Suicide', 'NO'),
(92, 92, 'Mark Stephen Foster', 'MALE', 48, 'Fled the scene', 'Arrested', 'NO'),
(93, 93, 'Amy Bishop Anderson', 'FEMALE', 44, 'Surrendered to Police', 'Arrested', 'NO'),
(94, 94, 'Bruco Strongeagle Eastwood', 'MALE', 32, 'Physical intervention by civilian', 'Arrested', 'NO'),
(95, 95, 'John Patrick Bedell', 'MALE', 36, 'Shot by police (Killed)', 'Killed', 'NO'),
(96, 96, 'Nathaniel Alvin Brown', 'MALE', 50, 'Suicide before police arrived', 'Suicide', 'NO'),
(97, 97, 'Arunya Rouch', 'FEMALE', 41, 'Shot by police (Survived)', 'Arrested', 'NO'),
(98, 98, 'Abdo Ibssa', 'MALE', 38, 'Suicide before police arrived', 'Suicide', 'NO'),
(99, 99, 'Rasheed Cherry', 'MALE', 17, 'Shot by police (Survived)', 'Arrested', 'NO'),
(100, 100, 'Robert Phillip Montgomery', 'MALE', 53, 'Suicide before police arrived', 'Suicide', 'NO'),
(101, 101, 'Abraham Dickan', 'MALE', 79, 'Shot by off-duty police (Killed)', 'Killed', 'NO'),
(102, 102, 'Gerardo Regalado', 'MALE', 37, 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(103, 103, 'Robert Reza', 'MALE', 37, 'Suicide when police arrived', 'Suicide', 'NO'),
(104, 104, 'Omar Sheriff Thornton', 'MALE', 34, 'Suicide when police arrived', 'Suicide', 'NO'),
(105, 105, 'Yvonne Hiller', 'FEMALE', 43, 'Surrendered to Police', 'Arrested', 'YES'),
(106, 106, 'Steven Jay Kropf', 'MALE', 63, 'Shot by police (Killed)', 'Killed', 'NO'),
(107, 107, 'Akouch Kashoual', 'MALE', 26, 'Suicide before police arrived', 'Suicide', 'NO'),
(108, 108, 'Clifford Louis Miller Jr', 'MALE', 24, 'Suicide before police arrived', 'Suicide', 'NO'),
(109, 109, 'Brendan O’Rourke (aka Brandon O’Rourke)', 'MALE', 41, 'Physical intervention by civilian', 'Arrested', 'NO'),
(110, 110, NULL, NULL, NULL, 'Fled the scene', 'Escaped (Never Caught)', 'NO'),
(111, 111, 'John Dennis Gillane', 'MALE', 45, 'Surrendered to Police', 'Arrested', 'YES'),
(112, 112, 'Clay Allen Duke', 'MALE', 56, 'Suicide after engaging police', 'Suicide', 'NO'),
(113, 113, 'Richard L. Butler Jr', 'MALE', 17, 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(114, 114, 'Jared Lee Loughner', 'MALE', 22, 'Physical intervention by civilian', 'Arrested', 'NO'),
(115, 115, 'Kanai Daniel Avery', 'MALE', 16, 'Physical Intervention by security guard', 'Arrested', 'NO'),
(116, 116, 'Michael Edward Hance', 'MALE', 51, 'Shot by police (Killed)', 'Killed', 'NO'),
(117, 117, 'Tyrone Miller', 'MALE', 22, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(118, 118, 'Eduardo Sencion (aka Eduardo Perez-Gonzalez)', 'MALE', 32, 'Suicide before police arrived', 'Suicide', 'NO'),
(119, 119, 'Jesse Ray Palmer', 'MALE', 48, 'Shot by police (Killed)', 'Killed', 'NO'),
(120, 120, 'Frank William Allman (aka Shareef Allman)', 'MALE', 49, 'Fled the scene; Shot by police (Killed)', 'Killed', 'NO'),
(121, 121, 'Scott Evans Dekraai', 'MALE', 41, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(122, 122, 'Andre Turner', 'MALE', 51, 'Suicide before police arrived', 'Suicide', 'NO'),
(123, 123, 'Ronald Dean Davis', 'MALE', 50, 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(124, 124, 'Timothy Patrick Mulqueen', 'MALE', 43, 'Shot by police (Killed)', 'Killed', 'NO'),
(125, 125, 'Thomas Michael Lane, III', 'MALE', 17, 'Physical intervention by civilian; fled the scene', 'Escaped (Arrested Later)', 'NO'),
(126, 126, 'John Schick', 'MALE', 30, 'Shot by police (Killed)', 'Killed', 'NO'),
(127, 127, 'O’Brian McNeil White', 'MALE', 24, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(128, 128, 'Su Nam Ko (aka One L. Goh)', 'MALE', 43, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(129, 129, 'Jacob Carl England', 'MALE', 19, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(130, 130, 'Ian Lee Stawicki', 'MALE', 40, 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(131, 131, 'Nathan Van Wilkins', 'MALE', 44, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(132, 132, 'James Eagan Holmes', 'MALE', 24, 'Surrendered to Police', 'Arrested', 'YES'),
(133, 133, 'Wade Michael Page', 'MALE', 40, 'Suicide after engaging police', 'Suicide', 'NO'),
(134, 134, 'Robert Wayne Gladden Jr.', 'MALE', 15, 'Physical intervention by civilian', 'Arrested', 'NO'),
(135, 135, 'Terence Tyler', 'MALE', 23, 'Suicide before police arrived', 'Suicide', 'NO'),
(136, 136, 'Andrew John Engeldinger', 'MALE', 36, 'Suicide before police arrived', 'Suicide', 'NO'),
(137, 137, 'Bradford Ramon Baumet', 'MALE', 36, 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(138, 138, 'Radcliffe Franklin Haughton', 'MALE', 45, 'Suicide before police arrived', 'Suicide', 'NO'),
(139, 139, 'Lawrence Jones', 'MALE', 42, 'Suicide before police arrived', 'Suicide', 'NO'),
(140, 140, 'Jacob Tyler Roberts', 'MALE', 22, 'Suicide before police arrived', 'Suicide', 'NO'),
(141, 141, 'Adam Lanza', 'MALE', 20, 'Suicide when police arrived', 'Suicide', 'NO'),
(142, 142, 'Jason Heath Letts', 'MALE', 38, 'Shot by police (Killed)', 'Killed', 'NO'),
(143, 143, 'Jeffrey Lee Michael', 'MALE', 44, 'Shot by police (Killed)', 'Killed', 'NO'),
(144, 144, 'Bryan Oliver', 'MALE', 16, 'Verbal intervention by civilian', 'Arrested', 'NO'),
(145, 145, 'Arthur Douglas Harmon, III', 'MALE', 70, 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(146, 146, 'Kurt Myers', 'MALE', 64, 'Fled the scene; Shot by police (Killed)', 'Killed', 'NO'),
(147, 147, 'Neil Allen MacInnis', 'MALE', 22, 'Physical Intervention by security guard', 'Arrested', 'NO'),
(148, 148, 'Dennis Clark III', 'MALE', 27, 'Shot by police (Killed)', 'Killed', 'NO'),
(149, 149, 'Esteban Jimenez Smith', 'MALE', 23, 'Shot by police (Killed)', 'Killed', 'NO'),
(150, 150, 'John Zawahri', 'MALE', 23, 'Shot by police (Killed)', 'Killed', 'NO'),
(151, 151, 'Lakin Anthony Faust', 'MALE', 23, 'Shot by police (Survived)', 'Arrested', 'NO'),
(152, 152, 'Pedro Alberto Vargas', 'MALE', 42, 'Shot by police (Killed)', 'Killed', 'NO'),
(153, 153, 'Rockne Warren Newell', 'MALE', 59, 'Physical intervention by civilian', 'Arrested', 'NO'),
(154, 154, 'Hubert Allen Jr.', 'MALE', 72, 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(155, 155, 'Aaron Alexis', 'MALE', 34, 'Shot by police (Killed)', 'Killed', 'NO'),
(156, 156, 'Jose Reyes', 'MALE', 12, 'Suicide before police arrived', 'Suicide', 'NO'),
(157, 157, 'Christopher Thomas Chase', 'MALE', 35, 'Shot by police (Killed)', 'Killed', 'NO'),
(158, 158, 'Paul Anthony Ciancia', 'MALE', 23, 'Shot by police (Survived)', 'Arrested', 'NO'),
(159, 159, 'Karl Halverson Pierson', 'MALE', 18, 'Suicide when police arrived', 'Suicide', 'NO'),
(160, 160, 'Alan Oliver Frazier', 'MALE', 51, 'Suicide when police arrived', 'Suicide', 'NO'),
(161, 161, 'Mason Andrew Campbell', 'MALE', 12, 'Verbal intervention by civilian', 'Arrested', 'NO'),
(162, 162, 'Shawn Walter Bair', 'MALE', 22, 'Shot by police (Killed)', 'Killed', 'NO'),
(163, 163, 'Darion Marcus Aguilar', 'MALE', 19, 'Suicide before police arrived', 'Suicide', 'NO'),
(164, 164, 'Cherie Louise Rhoades', 'FEMALE', 44, 'Physical intervention by civilian', 'Arrested', 'NO'),
(165, 165, 'Ivan Antonio Lopez-Lopez', 'MALE', 34, 'Suicide when police arrived', 'Suicide', 'NO'),
(166, 166, 'Frazier Glenn Miller, Jr.', 'MALE', 73, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(167, 167, 'Geddy Lee Kramer', 'MALE', 19, 'Suicide before police arrived', 'Suicide', 'NO'),
(168, 168, 'Porfirio Sayago-Hernandez', 'MALE', 40, 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(169, 169, 'Elliot Rodger', 'MALE', 22, 'Suicide after engaging police', 'Suicide', 'NO'),
(170, 170, 'Aaron Rey Ybarra', 'MALE', 26, 'Physical intervention by civilian', 'Arrested', 'NO'),
(171, 171, 'Dennis Ronald Marx', 'MALE', 48, 'Shot by police (Killed)', 'Killed', 'NO'),
(172, 172, 'Jerad Dwain Miller', 'MALE', 31, 'Shot by police (Killed)', 'Killed', 'NO'),
(173, 173, 'Jared Michael Padgett', 'MALE', 15, 'Suicide when police arrived', 'Suicide', 'NO'),
(174, 174, 'Richard Steven Plotts', 'MALE', 49, 'Shot by civilian (Survived)', 'Arrested', 'NO'),
(175, 175, 'Justin Joe Armstrong', 'MALE', 28, 'Shot by police (Killed)', 'Killed', 'NO'),
(176, 176, 'Kerry Joe Tesney', 'MALE', 45, 'Suicide before police arrived', 'Suicide', 'NO'),
(177, 177, 'Jaylen Ray Fryberg', 'MALE', 15, 'Verbal intervention by civilian; Suicide before police arrived', 'Suicide', 'NO'),
(178, 178, 'Myron May', 'MALE', 31, 'Shot by police (Killed)', 'Killed', 'NO'),
(179, 179, 'Curtis Wade Holley', 'MALE', 53, 'Shot by off-duty police (Killed)', 'Killed', 'NO'),
(180, 180, 'Larry Steven McQuilliams', 'MALE', 49, 'Shot by police (Killed)', 'Killed', 'NO'),
(181, 181, 'John Lee (aka Kane Grzebielski)', 'MALE', 29, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(182, 182, 'Jose Garcia-Rodriguez', 'MALE', 57, 'Suicide before police arrived', 'Suicide', 'NO'),
(183, 183, 'Raymond Kenneth Kmetz', 'MALE', 68, 'Shot by police (Killed)', 'Killed', 'NO'),
(184, 184, 'Tarod Tyrell Thornhill', 'MALE', 17, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(185, 185, 'Jeffrey Scott DeZeeuw', 'MALE', 51, 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(186, 186, 'Richard Castilleja', 'MALE', 29, 'Shot by police (Killed)', 'Killed', 'NO'),
(187, 187, 'Ryan Elliot Giroux', 'MALE', 41, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(188, 188, 'David Jamichael Daniels', 'MALE', 21, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(189, 189, 'Everardo Custodio', 'MALE', 21, 'Shot by civilian', 'Arrested', 'NO'),
(190, 190, 'Sergio Daniel Valencia Del Toro', 'MALE', 27, 'Suicide before police arrived', 'Suicide', 'NO'),
(191, 191, 'Marcell Travon Willis', 'MALE', 21, 'Suicide before police arrived', 'Suicide', 'NO'),
(192, 192, 'Dylann Storm Roof', 'MALE', 21, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(193, 193, 'Michael Holt', 'MALE', 35, 'Shot by police (Killed)', 'Killed', 'NO'),
(194, 194, 'Mohammad Youssuf Abdulazeez', 'MALE', 24, 'Shot by police (Killed)', 'Killed', 'NO'),
(195, 195, 'John Russell Houser', 'MALE', 59, 'Suicide when police arrived', 'Suicide', 'NO'),
(196, 196, 'Christopher Sean Harper-Mercer', 'MALE', 26, 'Suicide after engaging police', 'Suicide', 'NO'),
(197, 197, 'Robert Lee Mayes, Jr.', 'MALE', 40, 'Suicide when police arrived', 'Suicide', 'NO'),
(198, 198, 'Noah Jacob Harpham', 'MALE', 33, 'Shot by police (Killed)', 'Killed', 'NO'),
(199, 199, 'Robert Lewis Dear, Jr.', 'MALE', 57, 'Surrendered to Police', 'Arrested', 'YES'),
(200, 200, 'Syed Rizwan Farook', 'MALE', 28, 'Fled the scene; Shot by police (Killed)', 'Killed', 'NO'),
(201, 201, 'Jason Brian Dalton', 'MALE', 45, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(202, 202, 'Cedric Larry Ford', 'MALE', 38, 'Shot by police (Killed)', 'Killed', 'NO'),
(203, 203, 'James Austin Hancock', 'MALE', 14, 'Surrendered to Police', 'Arrested', 'YES'),
(204, 204, 'Michael Ford', 'MALE', 22, 'Shot by the police (Survived)', 'Arrested', 'NO'),
(205, 205, 'Jakob Edward Wagner', 'MALE', 18, 'Shot by police (Killed)', 'Killed', 'NO'),
(206, 206, 'Marion Guy Williams', 'MALE', 65, 'Suicide when police arrived', 'Suicide', 'NO'),
(207, 207, 'James David Walker', 'MALE', 36, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(208, 208, 'Dionisio Agustine Garza III', 'MALE', 25, 'Shot at by Civilian (Missed); Shot by police (Killed)', 'Killed', 'NO'),
(209, 209, 'Omar Mir Seddique Mateen', 'MALE', 29, 'Shot by police (Killed)', 'Killed', 'NO'),
(210, 210, 'Lakeem Keon Scott', 'MALE', 37, 'Shot by police (Survived)', 'Arrested', 'NO'),
(211, 211, 'Micah Xavier Johnson', 'MALE', 25, 'Killed by police controlled bomb carying robot', 'Killed', 'NO'),
(212, 212, 'Gavin Eugene Long', 'MALE', 29, 'Shot by police (Killed)', 'Killed', 'NO'),
(213, 213, 'Allen Christopher Ivanov', 'MALE', 19, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(214, 214, 'Tom Stanley Mourning II', 'MALE', 26, 'Unclear', 'Arrested', 'UNCLEAR'),
(215, 215, 'Nicholas N. Glenn', 'MALE', 25, 'Shot by police (Killed)', 'Killed', 'NO'),
(216, 216, 'Arcan Cetin', 'MALE', 20, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(217, 217, 'Nathan Desai', 'MALE', 46, 'Shot by police (Killed)', 'Killed', 'NO'),
(218, 218, 'Jesse Dewitt Osborne', 'MALE', 14, 'Armed intervention by civilian (no shots fired)', 'Arrested', 'NO'),
(219, 219, 'Getachew Tereda Fekede', 'MALE', 53, 'Suicide before police arrived', 'Suicide', 'NO'),
(220, 220, 'Raul Lopez Saenz', 'MALE', 25, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(221, 221, 'Esteban Santiago-Ruiz', 'MALE', 26, 'Surrendered to Police', 'Arrested', 'YES'),
(222, 222, 'Ely Ray Serna', 'MALE', 17, 'Physical intervention by civilian', 'Arrested', 'NO'),
(223, 223, 'Nengmy Vang', 'MALE', 45, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(224, 224, 'Rolando Bueno Cardenas', 'MALE', 55, 'Surrendered to Police', 'Arrested', 'YES'),
(225, 225, 'Allen Dion Cashe', 'MALE', 31, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(226, 226, 'Seth Thomas Wallace', 'MALE', 32, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(227, 227, 'Kori Ali Muhammad', 'MALE', 39, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(228, 228, 'Joshua James Ray Gueary', 'MALE', 25, 'Suicide before police arrived', 'Suicide', 'NO'),
(229, 229, 'Peter Raymond Selis', 'MALE', 49, 'Shot by police (Killed)', 'Killed', 'NO'),
(230, 230, 'Thomas Harry Hartless', 'MALE', 43, 'Suicide before police arrived', 'Suicide', 'NO'),
(231, 231, 'John Robert Neumann Jr', 'MALE', 45, 'Suicide before police arrived', 'Suicide', 'NO'),
(232, 232, 'Randy Robert Stair', 'MALE', 24, 'Suicide before police arrived', 'Suicide', 'NO'),
(233, 233, 'James Thomas Hodgkinson', 'MALE', 66, 'Shot by police (Killed)', 'Killed', 'NO'),
(234, 234, 'Jimmy Chanh Lam', 'MALE', 38, 'Suicide when police arrived', 'Suicide', 'NO'),
(235, 235, 'Dr. Henry Michael Bello', 'MALE', 45, 'Suicide before police arrived', 'Suicide', 'NO'),
(236, 236, 'Rick Whited', 'MALE', 54, 'Fled the scene after engaging security guards', 'Escaped (Arrested Later)', 'NO'),
(237, 237, 'Nathaniel Ray Jouett', 'MALE', 16, 'Surrendered to Police', 'Arrested', 'YES'),
(238, 238, 'Caleb Sharpe', 'MALE', 15, 'Verbal & Physical intervention by civilian', 'Arrested', 'YES'),
(239, 239, 'Emanuel Kidega Samson', 'MALE', 25, 'Armed intervention by civilian (no shots fired)', 'Arrested', 'NO'),
(240, 240, 'Stephen Craig Paddock', 'MALE', 64, 'Suicide before police arrived', 'Suicide', 'NO'),
(241, 241, 'Radee Labeeb Prince', 'MALE', 37, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(242, 242, 'Alan Ashmore', 'MALE', 61, 'Shot at by Civilian (Missed); Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(243, 243, 'Scott Allen Ostrem', 'MALE', 47, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(244, 244, 'Devin Patrick Kelley', 'MALE', 26, 'Shot by civilan (survived); committed suicide before police arrived', 'Suicide', 'NO'),
(245, 245, 'Kevin Janson Neal', 'MALE', 44, 'Suicide after engaging police', 'Suicide', 'NO'),
(246, 246, 'Travis Green', 'MALE', 29, 'Civilian intervention with automobile; Physical intervention by police', 'Arrested', 'NO'),
(247, 247, 'Robert Lorenzo Bailey, Jr', 'MALE', 28, 'Shot by civilian (Survived)', 'Arrested', 'NO'),
(248, 248, 'William Edward Atchison', 'MALE', 21, 'Suicide before police arrived', 'Suicide', 'NO'),
(249, 249, 'Mausean Vittorio Quran Carter', 'MALE', 30, 'Physical intervention by civilian', 'Arrested', 'NO'),
(250, 250, 'Isaiah Currie', 'MALE', 20, 'Suicide when police arrived', 'Suicide', 'NO'),
(251, 251, 'Gabriel Ross Parker', 'MALE', 15, 'Surrendered to Police', 'Arrested', 'YES'),
(252, 252, 'Nikolas Jacob Cruz', 'MALE', 19, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(253, 253, 'Walter Frank Thomas', 'MALE', 64, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(254, 254, 'Nasim Najafi Aghdam', 'FEMALE', 39, 'Suicide before police arrived', 'Suicide', 'NO'),
(255, 255, 'Travis Jeffrey Reinking', 'MALE', 29, 'Physical intervention by civilian; fled the scene', 'Escaped (Arrested Later)', 'NO'),
(256, 256, 'Rex Whitmire Harbour', 'MALE', 26, 'Suicide when police arrived', 'Suicide', 'NO'),
(257, 257, 'Matthew A. Milby Jr.', 'MALE', 19, 'Shot by police (Survived)', 'Arrested', 'NO'),
(258, 258, 'Dimitrios Pagourtzis', 'MALE', 17, 'Surrendered to Police', 'Arrested', 'NO'),
(259, 259, 'Alexander C. Tilghman', 'MALE', 28, 'Shot by civilian (Killed)', 'Killed', 'NO'),
(260, 260, NULL, 'MALE', 13, 'Physical intervention by civilian', 'Arrested', 'NO'),
(261, 261, NULL, NULL, NULL, 'Fled the scene', 'Escaped (Never Caught)', 'NO'),
(262, 262, 'Jarrod Warren Ramos', 'MALE', 38, 'Surrendered to Police', 'Arrested', 'YES'),
(263, 263, 'Kristine Peralez', 'FEMALE', 38, 'Suicide when police arrived', 'Suicide', 'NO'),
(264, 264, 'David Bennett Katz', 'MALE', 24, 'Suicide before police arrived', 'Suicide', 'NO'),
(265, 265, 'Omar Enrique Santa Perez', 'MALE', 29, 'Shot by police (Killed)', 'Killed', 'NO'),
(266, 266, 'Javier Casarez', 'MALE', 54, 'Fled the scene; Suicide when police arrived', 'Suicide', 'NO'),
(267, 267, 'Anthony Yente Tong', 'MALE', 43, 'Shot by police (Killed)', 'Killed', 'NO'),
(268, 268, 'Patrick Shaun Dowdell', 'MALE', 61, 'Shot by police (Killed)', 'Killed', 'NO'),
(269, 269, 'Snochia Moseley', 'FEMALE', 26, 'Suicide before police arrived', 'Suicide', 'NO'),
(270, 270, 'Gregory Alan Bush', 'MALE', 51, 'Shot at by civilian (missed); Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(271, 271, 'Robert Gregory Bowers', 'MALE', 46, 'Shot by police (Survived)', 'Arrested', 'NO'),
(272, 272, 'Scott Paul Beierle', 'MALE', 40, 'Suicide before police arrived', 'Suicide', 'NO'),
(273, 273, 'Davance Lamar Reed', 'MALE', 37, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(274, 274, 'Ian David Long', 'MALE', 28, 'Suicide after engaging police', 'Suicide', 'NO'),
(275, 275, 'Waid Anthony Melton', 'MALE', 30, 'Fled the scene; Committed Suicide', 'Suicide', 'NO'),
(276, 276, 'Juan Lopez', 'MALE', 32, 'Suicide after engaging police', 'Suicide', 'NO'),
(277, 277, 'Abdias Ucdiel Flores-Corado', 'MALE', 35, 'Shot by police (Killed)', 'Killed', 'NO'),
(278, 129, 'Alvin Lee Watts', 'MALE', 32, 'Fled the scene', 'Escaped (Arrested Later)', 'NO'),
(279, 172, 'Amanda Renee Miller', 'FEMALE', 22, 'Suicide after engaging police', 'Suicide', 'NO'),
(280, 200, 'Tashfeen Malik', 'FEMALE', 29, 'Fled the scene; Shot by police (Killed)', 'Killed', 'NO');

-- --------------------------------------------------------

--
-- Table structure for table `statelookup`
--

CREATE TABLE `statelookup` (
  `Id` int(11) NOT NULL,
  `Name` enum('Alabama','Alaska','Arizona','Arkansas','California','Colorado','Connecticut','Delaware','District of Columbia','Florida','Georgia','Hawaii','Idaho','Illinois','Indiana','Iowa','Kansas','Kentucky','Louisiana','Maine','Maryland','Massachusetts','Michigan','Minnesota','Mississippi','Missouri','Montana','Nebraska','Nevada','New Hampshire','New Jersey','New Mexico','New York','North Carolina','North Dakota','Ohio','Oklahoma','Oregon','Pennsylvania','Rhode Island','South Carolina','South Dakota','Tennessee','Texas','Utah','Vermont','Virginia','Washington','West Virginia','Wisconsin','Wyoming') NOT NULL
);

--
-- Dumping data for table `statelookup`
--

INSERT INTO `statelookup` (`Id`, `Name`) VALUES
(1, 'Alabama'),
(2, 'Alaska'),
(3, 'Arizona'),
(4, 'Arkansas'),
(5, 'California'),
(6, 'Colorado'),
(7, 'Connecticut'),
(8, 'Delaware'),
(9, 'District of Columbia'),
(10, 'Florida'),
(11, 'Georgia'),
(12, 'Hawaii'),
(13, 'Idaho'),
(14, 'Illinois'),
(15, 'Indiana'),
(16, 'Iowa'),
(17, 'Kansas'),
(18, 'Kentucky'),
(19, 'Louisiana'),
(20, 'Maine'),
(21, 'Maryland'),
(22, 'Massachusetts'),
(23, 'Michigan'),
(24, 'Minnesota'),
(25, 'Mississippi'),
(26, 'Missouri'),
(27, 'Montana'),
(28, 'Nebraska'),
(29, 'Nevada'),
(30, 'New Hampshire'),
(31, 'New Jersey'),
(32, 'New Mexico'),
(33, 'New York'),
(34, 'North Carolina'),
(35, 'North Dakota'),
(36, 'Ohio'),
(37, 'Oklahoma'),
(38, 'Oregon'),
(39, 'Pennsylvania'),
(40, 'Rhode Island'),
(41, 'South Carolina'),
(42, 'South Dakota'),
(43, 'Tennessee'),
(44, 'Texas'),
(45, 'Utah'),
(46, 'Vermont'),
(47, 'Virginia'),
(48, 'Washington'),
(49, 'West Virginia'),
(50, 'Wisconsin'),
(51, 'Wyoming');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `incident`
--
ALTER TABLE `incident`
  ADD PRIMARY KEY (`Id`),
  ADD UNIQUE KEY `Id` (`Id`),
  ADD KEY `Name` (`Name`),
  ADD KEY `LocationType` (`LocationType`),
  ADD KEY `Date` (`Date`);

--
-- Indexes for table `incidentstate`
--
ALTER TABLE `incidentstate`
  ADD PRIMARY KEY (`Id`),
  ADD UNIQUE KEY `Id` (`Id`),
  ADD KEY `incidentId` (`incidentId`),
  ADD KEY `stateId` (`stateId`);

--
-- Indexes for table `rawrecords`
--
ALTER TABLE `rawrecords`
  ADD PRIMARY KEY (`Id`),
  ADD UNIQUE KEY `Id` (`Id`);

--
-- Indexes for table `shooter`
--
ALTER TABLE `shooter`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `id` (`id`),
  ADD KEY `Name` (`Name`),
  ADD KEY `Gender` (`Gender`),
  ADD KEY `Age` (`Age`),
  ADD KEY `IncidentId` (`IncidentId`),
  ADD KEY `TerminatingEvent` (`TerminatingEvent`),
  ADD KEY `ShooterFate` (`ShooterFate`),
  ADD KEY `SurrenderedDuringIncident` (`SurrenderedDuringIncident`);

--
-- Indexes for table `statelookup`
--
ALTER TABLE `statelookup`
  ADD PRIMARY KEY (`Id`),
  ADD UNIQUE KEY `Id` (`Id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `incident`
--
ALTER TABLE `incident`
  MODIFY `Id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=278;

--
-- AUTO_INCREMENT for table `incidentstate`
--
ALTER TABLE `incidentstate`
  MODIFY `Id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=279;

--
-- AUTO_INCREMENT for table `rawrecords`
--
ALTER TABLE `rawrecords`
  MODIFY `Id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=278;

--
-- AUTO_INCREMENT for table `shooter`
--
ALTER TABLE `shooter`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=281;

--
-- AUTO_INCREMENT for table `statelookup`
--
ALTER TABLE `statelookup`
  MODIFY `Id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=52;




COMMIT;
