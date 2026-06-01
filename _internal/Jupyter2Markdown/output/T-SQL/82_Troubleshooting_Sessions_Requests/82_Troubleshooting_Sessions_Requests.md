# 82_Troubleshooting_Sessions_Requests

**Quelle:** `T-SQL\82_Troubleshooting_Sessions_Requests\82_Troubleshooting_Sessions_Requests.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 18  
**SQL-Zellen:** 8  

---

# Diagnose von „Previous execution is not yet complete (SqlEditors)“ & Monitoring laufender Requests

Dieses Notebook ist für **Schulungen** gedacht und hilft bei typischen Problemen, die nach einem **Server-Neustart** oder bei „hängenden“ Ausführungen in **SSMS** auftreten.

**Anwendungsfall:** Während eine Abfrage/Stored Procedure lief, wurde der SQL Server neu gestartet. In SSMS erscheint anschließend die Meldung  
> *Previous execution is not yet complete. (SqlEditors)*  

![Fehlermeldung](Error.png)


Dieses Notebook erklärt Ursachen, zeigt Abhilfen und liefert **fertige SQL-Snippets** zur **Sitzungs‑/Request‑Analyse**, **Wartediagnose**, **Blocking-Erkennung** und (falls nötig) dem **gezielten Beenden** einer Session.

> **Kernel-Hinweis:** Dieses Notebook ist für einen **SQL‑Kernel** (z. B. Azure Data Studio) gebaut – **kein Python erforderlich**.



## Was bedeutet die Fehlermeldung? (Kurzfassung)

- Während der vorherigen Ausführung hat **SSMS** die Verbindung verloren (z. B. durch **SQL‑Server‑Neustart** oder Netzwerkunterbrechung).
- Die **UI des SSMS** glaubt, dass die vorherige Anfrage noch läuft und **blockiert** deshalb eine neue Ausführung **im selben Editor-Tab**.
- **Auf Serverseite** existiert die alte Session **nicht mehr** (nach einem Neustart sind alle Sessions beendet). Das Problem ist **clientseitig** (Editorzustand).

**Schnelle Abhilfe (empfohlen):**
1. Im Editor **„Cancel Query“/Abbrechen** klicken (Alt+Break).
2. **Reconnect/Disconnect** in der Statusleiste auslösen **oder** den **Tab schließen** und einen neuen Tab öffnen.
3. Falls das nicht hilft: **SSMS neu starten**.

**Wichtig:** Wenn der Server tatsächlich noch eine lange Anfrage bearbeitet (ohne Neustart), sieht man das in den DMV‑Abfragen unten – dann kann man gezielt beobachten oder beenden.



## Lernziele dieses Notebooks

1. Aktive **Sessions** und **Requests** sicher identifizieren (inkl. **SPID**, Startzeit, Befehl, ggf. **`percent_complete`**).
2. Die **„eigene“ Session** erkennen (nach Login/Host/Programm).
3. **SQL‑Text, Ausführungsplan** und **Warteursachen** laufender Requests untersuchen.
4. **Blocking** und **Latches/Locks** sichtbar machen.
5. Bei Bedarf Requests **kontrolliert beenden** (`KILL SPID`) – mit Vorsicht und Dokumentation.
6. Optional: **Extended Events** zum Mitloggen laufender Stored Procedures.



## 0) Verbindung testen

> Wählen Sie oben die gewünschte **Datenbank-Verbindung** für den SQL‑Kernel aus und führen Sie die folgende Abfrage aus.



```sql
SELECT
    @@SERVERNAME                  AS server_name,
    DB_NAME()                     AS current_database,
    SUSER_SNAME()                 AS login_name,
    HOST_NAME()                   AS host_name,
    PROGRAM_NAME()                AS program_name,
    SYSDATETIMEOFFSET()           AS server_time;

```

## 1) Parameter (einmal setzen)

Passen Sie die folgenden Variablen bei Bedarf an. Die Defaults filtern auf **Ihre aktuelle Session-Umgebung** (Login, Host, SSMS).



```sql
DECLARE @ProcName SYSNAME      = N'dbo.usp_<IhreStoredProcedure>';
DECLARE @LikeText NVARCHAR(200)= N'%usp_<IhreStoredProcedure>%';

DECLARE @MyLogin SYSNAME       = SUSER_SNAME();      -- Ihr Login
DECLARE @MyHost  NVARCHAR(128) = HOST_NAME();        -- Ihr Host
DECLARE @MyProg  NVARCHAR(128) = PROGRAM_NAME();     -- Ihr Client/Programm

-- SSMS-Filter (kann für Azure Data Studio oder andere Tools angepasst werden)
DECLARE @SSMSFilter NVARCHAR(200) = N'%Microsoft SQL Server Management Studio%';

```

## 2) Aktive Requests & Sessions (Überblick)

Liste aller **aktiven Benutzeranfragen** inkl. **SPID, Status, Startzeit, Command**, ggf. **Prozentfortschritt** (nur für bestimmte Operationen verfügbar, z. B. BACKUP/RESTORE/DBCC).



```sql
SELECT
    r.session_id,
    s.login_name, s.host_name, s.program_name,
    r.status, r.command, r.start_time,
    r.percent_complete, r.total_elapsed_time/1000.0 AS elapsed_s,
    r.blocking_session_id,
    DB_NAME(r.database_id)        AS database_name,
    t.text                        AS sql_text
FROM sys.dm_exec_requests AS r
JOIN sys.dm_exec_sessions AS s
  ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE s.is_user_process = 1
ORDER BY r.start_time ASC;

```

### 2a) „Wahrscheinlich meine“ Requests

Filter auf **Ihr Login/Host** und (optional) **SSMS**. So finden Sie Ihre eigenen noch laufenden Sessions schnell.



```sql
SELECT
    r.session_id,
    s.login_name, s.host_name, s.program_name,
    r.status, r.command, r.start_time,
    r.percent_complete, r.total_elapsed_time/1000.0 AS elapsed_s,
    r.blocking_session_id,
    DB_NAME(r.database_id) AS database_name,
    t.text                 AS sql_text
FROM sys.dm_exec_requests AS r
JOIN sys.dm_exec_sessions AS s
  ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE s.is_user_process = 1
  AND s.login_name = @MyLogin
  AND s.host_name  = @MyHost
  AND s.program_name LIKE @SSMSFilter
ORDER BY r.start_time ASC;

```

## 3) Läuft (noch) meine Stored Procedure?

Sucht aktive Requests, deren SQL‑Text **Ihre Prozedur** enthält (heuristisch) **oder** die via **RPC** gestartet wurden.



# sys.dm\_exec\_requests – Statusübersicht

Diese Tabelle fasst die möglichen Werte der Spalte `status` in `sys.dm_exec_requests` zusammen – plus typische Ursachen, Checks und schnelle Maßnahmen.

| Status         | Bedeutung (kurz)                                     | Typische Ursachen/Beispiele                                                                                                   | Primäre Checks (DMVs)                                                                                       | Schnelle Maßnahmen                                                                                                    |
| -------------- | ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| **running**    | Anfrage hat CPU und wird ausgeführt.                 | Operatoren im Plan laufen gerade; Parallelismus aktiv.                                                                        | `sys.dm_exec_requests` (Elapsed, `wait_type` = NULL oder `CX*`), Plan via `sys.dm_exec_query_plan`.         | Beobachten; ggf. Plan prüfen (teure Scans/Sorts), DOP/CPU-Pressure analysieren.                                       |
| **runnable**   | Bereit zur Ausführung, wartet nur auf CPU-Zeit.      | CPU-Pressure, viele parallel laufende Sessions/Abfragen.                                                                      | `sys.dm_os_schedulers` (Runnable Queue), PerfMon CPU; `sys.dm_exec_requests`.                               | Parallelismus begrenzen (`MAXDOP`), Workload drosseln, Pläne optimieren, ggf. Ressourcen erhöhen.                     |
| **suspended**  | Wartet auf Ressource, kann derzeit nicht rechnen.    | Locks (`LCK_M_*`), Memory Grant (`RESOURCE_SEMAPHORE`), I/O (`PAGEIOLATCH_*`, `READ/WRITELOG`), TempDB-Latches, `THREADPOOL`. | `sys.dm_exec_requests.wait_type`, `sys.dm_os_waiting_tasks`; bei Locks: `sys.dm_tran_locks`, Blocker-Kette. | Nach Ursache handeln: Blocker identifizieren/auflösen; Pläne/Statistiken/Indizes optimieren; TempDB/IO/Memory prüfen. |
| **background** | Interne Hintergrundaufgabe.                          | Deadlock-Checker, Ghost-Cleanup u. a. System-Tasks.                                                                           | `sys.dm_exec_sessions`/`requests` (SPID ≤ 50 häufig System), `program_name`.                                | Normalfall: ignorieren; nicht beenden.                                                                                |
| **sleeping**   | Request inaktiv; wartet auf neuen Batch des Clients. | Session ist offen, aber kein aktiver Request.                                                                                 | `sys.dm_exec_sessions` (Session-Infos), `open_transaction_count`.                                           | Unkritisch; ggf. idles schließen, Transaktionen prüfen.                                                               |
| **rollback**   | Server führt Rollback einer Transaktion durch.       | `KILL` ausgelöst, Fehler im Batch, Crash-Recovery/Undo-Phase.                                                                 | `sys.dm_exec_requests.percent_complete`, `sys.dm_tran_active_transactions`, Errorlog.                       | Abwarten (kann dauern); große Transaktionen vermeiden; Batching/Checkpoints/Log-Größe beachten.                       |

## Hinweise

* **Nur laufende/wartende Requests** erscheinen in `sys.dm_exec_requests`. *Schlafende Sessions* sieht man primär in `sys.dm_exec_sessions` – sie können aber als `sleeping` auftauchen, wenn ein Request-Context vorhanden ist.
* Für *SUSPENDED* ist der **`wait_type`** der Schlüssel zur Diagnose. Ergänzend: `blocking_session_id`, `wait_time`, Plan und SQL-Text.
* Bei Rollbacks zeigt `percent_complete` Fortschritt an – Geduld; Abbruch beschleunigt Rollbacks nicht.

## Nützliche Snippets


## 4) Warteursachen & Blocking erkennen

### 4a) Warten/Locks pro aktivem Request



```sql
SELECT
    r.session_id,
    r.status,
    r.wait_type, r.wait_time, r.last_wait_type,
    r.blocking_session_id,
    DB_NAME(r.database_id) AS database_name,
    t.text AS sql_text
FROM sys.dm_exec_requests AS r
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.session_id > 50  -- System-Sessions ausblenden
ORDER BY r.wait_time DESC;

```

### 4b) Wer blockiert wen? (inkl. Hierarchie)



## 5) SQL‑Text & Ausführungsplan einsehen

Hilft beim Verständnis, **wo Zeit verbracht wird**.



```sql
SELECT TOP (20)
    r.session_id, r.status, r.command, r.start_time,
    DB_NAME(r.database_id) AS database_name,
    t.text                  AS sql_text,
    qp.query_plan
FROM sys.dm_exec_requests AS r
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) AS qp
WHERE r.session_id > 50
ORDER BY r.start_time ASC;

```

## 6) Aktive Transaktionen (Log-Nutzung, Dauer)

Zeigt **Transaktionsstart**, **Status** und **Log-Verbrauch**; hilfreich, wenn **lange Transaktionen** das Log belegen.



```sql
SELECT
    at.transaction_id,
    at.name,
    at.transaction_begin_time,
    at.transaction_type,   -- 1 Read/Write, 2 Read-only, 3 System, 4 Distributed
    at.transaction_state,  -- 0 Not initialized, 1 Initialized, 2 Active, 3 Ended, 4 Distributed init, 5 Prepared, 6 Committed, 7 Rolled back, 8 Committing
    dt.database_id, DB_NAME(dt.database_id) AS database_name,
    dt.database_transaction_log_bytes_used/1024/1024.0 AS log_used_MB
FROM sys.dm_tran_active_transactions AS at
JOIN sys.dm_tran_database_transactions AS dt
  ON dt.transaction_id = at.transaction_id
ORDER BY at.transaction_begin_time;

```

## 7) Fortschritt (nur für bestimmte Operationen)

`percent_complete` ist nur bei manchen Befehlen vorhanden (z. B. **BACKUP/RESTORE/DBCC/ALTER INDEX/DBCC CHECKDB**). Normale SELECT/INSERT/UPDATE/DELETE liefern **keinen Fortschrittswert**.



```sql
SELECT
    r.session_id, r.command, r.status, r.percent_complete,
    r.start_time, r.total_elapsed_time/1000.0 AS elapsed_s,
    DB_NAME(r.database_id) AS database_name
FROM sys.dm_exec_requests AS r
WHERE r.percent_complete > 0
ORDER BY r.start_time;

```

## 8) Session gezielt beenden (nur wenn nötig)

> **Vorsicht:** `KILL <SPID>` rollt die **aktuelle Transaktion** der Session zurück und kann **lange dauern**. Immer dokumentieren!

1. Ermitteln Sie die **korrekte SPID** (z. B. aus Abschnitt 2/3).
2. **Transaktions-/Auswirkungsanalyse** in Abschnitt 6 durchführen.
3. Erst dann beenden:



## 9) Optional: Lightweight‑Tracing per Extended Events

Mit **Extended Events** können Sie Prozedurstarts/-enden und SQL‑Statements **serverseitig** aufzeichnen – hilfreich, wenn Sie **Messages** des Clients (PRINT/RAISERROR) nicht sehen können.

> Hinweis: Es gibt kein natives „PRINT“-Event. Nutzen Sie **`RAISERROR (..., 0, 1) WITH NOWAIT`** in Ihrer Prozedur für Fortschrittsmarken oder loggen Sie in eigene Tabellen.



## 10) FAQ zur ursprünglichen Frage

**Q1: Wie kommt es dazu? Was bedeutet es?**  
- Nach einem **Server-Neustart** ist die alte Anfrage **serverseitig beendet**. Die SSMS‑UI hält aber am Editorzustand fest und verhindert eine neue Ausführung im selben Tab (siehe Intro).

**Q2: Wie finde ich die ID (SPID) der „alten“ Ausführung?**  
- Nach **Serverneustart existiert diese Session nicht mehr** – sie ist **weg**. Sie können nur **laufende** Sessions via DMV sehen (Abschnitt 2/3).  
- Wenn Sie **dauerhaft nachverfolgen** wollen, nutzen Sie **Tabellen-Logging** (in der Prozedur) oder **Extended Events** (Abschnitt 9).

**Q3: Kann ich mich an die alte Ausführung „anhängen“, um Messages zu sehen?**  
- **Nein.** Es gibt **keinen** Weg, die Ausgabe eines **fremden (oder beendeten)** Clients anzuzeigen.  
- Nutzen Sie **serverseitiges Logging** (Tabelle/Extended Events) oder `RAISERROR(...,0,1) WITH NOWAIT` in der Prozedur, um Fortschritt **serverseitig** zu erfassen.



## 11) Best Practices für robuste Langläufer

- In langen Prozeduren regelmäßig **Fortschritt loggen** (Tabelle mit `ExecutionID`, `Step`, `Message`, `InsertDate`).
- Für „Live“-Fortschritt `RAISERROR (N'<marker>', 0, 1) WITH NOWAIT` verwenden (kommt sofort beim Client an).  
- **Batches** und **kurze Transaktionen** statt eines großen Monolithen – bei Abbruch nur der laufende Batch wird zurückgerollt.
- SSMS‑„Stuck“-Zustände vermeiden: **Tab schließen/neu öffnen**, **Reconnect**, **SSMS updaten**.
- Für Monitoring **DMVs** und **Extended Events** standardmäßig in ein Admin‑Skript integrieren.


