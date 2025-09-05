# SQL Server Agent – Jobs, Schedules & Alerts – Übersicht  
*Automatisierung mit SQL Agent: Jobs, Zeitpläne, Operatoren, Alerts & Benachrichtigungen*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| **SQL Server Agent** | Windows-Dienst zur **Automatisierung** (Jobs, Zeitpläne, Alerts, Benachrichtigungen). Metadaten in **msdb**. |
| **Job** | Container für **Steps** (T-SQL, CmdExec, PowerShell, SSIS-Subsystem etc.); Ablaufsteuerung über „On success/failure go to…“. |
| **Job Step** | Ein Ausführungsschritt inkl. Subsystem, Command, Retry-Logik, Output-Logging (Tabelle/Datei). |
| **Schedule** | Zeitplan (Frequenz, Start/Ende, wiederkehrend/one-shot). Ein Job ↔ **mehrere** Schedules möglich. |
| **Alert** | Reagiert auf **SQL-Events** (Fehlernummer/Schweregrad), **Performance Conditions** oder **WMI-Events**. Kann Job starten/Operator benachrichtigen. |
| **Operator** | Empfänger von Benachrichtigungen (E-Mail via **Database Mail**, optional Pager/NetSend – veraltet). |
| **Notification** | Job-/Alert-Aktion: E-Mail an Operator **bei Erfolg/Fehler/Abbruch** o. ä. |
| **Proxy** | Sicherheitskontext für Steps nicht-T-SQL (CmdExec/PowerShell/SSIS) auf Basis eines **Credentials** (Least Privilege). |
| **Job Ownership** | T-SQL-Steps laufen im Kontext des **Job-Owners** (sysadmin ⇒ volle Rechte), andere Subsysteme i. d. R. via **Proxy**/Dienstkonto. |
| **Fixed Agent Roles** | `SQLAgentUserRole` / `SQLAgentReaderRole` / `SQLAgentOperatorRole` – **msdb**-Rollen für delegierte Administration. |
| **Job Category** | Klassifikation/Filter für Jobs (z. B. „Database Maintenance“). |
| **Agent Tokens** | Platzhalter wie `$(ESCAPE_SQUOTE(JOBNAME))`, `$(HOSTNAME)`, `$(JOBID)` in Steps/Skripten. |
| **Job History** | Ausführungshistorie in `msdb.dbo.sysjobhistory` (+ `sysjobactivity`, Output-Logs). |
| **Multi-Server Jobs** | Master/Target (MSX/TSX)-Architektur zur **zentralen** Verteilung/Steuerung von Jobs. |
| **Fail-Safe Operator** | Fallback-Empfänger, wenn keine andere Benachrichtigung greift. |
| **Database Mail** | Benachrichtigungen/E-Mails (`sp_send_dbmail`), Profil/Account nötig. |

---

## 2 | Struktur

### 2.1 | Architektur & Grundlagen (msdb, Rollen, Dienst)
> **Kurzbeschreibung:** Überblick über Agent-Dienst, msdb-Schema, Sicherheitsrollen & Rechtefluss.

- 📓 **Notebook:**  
  [`08_01_agent_architektur_grundlagen.ipynb`](08_01_agent_architektur_grundlagen.ipynb)
- 🎥 **YouTube:**  
  - [SQL Server Agent Overview](https://www.youtube.com/results?search_query=sql+server+agent+overview)
- 📘 **Docs:**  
  - [SQL Server Agent – Übersicht](https://learn.microsoft.com/en-us/sql/ssms/agent/sql-server-agent)

---

### 2.2 | Jobs & Steps – Subsysteme, Flow & Retry
> **Kurzbeschreibung:** Job/Step-Definition, Subsysteme (T-SQL, CmdExec, PowerShell, SSIS), Fehler-/Erfolgsverzweigungen, Retries.

- 📓 **Notebook:**  
  [`08_02_jobs_steps_subsysteme.ipynb`](08_02_jobs_steps_subsysteme.ipynb)
- 🎥 **YouTube:**  
  - [Create SQL Agent Job & Steps](https://www.youtube.com/results?search_query=create+sql+server+agent+job+steps)
- 📘 **Docs:**  
  - [`sp_add_job` / `sp_add_jobstep`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-add-job-transact-sql)

---

### 2.3 | Schedules – Wiederholungen, Fenster, Kalender
> **Kurzbeschreibung:** Einmalig/zyklisch, Tages-/Wochenpläne, Start-/Endfenster, mehrere Schedules pro Job.

- 📓 **Notebook:**  
  [`08_03_schedules_frequenzen_fenster.ipynb`](08_03_schedules_frequenzen_fenster.ipynb)
- 🎥 **YouTube:**  
  - [SQL Agent Schedules Tutorial](https://www.youtube.com/results?search_query=sql+server+agent+schedules)
- 📘 **Docs:**  
  - [`sp_add_schedule`, `sp_attach_schedule`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-add-schedule-transact-sql)

---

### 2.4 | Alerts – Fehler/Severity, Performance & Aktionen
> **Kurzbeschreibung:** SQL-Event-Alerts (Fehlernummer/Severity), Performance Condition Alerts, Aktionen (Job starten, Operator benachrichtigen).

- 📓 **Notebook:**  
  [`08_04_alerts_events_performance.ipynb`](08_04_alerts_events_performance.ipynb)
- 🎥 **YouTube:**  
  - [Configure SQL Agent Alerts](https://www.youtube.com/results?search_query=sql+server+agent+alerts)
- 📘 **Docs:**  
  - [`sp_add_alert`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-add-alert-transact-sql)

---

### 2.5 | WMI-Alerts & Performance Conditions
> **Kurzbeschreibung:** WMI-Events (z. B. Job-Status, AG-RoleChange), Performance Counter-Schwellen & Push-Down-Regeln.

- 📓 **Notebook:**  
  [`08_05_wmi_performance_alerts.ipynb`](08_05_wmi_performance_alerts.ipynb)
- 🎥 **YouTube:**  
  - [WMI Alerts in SQL Agent](https://www.youtube.com/results?search_query=sql+server+wmi+alerts)
- 📘 **Docs:**  
  - [WMI & Performance Alerts](https://learn.microsoft.com/en-us/sql/ssms/agent/alerts)

---

### 2.6 | Operators & Database Mail (Benachrichtigungen)
> **Kurzbeschreibung:** Operatoren anlegen, Database Mail Profil/Account, Job-/Alert-Notifications konfigurieren, Fail-Safe Operator.

- 📓 **Notebook:**  
  [`08_06_operators_database_mail.ipynb`](08_06_operators_database_mail.ipynb)
- 🎥 **YouTube:**  
  - [Database Mail Setup](https://www.youtube.com/results?search_query=sql+server+database+mail+setup)
- 📘 **Docs:**  
  - [`sp_add_operator`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-add-operator-transact-sql) ・ [`sp_send_dbmail`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-send-dbmail-transact-sql)

---

### 2.7 | Proxies & Credentials – Least Privilege
> **Kurzbeschreibung:** CmdExec/PowerShell/SSIS sicher betreiben; Proxies pro Subsystem, Credentials & Rechte.

- 📓 **Notebook:**  
  [`08_07_proxies_credentials.ipynb`](08_07_proxies_credentials.ipynb)
- 🎥 **YouTube:**  
  - [SQL Agent Proxy Accounts](https://www.youtube.com/results?search_query=sql+server+agent+proxy+account)
- 📘 **Docs:**  
  - [Agent Proxies & Credentials](https://learn.microsoft.com/en-us/sql/ssms/agent/create-a-sql-server-agent-proxy)

---

### 2.8 | Ownership & Sicherheit (msdb-Rollen)
> **Kurzbeschreibung:** Job-Owner, Ausführungskontext, Fixed Agent Roles in **msdb**, Delegation & Grenzen.

- 📓 **Notebook:**  
  [`08_08_job_ownership_security.ipynb`](08_08_job_ownership_security.ipynb)
- 🎥 **YouTube:**  
  - [Agent Roles & Security](https://www.youtube.com/results?search_query=sql+server+agent+roles+security)
- 📘 **Docs:**  
  - [Fixed Database Roles for SQL Agent](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/database-level-roles#sql-server-agent-fixed-database-roles)

---

### 2.9 | Logging, Output & Job History
> **Kurzbeschreibung:** Step-Output in Datei/Tabelle, `sysjobhistory`, `sysjobactivity`, Fehlercodes interpretieren.

- 📓 **Notebook:**  
  [`08_09_logging_history_output.ipynb`](08_09_logging_history_output.ipynb)
- 🎥 **YouTube:**  
  - [Read Job History & Logs](https://www.youtube.com/results?search_query=sql+server+agent+job+history)
- 📘 **Docs:**  
  - [`msdb`-Kataloge (Jobs/History)](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/backup-and-restore-tables-msdb-database) *(siehe auch `sysjobs`, `sysjobhistory`)*

---

### 2.10 | Monitoring & DMVs/XEvents
> **Kurzbeschreibung:** Live-Aktivität & Blocker erkennen, Alerts/Failures zentral beobachten, Agent Error Log.

- 📓 **Notebook:**  
  [`08_10_monitoring_dmvs_xevents.ipynb`](08_10_monitoring_dmvs_xevents.ipynb)
- 🎥 **YouTube:**  
  - [Monitor SQL Agent Activity](https://www.youtube.com/results?search_query=monitor+sql+server+agent+activity)
- 📘 **Docs:**  
  - [`sysjobactivity` / `sp_help_job`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-help-job-transact-sql)

---

### 2.11 | Ketten & Abhängigkeiten (Job Chaining)
> **Kurzbeschreibung:** Folgejobs mit `sp_start_job`, Schrittverzweigungen, „Master“-Job, Warte-/Retry-Muster.

- 📓 **Notebook:**  
  [`08_11_job_chaining_dependencies.ipynb`](08_11_job_chaining_dependencies.ipynb)
- 🎥 **YouTube:**  
  - [Chain SQL Agent Jobs](https://www.youtube.com/results?search_query=chain+sql+server+agent+jobs)
- 📘 **Docs:**  
  - [`sp_start_job`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-start-job-transact-sql)

---

### 2.12 | Multi-Server (MSX/TSX) – Zentrale Verteilung
> **Kurzbeschreibung:** Master/Target-Server einrichten, Jobs zentral ausrollen, Status zurückmelden.

- 📓 **Notebook:**  
  [`08_12_msx_tsx_multiserver_jobs.ipynb`](08_12_msx_tsx_multiserver_jobs.ipynb)
- 🎥 **YouTube:**  
  - [Multi-Server Jobs (MSX/TSX)](https://www.youtube.com/results?search_query=sql+server+msx+tsx+multi+server+jobs)
- 📘 **Docs:**  
  - [Master-Target Server Setup](https://learn.microsoft.com/en-us/sql/ssms/agent/multiserver-environments)

---

### 2.13 | HA/DR & Always On – Jobs auf Primär/Sekundär
> **Kurzbeschreibung:** „Primary-only“-Jobs via `sys.fn_hadr_is_primary_replica()`, Agent auf Cluster/AG, Rollovers.

- 📓 **Notebook:**  
  [`08_13_hadr_jobs_primary_only.ipynb`](08_13_hadr_jobs_primary_only.ipynb)
- 🎥 **YouTube:**  
  - [Agent Jobs with Always On](https://www.youtube.com/results?search_query=sql+server+agent+jobs+always+on)
- 📘 **Docs:**  
  - [Backups & Jobs auf AG-Replikas](https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/active-secondaries-backup-on-secondary-replicas)

---

### 2.14 | Tokens, Parametrisierung & wiederverwendbare Skripte
> **Kurzbeschreibung:** Agent-Tokens korrekt escapen, Host/Job/Step-Infos in Skripten nutzen, dynamische Dateinamen/Logs.

- 📓 **Notebook:**  
  [`08_14_agent_tokens_patterns.ipynb`](08_14_agent_tokens_patterns.ipynb)
- 🎥 **YouTube:**  
  - [SQL Agent Tokens Explained](https://www.youtube.com/results?search_query=sql+server+agent+tokens)
- 📘 **Docs:**  
  - [Agent Token Replacement](https://learn.microsoft.com/en-us/sql/ssms/agent/use-tokens-in-job-steps)

---

### 2.15 | Governance & Betrieb: Namenskonvention, Kategorien, Cleanup
> **Kurzbeschreibung:** Präfixe, Kategorien, zentrale Mail-Profile, History/Output-Retention & Aufräumjobs (`sp_purge_jobhistory`).

- 📓 **Notebook:**  
  [`08_15_governance_naming_cleanup.ipynb`](08_15_governance_naming_cleanup.ipynb)
- 🎥 **YouTube:**  
  - [Best Practices for Agent Jobs](https://www.youtube.com/results?search_query=sql+server+agent+jobs+best+practices)
- 📘 **Docs:**  
  - [`sp_purge_jobhistory`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-purge-jobhistory-transact-sql)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** Jobs als `sa`/sysadmin ohne Not, CmdExec ohne Proxy, fehlende Mail/Alerts, endlose Retries, kein Output-Logging, unklare Zeitpläne, keine RTO/RPO-Ableitung, MSX/TSX ohne Governance.

- 📓 **Notebook:**  
  [`08_16_agent_antipatterns_checkliste.ipynb`](08_16_agent_antipatterns_checkliste.ipynb)
- 🎥 **YouTube:**  
  - [Common SQL Agent Mistakes](https://www.youtube.com/results?search_query=sql+server+agent+mistakes)
- 📘 **Docs/Blog:**  
  - [Agent Best Practices (Übersicht)](https://learn.microsoft.com/en-us/sql/ssms/agent/sql-server-agent)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [SQL Server Agent – Startseite](https://learn.microsoft.com/en-us/sql/ssms/agent/sql-server-agent)  
- 📘 Microsoft Learn: [`sp_add_job` / `sp_add_jobstep` / `sp_update_job` / `sp_delete_job`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-add-job-transact-sql)  
- 📘 Microsoft Learn: [`sp_add_schedule` / `sp_attach_schedule`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-add-schedule-transact-sql)  
- 📘 Microsoft Learn: [`sp_add_alert` / `sp_add_notification`](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-add-alert-transact-sql)  
- 📘 Microsoft Learn: [`sp_add_operator` / Fail-Safe Operator](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-add-operator-transact-sql)  
- 📘 Microsoft Learn: [Database Mail – Konfiguration & `sp_send_dbmail`](https://learn.microsoft.com/en-us/sql/relational-databases/database-mail/database-mail)  
- 📘 Microsoft Learn: [Agent Proxies & Credentials (CmdExec/PowerShell/SSIS)](https://learn.microsoft.com/en-us/sql/ssms/agent/create-a-sql-server-agent-proxy)  
- 📘 Microsoft Learn: [Agent Tokens verwenden](https://learn.microsoft.com/en-us/sql/ssms/agent/use-tokens-in-job-steps)  
- 📘 Microsoft Learn: [msdb-Objekte: `sysjobs`, `sysjobsteps`, `sysjobhistory`, `sysjobactivity`](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/msdb-database)  
- 📘 Microsoft Learn: [Multi-Server Jobs (MSX/TSX)](https://learn.microsoft.com/en-us/sql/ssms/agent/multiserver-environments)  
- 📘 Microsoft Learn: [Always On Integration – Backups/Jobs auf Sekundär](https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/active-secondaries-backup-on-secondary-replicas)  
- 📝 Ola Hallengren: *SQL Server Maintenance Solution* (Agent-Jobs für Backups/Integrität/Index) – https://ola.hallengren.com/  
- 📝 Brent Ozar: *Agent Job Best Practices & Alerting* – https://www.brentozar.com/  
- 📝 SQLPerformance/SQLSkills: *Job History, msdb & Monitoring* – https://www.sqlperformance.com/?s=agent  
- 🎥 YouTube (Data Exposed): *Automating with SQL Agent* – Suchlink  
- 🎥 YouTube: *Alerts & Database Mail – End-to-End Demo* – Suchlink  
