# FBI_Active_Shooter_Incidents_2000-2022
A manual ETL of the primary data from the FBI's reports on active shooter incidents from 2000 to 2022, into a standardized structured dataset.
See:

* https://www.fbi.gov/file-repository/active-shooter-incidents-2000-2018.pdf/view
* https://www.fbi.gov/about/partnerships/office-of-partner-engagement/active-shooter-incidents-graphics
* https://www.fbi.gov/file-repository/active-shooter-incidents-in-the-us-2019-042820.pdf/view
* https://www.fbi.gov/file-repository/active-shooter-incidents-20-year-review-2000-2019-060121.pdf/view
* https://www.fbi.gov/file-repository/active-shooter-incidents-in-the-us-2020-070121.pdf/view
* https://www.fbi.gov/file-repository/active-shooter-incidents-in-the-us-2021-052422.pdf/view
* https://www.fbi.gov/file-repository/active-shooter-incidents-in-the-us-2022-042623.pdf/view

## Description
This is my own manual conversion of the raw FBI Active Shooting Incident reports. I made an Excel spreadsheet for each of the FBI's PDF reports, and a MySQL Relational Database containing everything unified in one place. Both contain the same dataset; allowing different methods of analytical inspection. The Excel spreadsheets also contain links to news stories for each incident for which additional research was needed to resolve ambiguity in the FBI data, or to find the shooter's name.

I've done my best to verify the data, but there might be some errors in my ETL processing. The raw incident reports total 61 pages of unstructured text that I had to read through & manually convert into precise mathematical data. I also had to do external research to disambiguate unspecified info, and some of the edge cases are a bit vague, and are difficult to put into fixed categories, while others come down to one's personal opinion, and the FBI did not document their's so it becomes rather difficult to make sure that I am coming to the same conclusion on ambiguity that they did.

I used several different methods to verify that my data accurately reproduces the data in the reports. However, there are some discrepancies between my data, and the summary data in some of the reports, and I also discovered several errors & some more possible errors in the FBI's data.

See the following sections for more info:
* Automated Tests Against Summary Data
* Secondary AI Verification
* Known Errors (In the FBI Report's Summary Data)
* Possible Errors

## How To Use
This project consists of 2 lenses into the same dataset. The spreadsheets can be found in the "RawReportData" folder, and SQL scripts to build the database can be found in the "Incremental Build Scripts" folder.

### Excel Spreadsheets:
There is a separate spreadsheet available for each datasource PDF. These spreadsheets also include hyperlinks to any secondary research which was necessary to resolve ambiguity in the FBI reports, or to determine the shooter's name.

### Relational Database (Implemented via MySQL / MariaDB):
The build scripts are located in the folder "Incremental Build Scripts". Run them in order of their number prefix.

Ex:
```
"00_BuildSchemaStructure.sql"
"01_PopulateLookupTables.sql"
"02_RawIncidentDescriptions.sql"
... and so on.
```
One easy way to do this is via PHP My Admin within XAMPP. This project was built & tested on: XAMPP Version 8.2.12, on MariaDB 10.4.32 & phpMyAdmin 5.2.1
1. Open PHP My Admin via the "Admin" button for the MySQL service in the XAMPP control panel dialog.
2. Click the "Import" button in the toolbar at the top of the webpage.
3. Click the "Browse" button under the "File to import" section, and open the file "00_BuildSchemaStructure.sql". Leave the rest of the form with their defaults, and then click the "Import" button at the bottom of the page. Only import the first file this way. This builds the DB schema structure. There's a much easier way that we'll import the rest of the files, but we can't do that without having the database schema created first. So, we run the first script this way to build the schema.
4. Once the first script finishes building the schema, click the "Databases" button in the toolbar at the top of the screen.
5. Click the link for the newly created "fbi_active_shooters" database from the listing.
6. Open windows explorer, and navigate to the "Incremental Build Scripts" folder.
7. Starting with the "01__PopulateLookupTables.sql" script, since we already ran the "00_..." script, one-by-one, click and drag the script files onto the webpage for the "fbi_active_shooters" database. Wait for each file to finish executing before draging the next file. They will execute against the active database schema, and open a small dialog in the bottom right corner of the page, showing a history of which files you've executed, in order, and with a progress bar for the active one.
8. Once you have executed the last script file, if there were no errors, then you're done, and the database is fully built, and ready to be used.


## DB Views
I've included several views, which provide what I believed to be some common desired slices & groupings of this data, which makes retrieving this data very simple. You can execute the following simple command:

```
SELECT * FROM fbi_active_shooters.OneOfTheViews;
```  

Replace "OneOfTheViews" with whichever view you wish to pull, and run that command. Object names in SQL are not case-sensitive, so don't worry about getting the upper/lower case perfect; all that matters is the spelling. If you are running from within PHP My Admin, with the fbi_active_shooters schema selected, then you don't even need the "fbi_active_shooters." prefix.

The available views are:

* perCapitaStats_yearly
* perCapitaStats_total
* perCapitaStatsByState_yearly
* perCapitaStatsByState_total
* ShootersByFate_Yearly
* ShootersByFate_Total
* ShootersByGender_Yearly
* ShootersByGender_Total
* ShootersByAge_Yearly
* ShootersByAge_Total
* ShootersByAgeAsColumns_Yearly
* ShootersByAgeAsColumns_Total
* casualtiesByLocation_yearly
* casualtiesByLocation_total
* casualtiesByShooterGender_yearly
* casualtiesByShooterGender_total
* casualtiesByShooterFate_yearly
* casualtiesByShooterFate_total

There are a few other views, but they are mostly used to build these main views.

It may be a little slow for the yearly ones (up to 10 seconds or so), because PHP My Admin is not very efficient at parsing large datasets and converting them into HTML for display in the browser, but the actual DB side of things should return in well under 1 second for all views.

Obviously, if you know SQL, you can run more complex queries, but my goal was to provide easy access for those who may not be accustomed to databases.

## Data Duplication: Multi-State & Multi-Shooter Incidents
Depending upon how you query the database, a small portion of data may or may not be duplicated. However, there are ways to query the data which avoids the duplication entirely. Typically, only queries which group the incident & casualty data by State or by shooter, end up incurring this duplication. The views which display the number of shooters by attributes of the shooter (ex: gender, age, fate, etc.), do not duplicate any data.

When grouping by State, the duplicated data accounts for around 1% of the total casualty data (See tables below). When grouping by shooter, the duplicated data acounts for around 1-4%.


Incidents & Casualties "By State" Duplication:
```
    Incidents
        W/Dups:   492
        Actual:   484
         Extra:     8 [1.65%]
    
    Deaths
        W/Dups: 1,313
        Actual: 1,304
        Extra:      9 [0.69%]
    
    Wounded
        W/Dups: 2,293
        Actual: 2,268
        Extra:     25 [1.10%]
    
    TotalCasualties
        W/Dups: 3,606
        Actual: 3,572
        Extra:     34 [0.95%]
```

Incidents & Casualties "By Shooter Gender" Duplication:
```
    Incidents
        W/Dups:   489
        Actual:   484
         Extra:     5 [1.03%]

    Deaths
        W/Dups: 1,342
        Actual: 1,304
        Extra:     38 [2.91%]

    Wounded
        W/Dups: 2,365
        Actual: 2,268
        Extra:     97 [4.28%]

    TotalCasualties
        W/Dups: 3,707
        Actual: 3,572
        Extra:    135 [3.78%]
```

Incidents & Casualties "By Shooter Fate" Duplication:
```
    [Same as "By Shooter Gender", except less duplication in incidents.]
    
    Incidents
        W/Dups:   486
        Actual:   484
         Extra:     2 [0.41%]
```

### Cause:
There are multiple incidents which cross State lines. Due to the way the FBI categorizes these incidents, much of the data is grouped together and considered a single incident. This presents problems when attempting to query data such as number of incidents by State, since the same incident will be counted twice (once for each State), and the entire casualty totals for the whole incident will be included in the totals for both States.

Additionally, the FBI summary data which I used to verify my data, only counts the incident for a single State; as the report puts it:

> "When an incident occurred in two or more States, it was counted only once (in the State where the FBI identified that the public was most at risk)."

Which sounds nice, but the report doesn't indicate anywhere, which State each of these events were counted in; making each multi-State incident arbitrarily assigned to one or the other, with no means of predicting which one it is. Thus, making the summary data inherently inaccurate for State-related incident data. However, there are only 8 multi-state incidents in the entire dataset, and all of them are only double-State incidents, there are no triple-State incidents; making the effect of their data duplication minimal.

Similarly, my database has no means of distinguishing the contributions of each shooter in incidents with multiple shooters. So, if your query groups the data by shooter, then the full casualty totals for the entire incident will be duplicated for each shooter in that incident. So, if an incident with 3 shooters resulted in 5 casualties, then all 3 of those shooters will show 5 casualties each. However, multi-shooter incidents account for a very small percentage of all incidents. There are only 8 double-shooter incidents, and only 3 triple-shooter incidents.

## Terminating Event / Shooter's Fate / Surrendered (during the incident)
The "Terminating Event" & "Shooter's Fate" columns, and to some extent the "Surrendered (during the incident)" column, should be taken with a grain of salt. It's a bit hard to explain, but figuring out a way to standardize the values & their definitions for these columns turned out to be surprisingly difficult to do, for a number of reasons. And thus, any data verification which depended upon these values (ex: number of shooters killed by civilians, number of times engaged by police, etc.), will likewise be unclear.

One issue is that, to some degree, much of that standardization depends upon personal preference. For example, what counts as a shooter being "engaged by police"? Them merely showing up, and he surrenders when he sees them? or do they have to aim their guns at him? Is mere threats enough, or do they actually have to shoot at him? What about if they tackle him, or force him off of the road in a car chase? Does an off-duty cop count as police? What about a soldier on a military base? Or an off-duty soldier? A security guard? And since the FBI's summary data does not go into detail about which they choose for each incident, and why, it's very difficult to figure out which incidents we differ on, and in what direction we differ.

But, perhaps the biggest issue was that many of these incidents involved multiple locations. So, if the shooter "escaped" the first scene, and went to another scene to attack more people, and was killed or captured at the scene of that one, what should be the value? I tried to partially solve this, via the semicolon list in the "Terminating Event" column, to indicate the value for the initial & intermediate locations, and then the value for the final location. For "Shooter's Fate", I tried to do something similar, by marking it as "Escaped (...)" if the shooter escaped any of the locations, and then the parenthesis indicating his ultimate fate. As for whether or not the shooter surrendered "during the incident", that was also surprisingly difficult to define. For example, there's the same multi-location issue, but also: how long does the shooter have to have escaped for before the cops catching up with him counts as a separate incident. If he escapes the first location, and drives away, and they find him 10 minutes later, and there's a car chase, and he surrenders after crashing his car, does that count has him surrendering "during the incident"? What about if he escapes, and several hours later kills some more people, and he surrenders when the cops show up there; did he surrender "during the incident"? And what about the incidents with multiple shooters? Also, sometimes the only information I could find on the event was ambiguous, and so I had to sort of read-between the lines, to figure out what happened, so this data is mostly correct at best.

Obviously, the best solution would be to redesign the structure of the DB to incorporate an "IncidentLocation" table, and have each incident have multiple locations, and separate records for each shooter at each location for each incident, and have a terminating event, casualty count, shooter's fate, etc. for each location. However, that would require more extensive alterations than I had intended to do in this update; especially because it would require going back through all of the data, and verifying everything again, as well as probably doing more extensive research to get the specifics on each location for every single event.

So, for now, I've done my best to summarize the values for these columns, to represent the overall gist of each incident, but this should not be taken as perfectly accurate, but rather more as rough summaries.

I considered dropping the columns, but I had already done so much research on them, that I thought it would be a waste to throw it out. At a minimum, they can be used as a starting point for anyone who wishes to delve deeper and refine the information.


## Unknown Shooters
In the summary data, the FBI counts unknown shooters as male for some years, and keeps them separate for others.

There is also ambiguity about the number of shooters that are counted when the total is unknown. See the following:

* Incident 117 - House Party in South Jamaica, NY

    The event description indicates 1 known shooter and an unknown number of additional shooters. The description specifically uses the "shooter(s)" designation. Based upon cross-referencing the summary data in the FBI's report with the known data from the other incidents, it appears that the FBI counts the unknown "shooter(s)" as 2 shooters in addition to the other known shooter; making a total of 3 shooters for that incident.

* Incident 261 - Highway 509 Near Seattle-Tacoma International Airport

    The event description indicates an unknown number of shooters. The description specifically uses the "shooter(s)" designation. Based upon cross-referencing the summary data in the FBI's report with the known data from the other incidents, it appears that the FBI counts this event as a single shooter.

## Automated Tests Against Summary Data
After finishing my manual data entry of all of the updated reports, I began my data integrity checks using the summary data provided within the FBI reports. I standardized this summary data into JSON files; one for each PDF datasource (See: "Summary-Check/\*.json"). I then wrote some code to read in these "expected" target values, and compare them to the equivalent data queried from the database (See: "Summary-Check/SummaryDataVerification.java"). While the majority was correct, the comparison results revealed some inconsistencies between my data and the FBI summary data, indicating possible errors in my data (See: "Summary-Check/Results___All.txt", or "Summary-Check/Results___FailuresOnly.txt").

## Secondary AI Verification
Despite considerable investigation, I could not find where my data was wrong. So, I decided to use AI to independently parse the FBI reports, and compare the AI's output to my own, to try to track down my mistakes.

### Methodology
I copied the raw text of the event descriptions from the FBI reports, and pasted them into text files. I then wrote a simple program (See: "RawTextExtracts/ParseRawPoliceReports.java") to parse this text, and clean it up for insertion into the database. I then wrote code to iterate through each incident, and package up the event info into an API request to OpenAI's GPT4 (See: "AI-Check/AiValidator.java").

The general format of the request was a large system prompt describing how I wanted the AI to handle ambiguity, and standardizing its output. This was followed by the shooting incident name & description, and finally a single data question (ex: which State did this occurr in?, etc.). This process was repeated multiple times for each incident; providing a fresh clean chat history for each data question, to prevent any data contamination between questions. The answers were then parsed and fed into the database.

Finally, I wrote some more code (Also in: "AI-Check/AiValidator.java") to query the database and iterate through each incident, pulling both the AI's answers and my own manual entry data, and checking for discrepancies. If the AI gave the same answer as me, then it was considered to be correct. If the AI gave a different answer, then it was flagged for manual review.

GPT4-Turbo appeared to have significant trouble with the suicide & arrest questions, resulting in a lot of false errors. I reran the verification with GPT4o, and it seemed to fair much better. As such, my manual re-checking was based upon the GPT4o verification. The GPT4-Turbo results are included for transparency & completeness, but ultimately were not used to inform the manual recheck.

### Result
While this did find a few minor mistakes, (such as a typo for one of the shootings in the original 2018 data where I entered the time as 6:45 instead of 6:42, etc.), the vast majority of the discrepancies between the AI's answers & mine, were due to ambiguities which the AI didn't understand. For example, for one incident, the police report indicated that a shooter was restrained by civilians until police arrived, but never actually explicitly stated that the shooter was arrested, so the AI concluded that he wasn't.

I manually re-checked all of the discrepancies between GPT4o's answers, and my manual data. I fixed the few minor issues, but the rest are false alarms. After the few small fixes, I re-ran the AI verification comparison.

The logs in the "AI-Check" folder contain all of the descrepancies remaining after these few minor fixes. After my manual re-check of the GPT4o descrepancies, I have concluded that all of them are false-alarms, and my data correctly matches the FBI incident reports. But, I have left them here, so that you can double-check them if you wish.

There are some which depend upon personal preference. For example, the only discrepancy in States (incident 359; See: https://www.justice.gov/usao-ednc/pr/man-sentenced-20-years-federal-prison-shooting-rampage-i-95-north-carolina ). In this incident, the shooter began shooting at other cars while driving along Interstate 95 in North Carolina. When police responded, they began a high-speed chase for 60 miles, and ended up crossing the border into Virginia. However, the actual shooting only took place in North Carolina; they merely chased him into Virginia. So, should the "incident" include Virginia? To some degree, it's a matter of opinion. I said "no", because the shooting was only in North Carolina, but you could argue "yes", because it was all a single continuous incident that ended in North Carolina.


## Known Errors (In the FBI Report's Summary Data)
There are numerous errors in the 20-year review (2000-2019) report's summary data.

The summary data in the 20-year review report lists the number of States as: 43 + District of Columbia, but my data lists that count at 44 + District of Columbia. This is because the only events which occurred in Delaware were multi-State incidents, and the FBI decided to count both of them in the other State. So, the FBI lists Delaware as having zero incidents, while I retain the count of those 2 multi-State incidents. Though, admittedly, this is not so much an "error" as a preference, but it does explain why my State count for 2000 - 2019 doesn't match theirs.

The 20-year review report is wrong for 2019, assuming that the 2019 report is correct. If you take the summary numbers from the 2019 report for casualty break down, and add the two new 2019 incidents from the 20-year review report, it produces numbers that don't match the 20-year review summary numbers for 2019. But, if you do the reverse, and look at the 2020 report's "previous year" data for 2019, the casualty numbers are different from the 20-year review report's numbers, and these new updated values match my data.

Also, in the 20-year review report, in the "20-Year Active Shooter Summary" on page 4, the chart in the bottom right corner ("Other Shooter Outcomes"), lists the number of "Shooters at large" as 5, but the last sentence of the text description below the info graphic, says there were only 4 ("4 at large."). The "correct" value appears to be 5, since on page 25 of the same PDF, the "Shooter Outcomes" summary charts, also list 5 as the number of "at large" shooters.

Also, it claims 18 events for Ohio, but the name "ohio" only occurrs in 17 of the event descriptions, for years 2019 and before.

Also, there are several States which under-count the number of incidents, but this is assumed to be a part of the FBI arbitrarily choosing where to count multi-State incidents. For example, 2 incidents took place in Delaware, but both were multi-State incidents, and both were counted in other States, so Delaware shows a count of zero in the FBI report.

However, not all such undercounting States can be accounted for in this way. For example, the 20-year review report lists Indiana as having 4 total incidents. However, there are 5 incidents from 2000 to 2019 which declare their State to be Indiana:
* Incident #7   "Nu-Wood Decorative Millwork Plant"
* Incident #9   "Bertrand Products, Inc."
* Incident #162 "Martin's Supermarket"
* Incident #260 "Noblesville West Middle School"
* Incident #329 "North Side Neighborhood in Evansville, Indiana"

And all of their provided descriptions exclusively mention Indiana; they do not even mention another State, so this discrepancy cannot be the result of counting one of these incidents for another State. There is also a 6th incident which mentioned Indiana, but the event occurred in Ohio; the shooter was just caught in Indiana, so that wouldn't solve it either.

* Incident #22 "Watkins Motor Lines"

To verify this, run the following query:
```
SELECT *
  FROM fbi_active_shooters.rawIncidentDescriptions
 WHERE (
        datasourceId = '2000-2018'
     OR datasourceId = '2019'
     OR datasourceId = '2000-2019'
 )
 AND (
        LOWER(rawIncidentTitle) LIKE '%indiana%'
     OR LOWER(incidentDesc)     LIKE '%indiana%'
 )
```

Also, the 20-year review report's updated summary data for location types in 2019 does not match my totals. However, double-checking my own data, a chain of logic proves that my data is correct. There is only 1 record in the RawIncidentDescriptions table whose parsed LocationType does not match the specified LocationType in its RawEventTitle, and it is the 1 record where the FBI classified it as "Residential" instead of their normal "Residence" type. So, I changed it to match the rest of the data. Finally, given that that means that all the LocationTypes are correct for the rawIncidentDescriptions, a cross-reference between the RawIncidentDescriptions and the fully processed Incident table records shows that there are zero Incident records whose LocationType does not match its corresponding RawIncidentDescription LocationType. My total count of all incidents in the Incident table matches the claimed total number of incidents in the summary stats of all the FBI reports for every year. Thus, my locationType data is correct, and the FBI summary data is wrong. There is a test case for this at the end of the automated tests.


## A Note On Casualty Counts In News Stories
If you try researching these events yourself, or if you look at some of the news articles I've provided, something I've noticed is that news agencies routinely include the shooter in their casualty numbers; especially in the headlines.

For example:
https://mainstreetmediatn.com/articles/gallatinnews/police-one-dead-two-injured-in-shooting-at-lock-4-park/

> "Police: One dead, two injured in shooting at Lock 4 Park"

But, that 1 death was the shooter committing suicide, and only the 2 wounded are actually victims.

And another:
https://www.parispi.net/news/local_news/article_b0995e76-a414-11ea-bb7a-d7e7cb0eb5c0.html

> "Three people were killed Monday when a Henry County business owner shot two women to death, including his estranged wife, and then killed himself."

I encountered this so many times doing this research. I find it rather deceptive, but regardless, it can be confusing if you're trying to match numbers between news stories & the FBI reports, because the FBI does not include the fate of the shooter in the casualty numbers; apparently, most news agencies do. So, if you do research on mass shootings, keep an eye out for this.

## Possible Errors

### "Finninger’s Catering Company"

The 20-year review report places the "Finninger’s Catering Company" shooting on April 19, 2006. However, multiple news stories for the event, were published on the 18th, and reference the shooting taking place, either the same day as the article, or explicitly on "Tuesday". April 19, 2006 was a Wednesday.

I chose to use the date of April 19, 2006, in order to match the FBI report, but this appears to be a mistake.

### "Tequila KC Bar" (Oct. 6, 2019)

The 20-year review report lists the ages of the shooters at 23 & 25, but my research to identify their names turned up multiple news stories, both around the time of the event, and years later, which identify the age gap at 6 years, rather than 2; the older of them being 29 at the time of the shooting, rather than 25.

However, since I don't have any special facts on the case, as with the other potential errors, I have gone with the FBI's numbers to match the report, but it is possible that this data is wrong.

### "Old Town Arvada, Arvada, CO" (Jun. 21, 2021)

The 2021 FBI Report documents the shooter has having only a shotgun. However, various news reports explicitly mention the shooter having either: a shotgun, an AR-15, or both; and the refernces to an AR-15 are explicitly repeated multiple times in each article. So, either the news stories are making stuff up, or there's some ambiguity here. As usual, I've gone with the FBI's account, but it might be wrong.

Also, this account only mentions the law enforcement officer who was killed. While it acknowledges that an armed civilian killed the shooter, and stopped the attack, it does not mention that another police officer killed the good samaritan. There seems to be some inconsistency for which injuries surrounding an event do or do not get counted. I thought I remembered an event from one of the previous years, where there was some kind of casualty due to collateral damage by police, and it was counted. But maybe I'm remembering wrong.

### "County Road C, Oakland, WI" (April 15, 2022)

The 2022 report documents the shooter as "armed with a handgun", but the only news article I could find on what appears to be the event (posted a year after the event), explicitly claims that "he used two handguns".

As always, I used the numbers in the FBI report.

### "Forum Shopping Center/Safeway, Bend, OR" (August 28, 2022)
The 2022 report documents the shooter as "armed with a rifle", but several news stories on the subject claim he had multiple weapons, though they don't agree on what they were, but the most common claim was 1 AR-15 & 1 shotgun:

> "The 20-year-old gunman legally purchased all of his weapons, which included two shotguns and a semi-automatic rifle."
> 
> https://www.opb.org/article/2023/08/28/bend-oregon-safeway-shooting-one-year-anniversary-guns/
	
> "Police officers found the gunman, whose name has not been released, dead 'in close proximity' to an AR-15-style weapon and a shotgun inside the Safeway supermarket,"
> 
> https://www.cbsnews.com/news/safeway-bend-oregon-shooting-three-dead-including-gunman/
	
> "At least three people, including the shooter, are dead in Bend after a man with a military-style rifle opened fire at the Forum Shopping Center off Highway 20. ... Police found a semi-automatic rifle and a shotgun near the shooter’s body."
> 
> https://www.opb.org/article/2022/08/28/bend-police-investigating-possible-active-shooter/
	
> "... said Bend Police spokeswoman Sheila Miller. The gunman is also dead, she said. Police did not say how he died. A shotgun was found near his body. ... She said the shooter may have had several weapons in addition to the rifle."
> 
> https://www.bendbulletin.com/localstate/gunman-sprays-aisles-of-bend-safeway-3-dead/article_27818d4c-2744-11ed-b73e-7373d977a1a2.html
	
> "At a press conference late Sunday, Bend Police Chief Mike Krantz said the suspect was carrying an AR-15-style rifle and a shotgun."
> 
> https://abcnews.go.com/US/dead-shooting-safeway-oregon-police/story?id=88382502

As always, I used the numbers in the FBI report.

### "Interstate 10, Avondale, AZ" (November 19, 2022)
The 2022 report documents the total casualties as "One person was killed; two people were wounded." However, all of the news articles I can find on what appears to be the event, document upwards of 5 casualties. At least one of them was from the shooter driving his car into a motorcyclist, so perhaps that was excluded since it wasn't a gunshot wound? I'm not sure.

> "Raymond continued shooting. Police say there were at least six victims, with at least two being shot, including a 14-year-old who was shot in the cheek, court documents said."
> 
> https://www.12news.com/article/news/crime/records-alleged-avondale-shooter-made-several-spontaneous-utterances-to-police-after-he-was-detained/75-e8c42adc-59db-4149-986a-e6819212a96f
	
> "The sixth victim, the motorcyclist, is in critical condition."
> 
> https://www.12news.com/article/news/crime/one-detained-following-shooting-near-avondale-boulevard-mcdowell-road-police-say/75-c5bb337d-e51e-447c-ba00-8047a7ecb051
	
> "One person has died, and 5 are injured after police say a man allegedly shot at cars that were driving on the I-10 freeway in Avondale Saturday afternoon."
> 
> https://www.azfamily.com/2022/11/20/1-dead-5-injured-after-suspect-allegedly-shoots-cars-i-10-avondale/
	
> "An eighth victim reported being shot at, but was not hurt."
> 
> https://www.fox10phoenix.com/news/large-police-investigation-underway-in-avondale

As always, I used the numbers in the FBI report.
