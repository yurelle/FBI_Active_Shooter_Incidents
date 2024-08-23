START TRANSACTION;

--
-- Database: `fbi_active_shooters`
--
CREATE DATABASE `fbi_active_shooters`;
USE `fbi_active_shooters`;

-- --------------------------------------------------------

--
-- Table structure for table `incident`
--

CREATE TABLE `incident` (
    `Id` INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    `Name` varchar(250) NOT NULL,
    `Date` date NOT NULL,
    `Time` time NOT NULL,
    `Year` INTEGER AS (YEAR(Date)),
    `LocationType` varchar(250) NOT NULL,
    `Rifles` INTEGER DEFAULT NULL,
    `Shotguns` INTEGER DEFAULT NULL,
    `Handguns` INTEGER DEFAULT NULL,
    `Deaths` INTEGER NOT NULL,
    `Wounded` INTEGER NOT NULL,
    `TotalCasualties` INTEGER NOT NULL,
    `DataSourceID` char(15) NOT NULL
);

-- Create Indexes
CREATE INDEX INCIDENT_NAME_INDEX         ON INCIDENT (Name);
CREATE INDEX INCIDENT_LOCATIONTYPE_INDEX ON INCIDENT (LocationType);
CREATE INDEX INCIDENT_DATE_INDEX         ON INCIDENT (Date);
CREATE INDEX INCIDENT_DATASOURCE_INDEX   ON INCIDENT (DataSourceID);

-- --------------------------------------------------------

--
-- Table structure for table `incidentstate`
--

CREATE TABLE `incidentstate` (
    `id` INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    `incidentId` INTEGER NOT NULL,
    `stateId` INTEGER NOT NULL
);

-- Create Indexes
CREATE INDEX INCIDENTSTATE_INCIDENTID_INDEX ON INCIDENTSTATE (incidentId);
CREATE INDEX INCIDENTSTATE_STATEID_INDEX    ON INCIDENTSTATE (stateId);

-- --------------------------------------------------------

--
-- Table structure for table `rawrecords`
--

CREATE TABLE `rawrecords` (
    `Id` INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
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
    `ShooterFate` varchar(250) NOT NULL,
    `SurrenderedDuringIncident` varchar(250) NOT NULL,
    `DataSourceID` char(15) NOT NULL
);

-- Create Indexes
CREATE INDEX RAWRECORDS_DATE_INDEX         ON RAWRECORDS (Date);
CREATE INDEX RAWRECORDS_INCIDENTNAME_INDEX ON RAWRECORDS (IncidentName);
CREATE INDEX RAWRECORDS_DATASOURCE_INDEX   ON RAWRECORDS (DataSourceID);

-- --------------------------------------------------------

--
-- Table structure for table `rawIncidentDescriptions`
--

CREATE TABLE `rawIncidentDescriptions` (
    `Id` INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    `IncidentId` INTEGER,
    `RawIncidentTitle` varchar(250) NOT NULL,
    `IncidentName` varchar(250) NOT NULL,
    `LocationType` varchar(250) NOT NULL,
    `IncidentDesc` varchar(5000) NOT NULL,
    `DataSourceID` char(15) NOT NULL
);

-- Create Indexes
CREATE INDEX RAWINCDESC_INC_ID_INDEX ON rawIncidentDescriptions (IncidentId);
CREATE INDEX RAWINCDESC_NAME_INDEX ON rawIncidentDescriptions (IncidentName);
CREATE INDEX RAWINCDESC_LOCATIONTYPE_INDEX ON rawIncidentDescriptions (LocationType);
CREATE INDEX RAWINCDESC_DATASOURCE_INDEX ON rawIncidentDescriptions (DataSourceID);

-- --------------------------------------------------------

--
-- Table structure for table `aiVerification`
--

CREATE TABLE `aiVerification` (
    `Id` INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    `IncidentId` INTEGER NOT NULL,
    `Deaths` varchar(250),
    `Wounded` varchar(250),
    `State` varchar(250),
    `Time` varchar(250),
    `Gender` varchar(250),
    `Age` varchar(250),
    `MultipleShooters` varchar(250),
    `NumShooters` varchar(250),
    `Arrested` varchar(250),
    `NumArrested` varchar(250),
    `Suicide` varchar(250),
    `NumSuicide` varchar(250),
    `AtLarge` varchar(250),
    `NumAtLarge` varchar(250),
    `AiModel` varchar(250)
);

-- Create Indexes
CREATE INDEX AIVERIFICATION_INCIDENTID_INDEX ON aiVerification (IncidentId);
CREATE INDEX AIVERIFICATION_AIMODEL_INDEX    ON aiVerification (AiModel);

-- --------------------------------------------------------

--
-- Table structure for table `shooter`
--

CREATE TABLE `shooter` (
    `id` INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    `IncidentId` INTEGER NOT NULL,
    `Name` varchar(250) DEFAULT NULL,
    `Gender` varchar(250) DEFAULT NULL,
    `Age` INTEGER DEFAULT NULL,
    `TerminatingEvent` varchar(250),
    `Fate` varchar(250) NOT NULL,
    `SurrenderedDuringIncident` varchar(250) NOT NULL
);

-- Create Indexes
CREATE INDEX SHOOTER_INCIDENTID_INDEX       ON SHOOTER (IncidentId);
CREATE INDEX SHOOTER_NAME_INDEX             ON SHOOTER (Name);
CREATE INDEX SHOOTER_GENDER_INDEX           ON SHOOTER (Gender);
CREATE INDEX SHOOTER_AGE_INDEX              ON SHOOTER (Age);
CREATE INDEX SHOOTER_TERMINATINGEVENT_INDEX ON SHOOTER (TerminatingEvent);
CREATE INDEX SHOOTER_FATE_INDEX             ON SHOOTER (Fate);
CREATE INDEX SHOOTER_SURRENDERED_INDEX      ON SHOOTER (SurrenderedDuringIncident);

-- --------------------------------------------------------

--
-- Table structure for table `dataSourceLookup`
--

CREATE TABLE `dataSourceFile` (
    `Id` char(15) NOT NULL PRIMARY KEY,
    `Name` varchar(250) NOT NULL
);

-- Create Indexes
CREATE INDEX DATASOURCEFILE_NAME_INDEX ON DATASOURCEFILE (Name);

-- --------------------------------------------------------

--
-- Table structure for table `statelookup`
--

CREATE TABLE `statelookup` (
    `Id` INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    `Name` enum(
        'Alabama',
        'Alaska',
        'Arizona',
        'Arkansas',
        'California',
        'Colorado',
        'Connecticut',
        'Delaware',
        'District of Columbia',
        'Florida',
        'Georgia',
        'Hawaii',
        'Idaho',
        'Illinois',
        'Indiana',
        'Iowa',
        'Kansas',
        'Kentucky',
        'Louisiana',
        'Maine',
        'Maryland',
        'Massachusetts',
        'Michigan',
        'Minnesota',
        'Mississippi',
        'Missouri',
        'Montana',
        'Nebraska',
        'Nevada',
        'New Hampshire',
        'New Jersey',
        'New Mexico',
        'New York',
        'North Carolina',
        'North Dakota',
        'Ohio',
        'Oklahoma',
        'Oregon',
        'Pennsylvania',
        'Rhode Island',
        'South Carolina',
        'South Dakota',
        'Tennessee',
        'Texas',
        'Utah',
        'Vermont',
        'Virginia',
        'Washington',
        'West Virginia',
        'Wisconsin',
        'Wyoming'
    ) NOT NULL
);

-- Create Indexes
CREATE INDEX STATELOOKUP_NAME_INDEX ON STATELOOKUP (Name);

-- --------------------------------------------------------

--
-- Table structure for table `population`
--

CREATE TABLE `population` (
    `id` INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    `year` INTEGER NOT NULL,
    `stateId` INTEGER DEFAULT NULL,
    `population` INTEGER NOT NULL,
    `per100Thousand` DOUBLE AS (100000 /population),
    `perMillion`     DOUBLE AS (1000000/population),
    `stateName` VARCHAR(250) NOT NULL -- Temporary column used while building DB.
);

-- Create Indexes
CREATE INDEX SHOOTER_YEAR_INDEX  ON POPULATION (year);
CREATE INDEX SHOOTER_STATE_INDEX ON POPULATION (stateId);

-- --------------------------------------------------------



-- --------------------------------------------------------

COMMIT;
