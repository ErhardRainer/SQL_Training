# Active Transactions

Dieses Thema ist fuer den Fall gedacht, dass `sys.databases.log_reuse_wait_desc`
den Wert `ACTIVE_TRANSACTION` liefert.

Das passende Diagnose-Script liegt hier:

- [`../SQLScripts/ListActiveTransactions_LogReuseWait.sql`](../SQLScripts/ListActiveTransactions_LogReuseWait.sql)

Das Script liefert drei Result Sets:

1. Eine Uebersicht pro Datenbank mit Anzahl aktiver Transaktionen,
   aeltester Begin-Zeit und geschaetztem Log-Verbrauch.
2. Pro Datenbank die wahrscheinlich wichtigste Transaktion
   (`oldest_rank = 1`).
3. Eine Detailansicht mit Session, Login, Host, Programm, Waits und
   SQL-Text.

Hinweise:

- Standardmaessig werden nur Datenbanken betrachtet, deren
  `log_reuse_wait_desc = 'ACTIVE_TRANSACTION'` ist.
- Mit `@DatabaseName` kann gezielt eine einzelne Datenbank untersucht
  werden.
- Mit `@OnlyDatabasesWithActiveTransactionWait = 0` kann das Script auch
  fuer allgemeine Transaktionsdiagnosen verwendet werden.
- Fuer die benoetigten DMVs ist `VIEW SERVER STATE` noetig.

## Killed / Rollback Historie

Fuer eine Session, die bereits in `KILLED/ROLLBACK` haengt, gibt es
zusaetzlich dieses Script:

- [`../SQLScripts/MonitorKilledRollbackHistory.sql`](../SQLScripts/MonitorKilledRollbackHistory.sql)
- [`../SQLScripts/SinceWhenRollbackRunning.sql`](../SQLScripts/SinceWhenRollbackRunning.sql)

Es schreibt die Historie in globale Temp-Tabellen:

- `##KillRollbackRequestHistory`
- `##KillRollbackWaitHistory`
- `##KillStatusHistory`

Das Script sampelt standardmaessig alle 2 Sekunden und beendet sich auf
Wunsch automatisch, sobald die Session nicht mehr existiert.
