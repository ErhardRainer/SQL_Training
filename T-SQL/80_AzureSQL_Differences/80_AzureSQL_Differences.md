# Azure SQL – Unterschiede On-Premises vs. Azure SQL – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Azure SQL Familie | PaaS-Angebote **Azure SQL Database** (Single DB, Elastic Pool, Hyperscale, Serverless) und **Azure SQL Managed Instance (MI)**; daneben **SQL Server auf Azure VMs (IaaS)** als nahezu 1:1 On-Prem-Äquivalent. |
| vCore-/DTU-Modell | Leistungs-/Preismodelle in Azure SQL: **vCore** (empfohlen; getrennte Skalierung Compute/Storage, AHB/Reserved Capacity) und **DTU** (gebündelt; nur Azure SQL Database). |
| Service Tiers | **General Purpose**, **Business Critical** (lokaler Speicher, zusätzliche HA-Features, Read Scale-Out), **Hyperscale** (mehrere TB, schnelle Backups/Restores, Named Replicas). |
| Serverless | Compute-Tier für Single DBs (und Hyperscale), skaliert automatisch, **Auto-Pause/-Resume** bei Inaktivität; Abrechnung pro Sekunde für Compute. |
| Elastic Pool | Gemeinsame Ressourcen für mehrere DBs mit schwankender Last (Budget-basierte Preis-/Performance-Steuerung). |
| HA/DR (Regional) | Zonenredundanz (je nach Tier), **Read Scale-Out** (BC/Hyperscale), **Wartungsfenster** konfigurierbar. |
| Geo-DR | **Active Geo-Replication** (Azure SQL Database, pro DB) & **Auto-Failover Groups** (logischer Server bzw. gesamter MI, Reader/Writer-Listener-Endpunkte). |
| Backups | **Automatische Backups** + PITR/LTR in Azure SQL Database (plattformverwaltet). **MI** unterstützt zusätzlich **native .bak** Restore/Backup über URL (Blob). |
| Sicherheit (Default) | **TDE** standardmäßig aktiv; **Microsoft Entra (Azure AD) Auth** inkl. *Entra-only* (SQL Logins abschaltbar); **Auditing**, **Defender for SQL**, **Ledger** (fälschungssichere Tabellen). |
| T-SQL Surface Area | Azure SQL Database: kein Instanzkontext (z. B. **SQL Agent**, **CLR**, **xp_cmdshell**, **Database Mail**, **Linked Server**, **FILESTREAM** etc.). **MI**: nahe an SQL Server (u. a. **SQL Agent**, **DB Mail**, **Linked Server**), dennoch Einschränkungen. |
| Cross-DB & Externe Daten | Azure SQL Database: eingeschränktes **Cross-DB** (Elastic Query/External Tables); **MI** erlaubt 3-/4-teilige Namen wie On-Prem. |
| Replikation | Azure SQL Database: nur **Subscriber** (Push) für Snapshot/Transactional Repl. **MI**: Publisher/Distributor/Subscriber für Snapshot/Transactional (mit Limits). |
| Automatische Optimierung | **Automatic Tuning** (FORCE_LAST_GOOD_PLAN, CREATE/DROP INDEX) & **Query Store** (DBs in Azure standardmäßig aktiv). |
| Netzwerk/Isolation | Azure SQL Database über **Private Endpoint**; **MI** läuft in **VNet**, optional Public Endpoint; Private Link/Firewall-Modelle. |
| Betrieb/Steuerung | Evergreen Engine (kein Patchen/Upgraden), **Maintenance Windows** steuerbar; **MI**: **Start/Stop** (GP) möglich. |
| Jobs & Orchestrierung | Azure SQL Database: keine Agent Jobs → **Elastic Jobs**, Azure Automation/Functions, Logic Apps. **MI**: SQL Agent verfügbar. |
| Kostenhebel | **Azure Hybrid Benefit** (eigene Lizenzen anrechnen), **Reserved Capacity** (1/3 Jahre), Serverless/Elastic Pool für variable Last. |

---

## 2 | Struktur

### 2.1 | Azure SQL – Bereitstellungsoptionen & Abgrenzung
> **Kurzbeschreibung:** Überblick über Azure SQL Database (Single, Pool, Hyperscale/Serverless), Azure SQL Managed Instance, SQL auf Azure-VMs; Auswahl nach Kompatibilität, Isolation, Featurebedarf.

- 📓 **Notebook:**  
  [`08_01_azure_sql_optionen.ipynb`](08_01_azure_sql_optionen.ipynb)

- 🎥 **YouTube:**  
  - [Azure SQL: Deployment Options (Data Exposed)](https://www.youtube.com/watch?v=2vWnqYQy7a4)  
  - [Azure SQL for Beginners – What is Azure SQL?](https://www.youtube.com/watch?v=gQAvl3A1nHU)

- 📘 **Docs:**  
  - [Azure SQL – Produktfamilie (Übersicht)](https://learn.microsoft.com/en-us/azure/azure-sql/?view=azuresql)  
  - [Features Comparison: SQL Server vs. Azure SQL](https://learn.microsoft.com/en-us/azure/azure-sql/database/features-comparison?view=azuresql)

---

### 2.2 | Compute & Storage: vCore/DTU, Serverless, Hyperscale
> **Kurzbeschreibung:** vCore vs. DTU, Serverless-Autopause, Hyperscale-Architektur & Named Replicas, Ressourcenlimits.

- 📓 **Notebook:**  
  [`08_02_compute_storage_serverless_hyperscale.ipynb`](08_02_compute_storage_serverless_hyperscale.ipynb)

- 🎥 **YouTube:**  
  - [Azure SQL Database Serverless – Überblick](https://www.youtube.com/watch?v=2ykwUOfEPoU)  
  - [Hyperscale Deep Dive (Data Exposed)](https://www.youtube.com/watch?v=4gk4Hl0f3Y4)

- 📘 **Docs:**  
  - [Serverless Compute Tier – Überblick](https://learn.microsoft.com/en-us/azure/azure-sql/database/serverless-tier-overview?view=azuresql)  
  - [Hyperscale – Überblick/Architektur](https://learn.microsoft.com/en-us/azure/azure-sql/database/service-tier-hyperscale?view=azuresql)

---

### 2.3 | Hochverfügbarkeit & Geo-DR (Read Scale-Out, Failover)
> **Kurzbeschreibung:** Zonenredundanz, Read Scale-Out (BC/Hyperscale), Active Geo-Replication (DB) vs. Auto-Failover Groups (DB & MI), RPO/RTO.

- 📓 **Notebook:**  
  [`08_03_ha_geodr_failover.ipynb`](08_03_ha_geodr_failover.ipynb)

- 🎥 **YouTube:**  
  - [Auto-Failover Groups – Praxis](https://www.youtube.com/watch?v=S5b6d2vD7bA)  
  - [Geo-Replication in Azure SQL](https://www.youtube.com/watch?v=R9p2B34qvOQ)

- 📘 **Docs:**  
  - [Active Geo-Replication (Azure SQL Database)](https://learn.microsoft.com/en-us/azure/azure-sql/database/active-geo-replication-overview?view=azuresql)  
  - [Failover Groups – SQL DB / MI](https://learn.microsoft.com/en-us/azure/azure-sql/database/failover-group-sql-db?view=azuresql)

---

### 2.4 | Backups, Wiederherstellung & LTR
> **Kurzbeschreibung:** Plattform-Backups (PITR/LTR) in Azure SQL Database, native .bak bei MI (Restore/Backup via URL), Wiederherstellungsstrategien.

- 📓 **Notebook:**  
  [`08_04_backups_restore_ltr.ipynb`](08_04_backups_restore_ltr.ipynb)

- 🎥 **YouTube:**  
  - [Backup/Restore in Azure SQL (Data Exposed)](https://www.youtube.com/watch?v=7x1wE_6eg44)  
  - [PITR & LTR erklärt](https://www.youtube.com/watch?v=vlQk2FbeWOk)

- 📘 **Docs:**  
  - [Automatische Backups & Wiederherstellung (SQL Database)](https://learn.microsoft.com/en-us/azure/azure-sql/database/automated-backups-overview?view=azuresql)  
  - [Backup/Restore (Managed Instance) – .bak/URL](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/restore-sample-database-quickstart?view=azuresql)

---

### 2.5 | Sicherheit: TDE, Entra-only Auth, Auditing, Defender, Ledger
> **Kurzbeschreibung:** Standardschutz (TDE), Microsoft Entra-only Auth, Audit/Defender-Konfiguration, Ledger-Tabellen für Nachweisbarkeit.

- 📓 **Notebook:**  
  [`08_05_security_tde_entra_audit_defender_ledger.ipynb`](08_05_security_tde_entra_audit_defender_ledger.ipynb)

- 🎥 **YouTube:**  
  - [Ledger in Azure SQL & SQL Server](https://www.youtube.com/watch?v=apXcV0nKd-8)  
  - [Defender for SQL – Überblick](https://www.youtube.com/watch?v=2rJxqkKjTrg)

- 📘 **Docs:**  
  - [Entra-only Authentication (Azure SQL)](https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-azure-ad-only-authentication?view=azuresql)  
  - [Auditing & Defender for SQL](https://learn.microsoft.com/en-us/azure/azure-sql/database/auditing-overview?view=azuresql)

---

### 2.6 | T-SQL Surface Area & Unterschiede (DB vs. MI vs. On-Prem)
> **Kurzbeschreibung:** Instanznahe Features (Agent, CLR, xp_cmdshell, Database Mail, Linked Server, FILESTREAM) – in Azure SQL Database nicht verfügbar; MI: weitgehend kompatibel, aber mit Limits.

- 📓 **Notebook:**  
  [`08_06_tsql_surface_area_differences.ipynb`](08_06_tsql_surface_area_differences.ipynb)

- 🎥 **YouTube:**  
  - [T-SQL on Azure SQL – Differences](https://www.youtube.com/watch?v=4u5XieYqiiA)  
  - [Managed Instance Deep Dive](https://www.youtube.com/watch?v=Rb0rXr2Vq3g)

- 📘 **Docs:**  
  - [T-SQL-Unterschiede: Azure SQL Database vs. SQL Server](https://learn.microsoft.com/en-us/azure/azure-sql/database/transact-sql-tsql-differences-sql-server?view=azuresql)  
  - [T-SQL-Unterschiede: Managed Instance vs. SQL Server](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/transact-sql-tsql-differences-sql-server?view=azuresql)

---

### 2.7 | Cross-Database, Externe Daten & PolyBase/Elastic Query
> **Kurzbeschreibung:** Cross-DB-Zugriffe in Azure SQL Database (Elastic Query/External Tables), Hyperscale Named Replicas; MI/On-Prem mit 3-/4-teiligen Namen & Linked Server.

- 📓 **Notebook:**  
  [`08_07_crossdb_external_polybase.ipynb`](08_07_crossdb_external_polybase.ipynb)

- 🎥 **YouTube:**  
  - [Elastic Query Basics](https://www.youtube.com/watch?v=4Hq6p3nEJ4Q)  
  - [External Tables/OPENROWSET](https://www.youtube.com/watch?v=hK1g3iKb3Ss)

- 📘 **Docs:**  
  - [Elastic Query – Überblick](https://learn.microsoft.com/en-us/azure/azure-sql/database/elastic-scale-introduction?view=azuresql)  
  - [PolyBase FAQ (kein PolyBase in Azure SQL Database)](https://learn.microsoft.com/en-us/sql/relational-databases/polybase/polybase-faq?view=sql-server-ver17)

---

### 2.8 | Jobs & Betrieb: SQL Agent (MI) vs. Elastic Jobs/Automation (DB)
> **Kurzbeschreibung:** Jobverwaltung ohne SQL Agent in Azure SQL Database (Elastic Jobs/Automation/Functions/Logic Apps) vs. klassischer Agent in MI.

- 📓 **Notebook:**  
  [`08_08_jobs_elastic_jobs_vs_agent.ipynb`](08_08_jobs_elastic_jobs_vs_agent.ipynb)

- 🎥 **YouTube:**  
  - [Elastic Jobs – Getting Started](https://www.youtube.com/watch?v=7vmp0lZK6qM)  
  - [Automate with Azure Automation](https://www.youtube.com/watch?v=3xeQHqPK8jo)

- 📘 **Docs:**  
  - [Elastic Jobs (Azure SQL Database)](https://learn.microsoft.com/en-us/azure/azure-sql/database/elastic-jobs-overview?view=azuresql)  
  - [SQL Agent in Managed Instance (Übersicht)](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/sql-managed-instance-paas-overview?view=azuresql)

---

### 2.9 | Performance & Wartung: Query Store, Automatic Tuning, Wartungsfenster
> **Kurzbeschreibung:** Query Store in Azure standardmäßig aktiv; Automatic Tuning (Plan-Erzwingung, Index mgmt.); planbare Wartungsfenster.

- 📓 **Notebook:**  
  [`08_09_perf_qstore_autotune_maintenance.ipynb`](08_09_perf_qstore_autotune_maintenance.ipynb)

- 🎥 **YouTube:**  
  - [Automatic Tuning – How it works](https://www.youtube.com/watch?v=9c4eYhDABaA)  
  - [Query Store – Best Practices](https://www.youtube.com/watch?v=m1p2l3SxK6o)

- 📘 **Docs:**  
  - [Automatic Tuning – Überblick](https://learn.microsoft.com/en-us/azure/azure-sql/database/automatic-tuning-overview?view=azuresql)  
  - [Query Performance Insight (Query Store vorausgesetzt)](https://learn.microsoft.com/en-us/azure/azure-sql/database/query-performance-insight-use?view=azuresql)

---

### 2.10 | Netzwerk & Auth: Private Endpoints, VNet (MI), Entra-Integration
> **Kurzbeschreibung:** Zugriffssicherung via Firewall/Private Link; MI im VNet; Entra-Integration, Entra-only Auth, Managed Identities.

- 📓 **Notebook:**  
  [`08_10_network_auth_private_link_entra.ipynb`](08_10_network_auth_private_link_entra.ipynb)

- 🎥 **YouTube:**  
  - [Private Link for Azure SQL](https://www.youtube.com/watch?v=q6Rj9oTCqOw)  
  - [Entra ID to Azure SQL (App → DB)](https://www.youtube.com/watch?v=tU7cgQ8sXGQ)

- 📘 **Docs:**  
  - [Microsoft Entra Auth – Übersicht](https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-overview?view=azuresql)  
  - [Private Endpoints – Azure SQL Database](https://learn.microsoft.com/en-us/azure/azure-sql/database/private-endpoint-overview?view=azuresql)

---

### 2.11 | Replikation & Datensynchronisation
> **Kurzbeschreibung:** Transactional/Snapshot Replication: Azure SQL Database nur Push-Subscriber; MI als Publisher/Distributor/Subscriber (mit Anforderungen). SQL Data Sync (Ablösung angekündigt).

- 📓 **Notebook:**  
  [`08_11_replication_datasync.ipynb`](08_11_replication_datasync.ipynb)

- 🎥 **YouTube:**  
  - [MI Link & Read-Scale Szenarien](https://www.youtube.com/watch?v=a3d6jDuM5RA)  
  - [SQL Data Sync – Use Cases (Data Exposed)](https://www.youtube.com/watch?v=3v2w4Qm4o5c)

- 📘 **Docs:**  
  - [Replication mit Managed Instance](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/replication-transactional-overview?view=azuresql)  
  - [SQL Data Sync (Retirement angekündigt)](https://learn.microsoft.com/en-us/azure/azure-sql/database/sql-data-sync-data-sql-server-sql-database?view=azuresql)

---

### 2.12 | Kosten & Governance (AHB, Reservierungen, Start/Stop MI)
> **Kurzbeschreibung:** Kostenmodelle (vCore/DTU), Azure Hybrid Benefit, Reservierungen; Serverless/Pool für variable Last; Start/Stop bei MI (GP) zum Kosten sparen.

- 📓 **Notebook:**  
  [`08_12_costs_ahb_reservations_startstop_mi.ipynb`](08_12_costs_ahb_reservations_startstop_mi.ipynb)

- 🎥 **YouTube:**  
  - [Pricing & Purchasing Models – Azure SQL](https://www.youtube.com/watch?v=Rq-X3fr4F6s)  
  - [Save with Azure Hybrid Benefit](https://www.youtube.com/watch?v=6cQjCq1gQ2g)

- 📘 **Docs:**  
  - [vCore-/DTU-Modelle (SQL Database)](https://learn.microsoft.com/en-us/azure/azure-sql/database/purchasing-models?view=azuresql)  
  - [Start/Stop Managed Instance (GP)](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/instance-stop-start-how-to?view=azuresql)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Features Comparison – SQL Server vs. Azure SQL](https://learn.microsoft.com/en-us/azure/azure-sql/database/features-comparison?view=azuresql)  
- 📘 Microsoft Learn: [Serverless Compute Tier – Azure SQL Database](https://learn.microsoft.com/en-us/azure/azure-sql/database/serverless-tier-overview?view=azuresql)  
- 📘 Microsoft Learn: [Hyperscale – Architektur & Verwaltung](https://learn.microsoft.com/en-us/azure/azure-sql/database/hyperscale-architecture?view=azuresql)  
- 📘 Microsoft Learn: [Active Geo-Replication (SQL DB)](https://learn.microsoft.com/en-us/azure/azure-sql/database/active-geo-replication-overview?view=azuresql)  
- 📘 Microsoft Learn: [Failover Groups – SQL DB & MI](https://learn.microsoft.com/en-us/azure/azure-sql/database/failover-group-sql-db?view=azuresql)  
- 📘 Microsoft Learn: [Automatische Backups & PITR/LTR (SQL DB)](https://learn.microsoft.com/en-us/azure/azure-sql/database/automated-backups-overview?view=azuresql)  
- 📘 Microsoft Learn: [Backup/Restore mit .bak (Managed Instance)](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/restore-sample-database-quickstart?view=azuresql)  
- 📘 Microsoft Learn: [T-SQL-Unterschiede – Azure SQL Database](https://learn.microsoft.com/en-us/azure/azure-sql/database/transact-sql-tsql-differences-sql-server?view=azuresql)  
- 📘 Microsoft Learn: [T-SQL-Unterschiede – Managed Instance](https://learn.microsoft.com/en-us/azure/azure-sql/managed-instance/transact-sql-tsql-differences-sql-server?view=azuresql)  
- 📘 Microsoft Learn: [Automatic Tuning – Übersicht](https://learn.microsoft.com/en-us/azure/azure-sql/database/automatic-tuning-overview?view=azuresql)  
- 📘 Microsoft Learn: [Microsoft Entra-only Authentication](https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-azure-ad-only-authentication?view=azuresql)  
- 📘 Microsoft Learn: [Azure SQL Database – Elastic Jobs](https://learn.microsoft.com/en-us/azure/azure-sql/database/elastic-jobs-overview?view=azuresql)  
- 📘 Microsoft Learn: [Query Performance Insight (Query Store)](https://learn.microsoft.com/en-us/azure/azure-sql/database/query-performance-insight-use?view=azuresql)  
- 📘 Microsoft Learn: [Auditing – Überblick](https://learn.microsoft.com/en-us/azure/azure-sql/database/auditing-overview?view=azuresql)  
