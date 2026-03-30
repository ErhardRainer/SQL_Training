

Wie du das Ergebnis liest

Sync läuft grundsätzlich

is_data_lake_replication_enabled = 1

sp_help_change_feed_settings liefert normale Settings und reseed_state = 0

in sys.dm_change_feed_log_scan_sessions ist entweder end_time IS NULL oder currently_processed_commit_time ist frisch

error_count = 0 bzw. sys.dm_change_feed_errors ist leer

in sp_help_change_feed stehen die Tabellen auf state = 4 (Active)

Sync hängt oder steht

currently_processed_commit_time ist alt

failed_sessions_count oder error_count steigt

sys.dm_change_feed_errors enthält aktuelle Fehler

reseed_state ist 1 oder 2, oder Tabellen stehen auf state = 7 (Reseeding)

Wichtig zur Interpretation

Die Spalten tran_count und command_count zeigen, dass in den Log-Scan-Sessions tatsächlich Änderungen verarbeitet wurden; currently_processed_commit_time ist der stärkste direkte Hinweis darauf, wann zuletzt Commit-Änderungen durch den Change Feed verarbeitet wurden. Meine SyncHealth-Ampel mit @StaleMinutes = 15 ist dabei eine praktische Heuristik, kein offizieller Microsoft-Statuswert. Die offiziellen Rohsignale sind end_time, currently_processed_commit_time, tran_count, command_count, latency und die Fehler-DMV.
Ja. Das erklärt den Fehler sauber:

is_change_feed_enabled gibt es erst ab SQL Server 2022+, is_data_lake_replication_enabled erst ab SQL Server 2025+ bzw. Azure SQL DB / MI. Für Fabric Mirroring aus SQL Server 2016–2022 verwendet Microsoft CDC, nicht den neuen Change-Feed-Mechanismus. Deshalb ist auf älteren SQL-Server-Versionen die richtige Prüfschiene CDC, nicht is_data_lake_replication_enabled.

Wenn eure Quelle also ein klassischer SQL Server 2016/2017/2019/2022 ist, dann ist diese Query die passendere Antwort auf deine eigentliche Frage: Läuft der Sync noch und werden Änderungen noch aus BI_DWH ausgelesen?
Die maßgeblichen Signale sind dabei:

is_cdc_enabled auf DB-Ebene,

is_tracked_by_cdc auf Tabellenebene,

die letzten Sessions aus sys.dm_cdc_log_scan_sessions,

Fehler aus sys.dm_cdc_errors,

sowie die CDC-Capture-/Cleanup-Jobs über sys.sp_cdc_help_jobs.
Microsoft dokumentiert außerdem explizit, dass Mirroring aus SQL Server 2016–2022 CDC nutzt und dass aktive Transaktionen das Log so lange festhalten können, bis der Mirroring-/CDC-Leser aufgeholt hat.