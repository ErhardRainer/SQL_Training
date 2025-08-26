# SQL Training – Übersicht

Dieses Repository bietet eine strukturierte Einführung in **T-SQL**.  
Die Kapitel **00–30** bilden das Basiswissen, **60+** sind optionale Spezialthemen.

---

## Basis-Kapitel (00–30)

- [01_Normalformen](./01_Normalformen/)  
  Grundlagen der Datenbankmodellierung – Normalformen zur Vermeidung von Redundanzen.

- [02_Select](./02_Select/)  
  `SELECT`-Grundlagen, Spaltenprojektion, Alias, einfache Sortierung.

- [03_JOIN](./03_JOIN/)  
  Tabellenverknüpfungen: `INNER`, `LEFT/RIGHT`, `FULL OUTER`, Anti-/Semi-Joins.

- [04_Where](./04_Where/)  
  Zeilenfilterung mit Operatoren, `LIKE`, `BETWEEN`, `IN`, `NULL`-Vergleiche.

- [05_Funktionen](./05_Funktionen/)  
  String-, Datums-, numerische Funktionen; `CASE` und bedingte Logik.

- [06_Delete](./06_Delete/)  
  Datensätze sicher löschen; `TOP`, `OUTPUT`, Transaktionssicherheit.

- [07_Insert](./07_Insert/)  
  Einfügen mit `INSERT … VALUES/SELECT`, Default-Werte, `IDENTITY`.

- [08_Update](./08_Update/)  
  Aktualisieren bestehender Daten mit `UPDATE`, Join-Update, `OUTPUT`, Integritätsaspekte.

- [09_Set_Operations](./09_Set_Operations/)  
  Mengenoperatoren: `UNION [ALL]`, `INTERSECT`, `EXCEPT`, Duplikatregeln.

- **10_GroupBy_Aggregate**  
  Gruppierungen mit `GROUP BY`, Aggregatfunktionen, `HAVING`.

- **11_WindowFunctions**  
  Analytische Funktionen mit `OVER()`: `ROW_NUMBER()`, `RANK()`, `LAG/LEAD`.

- **12_DataTypes_Conversion**  
  Datentypen, `CAST/CONVERT`, Präzision/Skalen, implizite Konvertierungen.

- [13_Merge](./13_Merge/)  
  Upsert-Szenarien mit `MERGE` (Insert/Update/Delete), typische Fallstricke.

- [14_Pivot_Unpivot](./14_Pivot_Unpivot/)  
  Quer-/Längstransformationen von Daten mit `PIVOT` und `UNPIVOT`.

- [15_SearchInTables](./15_SearchInTables/)  
  Techniken zum Durchsuchen von Tabellen/Spalten, Metadaten-Abfragen.

- [17_ANIS_NULL_&_Co](./17_ANIS_NULL_%26_Co/)  
  Arbeiten mit `NULL`: `IS NULL`, `ISNULL`, `COALESCE`, Dreiwertige Logik.

- **16_DataIntegrity_Constraints**  
  Schlüssel und Constraints: `PRIMARY KEY`, `FOREIGN KEY`, `CHECK`, `DEFAULT`.

- [18_Cube_Rollup](./18_Cube_Rollup/)  
  Erweiterte Aggregationen: `GROUP BY GROUPING SETS`, `ROLLUP`, `CUBE`.

- [19_Transactions](./19_Transactions/)  
  `BEGIN/COMMIT/ROLLBACK`, Fehlerfälle, saubere Transaktionsgrenzen.

- [20_Create_Database](./20_Create_Database/)  
  Datenbanken/Objekte anlegen: `CREATE DATABASE`, Schemata, grundlegende DDL.

- [21_QUOTED_IDENTIFIER](./21_QUOTED_IDENTIFIER/)  
  Wirkung von `QUOTED_IDENTIFIER` auf Identifikatoren und Anweisungen.

- **22_Views_Schemata**  
  Erstellung von Views, Einsatzbereiche, Sicherheitsaspekte.

- **23_StoredProcedures**  
  Einführung in Stored Procedures, Parameter, Resultsets.

- **24_UserDefinedFunctions**  
  Skalare und table-valued Funktionen, typische Anwendungsfälle.

- **25_ErrorHandling_TryCatch**  
  Fehlerbehandlung mit `TRY…CATCH`, `THROW/RAISERROR`, Logging.

- **26_Indexes_Basics**  
  Clustered/NONCLUSTERED Indizes, Schlüssel/Include, Performancegrundlagen.

- **27_ExecutionPlans_Basics**  
  Execution Plans lesen und verstehen, Kardinalitätsschätzung.

- **28_JSON_XML_Basics**  
  Grundlagen zu `JSON` und `XML` in SQL Server.

- **29_DateTime_Calendar**  
  Datumslogik: Zeiträume, Kalenderfunktionen, dynamische Zeitfilter.

- **30_BulkLoad_BCP_BULKINSERT**  
  Import/Export von Daten: `BULK INSERT`, BCP, Performance-Aspekte.

---

## Spezial-Kapitel (60+)

- [60_IsolationLevels](./60_IsolationLevels/)  
  Isolationsstufen, Sperrverhalten, Nebenläufigkeit und Anomalien.

- [61_SubQuery_CTE_TMP](./61_SubQuery_CTE_TMP/)  
  Unterabfragen, `WITH CTE`, temporäre Tabellen/Tabellenvariablen.

- [62_Row_Level_Security](./62_Row_Level_Security/)  
  Zeilenbasierte Sicherheit in SQL Server: Policies, Predicates, Performance.

- [63_Collation_Case_Sensitive](./63_Collation_Case_Sensitive/)  
  Sortierfolgen/Collations, `CI` vs. `CS`, Auswirkungen auf Vergleiche und Joins.

- **64_PerformanceTuning_Advanced**  
  Erweiterte Performance-Optimierung, Query Store, Parameter-Sniffing.

- **65_Partitioning**  
  Partitionierte Tabellen und Indizes, Switch-Strategien.

- **66_Security_Roles_Permissions**  
  Rollenmodell, Rechteverwaltung, Best Practices für Security.

- **67_TemporalTables_CDC_CT**  
  Historisierung mit system-versionierten Tabellen, Change Tracking, CDC.

- **68_InMemory_OLTP**  
  Memory-Optimized Tables, Natively Compiled Procedures.

- **69_ServiceBroker_Queues**  
  Message-basierte Verarbeitung in SQL Server.

- **70_ExternalTables_PolyBase**  
  Zugriff auf externe Datenquellen über PolyBase/External Tables.

- **71_BackupRestore_Strategies**  
  Backup-Typen, Recovery-Modelle, Point-in-Time-Restores.

- **72_SQLAgent_Jobs_Alerts**  
  Automatisierung mit SQL Agent: Jobs, Schedules, Alerts.

- **73_TVPs_TableTypes**  
  Table-Valued Parameters, effiziente Schnittstellen für Prozeduren.

- **74_SnapshotIsolation_Concurrency**  
  `RCSI`, `Snapshot Isolation`, Auswirkungen auf TempDB.

- **75_SSVEPatterns_for_ETL**  
  Best Practices für ETL-Prozesse, Idempotenz, Wasserzeichen, Checksummen.

- **76_Spatial_Geography**  
  Arbeiten mit Geo-/Spatial-Daten, Indizes, Abfragen.

- **77_JSON_ETL_Practices**  
  Verarbeitung von JSON-Daten, Validierung, Fehlertoleranz.

- **78_ColumnstoreIndexes**  
  OLAP-optimierte Indizes, Batch Mode Processing, Data Warehousing.

- **79_TSQL_Testing**  
  Unit-Testing in T-SQL (z. B. mit tSQLt).

- **80_AzureSQL_Differences**  
  Unterschiede On-Premises vs. Azure SQL, spezielle Features.

---

## Materialien

- **Präsentation:** [Vorlesung_Präsentation.pptx](./Vorlesung_Pr%C3%A4sentation.pptx)

---
