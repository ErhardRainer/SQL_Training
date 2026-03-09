# IndexUsage.sql

This script helps DBAs and developers analyze how a specific column is used
in the indexes of a table. It accepts three parameters (`SchemaName`,
`TableName`, and `ColumnName`), locates the corresponding object, and then
queries the system catalog views to find:

- indexes where the column appears in the key columns
- indexes where the column is included as a non‑key column
- filtered indexes whose predicate references the column
- indexes that include computed columns which depend on the column

The result set returns comprehensive metadata about each matching index,
including a dynamically generated `CREATE INDEX` statement that can be used
to recreate the index. The goal is to quickly identify and document all
indexes that affect or could benefit from the specified column.