START TRANSACTION;

--
-- Database: `fbi_active_shooters_2000_2018`
--
CREATE DATABASE `fbi_active_shooters_2000_2018`;
USE `fbi_active_shooters_2000_2018`;

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

-- --------------------------------------------------------

--
-- Table structure for table `incidentstate`
--

CREATE TABLE `incidentstate` (
  `id` int(11) NOT NULL,
  `incidentId` int(11) NOT NULL,
  `stateId` int(11) NOT NULL
);

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

-- --------------------------------------------------------

--
-- Table structure for table `statelookup`
--

CREATE TABLE `statelookup` (
  `Id` int(11) NOT NULL,
  `Name` enum('Alabama','Alaska','Arizona','Arkansas','California','Colorado','Connecticut','Delaware','District of Columbia','Florida','Georgia','Hawaii','Idaho','Illinois','Indiana','Iowa','Kansas','Kentucky','Louisiana','Maine','Maryland','Massachusetts','Michigan','Minnesota','Mississippi','Missouri','Montana','Nebraska','Nevada','New Hampshire','New Jersey','New Mexico','New York','North Carolina','North Dakota','Ohio','Oklahoma','Oregon','Pennsylvania','Rhode Island','South Carolina','South Dakota','Tennessee','Texas','Utah','Vermont','Virginia','Washington','West Virginia','Wisconsin','Wyoming') NOT NULL
);

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
  ADD PRIMARY KEY (`id`),
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
  MODIFY `Id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `incidentstate`
--
ALTER TABLE `incidentstate`
  MODIFY `Id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `rawrecords`
--
ALTER TABLE `rawrecords`
  MODIFY `Id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `shooter`
--
ALTER TABLE `shooter`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `statelookup`
--
ALTER TABLE `statelookup`
  MODIFY `Id` int(11) NOT NULL AUTO_INCREMENT;

COMMIT;
