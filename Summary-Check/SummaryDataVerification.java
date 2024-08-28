import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.intellij.lang.annotations.Language;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.sql.*;
import java.util.*;

/**
 * Requires the following dependencies:
 *
 * implementation group: 'com.mysql', name: 'mysql-connector-j', version: '8.4.0'
 * implementation group: 'com.fasterxml.jackson.core', name: 'jackson-databind', version: '2.17.1'
 * implementation 'org.jetbrains:annotations:24.0.0'   (Only used to provide syntax highlighting to SQL queries)
 */
public class SummaryDataVerification {
    Connection conn;
    boolean logSuccesses = false;
    public static final String SUMMARY_DATA_PARENT_DIR = "D:/FBI_Active_Shooter_Incidents/Summary-Check/";

    public SummaryDataVerification() throws ClassNotFoundException, InstantiationException, IllegalAccessException {
        Class.forName("com.mysql.cj.jdbc.Driver").newInstance();
    }

    public boolean getConnection() {
        try {
            if (conn != null) {
                conn.close();
            }
            conn = DriverManager.getConnection("jdbc:mysql://localhost:3306/fbi_active_shooters", "root", "");
        } catch(Exception e) {
            e.printStackTrace();
            return false;
        }
        return true;
    }

    public boolean closeConnection() {
        try {
            conn.close();
        } catch(Exception e) {
            e.printStackTrace();
            return false;
        }
        return true;
    }

    public void verifyAndLog(
            final String valName,
            final String incidentVal,
            final String aiVal) {

        //Verify
        final StringBuilder log = new StringBuilder();
        boolean success = verify(log, valName, incidentVal, aiVal, "", "");

        //Log
        final boolean shouldLog = !success || (success && logSuccesses);
        if (shouldLog) {
            System.out.println(log);
        }
    }

    public boolean verify(
            final StringBuilder sb,
            final String valName,
            final String incidentVal,
            final String aiVal
    ) {
        return verify(sb, valName, incidentVal, aiVal, "");
    }

    public boolean verify(
            final StringBuilder sb,
            final String valName,
            final String incidentVal,
            final String aiVal,
            final String extraSuccessFormatSuffix
    ) {
        return verify(sb, valName, incidentVal, aiVal, extraSuccessFormatSuffix, "");
    }

    public boolean verify(
            final StringBuilder sb,
            final String valName,
            final String incidentVal,
            final String aiVal,
            final String extraSuccessFormatSuffix,
            final String extraFailureFormatSuffix
    ) {
        //Label
        sb.append(valName + ": ");

        //Result
        final boolean isEq;

        //Null Check
        if (incidentVal == null) {
            isEq = (aiVal == null);
        } else if (aiVal == null) {
            isEq = false;
        }
        //Compare
        else if (incidentVal.trim().equalsIgnoreCase(aiVal.trim())) {
            isEq = true;
        } else {
            isEq = false;
        }

        //Log Result
        if (isEq) {
            sb.append("✓\t\t\t" + extraSuccessFormatSuffix);
//            sb.append("✓ [" + incidentVal + " = " + aiVal + "]\t\t" + extraFailureFormatSuffix);
            return true;
        } else {
            sb.append("! [" + incidentVal + " vs " + aiVal + "]\t" + extraFailureFormatSuffix);
            return false;
        }
    }

    public void setQueryParams(final PreparedStatement stmt, final Object ... params) throws SQLException {
        for (int x = 0; x < params.length; x++) {
            final Object param = params[x];
            final int paramIndex = x + 1;

            //Determine Data Type
            if (param instanceof String) {
                stmt.setString(paramIndex, (String) param);
            } else if (param instanceof Integer) {
                stmt.setInt(paramIndex, (Integer) param);
            } else if (param instanceof String[]) {
                //TODO: MySQL doesn't support Arrays
                final Array array = conn.createArrayOf("VARCHAR", (String[]) param);
                stmt.setArray(paramIndex, array);
            }
        }
    }

    public HashMap<String,Object> parseJSON(final String json) throws JsonProcessingException {
        final ObjectMapper mapper = new ObjectMapper();
        final TypeReference<HashMap<String,Object>> typeRef = new TypeReference<>() {};
        final HashMap<String,Object> result = mapper.readValue(json, typeRef);

        return result;
    }

    public String queryForValue(@Language("SQL") final String sql) throws SQLException {
        return queryForValue(sql, new Object[]{});
    }

    public String queryForValue(@Language("SQL") final String sql, final Object ... params) throws SQLException {
        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(sql);

        //Params
        setQueryParams(stmt, params);

        //Execute Query
        ResultSet rs = stmt.executeQuery();
        if (rs.next()) {
            return rs.getString(1);
        } else {
            throw new SQLException("Record Not Found!");
        }
    }

    public Map<String,String> queryForRow(@Language("SQL") final String sql) throws SQLException {
        return queryForRow(sql, new Object[]{});
    }

    public Map<String,String> queryForRow(@Language("SQL") final String sql, final Object ... params) throws SQLException {
        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(sql);

        //Params
        setQueryParams(stmt, params);

        //Execute Query
        ResultSet rs = stmt.executeQuery();
        Map<String,String> row = new HashMap<>();
        if (rs.next()) {
            ResultSetMetaData metaData = rs.getMetaData();
            final int numColumns = metaData.getColumnCount();
            for (int i = 1; i <= numColumns; i++) {
                row.put(metaData.getColumnName(i), rs.getString(i));
            }
            return row;
        } else {
            throw new SQLException("Record Not Found!");
        }
    }

    public static class Range {
        int lowerBound;
        int upperBound;

        public Range(int singleRecordIndex) {
            this.lowerBound = singleRecordIndex;
            this.upperBound = singleRecordIndex;
        }

        public Range(int lowerBound, int upperBound) {
            this.lowerBound = lowerBound;
            this.upperBound = upperBound;
        }
    }

    public void verify_overallStatistics(final HashMap<String,Object> summaryStats, final String datasourceID, final Range years) throws SQLException {
        verify_overallStatistics(summaryStats, new String[] {datasourceID}, years);
    }

    public void verify_overallStatistics(final HashMap<String,Object> summaryStats, final String[] datasourceIDs, final Range years) throws SQLException {
        System.out.println("\n" +
                "-----------------------\n" +
                "Verifying Overall Stats\n" +
                "-----------------------\n"
        );

        //ID List
        final String datasourceIdList = "'" + String.join("', '", datasourceIDs) + "'";

        //Incidents
        if (summaryStats.containsKey("TOTAL_INCIDENTS")) {
            verifyAndLog(
                    "Incidents",
                    ((Integer) summaryStats.get("TOTAL_INCIDENTS")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.incident inc
                               """ +
                               "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                               """
                                   AND ? <= `year` AND `year` <= ?;
                               """,
                            years.lowerBound,
                            years.upperBound
                    )
            );
        }

        //States
        if (summaryStats.containsKey("TOTAL_STATES")) {
            verifyAndLog(
                    "States",
                    ((Integer) summaryStats.get("TOTAL_STATES")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(distinct incSt.stateId) AS cnt
                                  FROM fbi_active_shooters.incident inc
                                  JOIN fbi_active_shooters.incidentState incSt
                                    ON incSt.incidentId = inc.id
                               """ +
                               "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                               """
                                   AND ? <= `year` AND `year` <= ?;
                               """,
                            years.lowerBound,
                            years.upperBound
                    )
            );
        }

        {//CasualtyBreakdown
            final Map<String, String> casualtyBreakdown = queryForRow(
                    """
                        SELECT SUM(totalCasualties) AS casualties,
                               SUM(deaths) AS deaths,
                               SUM(wounded) AS wounded
                          FROM fbi_active_shooters.incident inc
                       """ +
                       "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                       """
                           AND ? <= `year` AND `year` <= ?;
                       """,
                    years.lowerBound,
                    years.upperBound
            );

            //Casualties
            if (summaryStats.containsKey("TOTAL_CASUALTIES")) {
                verifyAndLog(
                        "Casualties",
                        ((Integer) summaryStats.get("TOTAL_CASUALTIES")).toString(),
                        casualtyBreakdown.get("casualties")
                );
            }

            //Deaths
            if (summaryStats.containsKey("TOTAL_DEATHS")) {
                verifyAndLog(
                        "Deaths",
                        ((Integer) summaryStats.get("TOTAL_DEATHS")).toString(),
                        casualtyBreakdown.get("deaths")
                );
            }

            //Wounded
            if (summaryStats.containsKey("TOTAL_WOUNDED")) {
                verifyAndLog(
                        "Wounded",
                        ((Integer) summaryStats.get("TOTAL_WOUNDED")).toString(),
                        casualtyBreakdown.get("wounded")
                );
            }
        }

        //Mass Killings
        if (summaryStats.containsKey("TOTAL_MASS-KILLINGS_(3+_DEATHS)")) {
            verifyAndLog(
                    "Mass Killings",
                    ((Integer) summaryStats.get("TOTAL_MASS-KILLINGS_(3+_DEATHS)")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.incident inc
                               """ +
                               "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                               """
                                   AND ? <= `year` AND `year` <= ?
                                   AND deaths >= 3;
                               """,
                            years.lowerBound,
                            years.upperBound
                    )
            );
        }

        //Engaged Shooters
        if (summaryStats.containsKey("NUM_TIMES_LAW_ENFORCEMENT_ENGAGED_THE_SHOOTER")) {
            verifyAndLog(
                    "Engaged Shooters",
                    ((Integer) summaryStats.get("NUM_TIMES_LAW_ENFORCEMENT_ENGAGED_THE_SHOOTER")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.incident inc
                                  JOIN fbi_active_shooters.shooter sh
                                    ON sh.incidentId = inc.id
                               """ +
                               "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                               """
                                   AND ? <= `year` AND `year` <= ?
                                   AND (
                                              sh.terminatingEvent = 'Shot by police (Killed)'
                                           OR sh.terminatingEvent = 'Shot by police (Survived)'
                                           OR sh.terminatingEvent = 'Suicide after engaging police'
                                           OR sh.terminatingEvent = 'Suicide while being pursued by police'
                                           OR sh.terminatingEvent = 'Fled the scene; Shot by police (Killed)'
                                       );
                               """,
                            years.lowerBound,
                            years.upperBound
                    )
            );
        }

        //All Shooters
        if (summaryStats.containsKey("NUM_SHOOTERS")) {
            verifyAndLog(
                    "All Shooters",
                    ((Integer) summaryStats.get("NUM_SHOOTERS")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.incident inc
                                  JOIN fbi_active_shooters.shooter sh
                                    ON sh.incidentId = inc.id
                               """ +
                               "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                               """
                                   AND ? <= `year` AND `year` <= ?;
                               """,
                            years.lowerBound,
                            years.upperBound
                    )
            );
        }

        //Male Shooters
        if (summaryStats.containsKey("NUM_MALE_SHOOTERS")) {
            verifyAndLog(
                    "Male Shooters",
                    ((Integer) summaryStats.get("NUM_MALE_SHOOTERS")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.incident inc
                                  JOIN fbi_active_shooters.shooter sh
                                    ON sh.incidentId = inc.id
                               """ +
                               "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                               """
                                   AND ? <= `year` AND `year` <= ?
                                   AND sh.gender = 'MALE';
                               """,
                            years.lowerBound,
                            years.upperBound
                    )
            );
        }

        //Female Shooters
        if (summaryStats.containsKey("NUM_FEMALE_SHOOTERS")) {
            verifyAndLog(
                    "Female Shooters",
                    ((Integer) summaryStats.get("NUM_FEMALE_SHOOTERS")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.incident inc
                                  JOIN fbi_active_shooters.shooter sh
                                    ON sh.incidentId = inc.id
                               """ +
                               "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                               """
                                   AND ? <= `year` AND `year` <= ?
                                   AND sh.gender = 'FEMALE';
                               """,
                            years.lowerBound,
                            years.upperBound
                    )
            );
        }

        //Non-Binary Shooters
        if (summaryStats.containsKey("NUM_NONBINARY_SHOOTERS")) {
            verifyAndLog(
                    "Non-Binary Shooters",
                    ((Integer) summaryStats.get("NUM_NONBINARY_SHOOTERS")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.incident inc
                                  JOIN fbi_active_shooters.shooter sh
                                    ON sh.incidentId = inc.id
                               """ +
                               "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                               """
                                   AND ? <= `year` AND `year` <= ?
                                   AND sh.gender = 'NONBINARY';
                               """,
                            years.lowerBound,
                            years.upperBound
                    )
            );
        }

        //FTM Trans Shooters
        if (summaryStats.containsKey("NUM_FTM_TRANS_SHOOTERS")) {
            verifyAndLog(
                    "FTM Transgender Shooters",
                    ((Integer) summaryStats.get("NUM_FTM_TRANS_SHOOTERS")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.incident inc
                                  JOIN fbi_active_shooters.shooter sh
                                    ON sh.incidentId = inc.id
                               """ +
                               "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                               """
                                   AND ? <= `year` AND `year` <= ?
                                   AND sh.gender = 'FTM Transgender';
                               """,
                            years.lowerBound,
                            years.upperBound
                    )
            );
        }

        //Unknown Shooters
        if (summaryStats.containsKey("NUM_UNKNOWN_SHOOTERS")) {
            verifyAndLog(
                    "Unknown Shooters",
                    ((Integer) summaryStats.get("NUM_UNKNOWN_SHOOTERS")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.incident inc
                                  JOIN fbi_active_shooters.shooter sh
                                    ON sh.incidentId = inc.id
                               """ +
                               "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                               """
                                   AND ? <= `year` AND `year` <= ?
                                   AND sh.gender IS NULL;
                               """,
                            years.lowerBound,
                            years.upperBound
                    )
            );
        }

        //Suicides
        if (summaryStats.containsKey("NUM_SUICIDES")) {
            verifyAndLog(
                    "Suicides",
                    ((Integer) summaryStats.get("NUM_SUICIDES")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.incident inc
                                  JOIN fbi_active_shooters.shooter sh
                                    ON sh.incidentId = inc.id
                               """ +
                               "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                               """
                                   AND ? <= `year` AND `year` <= ?
                                   AND sh.fate LIKE '%suicide%';
                               """,
                            years.lowerBound,
                            years.upperBound
                    )
            );
        }

        //Killed By Police
        if (summaryStats.containsKey("NUM_KILLED_BY_POLICE")) {
            verifyAndLog(
                    "Killed By Police",
                    ((Integer) summaryStats.get("NUM_KILLED_BY_POLICE")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.incident inc
                                  JOIN fbi_active_shooters.shooter sh
                                    ON sh.incidentId = inc.id
                               """ +
                               "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                               """
                                   AND ? <= `year` AND `year` <= ?
                                   AND (
                                       (
                                               sh.terminatingEvent LIKE '%killed%'
                                           AND sh.terminatingEvent LIKE '%police%'
                                       )
                                       OR  sh.fate LIKE '%killed later%'
                                   );
                               """,
                            years.lowerBound,
                            years.upperBound
                    )
            );
        }

        //Killed By Civilians
        if (summaryStats.containsKey("NUM_KILLED_BY_CIVILIAN")) {
            verifyAndLog(
                    "Killed By Civilians",
                    ((Integer) summaryStats.get("NUM_KILLED_BY_CIVILIAN")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.incident inc
                                  JOIN fbi_active_shooters.shooter sh
                                    ON sh.incidentId = inc.id
                               """ +
                               "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                               """
                                   AND ? <= `year` AND `year` <= ?
                                   AND sh.terminatingEvent LIKE '%killed%'
                                   AND (
                                          sh.terminatingEvent LIKE '%civilian%'
                                       OR sh.terminatingEvent LIKE '%security guard%'
                                   );
                               """,
                            years.lowerBound,
                            years.upperBound
                    )
            );
        }

        //Arrested
        if (summaryStats.containsKey("NUM_ARRESTED")) {
            verifyAndLog(
                    "Arrested",
                    ((Integer) summaryStats.get("NUM_ARRESTED")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.incident inc
                                  JOIN fbi_active_shooters.shooter sh
                                    ON sh.incidentId = inc.id
                               """ +
                               "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                               """
                                   AND ? <= `year` AND `year` <= ?
                                   AND (
                                          sh.fate LIKE '%arrested%'
                                       OR sh.fate LIKE '%turned self in%'
                                       OR sh.fate LIKE '%surrendered later%'
                                   );
                               """,
                            years.lowerBound,
                            years.upperBound
                    )
            );
        }

        //At Large
        if (summaryStats.containsKey("NUM_AT_LARGE")) {
            verifyAndLog(
                    "At Large",
                    ((Integer) summaryStats.get("NUM_AT_LARGE")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.incident inc
                                  JOIN fbi_active_shooters.shooter sh
                                    ON sh.incidentId = inc.id
                               """ +
                               "  WHERE inc.datasourceID IN (" + datasourceIdList + ")" +
                               """
                                   AND ? <= `year` AND `year` <= ?
                                   AND sh.fate LIKE '%never caught%';
                               """,
                            years.lowerBound,
                            years.upperBound
                    )
            );
        }
    }

    public void verify_incidentsByState(final HashMap<String,Object> summaryStats, final String datasourceId) throws SQLException {
        System.out.println("\n" +
                "----------------------------\n" +
                "Verifying Incidents By State\n" +
                "----------------------------\n"
        );

        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                    WITH incidentCounts AS (
                            SELECT incState.stateID AS stateID,
                                   COUNT(*) AS totalIncidents
                              FROM fbi_active_shooters.incidentState incState
                              JOIN fbi_active_shooters.incident inc
                                ON incState.incidentId = inc.id
                             WHERE inc.datasourceID = ?
                          GROUP BY incState.stateID
                    )
                    SELECT stateLU.name AS stateName,
                           IFNULL(incidentCounts.totalIncidents, 0) AS totalIncidents
                      FROM fbi_active_shooters.stateLookup stateLU
                      LEFT JOIN incidentCounts
                        ON stateLU.id = incidentCounts.stateId
                     ORDER BY totalIncidents DESC, stateName ASC;
                    """
        );
        stmt.setString(1, datasourceId);

        //Extract Target Summary Stat Root
        final Map<String, Object> incidentsByState = (Map<String, Object>) summaryStats.get("INCIDENTS_BY_STATE");

        //Execute Query
        ResultSet rs = stmt.executeQuery();
        boolean anyFound = false;
        while (rs.next()) {
            anyFound = true;

            //Data
            final String state = rs.getString("stateName");
            final String totalIncidents = rs.getString("totalIncidents");

            //Incidents
            verifyAndLog(
                    state,
                    (Optional.ofNullable((Integer) incidentsByState.get(state)).orElse(0)).toString(),
                    totalIncidents
            );
        }

        //Empty Check
        if (!anyFound) {
            throw new SQLException("Record Not Found!");
        }
    }

    public String getShootersInAgeRange(final String datasourceID, final int lowerBound, final int upperBound) throws SQLException {
        return queryForValue(
                """
                    SELECT COUNT(*) AS cnt
                      FROM fbi_active_shooters.shooter sh
                      JOIN fbi_active_shooters.incident inc
                        ON sh.incidentId = inc.id   
                     WHERE inc.datasourceID = ?
                       AND ? <= sh.age AND sh.age <= ?;
                   """,
                datasourceID,
                lowerBound,
                upperBound
        );
    }

    public void verify_shooterByAgeGroup(final HashMap<String,Object> summaryStats, final String datasourceID) throws SQLException {
        //Age Brackets (A standard established after the first few reports)
        LinkedHashMap<String, Range> ageBrackets = new LinkedHashMap<>();
        ageBrackets.put("<=18",  new Range(0,  18));
        ageBrackets.put("19-24", new Range(19, 24));
        ageBrackets.put("25-34", new Range(25, 34));
        ageBrackets.put("35-44", new Range(35, 44));
        ageBrackets.put("45-54", new Range(45, 54));
        ageBrackets.put("55-64", new Range(55, 64));
        ageBrackets.put("65+",   new Range(65, 999));

        //Execute
        verify_shooterByAgeGroup(summaryStats, datasourceID, ageBrackets);
    }

    public void verify_shooterByAgeGroup(final HashMap<String,Object> summaryStats, final String datasourceID, final LinkedHashMap<String, Range> ageBrackets) throws SQLException {
        System.out.println("\n" +
                "------------------------------\n" +
                "Verifying Shooter By Age Group\n" +
                "------------------------------\n"
        );

        //Extract Target Summary Stat Root
        final Map<String, Object> shooterByAgeGroup = (Map<String, Object>) summaryStats.get("SHOOTER_BY_AGE_GROUP");

        //Init Output Buffer
        StringBuilder log = new StringBuilder();

        //Verification Status
        boolean allSuccess = true;

        for(Map.Entry<String, Range> entry : ageBrackets.entrySet()) {
            final String ageBracket = entry.getKey();
            final Range range = entry.getValue();
            allSuccess &= verify(
                    log,
                    ageBracket,
                    ((Integer) shooterByAgeGroup.get(ageBracket)).toString(),
                    getShootersInAgeRange(datasourceID, range.lowerBound, range.upperBound)
            );
            log.append("\n");
        }

        //Log
        final boolean shouldLog = !allSuccess || (allSuccess && logSuccesses);
        if (shouldLog) {
            System.out.println(log);
        }
    }

    public void verify_incidentResolutions(final HashMap<String,Object> summaryStats, final String datasourceID) throws SQLException {
        System.out.println("\n" +
                "------------------------------\n" +
                "Verifying Incident Resolutions\n" +
                "------------------------------\n"
        );

        //Extract Target Summary Stat Root
        final Map<String, Object> incidentResolutions = (Map<String, Object>) summaryStats.get("INCIDENT_RESOLUTIONS");

        //Suicide
        if (incidentResolutions.containsKey("Suicide")) {
            verifyAndLog(
                    "Suicide",
                    ((Integer) incidentResolutions.get("Suicide")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.shooter sh
                                  JOIN fbi_active_shooters.incident inc
                                    ON sh.incidentId = inc.id   
                                 WHERE inc.datasourceID = ?
                                   AND sh.fate LIKE '%suicide%';
                               """,
                            datasourceID
                    )
            );
        }

        //Killed
        if (incidentResolutions.containsKey("Killed")) {
            verifyAndLog(
                    "Killed",
                    ((Integer) incidentResolutions.get("Killed")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.shooter sh
                                  JOIN fbi_active_shooters.incident inc
                                    ON sh.incidentId = inc.id   
                                 WHERE inc.datasourceID = ?
                                   AND sh.fate LIKE '%killed%';
                               """,
                            datasourceID
                    )
            );
        }

        //Apprehended
        if (incidentResolutions.containsKey("Apprehended")) {
            verifyAndLog(
                    "Apprehended",
                    ((Integer) incidentResolutions.get("Apprehended")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.shooter sh
                                  JOIN fbi_active_shooters.incident inc
                                    ON sh.incidentId = inc.id
                                 WHERE inc.datasourceID = ?
                                   AND (
                                          sh.fate LIKE '%arrested%'
                                       OR sh.fate LIKE '%turned self in%'
                                       OR sh.fate LIKE '%surrendered later%'
                                   );
                               """,
                            datasourceID
                    )
            );
        }

        //At Large
        if (incidentResolutions.containsKey("At Large")) {
            verifyAndLog(
                    "At Large",
                    ((Integer) incidentResolutions.get("At Large")).toString(),
                    queryForValue(
                            """
                                SELECT COUNT(*) AS cnt
                                  FROM fbi_active_shooters.shooter sh
                                  JOIN fbi_active_shooters.incident inc
                                    ON sh.incidentId = inc.id   
                                 WHERE inc.datasourceID = ?
                                   AND sh.fate LIKE '%never caught%';
                               """,
                            datasourceID
                    )
            );
        }
    }

    public void verify_locationType(final HashMap<String,Object> summaryStats, final String datasourceID) throws SQLException {
        System.out.println("\n" +
                "-----------------------\n" +
                "Verifying Location Type\n" +
                "-----------------------\n"
        );

        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                    WITH locationTypes AS (
                        SELECT distinct locationType
                          FROM fbi_active_shooters.incident inc
                    ),
                    counts AS (
                        SELECT locationType,
                               COUNT(*) AS cnt
                          FROM fbi_active_shooters.incident inc
                         WHERE inc.datasourceID = ?
                         GROUP BY locationType
                    )
                    SELECT locationTypes.locationType,
                           IFNULL(counts.cnt, 0) AS totalIncidents
                      FROM locationTypes
                      LEFT JOIN counts
                        ON locationTypes.locationType = counts.locationType;
                    """
        );
        stmt.setString(1, datasourceID);

        //Extract Target Summary Stat Root
        final Map<String, Object> incidentsByLocationType = (Map<String, Object>) summaryStats.get("INCIDENTS_BY_LOCATION_TYPE");

        //Execute Query
        ResultSet rs = stmt.executeQuery();
        boolean anyFound = false;
        while (rs.next()) {
            anyFound = true;

            //Init Output Buffer
            StringBuilder log = new StringBuilder();

            //Verification Status
            boolean allSuccess = true;

            //Data
            final String locationType = rs.getString("locationType");
            final String totalIncidents = rs.getString("totalIncidents");

            //Incidents
            allSuccess &= verify(
                    log,
                    locationType,
                    ((Integer) incidentsByLocationType.get(locationType)).toString(),
                    totalIncidents
            );

            //Log
            final boolean shouldLog = !allSuccess || (allSuccess && logSuccesses);
            if (shouldLog) {
                System.out.println(log);
            }
        }

        //Empty Check
        if (!anyFound) {
            throw new SQLException("Record Not Found!");
        }
    }

    public void verify_Month(final HashMap<String,Object> summaryStats, final String datasourceID) throws SQLException {
        System.out.println("\n" +
                "---------------\n" +
                "Verifying Month\n" +
                "---------------\n"
        );

        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                    WITH months AS (
                        SELECT distinct MONTHNAME(inc.date) as `month`,
                                MONTH(inc.date) as monthIndex
                          FROM fbi_active_shooters.incident inc
                    ),
                    counts AS (
                        SELECT MONTHNAME(inc.date) as `month`,
                               COUNT(*) AS cnt
                          FROM fbi_active_shooters.incident inc
                         WHERE inc.datasourceID = ?
                         GROUP BY `month`
                    )
                    SELECT months.`month`,
                           IFNULL(counts.cnt, 0) AS totalIncidents
                      FROM months
                      LEFT JOIN counts
                        ON months.`month` = counts.`month`
                     ORDER BY monthIndex;
                    """
        );
        stmt.setString(1, datasourceID);

        //Extract Target Summary Stat Root
        final Map<String, Object> incidentsByLocationType = (Map<String, Object>) summaryStats.get("INCIDENTS_BY_MONTH");

        //Execute Query
        ResultSet rs = stmt.executeQuery();
        boolean anyFound = false;
        while (rs.next()) {
            anyFound = true;

            //Init Output Buffer
            StringBuilder log = new StringBuilder();

            //Verification Status
            boolean allSuccess = true;

            //Data
            final String locationType = rs.getString("month");
            final String totalIncidents = rs.getString("totalIncidents");

            //Incidents
            allSuccess &= verify(
                    log,
                    locationType,
                    ((Integer) incidentsByLocationType.get(locationType)).toString(),
                    totalIncidents
            );

            //Log
            final boolean shouldLog = !allSuccess || (allSuccess && logSuccesses);
            if (shouldLog) {
                System.out.println(log);
            }
        }

        //Empty Check
        if (!anyFound) {
            throw new SQLException("Record Not Found!");
        }
    }

    public void verify_DayOfWeek(final HashMap<String,Object> summaryStats, final String datasourceID) throws SQLException {
        System.out.println("\n" +
                "---------------------\n" +
                "Verifying Day Of Week\n" +
                "---------------------\n"
        );

        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                    WITH days AS (
                        SELECT distinct DAYNAME(inc.date) as `day`,
                                DAYOFWEEK(inc.date) as dayIndex
                          FROM fbi_active_shooters.incident inc
                    ),
                    counts AS (
                        SELECT DAYNAME(inc.date) as `day`,
                               COUNT(*) AS cnt
                          FROM fbi_active_shooters.incident inc
                         WHERE inc.datasourceID = ?
                         GROUP BY `day`
                    )
                    SELECT days.`day`,
                           IFNULL(counts.cnt, 0) AS totalIncidents
                      FROM days
                      LEFT JOIN counts
                        ON days.`day` = counts.`day`
                     ORDER BY dayIndex;
                    """
        );
        stmt.setString(1, datasourceID);

        //Extract Target Summary Stat Root
        final Map<String, Object> incidentsByLocationType = (Map<String, Object>) summaryStats.get("INCIDENTS_BY_DAY_OF_WEEK");

        //Execute Query
        ResultSet rs = stmt.executeQuery();
        boolean anyFound = false;
        while (rs.next()) {
            anyFound = true;

            //Init Output Buffer
            StringBuilder log = new StringBuilder();

            //Verification Status
            boolean allSuccess = true;

            //Data
            final String locationType = rs.getString("day");
            final String totalIncidents = rs.getString("totalIncidents");

            //Incidents
            allSuccess &= verify(
                    log,
                    locationType,
                    ((Integer) incidentsByLocationType.get(locationType)).toString(),
                    totalIncidents
            );

            //Log
            final boolean shouldLog = !allSuccess || (allSuccess && logSuccesses);
            if (shouldLog) {
                System.out.println(log);
            }
        }

        //Empty Check
        if (!anyFound) {
            throw new SQLException("Record Not Found!");
        }
    }

    public void verify_2000_2018_overallStatistics(final HashMap<String,Object> summaryStats) throws SQLException {
        System.out.println("\n" +
                "-----------------------\n" +
                "Verifying Overall Stats\n" +
                "-----------------------\n"
        );

        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                    SELECT COUNT(*) AS totalIncidents,
                           SUM(totalCasualties) AS totalCasualties,
                           SUM(deaths) AS totalDeaths,
                           SUM(wounded) AS totalWounded
                      FROM fbi_active_shooters.incident inc
                     WHERE inc.datasourceID = '2000-2018';
                    """
        );

        //Execute Query
        ResultSet rs = stmt.executeQuery();
        if (rs.next()) {
            //Extract Target Summary Stats
            final Map<String, Object> overallStats = (Map<String, Object>) summaryStats.get("OVERALL_STATISTICS");
            final String totalIncidents = ((Integer) overallStats.get("TOTAL_INCIDENTS")).toString();
            final String totalCasualties = ((Integer) overallStats.get("TOTAL_CASUALTIES")).toString();
            final String totalDeaths = ((Integer) overallStats.get("TOTAL_DEATHS")).toString();
            final String totalWounded = ((Integer) overallStats.get("TOTAL_WOUNDED")).toString();

            //Init Output Buffer
            StringBuilder log = new StringBuilder();

            //Verification Status
            boolean allSuccess = true;

            //Incidents
            allSuccess &= verify(
                    log,
                    "TOTAL_INCIDENTS",
                    totalIncidents,
                    rs.getString("totalIncidents")
            );
            log.append("\n");

            //Casualties
            allSuccess &= verify(
                    log,
                    "TOTAL_CASUALTIES",
                    totalCasualties,
                    rs.getString("totalCasualties")
            );
            log.append("\n");

            //Deaths
            allSuccess &= verify(
                    log,
                    "TOTAL_DEATHS",
                    totalDeaths,
                    rs.getString("totalDeaths")
            );
            log.append("\n");

            //Wounded
            allSuccess &= verify(
                    log,
                    "TOTAL_WOUNDED",
                    totalWounded,
                    rs.getString("totalWounded")
            );
            log.append("\n");

            //Log
            final boolean shouldLog = !allSuccess || (allSuccess && logSuccesses);
            if (shouldLog) {
                System.out.println(log);
            }
        } else {
            throw new SQLException("Record Not Found!");
        }
    }

    public void verify_2000_2018_yearlyData(final HashMap<String,Object> summaryStats) throws SQLException {
        System.out.println("\n" +
                "-----------------------------------------\n" +
                "Verifying Incidents & Casualties Per Year\n" +
                "-----------------------------------------\n"
        );

        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                    WITH incidents AS (
                        SELECT `year`,
                               COUNT(*) AS totalIncidents
                          FROM fbi_active_shooters.incident inc
                         WHERE inc.datasourceID = '2000-2018'
                         GROUP BY `year`
                    ),
                    casualties AS (
                        SELECT `year`,
                               SUM(totalCasualties) AS totalCasualties
                          FROM fbi_active_shooters.incident inc
                         WHERE inc.datasourceID = '2000-2018'
                         GROUP BY `year`
                    ),
                    casualtyBreakdown AS (
                        SELECT `year`,
                               SUM(deaths) AS totalDeaths,
                               SUM(wounded) AS totalWounded
                          FROM fbi_active_shooters.incident inc
                         WHERE inc.datasourceID = '2000-2018'
                         GROUP BY `year`
                    )
                    SELECT incidents.`year`,
                           incidents.totalIncidents,
                           casualties.totalCasualties,
                           casualtyBreakdown.totalDeaths,
                           casualtyBreakdown.totalWounded
                      FROM incidents
                      JOIN casualties
                        ON incidents.`year` = casualties.`year`
                      JOIN casualtyBreakdown
                        ON incidents.`year` = casualtyBreakdown.`year`
                     ORDER BY incidents.`year`;
                    """
        );

        //Extract Target Summary Stat Roots
        final Map<String, Object> incidentsPerYear = (Map<String, Object>) summaryStats.get("INCIDENTS_PER_YEAR");
        final Map<String, Object> casualtiesPerYear = (Map<String, Object>) summaryStats.get("CASUALTIES_PER_YEAR");
        final Map<String, Object> casualtyBreakdownPerYear = (Map<String, Object>) summaryStats.get("CASUALTY_BREAKDOWN");

        //Execute Query
        ResultSet rs = stmt.executeQuery();
        boolean anyFound = false;
        while (rs.next()) {
            anyFound = true;

            //Init Output Buffer
            StringBuilder log = new StringBuilder();

            //Verification Status
            boolean allSuccess = true;

            //Data
            final String year = rs.getString("year");
            final String totalIncidents = rs.getString("totalIncidents");
            final String totalCasualties = rs.getString("totalCasualties");
            final String totalDeaths = rs.getString("totalDeaths");
            final String totalWounded = rs.getString("totalWounded");

            //Year
            log.append("Comparing [" + year + "] ...\t");

            //Incidents
            allSuccess &= verify(
                    log,
                    "Incidents",
                    ((Integer) incidentsPerYear.get(year)).toString(),
                    totalIncidents
            );

            //Casualties
            allSuccess &= verify(
                    log,
                    "Casualties",
                    ((Integer) casualtiesPerYear.get(year)).toString(),
                    totalCasualties
            );

            //Get casualty breakdown for current year
            final Map<String, Object> curYearCasualtyBreakdown = (Map<String, Object>) casualtyBreakdownPerYear.get(year);

            //Deaths
            allSuccess &= verify(
                    log,
                    "Deaths",
                    ((Integer) curYearCasualtyBreakdown.get("KILLED")).toString(),
                    totalDeaths
            );

            //Wounded
            allSuccess &= verify(
                    log,
                    "Wounded",
                    ((Integer) curYearCasualtyBreakdown.get("WOUNDED")).toString(),
                    totalWounded
            );

            //Log
            final boolean shouldLog = !allSuccess || (allSuccess && logSuccesses);
            if (shouldLog) {
                System.out.println(log);
            }
        }

        //Empty Check
        if (!anyFound) {
            throw new SQLException("Record Not Found!");
        }
    }

    public void verify_2000_2019_incidentsByState(final HashMap<String,Object> summaryStats) throws SQLException {
        System.out.println("\n" +
                "----------------------------\n" +
                "Verifying Incidents By State\n" +
                "----------------------------\n"
        );

        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                    WITH incidentCounts AS (
                            SELECT incState.stateID AS stateID,
                                   COUNT(*) AS totalIncidents
                              FROM fbi_active_shooters.incidentState incState
                              JOIN fbi_active_shooters.incident inc
                                ON incState.incidentId = inc.id
                             WHERE `year` <= 2019
                          GROUP BY incState.stateID
                    )
                    SELECT stateLU.name AS stateName,
                           IFNULL(incidentCounts.totalIncidents, 0) AS totalIncidents
                      FROM fbi_active_shooters.stateLookup stateLU
                      LEFT JOIN incidentCounts
                        ON stateLU.id = incidentCounts.stateId
                     ORDER BY totalIncidents DESC, stateName ASC;
                    """
        );

        //Extract Target Summary Stat Root
        final Map<String, Object> incidentsByState = (Map<String, Object>) summaryStats.get("INCIDENTS_BY_STATE");

        //Execute Query
        ResultSet rs = stmt.executeQuery();
        boolean anyFound = false;
        while (rs.next()) {
            anyFound = true;

            //Init Output Buffer
            StringBuilder log = new StringBuilder();

            //Verification Status
            boolean allSuccess = true;

            //Data
            final String state = rs.getString("stateName");
            final String totalIncidents = rs.getString("totalIncidents");

            //Incidents
            allSuccess &= verify(
                    log,
                    state,
                    (Optional.ofNullable((Integer) incidentsByState.get(state)).orElse(0)).toString(),
                    totalIncidents
            );

            //Log
            final boolean shouldLog = !allSuccess || (allSuccess && logSuccesses);
            if (shouldLog) {
                System.out.println(log);
            }
        }

        //Empty Check
        if (!anyFound) {
            throw new SQLException("Record Not Found!");
        }
    }

    public void verify_2000_2019_oldNewIncidents(final HashMap<String,Object> summaryStats) throws SQLException {
        System.out.println("\n" +
                "-----------------------------------------\n" +
                "Verifying Incidents & Casualties Per Year\n" +
                "-----------------------------------------\n"
        );

        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                    WITH oldIncidents AS (
                        SELECT `year`,
                               COUNT(*) AS totalIncidents
                          FROM fbi_active_shooters.incident inc
                         WHERE inc.datasourceID = '2000-2018'
                            OR inc.datasourceID = '2019'
                         GROUP BY `year`
                    ),
                    newIncidents AS (
                        SELECT `year`,
                               COUNT(*) AS totalIncidents
                          FROM fbi_active_shooters.incident inc
                         WHERE inc.datasourceID = '2000-2019'
                         GROUP BY `year`
                    ),
                    allIncidents AS (
                        SELECT `year`,
                               COUNT(*) AS totalIncidents
                          FROM fbi_active_shooters.incident inc
                         WHERE `year` <= 2019
                         GROUP BY `year`
                    ),
                    casualties AS (
                        SELECT `year`,
                               SUM(totalCasualties) AS totalCasualties
                          FROM fbi_active_shooters.incident inc
                         WHERE `year` <= 2019
                         GROUP BY `year`
                    ),
                    casualtyBreakdown AS (
                        SELECT `year`,
                               SUM(deaths) AS totalDeaths,
                               SUM(wounded) AS totalWounded
                          FROM fbi_active_shooters.incident inc
                         WHERE `year` <= 2019
                         GROUP BY `year`
                    )
                    SELECT oldIncidents.`year`,
                           oldIncidents.totalIncidents AS originalIncidents,
                           newIncidents.totalIncidents AS additionalIncidents,
                           allIncidents.totalIncidents AS totalIncidents,
                           casualties.totalCasualties,
                           casualtyBreakdown.totalDeaths,
                           casualtyBreakdown.totalWounded
                      FROM oldIncidents
                      JOIN newIncidents
                        ON oldIncidents.`year` = newIncidents.`year`
                      JOIN allIncidents
                        ON oldIncidents.`year` = allIncidents.`year`
                      JOIN casualties
                        ON oldIncidents.`year` = casualties.`year`
                      JOIN casualtyBreakdown
                        ON oldIncidents.`year` = casualtyBreakdown.`year`
                     ORDER BY oldIncidents.`year`;
                    """
        );

        //Extract Target Summary Stat Roots
        final Map<String, Object> incidentsPerYear = (Map<String, Object>) summaryStats.get("TOTAL_INCIDENTS_BY_YEAR");
        final Map<String, Object> casualtiesPerYear = (Map<String, Object>) summaryStats.get("CASUALTIES_BY_YEAR");

        //Execute Query
        ResultSet rs = stmt.executeQuery();
        boolean anyFound = false;
        while (rs.next()) {
            anyFound = true;

            //Init Output Buffer
            StringBuilder log = new StringBuilder();

            //Verification Status
            boolean allSuccess = true;

            //Data
            final String year = rs.getString("year");
            final String originalIncidents = rs.getString("originalIncidents");
            final String additionalIncidents = rs.getString("additionalIncidents");
            final String totalIncidents = rs.getString("totalIncidents");
            final String totalCasualties = rs.getString("totalCasualties");
            final String totalDeaths = rs.getString("totalDeaths");
            final String totalWounded = rs.getString("totalWounded");

            //Year
            log.append("Comparing [" + year + "] ...\t");

            //Get incident breakdown for current year
            final Map<String, Object> curYearIncidents = (Map<String, Object>) incidentsPerYear.get(year);

            //Original Incidents
            allSuccess &= verify(
                    log,
                    "Original Incidents",
                    ((Integer) curYearIncidents.get("ORIGINAL_INCIDENTS")).toString(),
                    originalIncidents
            );

            //Additional Incidents
            allSuccess &= verify(
                    log,
                    "Additional Incidents",
                    ((Integer) curYearIncidents.get("ADDITIONAL")).toString(),
                    additionalIncidents
            );

            //Total Incidents
            allSuccess &= verify(
                    log,
                    "Total Incidents",
                    ((Integer) curYearIncidents.get("TOTAL")).toString(),
                    totalIncidents
            );


            //Get casualty breakdown for current year
            final Map<String, Object> curYearCasualties = (Map<String, Object>) casualtiesPerYear.get(year);
            final Integer killed = (Integer) curYearCasualties.get("KILLED");
            final Integer wounded = (Integer) curYearCasualties.get("WOUNDED");

            //Casualties
            allSuccess &= verify(
                    log,
                    "Casualties",
                    ((Integer)(killed + wounded)).toString(),
                    totalCasualties,
                    "\t"
            );

            //Deaths
            allSuccess &= verify(
                    log,
                    "Deaths",
                    killed.toString(),
                    totalDeaths
            );

            //Wounded
            allSuccess &= verify(
                    log,
                    "Wounded",
                    wounded.toString(),
                    totalWounded
            );

            //Log
            final boolean shouldLog = !allSuccess || (allSuccess && logSuccesses);
            if (shouldLog) {
                System.out.println(log);
            }
        }

        //Empty Check
        if (!anyFound) {
            throw new SQLException("Record Not Found!");
        }
    }

    public void verify_2000_2019_shooterOutcomesByYear(final HashMap<String,Object> summaryStats) throws SQLException {
        System.out.println("\n" +
                "----------------------------------\n" +
                "Verifying Shooter Outcomes By Year\n" +
                "----------------------------------\n"
        );

        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                    WITH arrested AS (
                        SELECT `year`,
                               COUNT(*) AS cnt
                          FROM fbi_active_shooters.incident inc
                          JOIN fbi_active_shooters.shooter sh
                            ON sh.incidentId = inc.id
                         WHERE `year` <= 2019
                           AND (
                                  sh.fate LIKE '%arrested%'
                               OR sh.fate LIKE '%turned self in%'
                           )
                         GROUP BY `year`
                    ),
                    killed AS (
                        SELECT `year`,
                               COUNT(*) AS cnt
                          FROM fbi_active_shooters.incident inc
                          JOIN fbi_active_shooters.shooter sh
                            ON sh.incidentId = inc.id
                         WHERE `year` <= 2019
                           AND sh.fate LIKE '%killed%'
                         GROUP BY `year`
                    ),
                    suicides AS (
                        SELECT `year`,
                               COUNT(*) AS cnt
                          FROM fbi_active_shooters.incident inc
                          JOIN fbi_active_shooters.shooter sh
                            ON sh.incidentId = inc.id
                         WHERE `year` <= 2019
                           AND sh.fate LIKE '%suicide%'
                         GROUP BY `year`
                    ),
                    atLarge AS (
                        SELECT `year`,
                               COUNT(*) AS cnt
                          FROM fbi_active_shooters.incident inc
                          JOIN fbi_active_shooters.shooter sh
                            ON sh.incidentId = inc.id
                         WHERE `year` <= 2019
                           AND sh.fate LIKE '%never caught%'
                         GROUP BY `year`
                    )
                    SELECT distinct inc.year,
                           IFNULL(arrested.cnt, 0) AS numArrested,
                           IFNULL(killed.cnt, 0) AS numKilled,
                           IFNULL(suicides.cnt, 0) AS numSuicides,
                           IFNULL(atLarge.cnt, 0) AS numAtLarge
                      FROM fbi_active_shooters.incident inc
                      LEFT JOIN arrested
                        ON inc.year = arrested.year
                      LEFT JOIN killed
                        ON inc.year = killed.year
                      LEFT JOIN suicides
                        ON inc.year = suicides.year
                      LEFT JOIN atLarge
                        ON inc.year = atLarge.year
                     WHERE inc.year <= 2019
                     ORDER BY inc.year;
                    """
        );

        //Extract Target Summary Stat Roots
        final Map<String, Object> shooterOutcomesByYear = (Map<String, Object>) summaryStats.get("SHOOTER_OUTCOMES_BY_YEAR");

        //Execute Query
        ResultSet rs = stmt.executeQuery();
        boolean anyFound = false;
        while (rs.next()) {
            anyFound = true;

            //Init Output Buffer
            StringBuilder log = new StringBuilder();

            //Verification Status
            boolean allSuccess = true;

            //Data
            final String year = rs.getString("year");
            final String numSuicides = rs.getString("numSuicides");
            final String numArrested = rs.getString("numArrested");
            final String numKilled = rs.getString("numKilled");
            final String numAtLarge = rs.getString("numAtLarge");

            //Year
            log.append("Comparing [" + year + "] ...\t");

            //Get incident breakdown for current year
            final Map<String, Object> curYearShooterOutcomes = (Map<String, Object>) shooterOutcomesByYear.get(year);

            //Suicides
            allSuccess &= verify(
                    log,
                    "Suicides",
                    ((Integer) curYearShooterOutcomes.get("SUICIDES")).toString(),
                    numSuicides,
                    "\t"
            );

            //Arrested
            allSuccess &= verify(
                    log,
                    "Arrested",
                    ((Integer) curYearShooterOutcomes.get("APPREHENDED")).toString(),
                    numArrested,
                    "\t"
            );

            //Killed
            allSuccess &= verify(
                    log,
                    "Killed",
                    ((Integer) curYearShooterOutcomes.get("KILLED")).toString(),
                    numKilled
            );

            //At Large
            allSuccess &= verify(
                    log,
                    "At Large",
                    ((Integer) curYearShooterOutcomes.get("AT_LARGE")).toString(),
                    numAtLarge
            );

            //Log
            final boolean shouldLog = !allSuccess || (allSuccess && logSuccesses);
            if (shouldLog) {
                System.out.println(log);
            }
        }

        //Empty Check
        if (!anyFound) {
            throw new SQLException("Record Not Found!");
        }
    }

    public void verify_2000_2019_locationType(final HashMap<String,Object> summaryStats) throws SQLException {
        System.out.println("\n" +
                "-----------------------\n" +
                "Verifying Location Type\n" +
                "-----------------------\n"
        );

        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                    WITH locationTypes AS (
                        SELECT distinct locationType
                          FROM fbi_active_shooters.incident inc
                    ),
                    counts AS (
                        SELECT locationType,
                               COUNT(*) AS cnt
                          FROM fbi_active_shooters.incident inc
                         WHERE `year` <= 2019
                         GROUP BY locationType
                    )
                    SELECT locationTypes.locationType,
                           IFNULL(counts.cnt, 0) AS totalIncidents
                      FROM locationTypes
                      LEFT JOIN counts
                        ON locationTypes.locationType = counts.locationType;
                    """
        );

        //Extract Target Summary Stat Root
        final Map<String, Object> incLocation = (Map<String, Object>) summaryStats.get("LOCATION_TYPES");

        //Execute Query
        ResultSet rs = stmt.executeQuery();
        boolean anyFound = false;
        while (rs.next()) {
            anyFound = true;

            //Init Output Buffer
            StringBuilder log = new StringBuilder();

            //Verification Status
            boolean allSuccess = true;

            //Data
            final String locationType = rs.getString("locationType");
            final String totalIncidents = rs.getString("totalIncidents");

            //Value
            final int numIncidents;
            switch(locationType) {
                case "Commerce":
                    numIncidents = ((Integer) incLocation.get("BUSINESS_OPEN_TO_PEDESTRIANS")) +
                                    ((Integer) incLocation.get("BUSINESS_CLOSED_TO_PEDESTRIANS")) +
                                    ((Integer) incLocation.get("MALLS"));
                    break;
                case "Education":
                    numIncidents = ((Integer) incLocation.get("HIGHER_ED")) +
                                    ((Integer) incLocation.get("K-12"));
                    break;
                case "Government":
                    numIncidents = ((Integer) incLocation.get("GOVERNMENT")) +
                                    ((Integer) incLocation.get("MILITARY"));
                    break;
                case "Health Care":
                    numIncidents = (Integer) incLocation.get("HEALTH_CARE");
                    break;
                case "House of Worship":
                    numIncidents = (Integer) incLocation.get("HOUSE_OF_WORSHIP");
                    break;
                case "Open Space":
                    numIncidents = (Integer) incLocation.get("OPEN_SPACE");
                    break;
                case "Residence":
                    numIncidents = (Integer) incLocation.get("RESIDENCE");
                    break;
                case "Other":
                    numIncidents = (Integer) incLocation.get("OTHER");
                    break;
                default:
                    throw new IllegalArgumentException("Unrecognized Location Type (" + locationType + ")!");
            }

            //Incidents
            allSuccess &= verify(
                    log,
                    locationType,
                    ((Integer) numIncidents).toString(),
                    totalIncidents
            );

            //Log
            final boolean shouldLog = !allSuccess || (allSuccess && logSuccesses);
            if (shouldLog) {
                System.out.println(log);
            }
        }

        //Empty Check
        if (!anyFound) {
            throw new SQLException("Record Not Found!");
        }
    }

    public void verify_AllLocationTypesAgainstRawData() throws SQLException {
        System.out.println("\n" +
                "---------------------------------------------------------------------------\n" +
                "Verifying All Location Types (For All Years) Against Raw Event Descriptions\n" +
                "---------------------------------------------------------------------------\n"
        );

        //Init Output Buffer
        StringBuilder log = new StringBuilder();

        //Verification Status
        boolean allSuccess = true;

        //RawDescriptions - Match Count
        log.append("531 RawIncidentDescription records whose location type matches its RawIncidentTitle.\n");
        allSuccess &= verify(
                log,
                "Count (\"531\")",
                "531",
                queryForValue(
                        """
                            SELECT COUNT(*)
                              FROM rawincidentdescriptions rawDesc
                             WHERE rawDesc.RawIncidentTitle LIKE CONCAT('%(',rawDesc.LocationType,')%');
                           """
                )
        );
        log.append("\n\n");

        //RawDescriptions - Mismatch Count
        log.append("Only 1 RawIncidentDescription record whose location type does not match its RawIncidentTitle.\n");
        allSuccess &= verify(
                log,
                "Count (\"1\")",
                "1",
                queryForValue(
                        """
                            SELECT COUNT(*)
                              FROM rawincidentdescriptions rawDesc
                             WHERE rawDesc.RawIncidentTitle NOT LIKE CONCAT('%(',rawDesc.LocationType,')%');
                           """
                )
        );
        log.append("\n\n");

        {//Incident 323
            log.append("It is incident 323, where the FBI labeled it as \"Residential\" instead of \"Residence\", and I changed it to match the rest of the data.\n");

            final Map<String, String> incident323 = queryForRow(
                    """
                    SELECT rawDesc.IncidentId,
                    	   rawDesc.RawIncidentTitle,
                           rawDesc.LocationType
                      FROM rawincidentdescriptions rawDesc
                     WHERE rawDesc.RawIncidentTitle NOT LIKE CONCAT('%(',rawDesc.LocationType,')%');
                   """
            );

            //Incident ID
            allSuccess &= verify(
                    log,
                    "Incident ID (\"323\")",
                    "323",
                    incident323.get("IncidentId")
            );
            log.append("\n");

            //RawIncidentTitle
            allSuccess &= verify(
                    log,
                    "Raw Incident Title (\"Omega Psi Phi Fraternity House (Residential)\")",
                    "Omega Psi Phi Fraternity House (Residential)",
                    incident323.get("RawIncidentTitle")
            );
            log.append("\n");

            //LocationType
            allSuccess &= verify(
                    log,
                    "Location Type (\"Residence\")",
                    "Residence",
                    incident323.get("LocationType")
            );
            log.append("\n\n");
        }

        //Incident Table - Mismatch Count
        log.append("Zero Incident records whose LocationType does not match the RawIncidentDescription's LocationType\n");
        allSuccess &= verify(
                log,
                "Count (\"0\")",
                "0",
                queryForValue(
                        """
                            SELECT COUNT(*)
                              FROM incident inc
                              JOIN rawincidentdescriptions rawDesc
                                ON inc.id = rawDesc.IncidentId
                             WHERE rawDesc.LocationType <> inc.LocationType;
                           """
                )
        );
        log.append("\n");


        //Log
        final boolean shouldLog = !allSuccess || (allSuccess && logSuccesses);
        if (shouldLog) {
            System.out.println(log);
        }
    }

    public void run() throws SQLException, IOException {
        if (!getConnection()) {
            System.err.println("Error obtaining connection! Terminating...");
            return;
        }

        {//2000-2018
            System.out.println("\n" +
                    "=======================================\n" +
                    "=======================================\n" +
                    "=======================================\n" +
                    "==========                   ==========\n" +
                    "==========     2000-2018     ==========\n" +
                    "==========                   ==========\n" +
                    "=======================================\n" +
                    "=======================================\n" +
                    "=======================================\n"
            );
            HashMap<String, Object> summaryStats = parseJSON(Files.readString(Paths.get(SUMMARY_DATA_PARENT_DIR + "2000-2018.json")));
            verify_2000_2018_overallStatistics(summaryStats);
            verify_2000_2018_yearlyData(summaryStats);
            verify_locationType(summaryStats, "2000-2018");
        }

        {//2018
            System.out.println("\n" +
                    "==================================================\n" +
                    "==================================================\n" +
                    "==================================================\n" +
                    "==========                              ==========\n" +
                    "==========             2018             ==========\n" +
                    "==========     [2019 Previous Year]     ==========\n" +
                    "==========                              ==========\n" +
                    "==================================================\n" +
                    "==================================================\n" +
                    "==================================================\n"
            );
            HashMap<String, Object> summaryStats = parseJSON(Files.readString(Paths.get(SUMMARY_DATA_PARENT_DIR + "2018___2019-PreviousYear.json")));
            verify_overallStatistics(
                    summaryStats,
                    "2000-2018",
                    new Range(2018)
            );
        }

        {//2019
            System.out.println("\n" +
                    "==================================\n" +
                    "==================================\n" +
                    "==================================\n" +
                    "==========              ==========\n" +
                    "==========     2019     ==========\n" +
                    "==========              ==========\n" +
                    "==================================\n" +
                    "==================================\n" +
                    "==================================\n"
            );

            //Age Brackets
            LinkedHashMap<String, Range> ageBrackets = new LinkedHashMap<>();
            ageBrackets.put("<20",   new Range(0,  19));
            ageBrackets.put("20-29", new Range(20, 29));
            ageBrackets.put("30-39", new Range(30, 39));
            ageBrackets.put("40-49", new Range(40, 49));
            ageBrackets.put("50-59", new Range(50, 59));
            ageBrackets.put("60-69", new Range(60, 69));

            //Execute
            HashMap<String, Object> summaryStats = parseJSON(Files.readString(Paths.get(SUMMARY_DATA_PARENT_DIR + "2019.json")));
            verify_overallStatistics(summaryStats, "2019", new Range(2019));
            verify_incidentsByState(summaryStats, "2019");
            verify_shooterByAgeGroup(summaryStats, "2019", ageBrackets);
            verify_incidentResolutions(summaryStats, "2019");
            verify_locationType(summaryStats, "2019");
        }

        {//2000-2019 [20-Year Review]
            System.out.println("\n" +
                    "==============================================\n" +
                    "==============================================\n" +
                    "==============================================\n" +
                    "==========                          ==========\n" +
                    "==========         2000-2019        ==========\n" +
                    "==========     [20-Year Review]     ==========\n" +
                    "==========                          ==========\n" +
                    "==============================================\n" +
                    "==============================================\n" +
                    "==============================================\n"
            );
            HashMap<String, Object> summaryStats = parseJSON(Files.readString(Paths.get(SUMMARY_DATA_PARENT_DIR + "2000-2019.json")));

            verify_overallStatistics(
                    summaryStats,
                    new String[] {"2000-2018", "2019", "2000-2019"},
                    new Range(2000, 2019)
            );

            verify_2000_2019_incidentsByState(summaryStats);
            verify_2000_2019_oldNewIncidents(summaryStats);
            verify_2000_2019_shooterOutcomesByYear(summaryStats);
            verify_2000_2019_locationType(summaryStats);
        }

        {//2020
            System.out.println("\n" +
                    "==================================\n" +
                    "==================================\n" +
                    "==================================\n" +
                    "==========              ==========\n" +
                    "==========     2020     ==========\n" +
                    "==========              ==========\n" +
                    "==================================\n" +
                    "==================================\n" +
                    "==================================\n"
            );
            //Age Brackets
            LinkedHashMap<String, Range> ageBrackets = new LinkedHashMap<>();
            ageBrackets.put("<=18",  new Range(0,  18));
            ageBrackets.put("19-24", new Range(19, 24));
            ageBrackets.put("25-34", new Range(25, 34));
            ageBrackets.put("35-44", new Range(35, 44));
            ageBrackets.put("45-54", new Range(45, 54));
            ageBrackets.put("55-64", new Range(55, 64));
            ageBrackets.put("65-74", new Range(65, 74));
            ageBrackets.put("75+",   new Range(75, 999));

            //Execute
            HashMap<String, Object> summaryStats = parseJSON(Files.readString(Paths.get(SUMMARY_DATA_PARENT_DIR + "2020.json")));
            verify_overallStatistics(summaryStats, "2020", new Range(2020));
            verify_incidentsByState(summaryStats, "2020");
            verify_shooterByAgeGroup(summaryStats, "2020", ageBrackets);
            verify_incidentResolutions(summaryStats, "2020");
            verify_locationType(summaryStats, "2020");
            verify_Month(summaryStats, "2020");
            verify_DayOfWeek(summaryStats, "2020");
        }

        {//2021
            System.out.println("\n" +
                    "==================================\n" +
                    "==================================\n" +
                    "==================================\n" +
                    "==========              ==========\n" +
                    "==========     2021     ==========\n" +
                    "==========              ==========\n" +
                    "==================================\n" +
                    "==================================\n" +
                    "==================================\n"
            );
            HashMap<String, Object> summaryStats = parseJSON(Files.readString(Paths.get(SUMMARY_DATA_PARENT_DIR + "2021.json")));
            verify_overallStatistics(summaryStats, "2021", new Range(2021));
            verify_incidentsByState(summaryStats, "2021");
            verify_shooterByAgeGroup(summaryStats, "2021");
            verify_incidentResolutions(summaryStats, "2021");
            verify_locationType(summaryStats, "2021");
            verify_Month(summaryStats, "2021");
            verify_DayOfWeek(summaryStats, "2021");
        }

        {//2022
            System.out.println("\n" +
                    "==================================\n" +
                    "==================================\n" +
                    "==================================\n" +
                    "==========              ==========\n" +
                    "==========     2022     ==========\n" +
                    "==========              ==========\n" +
                    "==================================\n" +
                    "==================================\n" +
                    "==================================\n"
            );
            HashMap<String, Object> summaryStats = parseJSON(Files.readString(Paths.get(SUMMARY_DATA_PARENT_DIR + "2022.json")));
            verify_overallStatistics(summaryStats, "2022", new Range(2022));
            verify_incidentsByState(summaryStats, "2022");
            verify_shooterByAgeGroup(summaryStats, "2022");
            verify_incidentResolutions(summaryStats, "2022");
            verify_locationType(summaryStats, "2022");
            verify_Month(summaryStats, "2022");
            verify_DayOfWeek(summaryStats, "2022");
        }/**/

        {//2023
            System.out.println("\n" +
                    "==================================\n" +
                    "==================================\n" +
                    "==================================\n" +
                    "==========              ==========\n" +
                    "==========     2023     ==========\n" +
                    "==========              ==========\n" +
                    "==================================\n" +
                    "==================================\n" +
                    "==================================\n"
            );
            HashMap<String, Object> summaryStats = parseJSON(Files.readString(Paths.get(SUMMARY_DATA_PARENT_DIR + "2023.json")));
            verify_overallStatistics(summaryStats, "2023", new Range(2023));
            verify_incidentsByState(summaryStats, "2023");
            verify_shooterByAgeGroup(summaryStats, "2023");
            verify_incidentResolutions(summaryStats, "2023");
            verify_locationType(summaryStats, "2023");
            verify_Month(summaryStats, "2023");
            verify_DayOfWeek(summaryStats, "2023");
        }

        {//Location Type (All Years)
            System.out.println("\n" +
                    "====================================================\n" +
                    "====================================================\n" +
                    "====================================================\n" +
                    "==========                                ==========\n" +
                    "==========         Location Type          ==========\n" +
                    "==========                                ==========\n" +
                    "==========     [  Proof my data is  ]     ==========\n" +
                    "==========     [  correct and FBI   ]     ==========\n" +
                    "==========     [  summary data      ]     ==========\n" +
                    "==========     [  is wrong          ]     ==========\n" +
                    "==========                                ==========\n" +
                    "====================================================\n" +
                    "====================================================\n" +
                    "====================================================\n"
            );
            verify_AllLocationTypesAgainstRawData();
        }
    }

    public static void main(String[] args) throws Exception {
        new SummaryDataVerification().run();
    }
}
