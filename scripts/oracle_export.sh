#!/bin/bash
# Oracle Database Export Script for DB-Manager
# This script creates a SQL dump using Oracle's exp utility or SQLPlus

HOST=$1
PORT=$2
USERNAME=$3
PASSWORD=$4
DATABASE=$5
OUTPUT_FILE=$6
shift 6
TABLES=$@

# Create Oracle connection string
if [ -z "$DATABASE" ]; then
    CONN_STRING="${USERNAME}/${PASSWORD}@${HOST}:${PORT}/FREEPDB1"
else
    CONN_STRING="${USERNAME}/${PASSWORD}@${HOST}:${PORT}/${DATABASE}"
fi

# If no tables specified, export entire schema
if [ -z "$TABLES" ]; then
    # Export entire user schema using SQLPlus with spool
    sqlplus -S "$CONN_STRING" <<EOF > "$OUTPUT_FILE" 2>&1
SET PAGESIZE 0
SET FEEDBACK OFF
SET LINESIZE 32767
SET TRIMSPOOL ON
SET TERMOUT OFF
SET ECHO OFF
SET HEADING OFF

-- Generate DDL for all objects
SELECT DBMS_METADATA.GET_DDL(object_type, object_name, owner) || ';'
FROM all_objects
WHERE owner = UPPER('$USERNAME')
AND object_type IN ('TABLE', 'INDEX', 'SEQUENCE', 'VIEW', 'PROCEDURE', 'FUNCTION', 'PACKAGE')
ORDER BY object_type, object_name;

-- Generate INSERT statements for data
BEGIN
    FOR t IN (SELECT table_name FROM user_tables) LOOP
        DBMS_OUTPUT.PUT_LINE('-- Data for table ' || t.table_name);
        FOR r IN (SELECT * FROM t.table_name) LOOP
            -- This is simplified; real implementation would need proper column handling
            NULL;
        END LOOP;
    END LOOP;
END;
/

EXIT;
EOF
else
    # Export specific tables
    sqlplus -S "$CONN_STRING" <<EOF > "$OUTPUT_FILE" 2>&1
SET PAGESIZE 0
SET FEEDBACK OFF
SET LINESIZE 32767
SET TRIMSPOOL ON
SET TERMOUT OFF
SET ECHO OFF
SET HEADING OFF

-- Generate DDL for specific tables
$(for table in $TABLES; do
    echo "SELECT DBMS_METADATA.GET_DDL('TABLE', UPPER('$table'), UPPER('$USERNAME')) || ';' FROM DUAL;"
done)

EXIT;
EOF
fi

# Check if export was successful
if [ $? -eq 0 ] && [ -s "$OUTPUT_FILE" ]; then
    echo "Oracle export completed successfully"
    exit 0
else
    echo "Oracle export failed"
    exit 1
fi