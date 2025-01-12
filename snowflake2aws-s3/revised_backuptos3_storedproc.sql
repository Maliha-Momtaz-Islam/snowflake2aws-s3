CREATE OR REPLACE PROCEDURE backup_data_to_s3()
RETURNS STRING NOT NULL
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
var status = "SUCCESS";
var message = "";
var databaseName = 'DEV_COMMON'; // Database name
var schemaName = 'DEV_COMMON_ANALYTICS'; // Schema name
var currentDate = new Date().toISOString().slice(0, 10); // Gets YYYY-MM-DD format
var folderName = `bk_${databaseName}_${currentDate}`; // Folder for today's backups
var exportTable = ""; // Initialize exportTable for error messages
var anyFailures = false; // Flag to track if any table export fails

try {
    // Get the list of tables from the specified schema
    var getTablesQuery = `
        SELECT TABLE_NAME 
        FROM ${databaseName}.INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_TYPE = 'BASE TABLE' 
          AND TABLE_SCHEMA = '${schemaName}'
    `;
    var stmt = snowflake.createStatement({sqlText: getTablesQuery});
    var resultSet = stmt.execute();
    var tables = [];
    while (resultSet.next()) {
        tables.push(resultSet.getColumnValue(1));
    }

    // Start transaction
    var beginStmt = snowflake.createStatement({sqlText: "BEGIN"});
    beginStmt.execute();

    // Export each table to CSV with individual error handling
    for (var i = 0; i < tables.length; i++) {
        exportTable = tables[i];

        // Escape any double quotes in the table name
        var escapedTableName = exportTable.replace(/"/g, '""');

        // Enclose table name in double quotes to handle case sensitivity
        var quotedTableName = '"' + escapedTableName + '"';

        var fileName = `bk_${databaseName}_${exportTable}_${currentDate}.csv`;
        var s3Path = `${folderName}/${fileName}`; // Full path in S3

        // Construct the COPY INTO command using concat
        var exportQuery = "".concat(
            "COPY INTO @s3_backup_stage/",
            s3Path,
            " FROM ",
            " (SELECT * FROM ",
            databaseName,
            ".",
            '"' + schemaName.replace(/"/g, '""') + '"',
            ".",
            quotedTableName,
            ") ",
            " FILE_FORMAT = (TYPE = 'CSV', FIELD_OPTIONALLY_ENCLOSED_BY = '\"', NULL_IF = ('') ) ",
            " OVERWRITE = TRUE ",
            " MAX_FILE_SIZE = 5368709120 ",  // Increase max file size to 5 GB
            " SINGLE = FALSE ",  // Disable single file mode to avoid file size limit
            " HEADER = TRUE;"
        );

        try {
            // Execute the COPY INTO command
            var copyStmt = snowflake.createStatement({sqlText: exportQuery});
            copyStmt.execute();
            message += `Data exported to S3 for table: ${schemaName}.${exportTable}. `;
        } catch (err) {
            // Handle errors for this specific table
            anyFailures = true; // Set the failure flag
            message += `Error exporting table ${schemaName}.${exportTable}: ${err.message}. `;
        }
    }

    // Commit transaction
    var commitStmt = snowflake.createStatement({sqlText: "COMMIT"});
    commitStmt.execute();

    // Set the overall status based on whether any failures occurred
    if (anyFailures) {
        status = "FAILED";
    }

} catch (err) {
    // Rollback transaction in case of error
    try {
        var rollbackStmt = snowflake.createStatement({sqlText: "ROLLBACK"});
        rollbackStmt.execute();
    } catch (rollbackErr) {
        message += `Failed to rollback transaction: ${rollbackErr.message}. `;
    }
    status = "FAILED";
    message += `Error during backup process: ${err.message}`;
}

// Insert log entry
var logQuery = `
INSERT INTO backup_log_table_xyz123 (timestamp, status, message)
VALUES (CURRENT_TIMESTAMP, '${status}', '${message}');
`;
snowflake.execute({sqlText: logQuery});

return message;
$$;
