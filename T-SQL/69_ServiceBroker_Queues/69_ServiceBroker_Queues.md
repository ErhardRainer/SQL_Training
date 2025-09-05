# T-SQL Service Broker & Queues – Übersicht  
*Message-basierte Verarbeitung in SQL Server*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| **Service Broker (SSB)** | In-Engine-Messaging für **zuverlässige**, asynchrone Verarbeitung mit Transaktionen, Ordering pro Dialog und genau-einmal-Zustellung. |
| **Message Type** | Deklariert Nachrichtentyp + optionale Validierung (`NONE`/`VALIDATION = WELL_FORMED_XML`/`VALIDATION = EMPTY`). |
| **Contract** | Legt fest, **wer** (Initiator/Target) **welche** Message Types senden darf. |
| **Queue** | Ziel für eingehende Nachrichten (persistente Warteschlange); optional mit **Activation** (Auto-Start von Prozeduren). |
| **Service** | Logischer Endpunkt, der mit Queue + Contract verknüpft ist; ansprechbar via Service-Name. |
| **Dialog/Conversation** | Zuverlässiger, geordneter Kommunikationskanal zwischen zwei Services: `BEGIN DIALOG CONVERSATION` → `SEND`/`RECEIVE` → `END CONVERSATION`. |
| **Conversation Group** | Gruppiert Dialoge (GUID) zur **koordinierten** Verarbeitung/Sequenzierung. |
| **Activation** | Automatischer Start einer Proc bei Nachrichtenankunft: `MAX_QUEUE_READERS`, `EXECUTE AS`, Parallelität. |
| **Poison Message Handling** | 5 aufeinanderfolgende Rollbacks auf derselben Queue → Queue wird **deaktiviert** (konfigurierbar). |
| **Timer** | `BEGIN CONVERSATION TIMER` – zeitbasierte Message an die Queue (Timeout-Ereignisse). |
| **Routing** | `CREATE ROUTE` (lokal/remote), **Service Broker Endpoint** (TCP), **Remote Service Binding** (Sicherheit/Zertifikate). |
| **Security** | Dialog-/Transport-Sicherheit via Zertifikate/`REMOTE SERVICE BINDING`; Berechtigungen `SEND`/`RECEIVE`/`REFERENCES`. |
| **DMVs/Katalog** | Diagnose über `sys.transmission_queue`, `sys.conversation_endpoints`, `sys.service_queues`, `sys.routes`, `sys.dm_broker_queue_monitors`. |
| **ENABLE_BROKER** | DB-weite Aktivierung: `ALTER DATABASE … SET ENABLE_BROKER`; bei Kopien ggf. `NEW_BROKER`. |
| **Limits** | Nachrichtentext als `varbinary(max)`/`nvarchar(max)` (bis ~2 GB); Ordering **nur innerhalb** eines Dialogs garantiert. |

---

## 2 | Struktur

### 2.1 | Architektur & Kernobjekte (Message → Contract → Service/Queue)
> **Kurzbeschreibung:** Wie Message Types, Contracts, Services und Queues zusammenspielen; Dialog-Lebenszyklus & Transaktionen.

- 📓 **Notebook:**  
  [`08_01_sb_architektur_grundlagen.ipynb`](08_01_sb_architektur_grundlagen.ipynb)
- 🎥 **YouTube:**  
  - [SQL Server Service Broker – Overview](https://www.youtube.com/results?search_query=sql+server+service+broker+overview)
- 📘 **Docs:**  
  - [Service Broker – Überblick](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/sql-server-service-broker)

---

### 2.2 | Setup & Aktivierung: `ENABLE_BROKER`, Endpoints & Routes
> **Kurzbeschreibung:** Datenbankseitige Aktivierung; lokale vs. verteilte Szenarien mit `CREATE ENDPOINT`/`CREATE ROUTE`.

- 📓 **Notebook:**  
  [`08_02_enable_broker_endpoints_routes.ipynb`](08_02_enable_broker_endpoints_routes.ipynb)
- 🎥 **YouTube:**  
  - [Enable Service Broker & Create Endpoints](https://www.youtube.com/results?search_query=sql+server+enable+service+broker+endpoint)
- 📘 **Docs:**  
  - [`ALTER DATABASE … SET ENABLE_BROKER`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-transact-sql-set-options)  
  - [`CREATE ENDPOINT` (SERVICE_BROKER)](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-endpoint-transact-sql)

---

### 2.3 | Message Types & Contracts definieren
> **Kurzbeschreibung:** Typen & Validierung festlegen; Contracts für erlaubte Sende-Rollen (Initiator/Target) erstellen.

- 📓 **Notebook:**  
  [`08_03_message_types_contracts.ipynb`](08_03_message_types_contracts.ipynb)
- 🎥 **YouTube:**  
  - [Service Broker – Message Types & Contracts](https://www.youtube.com/results?search_query=sql+server+service+broker+message+type+contract)
- 📘 **Docs:**  
  - [`CREATE MESSAGE TYPE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-message-type-transact-sql)  
  - [`CREATE CONTRACT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-contract-transact-sql)

---

### 2.4 | Queues & Services erstellen (+ Optionen)
> **Kurzbeschreibung:** `CREATE QUEUE` (Status, `RETENTION`, Activation) & `CREATE SERVICE`; Bindung Service→Queue→Contract.

- 📓 **Notebook:**  
  [`08_04_create_queue_service_activation.ipynb`](08_04_create_queue_service_activation.ipynb)
- 🎥 **YouTube:**  
  - [Service Broker Queue & Service Basics](https://www.youtube.com/results?search_query=sql+server+create+queue+service+broker)
- 📘 **Docs:**  
  - [`CREATE QUEUE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-queue-transact-sql) ・ [`ALTER QUEUE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-queue-transact-sql)  
  - [`CREATE SERVICE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-service-transact-sql)

---

### 2.5 | Dialog starten & Nachrichten senden/empfangen
> **Kurzbeschreibung:** `BEGIN DIALOG CONVERSATION`, `SEND ON CONVERSATION`, `WAITFOR (RECEIVE …)`, `END CONVERSATION`.

- 📓 **Notebook:**  
  [`08_05_begin_send_receive_end.ipynb`](08_05_begin_send_receive_end.ipynb)
- 🎥 **YouTube:**  
  - [SEND/RECEIVE Tutorial](https://www.youtube.com/results?search_query=sql+server+service+broker+send+receive)
- 📘 **Docs:**  
  - [`BEGIN DIALOG CONVERSATION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/begin-dialog-conversation-transact-sql)  
  - [`SEND` / `RECEIVE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/send-transact-sql)

---

### 2.6 | Activation-Prozeduren & Parallelität
> **Kurzbeschreibung:** Auto-Worker über `ACTIVATION (PROCEDURE_NAME …, MAX_QUEUE_READERS, EXECUTE AS …)`; robuste Loop-/Transaktionsmuster.

- 📓 **Notebook:**  
  [`08_06_activation_stored_procedures.ipynb`](08_06_activation_stored_procedures.ipynb)
- 🎥 **YouTube:**  
  - [Queue Activation Explained](https://www.youtube.com/results?search_query=sql+server+service+broker+activation)
- 📘 **Docs:**  
  - [Queue Activation – Optionen](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-queue-transact-sql#arguments)

---

### 2.7 | Poison Messages, Retries & Deaktivierung
> **Kurzbeschreibung:** Erkennungslogik (5 Rollbacks), `ALTER QUEUE … WITH STATUS = ON`, `POISON_MESSAGE_HANDLING (STATUS=OFF)` – eigene Retry/Quarantäne.

- 📓 **Notebook:**  
  [`08_07_poison_message_handling.ipynb`](08_07_poison_message_handling.ipynb)
- 🎥 **YouTube:**  
  - [Poison Message Handling](https://www.youtube.com/results?search_query=sql+server+service+broker+poison+message)
- 📘 **Docs:**  
  - [`ALTER QUEUE` – Poison Handling & RETENTION](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-queue-transact-sql)

---

### 2.8 | Timer & Zeitgesteuerte Workflows
> **Kurzbeschreibung:** `BEGIN CONVERSATION TIMER` + Timeout-Message; Muster für Deadletter/Reminder/Timeout-Recovery.

- 📓 **Notebook:**  
  [`08_08_conversation_timer_patterns.ipynb`](08_08_conversation_timer_patterns.ipynb)
- 🎥 **YouTube:**  
  - [Conversation Timer Demo](https://www.youtube.com/results?search_query=sql+server+begin+conversation+timer)
- 📘 **Docs:**  
  - [Conversation Timer](https://learn.microsoft.com/en-us/sql/relational-databases/service-broker/dialog-conversations#conversation-timers)

---

### 2.9 | Sicherheit & Routing (remote)
> **Kurzbeschreibung:** Endpoints (TCP), `CREATE ROUTE`, `REMOTE SERVICE BINDING` + Zertifikate für Dialog-Sicherheit.

- 📓 **Notebook:**  
  [`08_09_security_routing_remote.ipynb`](08_09_security_routing_remote.ipynb)
- 🎥 **YouTube:**  
  - [Routes & Remote Service Binding](https://www.youtube.com/results?search_query=sql+server+service+broker+route+remote+service+binding)
- 📘 **Docs:**  
  - [`CREATE ROUTE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-route-transact-sql)  
  - [`CREATE REMOTE SERVICE BINDING`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-remote-service-binding-transact-sql)

---

### 2.10 | Monitoring & DMVs
> **Kurzbeschreibung:** `sys.transmission_queue` (Warteschlangen für ausgehende Nachrichten), `sys.conversation_endpoints` (Zustände), Queue-Monitore, Aktivierungs-Tasks.

- 📓 **Notebook:**  
  [`08_10_dmvs_monitoring_diagnostics.ipynb`](08_10_dmvs_monitoring_diagnostics.ipynb)
- 🎥 **YouTube:**  
  - [Diagnosing Service Broker](https://www.youtube.com/results?search_query=sql+server+service+broker+monitoring)
- 📘 **Docs:**  
  - [`sys.transmission_queue`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-transmission-queue-transact-sql) ・ [`sys.conversation_endpoints`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-conversation-endpoints-transact-sql)  
  - [`sys.dm_broker_queue_monitors`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-broker-queue-monitors-transact-sql)

---

### 2.11 | Performance & Skalierung
> **Kurzbeschreibung:** Batching (`RECEIVE TOP (N)`), Conversation Groups, idempotente Handler, „at-least-once“-Denke, Message-Größe & -Format.

- 📓 **Notebook:**  
  [`08_11_performance_batching_scaling.ipynb`](08_11_performance_batching_scaling.ipynb)
- 🎥 **YouTube:**  
  - [Service Broker Performance Tips](https://www.youtube.com/results?search_query=sql+server+service+broker+performance)
- 📘 **Docs:**  
  - [Best Practices – Message Processing](https://learn.microsoft.com/en-us/sql/relational-databases/service-broker/service-broker-best-practices)

---

### 2.12 | Fehlerbilder & Troubleshooting
> **Kurzbeschreibung:** `transmission_status`, fehlende Routes/Endpunkte, Zertifikate, Firewall; hängende Dialoge korrekt beenden.

- 📓 **Notebook:**  
  [`08_12_troubleshooting_transmission_status.ipynb`](08_12_troubleshooting_transmission_status.ipynb)
- 🎥 **YouTube:**  
  - [Fixing Stuck Conversations](https://www.youtube.com/results?search_query=sql+server+service+broker+stuck+conversation)
- 📘 **Docs:**  
  - [Troubleshoot Routes & Conversations](https://learn.microsoft.com/en-us/sql/relational-databases/service-broker/troubleshooting-service-broker)

---

### 2.13 | Muster: Request/Reply, Outbox, Fan-Out
> **Kurzbeschreibung:** Typische Patterns inkl. Transaktionskopplung (Outbox), dedizierte Contract/Service-Designs.

- 📓 **Notebook:**  
  [`08_13_design_patterns_outbox_reply_fanout.ipynb`](08_13_design_patterns_outbox_reply_fanout.ipynb)
- 🎥 **YouTube:**  
  - [Service Broker Patterns](https://www.youtube.com/results?search_query=sql+server+service+broker+patterns)
- 📘 **Docs:**  
  - [Dialoge & Contracts – Entwurfstipps](https://learn.microsoft.com/en-us/sql/relational-databases/service-broker/dialog-conversations)

---

### 2.14 | HA/DR & Deployments (AG/Mirroring/Restore)
> **Kurzbeschreibung:** Umgang mit `service_broker_guid` nach Restore/Clones; `NEW_BROKER` vs. **Konversationen migrieren**; Routen aktualisieren.

- 📓 **Notebook:**  
  [`08_14_hadr_restore_new_broker_guid.ipynb`](08_14_hadr_restore_new_broker_guid.ipynb)
- 🎥 **YouTube:**  
  - [Service Broker after Restore](https://www.youtube.com/results?search_query=sql+server+service+broker+restore+new+broker)
- 📘 **Docs:**  
  - [Broker GUID & Aktivierung nach Restore](https://learn.microsoft.com/en-us/sql/relational-databases/service-broker/service-broker-identifiers)

---

### 2.15 | Berechtigungen & Sicherheit im Detail
> **Kurzbeschreibung:** `GRANT SEND ON SERVICE`, `RECEIVE` auf Queue, `REFERENCES` auf Contract; Signieren/Certs für Dialog-Sicherheit.

- 📓 **Notebook:**  
  [`08_15_permissions_security_details.ipynb`](08_15_permissions_security_details.ipynb)
- 🎥 **YouTube:**  
  - [Service Broker Permissions](https://www.youtube.com/results?search_query=sql+server+service+broker+permissions)
- 📘 **Docs:**  
  - [Berechtigungen (Service, Queue, Contract)](https://learn.microsoft.com/en-us/sql/relational-databases/service-broker/permissions-and-surface-area-configuration-service-broker)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** Kein `END CONVERSATION`, Endlos-Retries ohne Quarantäne, `WAITFOR`-Busy-Loop, Activation ohne `EXECUTE AS`, große Nachrichten als Blob statt Referenzen, ungesicherte Remote-Dialoge.

- 📓 **Notebook:**  
  [`08_16_sb_antipatterns_checkliste.ipynb`](08_16_sb_antipatterns_checkliste.ipynb)
- 🎥 **YouTube:**  
  - [Common Service Broker Mistakes](https://www.youtube.com/results?search_query=sql+server+service+broker+mistakes)
- 📘 **Docs/Blog:**  
  - [Best Practices & Pitfalls](https://learn.microsoft.com/en-us/sql/relational-databases/service-broker/service-broker-best-practices)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Service Broker – Überblick & Architektur](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/sql-server-service-broker)  
- 📘 Microsoft Learn: [`CREATE MESSAGE TYPE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-message-type-transact-sql) ・ [`CREATE CONTRACT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-contract-transact-sql)  
- 📘 Microsoft Learn: [`CREATE QUEUE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-queue-transact-sql) ・ [`ALTER QUEUE` (Activation/Poison/Retention)](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-queue-transact-sql) ・ [`CREATE SERVICE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-service-transact-sql)  
- 📘 Microsoft Learn: [`BEGIN DIALOG CONVERSATION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/begin-dialog-conversation-transact-sql) ・ [`SEND`/`RECEIVE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/send-transact-sql) ・ [`END CONVERSATION`](https://learn.microsoft.com/en-us/sql/t-sql/statements/end-conversation-transact-sql)  
- 📘 Microsoft Learn: [Conversation Timers](https://learn.microsoft.com/en-us/sql/relational-databases/service-broker/dialog-conversations#conversation-timers)  
- 📘 Microsoft Learn: [`CREATE ROUTE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-route-transact-sql) ・ [`CREATE REMOTE SERVICE BINDING`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-remote-service-binding-transact-sql) ・ [`CREATE ENDPOINT`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-endpoint-transact-sql)  
- 📘 Microsoft Learn: [Best Practices – Service Broker](https://learn.microsoft.com/en-us/sql/relational-databases/service-broker/service-broker-best-practices)  
- 📘 Microsoft Learn: DMVs/Kataloge – [`sys.transmission_queue`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-transmission-queue-transact-sql), [`sys.conversation_endpoints`](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-conversation-endpoints-transact-sql), [`sys.dm_broker_queue_monitors`](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-broker-queue-monitors-transact-sql)  
- 📘 Microsoft Learn: [Troubleshooting Service Broker](https://learn.microsoft.com/en-us/sql/relational-databases/service-broker/troubleshooting-service-broker)  
- 📘 Microsoft Learn: [Permissions & Surface Area](https://learn.microsoft.com/en-us/sql/relational-databases/service-broker/permissions-and-surface-area-configuration-service-broker)  
- 📝 Simple Talk (Redgate): *SQL Server Service Broker – Getting Started*  
- 📝 Remus Rusanu: *Service Broker Series (Patterns & Internals)* – https://rusanu.com/  
- 📝 SQLPerformance/Brent Ozar: *Poison Messages, Activation & Retry Loops* – Blogs (Suche)  
- 🎥 YouTube: *Service Broker Tutorials / Demos* – Playlists (Suche)  
