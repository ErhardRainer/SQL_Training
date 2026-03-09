SELECT
    d.name AS DatabaseName,
    d.state_desc,
    d.recovery_model_desc,
    ls.total_log_size_mb,
    ls.active_log_size_mb,
    CAST(
        CASE
            WHEN ls.total_log_size_mb > 0
                THEN (ls.active_log_size_mb * 100.0) / ls.total_log_size_mb
            ELSE 0
        END
        AS DECIMAL(10,2)
    ) AS LogUsedPct,
    d.log_reuse_wait_desc,
    ls.log_truncation_holdup_reason,
    ls.log_since_last_log_backup_mb,
    ls.log_backup_time,
    CASE d.log_reuse_wait_desc
        WHEN 'NOTHING' THEN 'Der Log kann wiederverwendet werden; akuter Reuse-Blocker ist nicht sichtbar.'
        WHEN 'CHECKPOINT' THEN 'Bei SIMPLE wird Log-Space typischerweise erst nach Checkpoint wiederverwendbar.'
        WHEN 'ACTIVE_TRANSACTION' THEN 'Eine lange/offene Transaktion verhindert die Log-Wiederverwendung.'
        WHEN 'ACTIVE_BACKUP_OR_RESTORE' THEN 'Backup- oder Restore-Vorgang blockiert aktuell die Wiederverwendung.'
        WHEN 'REPLICATION' THEN 'Replikation/Verteilung hält Log-Einträge noch fest.'
        WHEN 'DATABASE_MIRRORING' THEN 'Spiegelung/entsprechende Synchronisation blockiert die Wiederverwendung.'
        WHEN 'AVAILABILITY_REPLICA' THEN 'Eine Availability Replica hält die Wiederverwendung zurück.'
        WHEN 'XTP_CHECKPOINT' THEN 'In-Memory-OLTP-Checkpoint hält die Wiederverwendung zurück.'
        ELSE 'Details über log_reuse_wait_desc bzw. log_truncation_holdup_reason prüfen.'
    END AS Interpretation
FROM sys.databases AS d
CROSS APPLY sys.dm_db_log_stats(d.database_id) AS ls
WHERE d.recovery_model_desc = 'SIMPLE'
ORDER BY
    LogUsedPct DESC,
    ls.active_log_size_mb DESC;