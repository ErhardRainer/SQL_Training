Dieses Projekt ist eine Sammlung von Schulungsunterlagen und Beispielen, die ich über die Jahre für verschiedene Zwecke erstellt und weiterentwickelt habe. Es dient nicht nur als Lehrmaterial für meine Studenten, sondern auch als praktische Wissensbasis für meine tägliche Consulting-Tätigkeit. Darüber hinaus nutze ich diese Themen, um fundierte Fragen für Assessment-Center auszuarbeiten und so die fachlichen Fähigkeiten von Kandidaten zu bewerten.

Die hier vorliegenden Inhalte sind das Ergebnis jahrelanger manueller Arbeit. Jedes Kapitel wurde sorgfältig konzipiert und geschrieben, um komplexe Themen verständlich zu machen. Im Jahr 2025 wurden einige dieser Kapitel mithilfe von speziell entwickelten Custom GPTs verfeinert, um die Erklärungen zu präzisieren, die Beispiele zu erweitern und die Vollständigkeit sicherzustellen. Die manuelle, praxisorientierte Ausarbeitung bleibt jedoch das Herzstück dieses Projekts.

Ich hoffe, die Unterlagen sind für euch ebenso nützlich, wie sie es für mich und meine Studenten sind.

# SQL Training – Übersicht
Dieses Repository bietet eine strukturierte Einführung in T-SQL. Die Kapitel 00–30 bilden das Basiswissen, 60+ sind optionale Spezialthemen.
---

## Basis-Kapitel (00–30)

- [01_Normalformen](https://github.com/ErhardRainer/SQL_Training/tree/main/T-SQL/01_Normalformen)  
  Grundlagen der Datenbankmodellierung – Normalformen zur Vermeidung von Redundanzen.

- [02_Select](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/02_Select/02_Select.md)  
  `SELECT`-Grundlagen, Spaltenprojektion, Alias, einfache Sortierung.

- [03_JOIN](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/03_JOIN/03_Join.md)  
  Tabellenverknüpfungen: `INNER`, `LEFT/RIGHT`, `FULL OUTER`, Anti-/Semi-Joins.

- [04_Where](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/04_Where/04_WHERE.md)  
  Zeilenfilterung mit Operatoren, `LIKE`, `BETWEEN`, `IN`, `NULL`-Vergleiche.

- [05_Funktionen](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/05_Funktionen/05_Funktionen.md)  
  String-, Datums-, numerische Funktionen; `CASE` und bedingte Logik.

- [06_Delete](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/06_Delete/06_Delete.md)  
  Datensätze sicher löschen; `TOP`, `OUTPUT`, Transaktionssicherheit.

- [07_Insert](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/07_Insert/07_Insert.md)  
  Einfügen mit `INSERT … VALUES/SELECT`, Default-Werte, `IDENTITY`.

- [08_Update](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/08_Update/08_Update.md)  
  Aktualisieren bestehender Daten mit `UPDATE`, Join-Update, `OUTPUT`, Integritätsaspekte.

- [09_Set_Operations](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/09_Set_Operations/09_Set_Operations.md)  
  Mengenoperatoren: `UNION [ALL]`, `INTERSECT`, `EXCEPT`, Duplikatregeln.

- [10_GroupBy_Aggregate](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/10_GroupBy_Aggregate/10_GroupBy_Aggregate.md)  
  Gruppierungen mit `GROUP BY`, Aggregatfunktionen, `HAVING`.

- [11_WindowFunctions](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/11_WindowFunctions/11_WindowFunctions.md)  
  Analytische Funktionen mit `OVER()`: `ROW_NUMBER()`, `RANK()`, `LAG/LEAD`.

- [12_DataTypes_Conversion](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/12_DataTypes_Conversion/12_DataTypes_Conversion.md)  
  Datentypen, `CAST/CONVERT`, Präzision/Skalen, implizite Konvertierungen.

- [13_Merge](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/13_Merge/13_Merge.md)  
  Upsert-Szenarien mit `MERGE` (Insert/Update/Delete), typische Fallstricke.

- [14_Pivot_Unpivot](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/14_Pivot_Unpivot/14_Pivot_Unpivot.md)  
  Quer-/Längstransformationen von Daten mit `PIVOT` und `UNPIVOT`.

- [15_SearchInTables](https://github.com/ErhardRainer/SQL_Training/tree/main/T-SQL/15_SearchInTables)  
  Techniken zum Durchsuchen von Tabellen/Spalten, Metadaten-Abfragen.

- [16_DataIntegrity_Constraints](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/16_DataIntegrity_Constraints/16_DataIntegrity_Constraints.md)  
  Schlüssel und Constraints: `PRIMARY KEY`, `FOREIGN KEY`, `CHECK`, `DEFAULT`.

- [17_ANIS_NULL_&_Co](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/17_ANSI_NULL%20%26%20Co/17_ANSI_NULL.md)  
  Arbeiten mit `NULL`: `IS NULL`, `ISNULL`, `COALESCE`, Dreiwertige Logik.

- [18_Cube_Rollup](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/18_Cube_Rollup/18_Cube_Rollup.md)  
  Erweiterte Aggregationen: `GROUP BY GROUPING SETS`, `ROLLUP`, `CUBE`.

- [19_Transactions](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/19_Transaktions/19_Transactions.md)  
  `BEGIN/COMMIT/ROLLBACK`, Fehlerfälle, saubere Transaktionsgrenzen.

- [20_Create_Database](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/20_Create_Database/20_Create_Database.md)  
  Datenbanken/Objekte anlegen: `CREATE DATABASE`, Schemata, grundlegende DDL.

- [21_QUOTED_IDENTIFIER](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/21_QUOTED_IDENTIFIER/21_Quoted_Identifier.md)  
  Wirkung von `QUOTED_IDENTIFIER` auf Identifikatoren und Anweisungen.

- [22_Views_Schemata](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/22_Views_Schemata/22_Views_Schemata.md)  
  Erstellung von Views, Einsatzbereiche, Sicherheitsaspekte.

- [23_StoredProcedures](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/23_StoredProcedures/23_StoredProcedures.md)  
  Einführung in Stored Procedures, Parameter, Resultsets.

- [24_UserDefinedFunctions](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/24_UserDefinedFunctions/24_UserDefinedFunctions.md)  
  Skalare und table-valued Funktionen, typische Anwendungsfälle.

- [25_ErrorHandling_TryCatch](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/25_ErrorHandling_TryCatch/25_ErrorHandling_TryCatch.md)  
  Fehlerbehandlung mit `TRY…CATCH`, `THROW/RAISERROR`, Logging.

- [26_Indexes_Basics](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/26_Indexes_Basics/26_Indexes_Basics.md)  
  Clustered/NONCLUSTERED Indizes, Schlüssel/Include, Performancegrundlagen.

- [27_ExecutionPlans_Basics](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/27_ExecutionPlans_Basics/27_ExecutionPlans_Basics.md)  
  Execution Plans lesen und verstehen, Kardinalitätsschätzung.

- [28_JSON_XML_Basics](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/28_JSON_XML_Basics/28_JSON_XML_Basics.md)  
  Grundlagen zu `JSON` und `XML` in SQL Server.

- [29_DateTime_Calendar](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/29_DateTime_Calendar/29_DateTime_Calendar.md)  
  Datumslogik: Zeiträume, Kalenderfunktionen, dynamische Zeitfilter.

- [30_BulkLoad_BCP_BULKINSERT](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/30_BulkLoad_BCP_BULKINSERT/30_BulkLoad_BCP_BULKINSERT.md)  
  Import/Export von Daten: `BULK INSERT`, BCP, Performance-Aspekte.

---

## Spezial-Kapitel (60+)

- [60_IsolationLevels](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/60_IsolationLevels/60_IsolationLevels.md)  
  Isolationsstufen, Sperrverhalten, Nebenläufigkeit und Anomalien.

- [61_SubQuery_CTE_TMP](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/61_SubQuery_CTE_TMP/61_SubQuery_CTE_TMP.md)  
  Unterabfragen, `WITH CTE`, temporäre Tabellen/Tabellenvariablen.

- [62_Row_Level_Security](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/62_Row_Level_Security/62_Row_Level_Security.md)  
  Zeilenbasierte Sicherheit in SQL Server: Policies, Predicates, Performance.

- [63_Collation_Case_Sensitive](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/63_Collation_Case_Sensitive/63_Collation_Case_Sensitive.md)  
  Sortierfolgen/Collations, `CI` vs. `CS`, Auswirkungen auf Vergleiche und Joins.

- [64_PerformanceTuning_Advanced](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/64_PerformanceTuning_Advanced/64_PerformanceTuning_Advanced.md)  
  Erweiterte Performance-Optimierung, Query Store, Parameter-Sniffing.

- [65_Partitioning](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/65_Partitioning/65_Partitioning.md)  
  Partitionierte Tabellen und Indizes, Switch-Strategien.

- [66_Security_Roles_Permissions](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/66_Security_Roles_Permissions/66_Security_Roles_Permissions.md)  
  Rollenmodell, Rechteverwaltung, Best Practices für Security.

- [67_HA/DR & Replikation](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/67_HA_DR/HA_DR.md)  
  Hochverfügbarkeit & Disaster Recovery (AGs, Distributed AGs, Failover Cluster Instance, Log Shipping, (t-)Replikation, Peer-to-Peer, Legacy Mirroring).

- [68_TemporalTables_CDC_CT](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/68_TemporalTables_CDC_CT/68_TemporalTables_CDC_CT.md)  
  Historisierung mit system-versionierten Tabellen, Change Tracking, CDC.
  
- [69_ServiceBroker_Queues](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/69_ServiceBroker_Queues/69_ServiceBroker_Queues.md)  
  Message-basierte Verarbeitung in SQL Server.

- [70_ExternalTables_PolyBase](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/70_ExternalTables_PolyBase/70_ExternalTables_PolyBase.md)  
  Zugriff auf externe Datenquellen über PolyBase/External Tables.

- [71_BackupRestore_Strategies](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/71_BackupRestore_Strategies/71_BackupRestore_Strategies.md)  
  Backup-Typen, Recovery-Modelle, Point-in-Time-Restores, Log-Ketten & Copy-Only.

- [72_SQLAgent_Jobs_Alerts](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/72_SQLAgent_Jobs_Alerts/72_SQLAgent_Jobs_Alerts.md)  
  Automatisierung mit SQL Agent: Jobs, Schedules, Alerts.

- [73_TVPs_TableTypes](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/73_TVPs_TableTypes/73_TVPs_TableTypes.md)  
  Table-Valued Parameters, effiziente Schnittstellen für Prozeduren.

- [74_SnapshotIsolation_Concurrency](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/74_SnapshotIsolation_Concurrency/74_SnapshotIsolation_Concurrency.md)  
  `RCSI`, `Snapshot Isolation`, Auswirkungen auf TempDB.

- [75_SSVEPatterns_for_ETL](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/75_SSVEPatterns_for_ETL/75_SSVEPatterns_for_ETL.md)  
  Best Practices für ETL-Prozesse, Idempotenz, Wasserzeichen, Checksummen.

- [76_Spatial_Geography](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/76_Spatial_Geography/76_Spatial_Geography.md)  
  Arbeiten mit Geo-/Spatial-Daten, Indizes, Abfragen.

- [77_JSON_ETL_Practices](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/77_JSON_ETL_Practices/77_JSON_ETL_Practices.md)  
  Verarbeitung von JSON-Daten, Validierung, Fehlertoleranz.

- [78_ColumnstoreIndexes](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/78_ColumnstoreIndexes/78_ColumnstoreIndexes.md)  
  OLAP-optimierte Indizes, Batch Mode Processing, Data Warehousing.

- [79_TSQL_Testing](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/79_TSQL_Testing/79_TSQL_Testing.md)  
  Unit-Testing in T-SQL (z. B. mit tSQLt).

- [80_AzureSQL_Differences](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/80_AzureSQL_Differences/80_AzureSQL_Differences.md)  
  Unterschiede On-Premises vs. Azure SQL, spezielle Features.

- [81_InMemory_OLTP](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/81_InMemory_OLTP/81_InMemory_OLTP.md)  
  Memory-Optimized Tables, Natively Compiled Procedures.

- [82_Troubleshooting_Sessions_Requests](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/82_Troubleshooting_Sessions_Requests/82_Troubleshooting_Sessions_Requests.md)  
  Client-/Session-Troubleshooting und Monitoring (DMVs/XE).

---

## Materialien

- **Präsentation:** [Vorlesung_Präsentation.pptx](https://github.com/ErhardRainer/SQL_Training/blob/main/T-SQL/Vorlesung_Pr%C3%A4sentation.pptx)

---
## Anmerkung
Hier sind die spezifischen Custom GPTs, die dabei zum Einsatz kamen:

GPT-1: [SQL Begriffsdefinitionen& Übersicht (für die md-Seiten)](https://chatgpt.com/g/g-68bacb69b10c8191bc2b6eff411b05c2-arbeit-sql-begriffsdefinitionen-ubersicht)

GPT-2: [Generierung von JupyterNotebooks aus Code-Schnippsel](https://chatgpt.com/g/g-68bb64075e50819186be5a86d9d13464-arbeit-sql-jupyter-notebooks/)

Der manuelle Aufwand für die Erstellung der ursprünglichen Materialien war enorm und bildet das Fundament dieses Projekts. Die KI-Unterstützung diente lediglich dazu, das bereits vorhandene Material zu optimieren und zu ergänzen.

Ich hoffe, die Unterlagen helfen euch weiter!
