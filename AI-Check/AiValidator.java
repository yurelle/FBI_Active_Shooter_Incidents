import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.sql.*;
import java.util.*;
import java.util.function.Function;

/**
 * Requires the following dependencies:
 *
 * implementation group: 'com.mysql', name: 'mysql-connector-j', version: '8.4.0'
 * implementation group: 'com.fasterxml.jackson.core', name: 'jackson-databind', version: '2.17.1'
 */
public class AiValidator {
    Connection conn;
    boolean logSuccesses = true;

    public AiValidator() throws ClassNotFoundException, InstantiationException, IllegalAccessException {
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

    public static final String SYSTEM_MESSAGE = "" +
            "You are a helpful assistant. You are being used to verify data which was manually extracted from an " +
            "FBI report on active shooters. The report consists of short summaries of police reports, with one " +
            "report for each incident. You will be given one incident at a time, including the name of the " +
            "incident and its event summary. You will then be asked a single question, to retrieve a specific " +
            "data point from the summary; for example: the number of people which were wounded during the event. " +
            "You will answer truthfully and accurately. " +
            "This process is being implemented as a programmatic batch process, and your answers will be read in " +
            "by a simple computer program, so please keep your answers to the following format. Do not wrap your " +
            "answer in a sentence. Instead, simply state the answer directly (For example, Question: \\\"What State " +
            "did this event occur in?\\\" Answer: \\\"North Carolina\\\"; not: \\\"This event occurred in North Carolina.\\\"). " +
            "Do not include quotation marks in your answers. They are used in these examples, simply to help you " +
            "understand your instructions. " +
            "When the answer is a number, please write the number using numerical digits, rather than spelling " +
            "out the number with letters (For example, Question: \\\"How many people where wounded?\\\" Answer: \\\"2\\\"; " +
            "not \\\"two\\\"). " +
            "The casualty counts provided in the FBI report do not include the shooter. When asked for the death or " +
            "wounded counts, provide the number explicitly mentioned in the summary. Do not add the shooter's fate to " +
            "the counts (For example, in an incident where the shooter killed 3 people, and then the shooter died, " +
            "regardless of whether the shooter was killed by police or committed suicide, Question: \\\"How many people " +
            "where killed?\\\" Answer: \\\"3\\\"). " +
            "When the answer is a gender, please use either \\\"MALE\\\", \\\"FEMALE\\\", \\\"NONBINARY\\\", or \\\"UNKNOWN\\\". " +
            "If there are multiple shooters, please provide the answer for every shooter, separated by ' & '; an " +
            "ampersand padded with spaces (For example, for an incident with 3 shooters, 2 male & 1 female, " +
            "Question: \\\"What was the gender of the shooter(s)?\\\" Answer: \\\"MALE & MALE & FEMALE\\\"). " +
            "If there are multiple states, please do the same (For example, an incident which includes both Florida and Georgia," +
            "Question: \\\"What State did this event occur in?\\\" Answer: \\\"Florida & Georgia\\\"). " +
            "If the answer is a yes or no question, please answer simply \\\"YES\\\", \\\"NO\\\", or \\\"UNKNOWN\\\" (For example, " +
            "Question: \\\"Were there multiple shooters?\\\" Answer: \\\"YES\\\"). " +
            "Arrest & Suicide are considered mutually exclusive. If the shooter committed suicide, then they are not " +
            "considered to have been arrested. " +
            "A human has previously read through these reports and entered the data into a database. Your answers " +
            "will be compared to those values, to double-check accuracy, and precisely locate any errors in the human " +
            "data entry. So, please be as accurate & precise as possible.";

    enum DataPoint {
        DEATHS  ("How many people where killed?"),
        WOUNDED ("How many people where wounded?"),
        STATE   ("What State did this event occur in?"),
        TIME    ("At what time of day did this event occur?"),
        GENDER  ("What was the gender of the shooter(s)?"),
        AGE     ("What was the age of the shooter(s)?"),
        MULTIPLE_SHOOTERS ("Were there multiple shooters?"),
        NUM_SHOOTERS ("How many shooters were there?"),
        ARRESTED("Did police arrest the shooter(s)?"),
        NUM_ARRESTED("How many shooters were arrested?"),
        SUICIDE ("Did the shooter(s) commit suicide?"),
        NUM_SUICIDE ("How many shooters committed suicide?"),
        AT_LARGE ("Is the shooter still at large? (i.e. they escaped and were never caught)"),
        NUM_AT_LARGE ("How many shooters are still at large? (i.e. they escaped and were never caught)");/**/

        private String question;

        DataPoint(String question) {
            this.question = question;
        }

        public String getQuestion() {
            return question;
        }
    }

    public void saveAiResponseToDB(AI_Result result) throws SQLException {
        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
               """
               INSERT INTO fbi_active_shooters.aiVerification (
                     IncidentId, Deaths, Wounded, State,
                     Time, Gender, Age,
                     MultipleShooters, NumShooters,
                     Arrested, NumArrested,
                     Suicide, NumSuicide,
                     AtLarge, NumAtLarge,
                     AiModel
               )
               VALUES (
                     ?, ?, ?, ?,
                     ?, ?, ?,
                     ?, ?,
                     ?, ?,
                     ?, ?,
                     ?, ?,
                     ?
               );
                """
        );
        int index = 1;
        stmt.setInt     (index++, result.incidentId);
        stmt.setString  (index++, result.deaths);
        stmt.setString  (index++, result.wounded);
        stmt.setString  (index++, result.state);
        stmt.setString  (index++, result.time);
        stmt.setString  (index++, result.gender);
        stmt.setString  (index++, result.age);
        stmt.setString  (index++, result.multipleShooters);
        stmt.setString  (index++, result.numShooters);
        stmt.setString  (index++, result.arrested);
        stmt.setString  (index++, result.numArrested);
        stmt.setString  (index++, result.suicide);
        stmt.setString  (index++, result.numSuicide);
        stmt.setString  (index++, result.atLarge);
        stmt.setString  (index++, result.numAtLarge);
        stmt.setString  (index++, result.model);

        //Execute
        stmt.executeUpdate();

        //Close Resources
        stmt.close();
    }

    public String generateSqlInsert(AI_Result result) {
        final StringBuilder columns = new StringBuilder();
        final StringBuilder values = new StringBuilder();

        //incidentId
        columns.append("incidentId, ");
        values.append(result.incidentId + ", ");//value is num, don't wrap in quotes

        //deaths
        columns.append("deaths, ");
        values.append("'" + result.deaths + "', ");

        //wounded
        columns.append("wounded, ");
        values.append("'" + result.wounded + "', ");

        //state
        columns.append("state, ");
        values.append("'" + result.state + "', ");

        //time
        columns.append("time, ");
        values.append("'" + result.time + "', ");

        //gender
        columns.append("gender, ");
        values.append("'" + result.gender + "', ");

        //age
        columns.append("age, ");
        values.append("'" + result.age + "', ");

        //multipleShooters
        columns.append("multipleShooters, ");
        values.append("'" + result.multipleShooters + "', ");

        //numShooters
        columns.append("numShooters, ");
        values.append("'" + result.numShooters + "', ");

        //arrested
        columns.append("arrested, ");
        values.append("'" + result.arrested + "', ");

        //numArrested
        columns.append("numArrested, ");
        values.append("'" + result.numArrested + "', ");

        //suicide
        columns.append("suicide, ");
        values.append("'" + result.suicide + "', ");

        //numSuicide
        columns.append("numSuicide, ");
        values.append("'" + result.numSuicide + "', ");

        //atLarge
        columns.append("atLarge, ");
        values.append("'" + result.atLarge + "', ");

        //numAtLarge
        columns.append("numAtLarge, ");
        values.append("'" + result.numAtLarge + "', ");

        //model
        columns.append("aiModel");
        values.append("'" + result.model + "'");//Last column, no comma

        return "INSERT INTO fbi_active_shooters.aiVerification (" + columns.toString() +
                ") VALUES (" + values.toString() + ");";
    }


    public void saveAiResponseToDB(
            final int incidentVerificationId,
            final DataPoint dataPoint,
            final HashMap<String, Object> result
    ) throws SQLException {
        final List<Map<String, Object>> choices = (List<Map<String, Object>>) result.get("choices");
        final Map<String, Object> message = (Map<String, Object>) choices.get(0).get("message");
        final String content = (String) message.get("content");

        //Save DataPoint
        final String columnName;
        switch(dataPoint) {
            case DEATHS             -> columnName = "Deaths";
            case WOUNDED            -> columnName = "Wounded";
            case STATE              -> columnName = "State";
            case TIME               -> columnName = "Time";
            case GENDER             -> columnName = "Gender";
            case AGE                -> columnName = "Age";
            case MULTIPLE_SHOOTERS  -> columnName = "MultipleShooters";
            case NUM_SHOOTERS       -> columnName = "NumShooters";
            case ARRESTED           -> columnName = "Arrested";
            case NUM_ARRESTED       -> columnName = "NumArrested";
            case SUICIDE            -> columnName = "Suicide";
            case NUM_SUICIDE        -> columnName = "NumSuicide";
            case AT_LARGE           -> columnName = "AtLarge";
            case NUM_AT_LARGE       -> columnName = "NumAtLarge";
            default -> throw new IllegalArgumentException("Invalid data point: " + dataPoint);
        }

        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                " UPDATE fbi_active_shooters.aiVerification SET " + columnName + " = ? WHERE id = ? ;"
        );
        int index = 1;
        stmt.setString(index++, content.trim());
        stmt.setInt   (index++, incidentVerificationId);

        //Execute
        stmt.executeUpdate();

        //Close Resources
        stmt.close();
    }

    public int createNewIncidentVerificationRecord(Incident incidentObj) throws SQLException {
        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                INSERT INTO fbi_active_shooters.aiVerification (
                      IncidentId,
                      AiModel
                )
                VALUES (
                      ?,
                      ?
                );
                 """
        );
        int index = 1;
        stmt.setString  (index++, incidentObj.custom_id.split("_")[0]);
        stmt.setString  (index++, incidentObj.body.model);

        //Execute
        stmt.executeUpdate();
        stmt.close();

        //Get ID
        stmt = conn.prepareStatement(
                """
                SELECT LAST_INSERT_ID();
                 """
        );/**/
        ResultSet rs = stmt.executeQuery();
        rs.next();
        int id = rs.getInt(1);//the ID of the new record

        //Close Resources
        stmt.close();
        rs.close();

        //Return
        return id;
    }

    public void queryAIForIncidents_realTime() throws SQLException, IOException, InterruptedException {
        /*
         * API has rate limit of 30,000 tokens per minute at my current reputation level.
         * These requests are roughly around 720-740 token. I rounded up to 750 just to be safe.
         * 30,000 [tokens per minute] / 750 [tokens per request] = 40 requests per minute
         * 60 [seconds] / 40 [requests] = 1.5 [seconds per request]
         */
        final long minCycleLag = 1_500;

        List<Incident> incidents = getIncidents();

        //Query AI API
        final String API_KEY = "YOUR_API_KEY";//Get one here: https://platform.openai.com/api-keys
        final String url = "https://api.openai.com/v1/chat/completions";
        for (Incident incidentObj : incidents) {
            final ObjectMapper mapper = new ObjectMapper();
            final String incidentTemplate = mapper.writeValueAsString(incidentObj.body);

            final int incidentVerificationId = createNewIncidentVerificationRecord(incidentObj);

            int dataPointIndex = 0;
            for (DataPoint dp : DataPoint.values()) {
                final long start = System.currentTimeMillis();

                final String requestBody = incidentTemplate.replace("#QUESTION#", dp.getQuestion());

                //Retry Loop
                boolean success = false;
                int attempt = 0;
                final int NUM_MAX_ATTEMPTS = 10;
                while(!success && attempt < NUM_MAX_ATTEMPTS) {
                    attempt++;

                    //Init HTTP Request
                    System.out.print("[" + incidentObj.custom_id.split("_")[0] + "_" + (dataPointIndex++) + "]\tSubmitting API Request...");
                    HttpClient client = HttpClient.newHttpClient();
                    HttpRequest request = HttpRequest.newBuilder()
                            .uri(URI.create(url))
                            .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                            .setHeader("Content-Type", "application/json")
                            .setHeader("Authorization", "Bearer " + API_KEY)
                            .build();

                    //Execute Request
                    HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
                    client.close();
                    System.out.print("Complete!");

                    //Parse Response
                    System.out.print("\tProcessing Response...");
                    final String responseStr = response.body()
                            .replace("\r", "")
                            .replace("\n", "")
                            .replace("\t", "");
                    final TypeReference<HashMap<String,Object>> typeRef = new TypeReference<>() {};
                    final HashMap<String,Object> resultObj = mapper.readValue(responseStr, typeRef);
                    if (resultObj.containsKey("error")) {
                        //Error
                        System.out.flush();
                        System.err.println("ERROR!");
                        System.err.println("\n\t" + responseStr);
                        System.err.flush();

                        System.out.print("Retrying...");
                        System.out.flush();
                        continue;
                    } else {
                        //Success
                        System.out.println("\n\t" + responseStr);
                        success = true;
                        System.out.println("Success!");
                    }
                    System.out.print("\tSaving Results to DB...");
                    saveAiResponseToDB(incidentVerificationId, dp, resultObj);
                    System.out.print("Complete!");

                    //Throttle to prevent rejection by API for too many request.
                    final long end = System.currentTimeMillis();
                    final long timeSpent = end - start;
                    final long remainingWaitTime = minCycleLag - timeSpent;
                    System.out.print("\tTook [" + timeSpent + "ms]");
                    if (remainingWaitTime > 0) {
                        System.out.print("\tWaiting [" + remainingWaitTime + "ms]...");
                        Thread.sleep(remainingWaitTime);
                        System.out.println("continuing.");
                    } else {
                        System.out.println("\tSlow enough, continuing immediately.");
                    }
                    System.out.println();
                }
            }
        }
    }

    public List<String> queryAIForIncidents_batch() throws SQLException, IOException, InterruptedException {
        //Query Incidents from DB
        List<Incident> incidents = getIncidents();

        //Each Incident
        final List<String> batchRequests = new ArrayList<>(incidents.size());
        final long start = System.currentTimeMillis();
        for (Incident incidentObj : incidents) {
            final ObjectMapper mapper = new ObjectMapper();
            final String incidentTemplate = mapper.writeValueAsString(incidentObj);

            //Each Question
            for (DataPoint dp : DataPoint.values()) {
                batchRequests.add(
                        incidentTemplate
                                .replace("#ID_SUFFIX#", dp.name())
                                .replace("#QUESTION#", dp.getQuestion())
                );
            }
        }
        //Log Benchmark
        final long end = System.currentTimeMillis();
        final long timeSpent = end - start;
        System.out.print("\tTook [" + timeSpent + "ms]");

        //Return
        return batchRequests;
    }

    public String parseAIBatchResults(List<String> aiResponses) throws JsonProcessingException {
        //Parse Batch Responses
        final HashMap<Integer, AI_Result> results = new HashMap<>();
        for(final String aiResponseStr : aiResponses) {
            parseAIResult(results, aiResponseStr);
        }

        //Save to DB
        final StringBuilder inserts = new StringBuilder();
        final String DELIMITER = " VALUES ";
        String insertPrefix = null;
        for(AI_Result result : results.values()) {
            final String insertStatement = generateSqlInsert(result);
            final String[] pieces = insertStatement.split(DELIMITER);
            final String columnsPortion = pieces[0];
            final String values = pieces[1];

            //Export Query Prefix
            if (insertPrefix == null) {
                insertPrefix = columnsPortion;
            }

            //Save insert values
            inserts.append(values.replace(";", ",") + "\n\t");
        }

        //Return
        return insertPrefix + DELIMITER + "\n\t" + replaceLast(inserts.toString(), ",", ";");
    }

    public String replaceLast(final String containingStr, final String toReplace, final String replaceWith) {
        final int start = containingStr.lastIndexOf(toReplace);
        return containingStr.substring(0, start) +
                replaceWith +
                containingStr.substring(start + toReplace.length());
    }

    public void parseAIResult(
            final HashMap<Integer, AI_Result> results,
            final String responseStr_raw
    ) throws JsonProcessingException {
        //Parse JSON
        final ObjectMapper mapper = new ObjectMapper();
        final TypeReference<HashMap<String,Object>> typeRef = new TypeReference<>() {};
        final HashMap<String,Object> result = mapper.readValue(responseStr_raw, typeRef);
//            System.out.println(result);

        //Extract Values
        final String customId = result.get("custom_id").toString();
        final Map<String, Object> response = (Map<String, Object>) result.get("response");
        final Map<String, Object> body = (Map<String, Object>) response.get("body");
        final String model = (String) body.get("model");
        final List<Map<String, Object>> choices = (List<Map<String, Object>>) body.get("choices");
        final Map<String, Object> message = (Map<String, Object>) choices.get(0).get("message");
        final String content = (String) message.get("content");

        //Extract sub-values from Custom ID
        final int splitIndex = customId.indexOf("_");
        final Integer incidentId = Integer.parseInt(customId.substring(0,splitIndex));
        final DataPoint dataPoint = DataPoint.valueOf(customId.substring(splitIndex+1));

        //Retrieve Obj
        final AI_Result aiResult;
        if (results.containsKey(incidentId)) {
            aiResult = results.get(incidentId);
        } else {
            aiResult = new AI_Result();
            aiResult.incidentId = incidentId;
            aiResult.model = model;

            //Push to list
            results.put(incidentId, aiResult);
        }

        //Save DataPoint
        switch(dataPoint) {
            case DEATHS             -> aiResult.deaths = content;
            case WOUNDED            -> aiResult.wounded = content;
            case STATE              -> aiResult.state = content;
            case TIME               -> aiResult.time = content;
            case GENDER             -> aiResult.gender = content;
            case AGE                -> aiResult.age = content;
            case MULTIPLE_SHOOTERS  -> aiResult.multipleShooters = content;
            case NUM_SHOOTERS       -> aiResult.numShooters = content;
            case ARRESTED           -> aiResult.arrested = content;
            case NUM_ARRESTED       -> aiResult.numArrested = content;
            case SUICIDE            -> aiResult.suicide = content;
            case NUM_SUICIDE        -> aiResult.numSuicide = content;
            case AT_LARGE           -> aiResult.atLarge = content;
            case NUM_AT_LARGE       -> aiResult.numAtLarge = content;
            default -> throw new IllegalArgumentException("Invalid data point: " + dataPoint);
        }
    }

    public List<Incident> getIncidents() throws SQLException {
        Statement stmt;
        ResultSet rs;

        //Query
        stmt = conn.createStatement();
        stmt.execute(
                """
                SELECT inc.id AS incidentID,
                       raw_desc.id AS rawIncidentDescId,
                       raw_desc.incidentName,
                       raw_desc.incidentDesc
                  FROM fbi_active_shooters.rawIncidentDescriptions raw_desc
                  JOIN fbi_active_shooters.incident inc
                    ON raw_desc.incidentId = inc.id
                 -- WHERE 0 < inc.id AND inc.id <= 2 -- 500
                 -- WHERE inc.id = 5
                    WHERE inc.dataSourceId = '2023'
                 ORDER BY inc.id;
                """
        );

        //Result
        rs = stmt.getResultSet();

        //Process
        final List<Incident> batchList = new ArrayList<>();
        int count = 0;
        while (rs.next()) {
            //OpenAI's API wants the JSON object formatted as a single line, with one object
            //on each line, but not wrapped in the JSON array syntax.
            //
            //Apparently, it's called JSON-L / "JSON Lines" / "newline-delimited JSON".
            //See: https://jsonlines.org/
            final Incident incident = new Incident();
            batchList.add(incident);

            final String incidentID = rs.getString("incidentID");
            incident.custom_id = incidentID + "_#ID_SUFFIX#";
            Body body = incident.body;
            body.messages.add(new SystemMessage(
                    SYSTEM_MESSAGE
            ));
            body.messages.add(new UserMessage(
                    "Event Name: " + escapeJSONChars(rs.getString("incidentName")) +
                    "\nEvent Summary: " + escapeJSONChars(rs.getString("incidentDesc")) +
                    "\nQuestion: #QUESTION#"
            ));

            //Increment Count
            count++;
        }

        //Close Resources
        rs.close();
        stmt.close();

        //Return
        System.out.println("Num Records: " + count);
        return batchList;
    }

    public void verifyDirectSingleValues(final String aiModel) throws SQLException {
        System.out.println("\n" +
                "------------------------------\n" +
                "Verifying Direct Single Values\n" +
                "------------------------------\n"
        );

        //Prepare Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                SELECT inc.id AS inc_id,
                       inc.deaths AS inc_deaths,
                       inc.wounded AS inc_wounded,
                       inc.time AS inc_time,
                       ai.id AS ai_id,
                       ai.deaths AS ai_deaths,
                       ai.wounded AS ai_wounded,
                       ai.time AS ai_time,
                       TRUE AS singleTime
                  FROM fbi_active_shooters.aiVerification ai
                  JOIN fbi_active_shooters.incident inc
                    ON ai.incidentID = inc.id
                 WHERE ai.aiModel = """ + "'" + aiModel + "'" + """
                   AND ai.time NOT LIKE '%-%'
                   AND ai.time NOT LIKE '%to%'
                   AND ai.time NOT LIKE '%and%'
                   AND ai.time NOT LIKE '%&%'
                 UNION ALL
                SELECT inc.id AS inc_id,
                       inc.deaths AS inc_deaths,
                       inc.wounded AS inc_wounded,
                       inc.time AS inc_time,
                       ai.id AS ai_id,
                       ai.deaths AS ai_deaths,
                       ai.wounded AS ai_wounded,
                       ai.time AS ai_time,
                       FALSE AS singleTime
                  FROM fbi_active_shooters.aiVerification ai
                  JOIN fbi_active_shooters.incident inc
                    ON ai.incidentID = inc.id
                 WHERE ai.aiModel = """ + "'" + aiModel + "'" + """
                   AND (
                               ai.time LIKE '%-%'
                            OR ai.time LIKE '%to%'
                            OR ai.time LIKE '%and%'
                            OR ai.time LIKE '%&%'
                   )
                 ORDER BY inc_id;
                 """
        );

        //Result
        ResultSet rs = stmt.executeQuery();

        //Validate
        while (rs.next()) {
            final StringBuilder log = new StringBuilder();
            log.append("Comparing ");

            //Incident Values
            final int incidentId = rs.getInt("inc_id");
            log.append("[incident: " + incidentId + "] ...\t");
            final int incidentDeaths = rs.getInt("inc_deaths");
            final int incidentWounded = rs.getInt("inc_wounded");
            final Time incidentTime = rs.getTime("inc_time");

            //AI Values
            final int aiId = rs.getInt("ai_id");
            final int aiDeaths = rs.getInt("ai_deaths");
            final int aiWounded = rs.getInt("ai_wounded");
            final String aiTime = rs.getString("ai_time").replace("Between", "").trim();
            final boolean singleTime = rs.getBoolean("singleTime");

            //Verification Status
            boolean allSuccess = true;

            //Casualties
            allSuccess &= verify(log, "Deaths",  incidentDeaths+"",  aiDeaths+"");
            allSuccess &= verify(log, "Wounded", incidentWounded+"", aiWounded+"", "\t", "\t");

            //Time
            if (singleTime) {
                final Time parsedTime = parseTimeStr(aiTime);
                allSuccess &= verify(log, "Time", incidentTime+"", parsedTime+"");
            } else {
                //log.append("'" + aiTime + "'");

                //Split Dual Time Str
                final String[] timeParts;
                if (aiTime.contains("&")) {
                    timeParts = aiTime.split(" & ");
                } else if (aiTime.contains("and")) {
                    timeParts = aiTime.split(" and ");
                } else if (aiTime.contains("to")) {
                    timeParts = aiTime.split(" to ");
                } else if (aiTime.contains("-")) {
                    timeParts = aiTime.split(" - ");
                } else {
                    throw new IllegalArgumentException("Invalid time format: " + aiTime);
                }
                final Time time1 = parseTimeStr(timeParts[0]);
                final Time time2 = parseTimeStr(timeParts[1]);

                //Time 1
                final StringBuilder time1Log = new StringBuilder();
                final boolean aMatches = verify(time1Log, "Time", incidentTime+"", time1+"");

                //Time 2
                final StringBuilder time2Log = new StringBuilder();
                final boolean bMatches = verify(time2Log, "Time", incidentTime+"", time2+"");

                //Any Match
                if (aMatches) {
                    log.append(time1Log);
                } else if (bMatches) {
                    log.append(time2Log);
                } else {
                    log.append(time1Log + " " + time2Log);
                    allSuccess = false;
                }
            }

            //Log
            final boolean shouldLog = !allSuccess || (allSuccess && logSuccesses);
            if (shouldLog) {
                System.out.println(log);
            }
        }

        //Close Resources
        stmt.close();
        rs.close();
    }

    public static Time parseTimeStr(String timeStr) {
        if (timeStr == null) throw new java.lang.IllegalArgumentException();

        //Ensure Minutes
        if (!timeStr.contains(":")) {
            timeStr = timeStr.replace(" ", ":00 ");
        }

        //Parse
        int hour;
        final int minute;
        final boolean isPm;
        final int colon = timeStr.indexOf(':');
        final int len = timeStr.length();
        if (colon > 0) {
            hour = Integer.parseInt(timeStr, 0, colon, 10);
            minute = Integer.parseInt(timeStr, colon + 1, colon + 3, 10);
            if (timeStr.toLowerCase().contains("m")) {//12-hour time
                String amPm = timeStr.substring(colon + 4, len);
                isPm = amPm.trim().equalsIgnoreCase("p.m.");
            } else if (hour <= 24) {//24-hour time
                if (hour >= 12) {
                    isPm = true;
                    //exactly 12 is both PM and not subtracted
                    //because our time system is retarded.
                    if (hour > 12) {
                        hour -= 12;
                    }
                } else {
                    isPm = false;
                }
            } else {//Unknown format
                throw new IllegalArgumentException("Invalid time format: " + timeStr);
            }
        } else {
            throw new java.lang.IllegalArgumentException();
        }

        //12 to 24 hour conversion
        if (isPm) {
            if (hour < 12) {
                hour += 12;
            }
        } else {
            if (hour == 12) {
                hour = 0;
            }
        }

        return new Time(
                hour,
                minute,
                0
        );
    }

    public void verifyStates(final String aiModel) throws SQLException {
        System.out.println("\n" +
                "----------------\n" +
                "Verifying States\n" +
                "----------------\n"
        );

        //Get One-To-Many States for Incidents
        final Map<Integer, List<String>> incidentStatesMap = getIncidentStates();

        //Get AI States
        final Map<Integer, String> aiStatesMap = getAiStates(aiModel);

        //Verify
        for (Map.Entry<Integer, List<String>> incidentStatesEntry : incidentStatesMap.entrySet()) {
            StringBuilder log = new StringBuilder();

            //Verification Status
            boolean allSuccess = true;

            //Incident ID
            final int incidentID = incidentStatesEntry.getKey();
            log.append("Comparing [incident: " + incidentID + "] ...\t");

            //Alphabetically sort Incident States
            final String incidentStatesStr = makeSortedMultiRecordString(incidentStatesEntry.getValue());

            //Alphabetically sort AI state string
            final String aiStateStr = sortMultiRecordString(aiStatesMap.get(incidentID));

            //Verify
            allSuccess &= verify(
                    log,
                    "States",
                    incidentStatesStr,
                    aiStateStr.replace("Washington, D.C.", "District of Columbia")//Standardize DC name
            );

            //Log
            final boolean shouldLog = !allSuccess || (allSuccess && logSuccesses);
            if (shouldLog) {
                System.out.println(log);
            }
        }
    }

    public Map<Integer, List<String>> getIncidentStates() throws SQLException {
        final Map<Integer, List<String>> incidentStates = new HashMap<>();

        //Prepare Incident State Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                SELECT incState.incidentId AS inc_id,
                       stateLU.name AS inc_state
                  FROM fbi_active_shooters.incidentState incState
                  JOIN fbi_active_shooters.stateLookup stateLU
                    ON incState.stateId = stateLU.id
                 ORDER BY inc_id
                 """
        );

        //Incident States
        ResultSet rs = stmt.executeQuery();
        while (rs.next()) {
            //Pull DB Values
            final int incidentId = rs.getInt("inc_id");
            final String incidentState = rs.getString("inc_state");

            //Ensure record in master map
            List<String> states = incidentStates.get(incidentId);
            if (states == null) {
                states = new ArrayList<>();
                incidentStates.put(incidentId, states);
            }

            //Add state to list
            states.add(incidentState);
        }

        //Close Resources
        stmt.close();
        rs.close();

        //Return
        return incidentStates;
    }

    public Map<Integer, String> getAiStates(final String aiModel) throws SQLException {
        final Map<Integer, String> aiStates = new HashMap<>();

        //Prepare AI States Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                 SELECT ai.incidentId,
                        ai.state
                   FROM fbi_active_shooters.aiVerification ai
                  WHERE ai.aiModel = """ + "'" + aiModel +"'" + """
                  ORDER BY ai.incidentId
                 """
        );

        //AI States
        ResultSet rs = stmt.executeQuery();
        while (rs.next()) {
            //Pull DB Values
            final int aiId = rs.getInt("incidentId");
            final String aiState = rs.getString("state");

            //Add state to map
            aiStates.put(aiId, aiState);
        }

        //Close Resources
        stmt.close();
        rs.close();

        //Return
        return aiStates;
    }

    public void verifyShooters(final String aiModel) throws SQLException {
        System.out.println("\n" +
                "------------------\n" +
                "Verifying Shooters\n" +
                "------------------\n"
        );

        //Get One-To-Many Shooters for Incidents
        final Map<Integer, List<Shooter>> incidentShootersMap = getIncidentShooters();

        //Get AI Shooters
        final Map<Integer, AI_Result> aiShootersMap = getAiShooters(aiModel);

        //Verify
        for (Map.Entry<Integer, List<Shooter>> incidentShootersEntry : incidentShootersMap.entrySet()) {
            StringBuilder log = new StringBuilder();

            //Verification Status
            boolean allSuccess = true;

            //Incident ID
            final int incidentID = incidentShootersEntry.getKey();
            log.append("Comparing [incident: " + incidentID + "] ...\t");
            final List<Shooter> incShooters = incidentShootersEntry.getValue();

            //Get corresponding AI record
            final AI_Result aiResult = aiShootersMap.get(incidentID);

            //Multiple Shooters
            allSuccess &= verify(
                    log,
                    "Multiple Shooters",
                    incShooters.size() > 1 ? "YES" : "NO",
                    aiResult.multipleShooters,
                    "\t\t"
            );

            //Num Shooters
            allSuccess &= verify(
                    log,
                    "Num Shooters",
                    incShooters.size() + "",
                    aiResult.numShooters,
                    "\t\t"
            );

            {//Arrested
                final long numArrested =
                        countOccurrancesInList(incShooters, x -> x.fate, "arrested") +
                        countOccurrancesInList(incShooters, x -> x.fate, "surrendered") +
                        countOccurrancesInList(incShooters, x -> x.fate, "turned self in");

                //Was Arrested
                allSuccess &= verify(
                        log,
                        "Arrested",
                        numArrested > 0 ? "YES" : "NO",
                        aiResult.arrested,
                        "\t\t",
                        "\t"
                );

                //Num Arrested
                allSuccess &= verify(
                        log,
                        "Num Arrested",
                        numArrested + "",
                        aiResult.numArrested,
                        "\t"
                );
            }

            {//Suicide
                final long numSuicide = countOccurrancesInList(incShooters, x -> x.fate, "suicide");

                //Did Suicide
                allSuccess &= verify(
                        log,
                        "Suicide",
                        numSuicide > 0 ? "YES" : "NO",
                        aiResult.suicide,
                        "\t"
                );

                //Num Suicide
                allSuccess &= verify(
                        log,
                        "Num Suicide",
                        numSuicide + "",
                        aiResult.numSuicide,
                        "\t",
                        "\t"
                );
            }

            {//At Large
                final long numAtLarge = countOccurrancesInList(incShooters, x -> x.fate, "never caught");

                //Is At Large
                allSuccess &= verify(
                        log,
                        "At Large",
                        numAtLarge > 0 ? "YES" : "NO",
                        aiResult.atLarge,
                        "\t\t",
                        "\t"
                );

                //Num At Large
                allSuccess &= verify(
                        log,
                        "Num At Large",
                        numAtLarge + "",
                        aiResult.numAtLarge,
                        "\t",
                        "\t"
                );/**/
            }

            //Gender
            allSuccess &= verify(
                    log,
                    "Gender",
                    makeSortedMultiRecordString(incShooters.stream().map(x -> Optional.ofNullable(x.gender).orElse("UNKNOWN")).toList()),
                    sortMultiRecordString(aiResult.gender.replace("NON-BINARY", "NONBINARY")),
                    "\t\t"
            );

            //Age
            allSuccess &= verify(
                    log,
                    "Age",
                    makeSortedMultiRecordString(incShooters.stream().map(x -> Optional.ofNullable(x.age).orElse("UNKNOWN")).toList()),
                    sortMultiRecordString(aiResult.age)
            );

            //Log
            final boolean shouldLog = !allSuccess || (allSuccess && logSuccesses);
            if (shouldLog) {
                System.out.println(log);
            }
        }
    }

    public static <T> long countOccurrancesInList(List<T> list, Function<T,String> mapper, String targetStr) {
        return list.stream().filter(x -> mapper.apply(x) != null && mapper.apply(x).toLowerCase().contains(targetStr.toLowerCase())).count();
    }

    public static class Shooter {
        String gender;
        String age;
        String fate;
        String surrendered;
    }

    public Map<Integer, List<Shooter>> getIncidentShooters() throws SQLException {
        final Map<Integer, List<Shooter>> incidentShooters = new HashMap<>();

        //Prepare Incident Shooters Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                SELECT inc.id AS inc_id,
                       sh.gender AS sh_gender,
                       sh.age AS sh_age,
                       sh.fate AS sh_fate,
                       sh.surrenderedDuringIncident AS sh_surrendered
                  FROM fbi_active_shooters.incident inc
                  JOIN fbi_active_shooters.shooter sh
                    ON sh.incidentId = inc.id
                 ORDER BY inc_id
                 """
        );

        //Incident Shooters
        ResultSet rs = stmt.executeQuery();
        while (rs.next()) {
            //Pull DB Values
            final int incidentId = rs.getInt("inc_id");
            final Shooter shooter = new Shooter();
            shooter.gender = rs.getString("sh_gender");
            shooter.age = rs.getString("sh_age");
            shooter.fate = rs.getString("sh_fate");
            shooter.surrendered = rs.getString("sh_surrendered");

            //Ensure record in master map
            List<Shooter> shooters = incidentShooters.get(incidentId);
            if (shooters == null) {
                shooters = new ArrayList<>();
                incidentShooters.put(incidentId, shooters);
            }

            //Add shooter to list
            shooters.add(shooter);
        }

        //Close Resources
        stmt.close();
        rs.close();

        //Return
        return incidentShooters;
    }

    public Map<Integer, AI_Result> getAiShooters(final String aiModel) throws SQLException {
        final Map<Integer, AI_Result> aiShooters = new HashMap<>();

        //Prepare AI Shooters Query
        PreparedStatement stmt;
        stmt = conn.prepareStatement(
                """
                 SELECT ai.incidentId,
                        ai.gender,
                        ai.age,
                        ai.multipleShooters,
                        ai.numShooters,
                        ai.arrested,
                        ai.numArrested,
                        ai.suicide,
                        ai.numSuicide,
                        ai.atLarge,
                        ai.numAtLarge
                   FROM fbi_active_shooters.aiVerification ai
                  WHERE ai.aiModel = """ + "'" + aiModel + "'" + """
                  ORDER BY ai.incidentId
                 """
        );

        //AI Shooters
        ResultSet rs = stmt.executeQuery();
        while (rs.next()) {
            //Pull DB Values
            final AI_Result aiResult = new AI_Result();
            aiResult.incidentId = rs.getInt("incidentId");
            aiResult.gender = rs.getString("gender");
            aiResult.age = rs.getString("age");
            aiResult.multipleShooters = rs.getString("multipleShooters");
            aiResult.numShooters = rs.getString("numShooters");
            aiResult.arrested = rs.getString("arrested");
            aiResult.numArrested = rs.getString("numArrested");
            aiResult.suicide = rs.getString("suicide");
            aiResult.numSuicide = rs.getString("numSuicide");
            aiResult.atLarge = rs.getString("atLarge");
            aiResult.numAtLarge = rs.getString("numAtLarge");

            //Add shooter to map
            aiShooters.put(aiResult.incidentId, aiResult);
        }

        //Close Resources
        stmt.close();
        rs.close();

        //Return
        return aiShooters;
    }

    public static String sortMultiRecordString(final String str) {
        if (str == null || str.length() == 0) {
            return str;
        }

        //Split string on delimiter
        if (!str.contains(" & ")) {
            //No Delimiter
            return str;
        } else {
            final List<String> records = Arrays.asList(str.split(" & "));

            //Reconstruct combined string
            return makeSortedMultiRecordString(records);
        }
    }

    public static String makeSortedMultiRecordString(final List<String> origList) {
        final List<String> tmpList = new ArrayList<>(origList);
        tmpList.sort(Comparator.nullsFirst(String.CASE_INSENSITIVE_ORDER));
        return String.join(" & ", tmpList.toArray(new String[]{}));
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

    public void verifyAIAgainstManualDataEntry(final String model) throws SQLException {
        verifyDirectSingleValues(model);
        verifyStates(model);
        verifyShooters(model);
    }

    public static class Incident {
        String custom_id;
        String method = "POST";
        String url = "/v1/chat/completions";
        Body body = new Body();

        public String getCustom_id() {
            return custom_id;
        }

        public void setCustom_id(String custom_id) {
            this.custom_id = custom_id;
        }

        public String getMethod() {
            return method;
        }

        public void setMethod(String method) {
            this.method = method;
        }

        public String getUrl() {
            return url;
        }

        public void setUrl(String url) {
            this.url = url;
        }

        public Body getBody() {
            return body;
        }

        public void setBody(Body body) {
            this.body = body;
        }
    }

    public static class Body {
        String model;
        int max_tokens;
        List<Message> messages;

        public Body() {
            model = "gpt-4o";
            max_tokens = 1000;
            messages = new ArrayList<>(2);
        }

        public String getModel() {
            return model;
        }

        public void setModel(String model) {
            this.model = model;
        }

        public int getMax_tokens() {
            return max_tokens;
        }

        public void setMax_tokens(int max_tokens) {
            this.max_tokens = max_tokens;
        }

        public List<Message> getMessages() {
            return messages;
        }

        public void setMessages(List<Message> messages) {
            this.messages = messages;
        }
    }

    public static class Message {
        String content;
        String role;

        public Message(String content, String role) {
            this.content = content;
            this.role = role;
        }

        public String getContent() {
            return content;
        }

        public void setContent(String content) {
            this.content = content;
        }

        public String getRole() {
            return role;
        }

        public void setRole(String role) {
            this.role = role;
        }
    }
    public static class SystemMessage extends Message {
        public SystemMessage(String content) {
            super(content, "system");
        }
    }
    public static class UserMessage extends Message {
        public UserMessage(String content) {
            super(content, "user");
        }
    }

    public static class AI_Result {
        int incidentId;
        String model;
        String deaths;
        String wounded;
        String state;
        String time;
        String gender;
        String age;
        String multipleShooters;
        String numShooters;
        String arrested;
        String numArrested;
        String suicide;
        String numSuicide;
        String atLarge;
        String numAtLarge;
    }

    public void queueTemplate(StringBuilder sb, StringBuilder template, String question, String idSuffix) {
        sb.append(template.toString()
                .replace("#QUESTION#", question)
                .replace("#ID_SUFFIX#", idSuffix)
        );
        sb.append("\n");
    }

    public void append(StringBuilder sb, String ... strs) {
        for (String s : strs) {
            sb.append(s);
        }
    }

    public String escapeJSONChars(final String str) {
        return str.replace("\"", "\\\"");
    }

    public void run() throws SQLException, IOException, InterruptedException {
        if (!getConnection()) {
            System.err.println("Error obtaining connection! Terminating...");
            return;
        }

        //Build Batch Request
        /*final String incidentQuestions = String.join("\n", queryAIForIncidents_batch());
        Files.write(Paths.get("D:/___IncidentQuestions_ChatGPT-API.jsonl"), incidentQuestions.getBytes(StandardCharsets.UTF_8));/**/

        //Process Batch Results
        /*final List<String> responses = Files.readAllLines(Paths.get("D:/___aiVerificationResponses.jsonl"));
        final String aiResultInserts = parseAIBatchResults(responses);
        Files.write(Paths.get("D:/___aiVerificationInserts.sql"), aiResultInserts.getBytes(StandardCharsets.UTF_8));/**/

        //Verify AI Responses Against Manual Data Entry
//        final String aiModel = "gpt-4-turbo-2024-04-09";
        final String aiModel = "gpt-4o-2024-05-13";
        verifyAIAgainstManualDataEntry(aiModel);/**/
    }

    public static void main(String[] args) throws SQLException, IOException, InterruptedException, ClassNotFoundException, InstantiationException, IllegalAccessException {
        new AiValidator().run();
    }
}