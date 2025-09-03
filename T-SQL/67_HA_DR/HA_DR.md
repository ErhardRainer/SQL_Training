
# Optionen zur Sync-/Replikation von SQL-Server-Daten (Übersicht)

> Dieses `HA_DR.md` ist der **Einstiegspunkt**. Es ordnet alle HA/DR- und Replikationsoptionen ein, erklärt Auswahlkriterien (RPO/RTO, Latenz, Kosten/Editionen) und verweist auf die **Detail-Notebooks** („Einrichten“, „Warten/Betreiben“, „Monitoring“, „Troubleshooting“).

----------

## TL;DR – Schnellwahl nach Ziel


| Ziel                                                             | Geeignetes Verfahren                                                      |               Latenz |           Datenverlust (RPO) |       Failover (RTO) |    Komplexität |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------- | -------------------: | ---------------------------: | -------------------: | -------------: |
| **Nahezu live + automatisches Failover + Read-Only Secondaries** | **Always On Availability Groups (AGs)** (sync/async, ggf. Distributed AG) | sehr gering / gering | **0** (sync) / klein (async) | sehr gering / gering |    mittel–hoch |
| **Einfaches, robustes DR (minütlich)**                           | **Log Shipping** (mit `STANDBY` für Reporting)                            |              Minuten |                      Minuten |              manuell | niedrig–mittel |
| **Teilmenge (Tabellen/Spalten) an Reporting-Server**             | **Transaktionale Replikation**                                            |          sehr gering |                   sehr klein |                    – |         mittel |
| **Multi-Master (selten nötig)**                                  | **Peer-to-Peer Replikation**                                              |          sehr gering |             konfliktanfällig |                    – |           hoch |
| **Selten geänderte Daten, periodisch**                           | **Snapshot-Replikation**                                                  |                 hoch |    bis zum nächsten Snapshot |                    – |        niedrig |
| **Historisierung/ETL-Inkrementell (Analytics)**                  | **CDC/Change Tracking + ETL** / **Fabric-Mirroring (CDC)**                |             variabel |              n. a. (kein HA) |                    – | niedrig–mittel |
| **Instanz-/VM-basiertes DR**                                     | **FCI / Storage-Replikation / ASR**                                       |          sehr gering |       0–klein (je nach Sync) |               gering |         mittel |


> **Begriffe**  
> **RPO** = maximal tolerierter Datenverlust, **RTO** = maximale Wiederanlaufzeit.

----------

## Entscheidungsleitfaden

1.  **RPO/RTO** festlegen (Business-Impact-Analyse).
    
2.  **Topologie** wählen: Single-Site HA? Multi-Site DR? Geo-Verteilung?
    
3.  **Workload**: Ganze DB(s) vs. Teilmengen (Tabellen/Spalten)? **Read-Only Secondaries** benötigt?
    
4.  **Editionen/Lizenzen**: Standard vs. Enterprise (AG-Features!), Windows Failover Cluster?
    
5.  **Betrieb**: Monitoring, Patching, **Failover-Drills**, Runbooks.
    
6.  **Netzwerk/Ports**: Latenz, Bandbreite, Firewalls, Quorum-Design.
    
7.  **Security/Compliance**: Verschlüsselung (TDE, TLS), Secrets, Audit.
    

----------

## Verfahren (Kurzbeschreibungen & Hinweise)

### 1) Always On Availability Groups (AGs)

-   **Ebene:** Datenbank (mehrere DBs pro AG).
    
-   **Modi:** synchron (0-RPO) / asynchron (kleines RPO).
    
-   **Features:** Listener, **Read-Only Secondaries**, automatisches Failover (synchron + Quorum).
    
-   **Varianten:** **Distributed AGs** für standortübergreifende Szenarien.
    
-   **Edition:** volle Features i. d. R. **Enterprise** (Feature-Scope je Version prüfen).
    

👉 **Notebooks:** _Planung_, _Einrichten (Sync/Async)_, _Distributed AG_, _Warten/Betreiben_, _Monitoring_, _Troubleshooting_.

----------

### 2) Failover Cluster Instance (FCI)

-   **Ebene:** **Instanz** (Shared Storage).
    
-   **Nutzen:** Server-/Instanz-Failover; **kein Read-Only Secondary**.
    
-   **Kombi:** Häufig **FCI** (lokales HA) + **AG** (DR/Reporting).
    

👉 **Notebooks:** _Planung_, _Einrichten_, _Warten/Betreiben_, _Monitoring_, _Troubleshooting_.

----------

### 3) Log Shipping

-   **Mechanik:** Log-Backups → Kopieren → Restore am Sekundär.
    
-   **Granularität:** Datenbank. **Intervall:** minütlich.
    
-   **Vorteile:** robust, simpel, kosteneffizient.
    
-   **Read-Only:** möglich via `STANDBY` (zwischen Restores lesbar).
    

👉 **Notebooks:** _Einrichten_, _Warten/Betreiben (Alerts, LSN-Kette)_, _Monitoring_, _Troubleshooting (LSN-Brüche)_.

----------

### 4) Transaktionale Replikation

-   **Ziel:** Near-Real-Time-Verteilung von **Tabellen/Spalten** (Artikel).
    
-   **Rollen:** **Publisher, Distributor, Subscriber**.
    
-   **Hinweis:** Subscriber typ. **read-only**; Schreibkonflikte vermeiden.
    
-   **Variante:** **Peer-to-Peer** (Multi-Master) nur für konfliktarme Szenarien.
    

👉 **Notebooks:** _Einrichten (t-Repl)_, _Peer-to-Peer_, _Warten/Betreiben (Repl-Agenten)_, _Monitoring_, _Troubleshooting (Fehler 20598 etc.)_.

----------

### 5) Snapshot-Replikation

-   **Prinzip:** periodische **Voll-Snapshots** (kein Delta).
    
-   **Einsatz:** kleine/selten geänderte Datasets.
    

👉 **Notebooks:** _Einrichten_, _Warten/Betreiben_, _Troubleshooting_.

----------

### 6) (Legacy) Database Mirroring

-   **Modi:** High Safety (sync, optional Witness) / High Performance (async).
    
-   **Status:** von **AGs** abgelöst; **nur für Altbestände**.
    

👉 **Notebook:** _Bewertung & Migrationspfad zu AGs_.

----------

### 7) Change Tracking / CDC + ETL (inkl. Fabric-Mirroring)

-   **Zweck:** **ETL-Inkrementell**, **Analytics-Spiegel** (OneLake/Warehouse).
    
-   **Kein HA:** kein automatisches Failover, andere Ziele als AG/Log Shipping.
    
-   **Hinweis:** Fabric-Mirroring nutzt **CDC** für kontinuierliche Inkremente.
    

👉 **Notebooks:** _CT/CDC-Patterns_, _Fabric-Mirroring (Einrichten/Warten)_, _Idempotenz, Wasserzeichen, Checksummen_.

----------

### 8) Storage/VM-basierte Replikation & Cloud-DR

-   **Beispiele:** **FCI + SAN-Replika**, **Hyper-V/Azure Site Recovery (ASR)**, **VM-Snapshots**.
    
-   **Ebene:** Block-/VM-Level (SQL-unaware) – **Konsistenz-Garantien** beachten.
    

👉 **Notebooks:** _Architekturvarianten_, _Runbooks & Tests_, _Wiederherstellung/Failback_.

----------

## Betriebsaspekte (Checkliste)

-   **Monitoring:** AG-DMVs, Repl-Agenten, Log-Shipping-Status, LSN-Ketten, Alerts (Agent/SMO).
    
-   **Backups:** Unabhängig von HA/DR weiterführen (TDE-Schlüssel, Copy-Only, Offsite).
    
-   **Patching/Updates:** Rolling Upgrades, Reihenfolge (Primary/Secondary), Listener-Failover üben.
    
-   **Security:** TLS erzwingen, TDE/Keys sichern, Zertifikate/Secrets rotieren.
    
-   **Dokumentation:** **RPO/RTO-Ziele**, Topologien, Ports, Service-Konten, **Runbooks**, **Failover-Drills** (≥2×/Jahr).
    

----------

## Verzeichnis & Notebook-Gliederung

- 67_HA_DR_Replication/
  - README.md  (dieses Dokument)
  - 10_AlwaysOn_AG/
    - 00_Einordnung_Architektur.ipynb
    - 10_Planung_RPO_RTO_Quorum_Listener.ipynb
    - 20_Einrichten_Sync_AG.ipynb
    - 21_Einrichten_Async_AG.ipynb
    - 30_Distributed_AG_Standortuebergreifend.ipynb
    - 40_Warten_Betreiben_Patching.ipynb
    - 50_Monitoring_DMVs_Alerts.ipynb
    - 60_Troubleshooting_Failover_Latenz.ipynb
  - 20_FCI_Cluster/
    - 10_Planung_Storage_Quorum.ipynb
    - 20_Einrichten_WindowsFCI_SQL.ipynb
    - 40_Warten_Monitoring.ipynb
    - 60_Troubleshooting.ipynb
  - 30_LogShipping/
    - 10_Einrichten_Primary_Secondary.ipynb
    - 20_STANDBY_Reporting_Mode.ipynb
    - 40_Warten_Alerts_LogChain.ipynb
    - 50_Monitoring_Health.ipynb
    - 60_Troubleshooting_LSN_Brueche.ipynb
  - 40_Replication/
    - 10_TransaktionaleReplikation_Einrichten.ipynb
    - 20_PeerToPeer_Design_und_Setup.ipynb
    - 30_SnapshotReplikation_Einrichten.ipynb
    - 40_Warten_Agenten_Reseeding.ipynb
    - 50_Monitoring_Perf_Metriken.ipynb
    - 60_Troubleshooting_TopFehler.ipynb
  - 50_Mirroring_Legacy/
    - 10_Bewertung_Migration_zu_AGs.ipynb
  - 60_CT_CDC_ETL_und_Fabric/
    - 10_CT_vs_CDC_Architektur.ipynb
    - 20_Fabric_Mirroring_SQL_to_OneLake.ipynb
    - 30_Einrichten_ETL_Inkrementell.ipynb
    - 40_Idempotenz_Wasserzeichen_Checksummen.ipynb
    - 60_Troubleshooting_CDC_Latenzen.ipynb
  - 70_Storage_VM_DR/
    - 10_Architekturen_FCI_SAN_ASR.ipynb
    - 20_Runbooks_DR_Test_Failover_Failback.ipynb
    - 30_Konsistenz_Pruefungen.ipynb
  - 80_CrossCutting/
    - 10_RPO_RTO_Matrix_Vorlage.ipynb
    - 20_Netzwerk_Ports_Latenz_Sizing.ipynb
    - 30_Security_TLS_TDE_Keys.ipynb
    - 40_Monitoring_Dashboards_Alerting.ipynb


----------

## Referenz-Matrix (Auswahl & Einsatzgrenzen)


| Verfahren                    | Ebene          | Read-Only Ziel | Autom. Failover | Geo-DR              | Teilmengen möglich | Bemerkungen                               |
| ---------------------------- | -------------- | -------------- | --------------- | ------------------- | ------------------ | ----------------------------------------- |
| **AG (sync/async)**          | DB             | ✓              | ✓/✗             | ✓ (Distributed)     | ✗                  | Enterprise-Fokus, Listener, Quorum-Design |
| **FCI**                      | Instanz        | ✗              | ✓               | (mit Storage-Repl.) | n/a                | Shared Storage; oft mit AG kombiniert     |
| **Log Shipping**             | DB             | ✓ (`STANDBY`)  | ✗               | ✓                   | ✗                  | Einfach/robust, minütliche Latenz         |
| **t-Replikation**            | Tabelle/Spalte | ✓              | ✗               | ✓                   | ✓                  | Artikel-Granularität, nahe live           |
| **Peer-to-Peer**             | Tabelle        | –              | –               | ✓                   | ✓                  | Multi-Master, Konfliktrisiko              |
| **Snapshot-Repl.**           | Tabelle        | ✓              | ✗               | ✓                   | ✓                  | Periodisch, Voll-Snapshot                 |
| **Mirroring (alt)**          | DB             | ✗              | ✓ (Witness)     | begrenzt            | ✗                  | Legacy – Migration zu AG empfohlen        |
| **CT/CDC + ETL / Fabric**    | Zeile/Änderung | ✓ (DWH)        | ✗               | ✓                   | ✓                  | **Nicht HA**; Analytics/OneLake-Sync      |
| **Storage/VM (FCI/SAN/ASR)** | Instanz/VM     | n/a            | VM-Failover     | ✓                   | n/a                | SQL-unaware, Konsistenz beachten          |


----------

## Best Practices (kompakt)

-   **Planung zuerst:** RPO/RTO und Lastprofil → Technologieauswahl.
    
-   **Automatisierung:** Agent-Jobs, Runbooks, IaC (wo möglich).
    
-   **Überwachung:** Dashboards + Alerts auf Latenzen/Queues/LSN-Ketten.
    
-   **Drills:** **Regelmäßige Failover-Übungen** + dokumentierte Lessons Learned.
    
-   **Sicherheit:** TDE-Keys sichern, Zertifikate/Secrets rotieren, TLS erzwingen.
    
-   **Dokumentation:** Topologien, Ports, Service-Konten, Escalation-Pfad.
    

----------

## Nächste Schritte

1.  In der **Schnellwahl** die passende Option bestimmen.
    
2.  Das zugehörige **„00/10_*“-Notebook** für Architektur & Planung öffnen.
    
3.  Den **Einrichten-Pfad** durchlaufen, danach **Warten/Monitoring**.
    
4.  Einen **Failover-Test** im nächsten Wartungsfenster einplanen.
    

> Feedback & PRs willkommen – bitte Issues/PRs im Repo anlegen.
