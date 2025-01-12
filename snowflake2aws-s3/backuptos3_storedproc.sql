CREATE OR REPLACE PROCEDURE backup_data_to_s3()
RETURNS STRING NOT NULL
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
var status = "SUCCESS";
var message = "";
var databaseName = 'DEV_COMMON';
var schemaName = 'DEV_COMMON_ANALYTICS';
var currentDate = new Date().toISOString().slice(0, 10);
var folderName = `bk_${databaseName}_${currentDate}`;
var exportTable = "";
var anyFailures = false;

try {
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

    var beginStmt = snowflake.createStatement({sqlText: "BEGIN"});
    beginStmt.execute();

    for (var i = 0; i < tables.length; i++) {
        exportTable = tables[i];
        var escapedTableName = exportTable.replace(/"/g, '""');
        var fileName = `bk_${databaseName}_${exportTable}_${currentDate}.csv`;
        var s3Path = `${folderName}/${fileName}`;
        var exportQuery = "".concat(
            "COPY INTO @s3_backup_stage/",
            s3Path,
            " FROM ",
            " (SELECT * FROM ",
            databaseName,
            ".",
            '"' + schemaName.replace(/"/g, '""') + '"',
            ".",
            '"' + escapedTableName + '"',
            ") ",
            " FILE_FORMAT = (TYPE = 'CSV', FIELD_OPTIONALLY_ENCLOSED_BY = '\"', NULL_IF = ('') ) ",
            " OVERWRITE = TRUE ",
            " SINGLE = TRUE ",
            " HEADER = TRUE;"
        );
        
        try {
            var copyStmt = snowflake.createStatement({sqlText: exportQuery});
            copyStmt.execute();
            message += `Data exported to S3 for table: ${schemaName}.${exportTable}. `;
        } catch (err) {
            anyFailures = true;
            message += `Error exporting table ${schemaName}.${exportTable}: ${err.message}. `;
        }
    }

    var commitStmt = snowflake.createStatement({sqlText: "COMMIT"});
    commitStmt.execute();

    if (anyFailures) {
        status = "FAILED";
    }

} catch (err) {
    try {
        var rollbackStmt = snowflake.createStatement({sqlText: "ROLLBACK"});
        rollbackStmt.execute();
    } catch (rollbackErr) {
        message += `Failed to rollback transaction: ${rollbackErr.message}. `;
    }
    status = "FAILED";
    message += `Error during backup process: ${err.message}`;
}

var logQuery = `
INSERT INTO backup_log_table_xyz123 (timestamp, status, message)
VALUES (CURRENT_TIMESTAMP, '${status}', '${message}');
`;
snowflake.execute({sqlText: logQuery});

return message;
$$;
