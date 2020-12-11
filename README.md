# FBI_Active_Shooter_Incidents_2000-2018
A manual ETL of the primary data from the FBI's 19 year report on active shooters incidents, into a standardized structured dataset.
See:
https://www.fbi.gov/file-repository/active-shooter-incidents-2000-2018.pdf/view

The resulting datasets match the summary data provided by the FBI's overview infographic report:
https://www.fbi.gov/about/partnerships/office-of-partner-engagement/active-shooter-incidents-graphics

----

This is my own manual conversion of the raw FBI Active Shooting Incident reports. I produced an Excel spreadsheet & a MySQL Relational Database, each containing the same dataset; allowing different methods of analytical inspection.

I've done my best to verify the data, but there might be some errors in my ETL processing. The raw FBI report is 32 pages of unstructured text that I had to read through & manually convert to precise mathematical data. I also had to do external research to disambiguate unspecified info, and some of the edge cases are a bit vague, and are difficult to put into fixed categories.

In the end, the location category distributions, and the yearly totals for number of incidents, deaths, wounded, & total casualties (in both the Excel spreadsheet & the database tables) exactly match the summary data provided by the FBI in their overview infographic report.

Final Note:
See the text file named "___Delaware Incident Anomaly.txt" in the root directory, for a clarification on a data standardization decision.
