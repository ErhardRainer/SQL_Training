# 82 – Troubleshooting laufender Sessions & Requests (SSMS / SQL Server)

Dieses Modul hilft dir, **laufende Stored-Procedure-Ausführungen** zu finden, zu analysieren und typische Ursachen für **Hänger / SUSPENDED / Blocking / Memory-Grants** sichtbar zu machen – wahlweise für **eine** oder **mehrere** Sessions. Es besteht aus einem **Jupyter-Notebook** (SQL-Kernel, kein Python nötig) und **SQL-Skripten**.

---

## Inhalte

### 1) Jupyter-Notebook (SQL-Kernel)

* **Datei:** `82_Troubleshooting_Sessions_Requests.ipynb`
* **Zweck:** Geführte Diagnose mit kommentierten T-SQL-Zellen: Verbindungstest, Session/Request-Übersicht, Waits/Blocking, Plan-Einsicht, Memory-Grants, Transaktionen, optionale Extended-Events (Ringbuffer).
* **Einsatz:** Ideal für **Schulungen** und Live-Analysen in **Azure Data Studio** (Kernel „SQL“) oder jeder Jupyter-Umgebung mit SQL-Kernel.

### 2) SQL-Skripte

* **`82_Troubleshooting_Sessions_Request_Full.sql`** – *Einzelsession-Fokus*:
  Findet **genau eine** Ziel-Session anhand eines Suchmusters/Prozedurnamens und liefert zwei **Summary-Resultsets** (Request/Plan/Memory + Transaktionen).
* **`Check_sp.sql`** – *Multi-Session-Variante*:
  Ermittelt **mehrere** passende Sessions (limitierbar) und gibt die beiden **Summaries für alle** Kandidaten aus – sinnvoll bei parallelen Läufen oder weiten Textmustern.

---

## Quick Start

### Notebook

1. **Azure Data Studio** öffnen → **Open File** → `82_Troubleshooting_Sessions_Requests.ipynb`.
2. Oben **SQL-Verbindung** wählen.
3. Zellen von oben nach unten ausführen und – falls nötig – die Parameterzelle anpassen (`@ProcName`, `@LikeText`, Zeitfenster, etc.).

### SQL-Skripte

In SSMS/ADS öffnen und folgende **Parameter** setzen (Beispiel):

```sql
-- Minimal:
DECLARE @ProcName SYSNAME       = N'dbo.usp_Lookup_LW_Order_LW';
DECLARE @LikeText NVARCHAR(200) = N'%usp_Lookup_LW_Order_LW%';

-- Optional (Multi-Variante, Check_sp.sql):
DECLARE @TimeWindowMin INT = 240;  -- nur Anfragen der letzten 240 Minuten
DECLARE @ExcludeSelf   BIT = 1;    -- eigenen Editor-Tab ausschließen
DECLARE @MaxSessions   INT = 20;   -- Obergrenze der Kandidaten
```

Ausführen.
Wenn **keine** oder **mehrere** Sessions gefunden werden, brechen die Skripte mit einer **klaren Fehlermeldung** ab (absichtlich), damit du den Filter nachschärfst.

---

## Output (Ergebnisse)

### Summary 1 – Request / Session / Waits / Plan / Memory (je Session)

**Spalten:**

* `server_name`, `current_database`, `found_procedure`, `session_id`, `start_time`, `login_name`, `host_name`, `program_name`,
* `status`, `command`, `wait_type`, `last_wait_type`, `wait_time`, `blocking_session_id`,
* `sql_text`, `elapsed_s`, `percent_complete`,
* `requested_memory_kb`, `granted_memory_kb`, `max_used_memory_kb`,
* `query_plan` (XML)

**Interpretation (Kurz):**

* `status`: `running`/`runnable`/`suspended`
* `wait_type`: z. B. `LCK_M_*` (Locks), `RESOURCE_SEMAPHORE` (Memory Grant), `PAGEIOLATCH_*` (I/O), `THREADPOOL` (Worker-Knappheit)
* `percent_complete`: nur bei bestimmten Operationen > 0 (Backup/Restore/DBCC/…)

### Summary 2 – Transaktionen (je Session)

**Spalten:**

* `session_id`, `transaction_id`, `name`, `transaction_begin_time`,
* `transaction_type` (1=RW, 2=RO, 3=System, 4=Distributed),
* `transaction_state` (u. a. 2=Active, 6=Committed, 7=Rolled back),
* `database_id`, `database_name`, `log_used_MB` (Log-Verbrauch pro DB)

---

## Typische Use-Cases

* „**Meine SP hängt** – woran?“ → Status/Waits/Blocker + Plan/Memory prüfen.
* „**Welche Sessions** laufen gerade mit Muster *X*?“ → Multi-Skript mit `@MaxSessions`.
* „**Rollback** dauert ewig?“ → `status=rollback`, `percent_complete`, Transaktionen & `log_used_MB` beobachten.
* „**Memory-Engpässe**?“ → `sys.dm_exec_query_memory_grants`-Abschnitt in Summary 1.

---

## Ordnerstruktur (Vorschlag)

```
T-SQL/
└─ 82_Troubleshooting_Sessions_Requests/
   ├─ 82_Troubleshooting_Sessions_Requests.ipynb
   ├─ 82_Troubleshooting_Sessions_Request_Full.sql
   └─ Check_sp.sql
```

---

## Verbundene Kapitel & Warum

* **19\_Transactions** – Verstehen von `BEGIN/COMMIT/ROLLBACK`, Undo/Redo und großen Transaktionen (Rollback-Dauer, Log-Verbrauch).
* **27\_ExecutionPlans\_Basics** – Pläne lesen (teure Scans, Sort/Mem-Grants, Parallelisierung).
* **60\_IsolationLevels** – Sperrverhalten/Phantome; viele `LCK_M_*`-Waits hängen direkt mit Isolationsstufen zusammen.
* **64\_PerformanceTuning\_Advanced** – DMVs, Query Store, Parameter-Sniffing (Troubleshooting-Grundlagen).
* **71\_BackupRestore\_Strategies** – Bezug zum **Crash-/Startup-Recovery** (Rollback/Undo), Fortschritt via `percent_complete`.
* **72\_SQLAgent\_Jobs\_Alerts** – Automatisiertes Monitoring/Alerts (Blocking-Erkennung, Long-Running).
* **74\_SnapshotIsolation\_Concurrency** – `RCSI`/SI und Auswirkungen auf TempDB/Version Store statt klassischer Locks.
* **79\_TSQL\_Testing** – Reproduzierbare Testfälle für Problemabfragen.

> Diese Querverweise unterstützen den **didaktischen Fluss**: von grundlegender Transaktions- und Plan-Logik (19/27) über Nebenläufigkeit/Isolationsentscheidungen (60/74) hin zu Performance-Ursachen (64) und operativem Betrieb (71/72).

---

## Tipps & Best Practices

* Lange Prozeduren mit **serverseitigem Logging** (Tabelle) instrumentieren; für Live-Marker `RAISERROR(...,0,1) WITH NOWAIT`.
* Große DML in **Batches** mit kurzen Transaktionen; erleichtert Abbruch & Recovery.
* Bei Mehrtreffern Filter schärfen (`@LikeText`, `@ProcName`, optional `@TimeWindowMin`).
* TempDB-/I/O-Engpässe und Memory-Grants als **erste Hypothesen** prüfen.

---

## Änderungshistorie

* v1.0 – Initiale Fassung (Notebook + Full/Multi SQL-Skripte, Summaries, README) – 2025-09-18.
