import javax.swing.*;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.PrintWriter;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.Iterator;
import java.util.List;
import java.util.stream.Collectors;

public class ParseRawPoliceReports {
    public static final String[] LOCATION_TYPES = {
            "(Commerce)",
            "(Education)",
            "(Government)",
            "(Health Care)",
            "(House of Worship)",
            "(Open Space)",
            "(Other)",
            "(Residence)",
            "(Residential)"
    };

    private void run() throws IOException {
        //Set LAF
        setLAF();

        //Get TXT Dir
        final File txtDir = getTxtDir();
        System.out.println("File: " + txtDir);

        //Establish Output File
        final File outputFile = new File(txtDir, "RawIncidentDescriptions.sql");

        //Clobber Check
        FileOutputStream fos;
        PrintWriter file_writer;
        if (!outputFile.exists()) {
            //Make Output File
            outputFile.createNewFile();
            fos = new FileOutputStream(outputFile, true);
            file_writer = new PrintWriter(fos, false, StandardCharsets.UTF_8);

        } else {//Skip this file
            final String errMsg = "Error! Output file already exists. Aborting.";
            System.err.println(errMsg);
            showErrorMessage(errMsg);
            return;
        }

        //Write Output File Preamble
        file_writer.println("START TRANSACTION;");
        file_writer.println("-- \n-- Database: `fbi_active_shooters`\n-- ");
        file_writer.println("USE `fbi_active_shooters`;");
        file_writer.println("\n\n-- ------------------------------------------------\n\n");

        //Get CSV Files
        File[] txtFiles = txtDir.listFiles(file -> file.isFile() && getFilenameChunks(file.getName()).ext.equalsIgnoreCase("txt"));

        //Process Files
        for (File incidentsFile : txtFiles) {
            //Filename should be same as data source file name
            final FilenameChunks fnc = getFilenameChunks(incidentsFile.getName());

            //First Pass
            final StringBuilder _1stPassOutput = new StringBuilder();
            {
                //Read File
                final List<String> lines = Files.readAllLines(incidentsFile.toPath(), StandardCharsets.UTF_8);

                //Process Pass
                boolean isFirstRecord = true;
                for (final String line_raw : lines) {
                    final String line = line_raw.trim();

                    if (isUnsignedNumber(line)) {//is page number line. Ignore
                        //Do Nothing. Skip.
                    } else if (line.isBlank()) {//is random blank line
                        //Do Nothing. Skip.
                    } else if (//Is Name Line
                            containsIgnoreCaseOR(
                                    line,
                                    LOCATION_TYPES
                            )
                    ) {
                        //Delimiter
                        if (isFirstRecord) {
                            isFirstRecord = false;
                        } else {
                            //Add Separator Line
                            _1stPassOutput.append('\n');
                        }

                        //Write Name Line
                        _1stPassOutput.append(line);
                        _1stPassOutput.append('\n');
                    } else {//Is Content Line
                        //Write Line
                        _1stPassOutput.append(line);
                        _1stPassOutput.append('\n');
                    }
                }
            }


            //Second Pass
            final StringBuilder _2ndPassOutput = new StringBuilder();
            {
                //Migrate Previous Pass Output To Input
                final List<String> lines = _1stPassOutput.toString()
                        .lines()
                        .collect(Collectors.toList());

                //Manually Iterate over lines
                final Iterator<String> it = lines.iterator();


                //Assume clean structure created by first pass
                file_writer.println("-- \n-- " + fnc.name + ".pdf\n-- \n");
                file_writer.println("INSERT INTO rawIncidentDescriptions (DataSourceFile, RawIncidentTitle, IncidentName, LocationType, IncidentDesc) VALUES");
                file_writer.flush();
                boolean isFirst = true;
                while (it.hasNext()) {
                    String eventName = null;
                    StringBuilder eventDescription = new StringBuilder();

                    //1st line is name
                    final String rawIncidentTitle = it.next();
                    final String locationType = getLocationType(rawIncidentTitle);
                    eventName = removeAll(rawIncidentTitle, LOCATION_TYPES).trim();//Replace with normal ASCII single quote, but also escape it for SQL by doubling it.

                    //All following non-blank lines are description
                    //Merge with a space instead of new line
                    String line = null;
                    while (it.hasNext() && !(line = it.next()).isBlank()) {
                        eventDescription.append(line.trim());
                        eventDescription.append(' ');
                    }

                    //At this point we have full event obj

                    //Delimiter
                    if (isFirst) {
                        isFirst = false;
                    } else {
                        file_writer.print(",\n");
                    }
                    file_writer.flush();

                    //Write to file
                    file_writer.print("('" + fnc.name + ".pdf', ");//Filename should be same as data source file name
                    file_writer.flush();
                    file_writer.print("'" + escapeSQLChars(rawIncidentTitle) + "', ");
                    file_writer.flush();
                    file_writer.print("'" + escapeSQLChars(eventName) + "', ");
                    file_writer.flush();
                    file_writer.print("'" + escapeSQLChars(locationType) + "', ");
                    file_writer.flush();
                    file_writer.print("'" + escapeSQLChars(eventDescription.toString()) + "'");
                    file_writer.flush();
                    file_writer.print(")");
                    file_writer.flush();
                }
            }

            //Close values insert
            file_writer.println(";");
            file_writer.println("\n\n-- ------------------------------------------------\n\n");
        }

        //Commit Transaction
        file_writer.println("COMMIT;\n\n");

        //Flush Streams
        file_writer.flush();
        fos.flush();

        //Close File
        fos.close();
        file_writer.close();
    }

    public String removeAll(final String containingStr, final String ... testStr) {
        String output = containingStr;
        for (String s : testStr) {
            output = output
                    .replaceAll(escapeParenthesis(s), "");
        }
        return output;
    }

    public String escapeParenthesis(final String str) {
        return str
                .replaceAll("\\(", "\\\\(")
                .replaceAll("\\)", "\\\\)");
    }

    public String escapeSQLChars(final String str) {
        return str.replaceAll("'", "''");
    }

    public static boolean containsIgnoreCaseOR(final String containingStr, final String ... testStrs) {
        return getWhich(containingStr, testStrs) != null;
    }
    public static String getWhich(final String containingStr, final String ... testStrs) {
        for (String testStr : testStrs) {
            if (containsIgnoreCase(containingStr, testStr)) {
                return testStr;
            }
        }
        return null;
    }

    public static String getLocationType(final String rawTitle) {
        final String locationType = getWhich(rawTitle, LOCATION_TYPES)
                .replace("(", "")
                .replace(")", "");

        if (locationType.equals("Residential")) {//Standardize on "Residence"
            return "Residence";
        } else {
            return locationType;
        }
    }

    public static boolean containsIgnoreCase(final String containingStr, final String searchStr) {
        return containingStr.toLowerCase().contains(searchStr.toLowerCase());
    }

    public static boolean isUnsignedNumber(final String str) {
        return str.matches("\\d+");
    }

    public static FilenameChunks getFilenameChunks(final String filename) {
        final int index = filename.lastIndexOf('.');
        return new FilenameChunks(
                filename.substring(0, index),
                filename.substring(index + 1)
        );
    }

    public static class FilenameChunks {
        final String name;
        final String ext;

        public FilenameChunks(String name, String ext) {
            this.name = name;
            this.ext = ext;
        }
    }

    public static File getTxtDir() {
        //Show Instruction Dialog
        JOptionPane.showMessageDialog(null, "Choose the directory containing the TXT files.");

        //Open Browse Dialog
        JFileChooser browse = new JFileChooser(new File("C:/"));
        browse.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
        final int retVal = browse.showOpenDialog(null);

        //Get Selection
        if (retVal == JFileChooser.APPROVE_OPTION) {
            return browse.getSelectedFile();
        } else {
            return null;
        }
    }

    public static void setLAF() {
        try {
            UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
        }
        catch (Exception e) {
            showErrorMessage("Error! Unable to set system Look And Feel.\nContinuing with default Java Look And Feel.");
        }
    }

    public static void showErrorMessage(final String errMsg) {
        JOptionPane.showMessageDialog(
                null,
                errMsg,
                "Error!",
                JOptionPane.ERROR_MESSAGE
        );
    }

    public static void main(String[] args) throws IOException {
        new ParseRawPoliceReports().run();
        /*String name = "McDonald’s and Burger King";
        System.out.println("'" + name + "'");
        System.out.println("'" + name.replaceAll("’", "''") + "'");/**/
    }
}
