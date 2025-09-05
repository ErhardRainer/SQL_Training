# T-SQL Security: Rollen & Berechtigungen – Übersicht  
*Rollenmodell, Rechteverwaltung, Best Practices für Security*

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| Principal | Sicherheitsidentität: **Logins** (Server), **User** (Datenbank), **Rollen** (Server/DB), **Anwendungsrollen**, **Zertifikate**, **Asym. Schlüssel**. |
| Securable | Sicherheitsobjekt mit Rechten: **Server** → **Datenbank** → **Schema** → **Objekte** (Tabelle, View, Proc, …) → **Spalten**. |
| Permission | `GRANT` / `DENY` / `REVOKE` auf Securables, inkl. **WITH GRANT OPTION** (Rechte weitergeben). |
| Permission-Hierarchie | **CONTROL** ⊃ **ALTER**/`ALTER ANY …` ⊃ **SELECT/INSERT/UPDATE/DELETE/EXECUTE**; Vererbung über Schema/Objekt-Hierarchie. |
| Fixed Server Roles | Vordefinierte Serverrollen (z. B. `sysadmin`, `securityadmin`, `serveradmin` …). |
| Fixed Database Roles | Vordefinierte DB-Rollen (z. B. `db_owner`, `db_datareader`, `db_datawriter`, `db_ddladmin` …). |
| Benutzerdef. Rollen | Eigene (Server-/DB-)Rollen zur Gruppierung von Rechten; Mitgliedschaften verwalten. |
| Schemas als Boundary | Schema als **Sicherheitsgrenze** nutzen: Rechte **auf Schema** statt auf Einzelobjekte vergeben. |
| Ownership Chaining | Wenn Eigentümer (Owner) gleich ist, prüft SQL Server nachgelagerte Objektberechtigungen ggf. **nicht erneut** (Beachtung bei Procs/Views). |
| Module Signing | Module (PROC/VIEW/TRIGGER) mit **Zertifikat/Asym.-Schlüssel** signieren → **privilegierte Operationen** ohne `EXECUTE AS`. |
| `EXECUTE AS` | Kontextwechsel: `CALLER`/`SELF`/`OWNER`/`'user'` – beeinflusst Rechteprüfung und Cross-DB-Zugriff. |
| Contained Database User | Benutzer **ohne Server-Login** (`CONTAINED`) – vereinfacht Bereitstellung/Restore. |
| Authentifizierung | **Windows/AD** (empfohlen), **SQL Logins**, **Azure AD** (bei Azure SQL). |
| Effektive Berechtigungen | Ergebnis aus GRANT/REVOKE/Vererbung/Rollen; **DENY** hat Vorrang vor `GRANT`. |
| Auditing/Monitoring | Server/DB-Audit, `fn_my_permissions`, Katalog-Views (`sys.server_permissions`, `sys.database_permissions`, …). |
| Best Practices | **Least Privilege**, Rolle-basierte Rechte, Schema-basiert vergeben, `db_owner`/`sysadmin` minimieren, Secrets/Keys geschützt verwalten. |

---

## 2 | Struktur

### 2.1 | Sicherheitsmodell: Principals, Securables, Permissions
> **Kurzbeschreibung:** Hierarchie & Begriffe; von Server bis Spalte, Vererbung & Priorität von `DENY`.

- 📓 **Notebook:**  
  [`08_01_security_modell_grundlagen.ipynb`](08_01_security_modell_grundlagen.ipynb)
- 🎥 **YouTube:**  
  - [SQL Server Permissions & Securables Overview](https://www.youtube.com/results?search_query=sql+server+permissions+securables+overview)
- 📘 **Docs:**  
  - [Permissions Hierarchy](https://learn.microsoft.com/en-us/sql/relational-databases/security/permissions-database-engine)  
  - [Securables](https://learn.microsoft.com/en-us/sql/relational-databases/security/securables)

---

### 2.2 | Serverrollen & Serverberechtigungen
> **Kurzbeschreibung:** Fixed Server Roles, `GRANT CONTROL SERVER`, Logins erstellen, Passwort-/Policy-Optionen.

- 📓 **Notebook:**  
  [`08_02_serverrollen_berechtigungen.ipynb`](08_02_serverrollen_berechtigungen.ipynb)
- 🎥 **YouTube:**  
  - [Fixed Server Roles Explained](https://www.youtube.com/results?search_query=sql+server+fixed+server+roles)
- 📘 **Docs:**  
  - [Server-Level Roles](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/server-level-roles)  
  - [`CREATE LOGIN`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-login-transact-sql)

---

### 2.3 | Datenbankrollen & Rechtevergabe
> **Kurzbeschreibung:** Fixed DB Roles vs. Custom Roles; `CREATE USER`, `ALTER ROLE … ADD MEMBER`, Rechte paketieren.

- 📓 **Notebook:**  
  [`08_03_dbrollen_rechtevergabe.ipynb`](08_03_dbrollen_rechtevergabe.ipynb)
- 🎥 **YouTube:**  
  - [Database Roles & Users](https://www.youtube.com/results?search_query=sql+server+database+roles+users)
- 📘 **Docs:**  
  - [Database-Level Roles](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/database-level-roles)  
  - [`CREATE USER`](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-user-transact-sql)

---

### 2.4 | GRANT / DENY / REVOKE – Syntax & Muster
> **Kurzbeschreibung:** Objekt-, Schema-, Datenbank- und Server-Scopes; `WITH GRANT OPTION`; `DENY`-Auswirkungen.

- 📓 **Notebook:**  
  [`08_04_grant_deny_revoke_patterns.ipynb`](08_04_grant_deny_revoke_patterns.ipynb)
- 🎥 **YouTube:**  
  - [Grant, Deny, Revoke in SQL Server](https://www.youtube.com/results?search_query=sql+server+grant+deny+revoke)
- 📘 **Docs:**  
  - [`GRANT` (Database Engine)](https://learn.microsoft.com/en-us/sql/t-sql/statements/grant-database-engine) ・ [`DENY`](https://learn.microsoft.com/en-us/sql/t-sql/statements/deny-database-engine) ・ [`REVOKE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/revoke-database-engine)

---

### 2.5 | Schemas als Sicherheitsgrenze
> **Kurzbeschreibung:** Rechte **auf Schema** vergeben, Ownership, Deployment-Strategien, Objektlebenszyklus.

- 📓 **Notebook:**  
  [`08_05_schema_security_boundary.ipynb`](08_05_schema_security_boundary.ipynb)
- 🎥 **YouTube:**  
  - [Schema-Based Security](https://www.youtube.com/results?search_query=sql+server+schema+based+security)
- 📘 **Docs:**  
  - [Database Schemas – Security](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/principals-database#schemas)

---

### 2.6 | Ownership Chaining & Cross-DB Access
> **Kurzbeschreibung:** Wann werden Objektberechtigungen übersprungen? Cross-DB-Ownership-Chaining, Risiken & Alternativen.

- 📓 **Notebook:**  
  [`08_06_ownership_chaining_crossdb.ipynb`](08_06_ownership_chaining_crossdb.ipynb)
- 🎥 **YouTube:**  
  - [Ownership Chains Explained](https://www.youtube.com/results?search_query=sql+server+ownership+chaining)
- 📘 **Docs:**  
  - [Ownership Chains](https://learn.microsoft.com/en-us/sql/relational-databases/security/ownership-chains)

---

### 2.7 | `EXECUTE AS` – Kontextwechsel richtig einsetzen
> **Kurzbeschreibung:** `CALLER/OWNER/SELF/'user'`, Signatur & Berechtigungsprüfung, Rückkehr via `REVERT`.

- 📓 **Notebook:**  
  [`08_07_execute_as_kontextwechsel.ipynb`](08_07_execute_as_kontextwechsel.ipynb)
- 🎥 **YouTube:**  
  - [EXECUTE AS Demo](https://www.youtube.com/results?search_query=sql+server+execute+as+demo)
- 📘 **Docs:**  
  - [`EXECUTE AS` Clause](https://learn.microsoft.com/en-us/sql/t-sql/statements/execute-as-clause-transact-sql)

---

### 2.8 | Module Signing (Zertifikat/Asym. Schlüssel)
> **Kurzbeschreibung:** Module signieren statt dauerhafte Elevation; Cross-DB-Zugriffe sicher ermöglichen.

- 📓 **Notebook:**  
  [`08_08_module_signing_certificates.ipynb`](08_08_module_signing_certificates.ipynb)
- 🎥 **YouTube:**  
  - [Module Signing in SQL Server](https://www.youtube.com/results?search_query=sql+server+module+signing)
- 📘 **Docs:**  
  - [Sign Stored Procedure with a Certificate](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/signing-stored-procedures)

---

### 2.9 | Contained Databases & Benutzer ohne Login
> **Kurzbeschreibung:** `CONTAINMENT = PARTIAL`, Benutzerverwaltung pro DB, Migrations-/Restore-Vorteile.

- 📓 **Notebook:**  
  [`08_09_contained_db_users.ipynb`](08_09_contained_db_users.ipynb)
- 🎥 **YouTube:**  
  - [Contained Users Explained](https://www.youtube.com/results?search_query=sql+server+contained+database+users)
- 📘 **Docs:**  
  - [Contained Databases](https://learn.microsoft.com/en-us/sql/relational-databases/databases/contained-databases)

---

### 2.10 | Anwendungsrollen & Proxy/Credentials (Agent)
> **Kurzbeschreibung:** **Application Roles** für app-spezifische Rechte; SQL Agent **Proxies** via Credentials.

- 📓 **Notebook:**  
  [`08_10_application_roles_agent_proxies.ipynb`](08_10_application_roles_agent_proxies.ipynb)
- 🎥 **YouTube:**  
  - [Application Roles in SQL Server](https://www.youtube.com/results?search_query=sql+server+application+roles)
- 📘 **Docs:**  
  - [Application Roles](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/application-roles)  
  - [SQL Agent Proxies](https://learn.microsoft.com/en-us/sql/ssms/agent/create-a-sql-server-agent-proxy)

---

### 2.11 | Effektive Rechte prüfen & auditieren
> **Kurzbeschreibung:** `fn_my_permissions`, `HAS_PERMS_BY_NAME`, Katalog-Views; Server-/DB-Audits konfigurieren.

- 📓 **Notebook:**  
  [`08_11_effective_permissions_audit.ipynb`](08_11_effective_permissions_audit.ipynb)
- 🎥 **YouTube:**  
  - [Check Effective Permissions](https://www.youtube.com/results?search_query=sql+server+effective+permissions)
- 📘 **Docs:**  
  - [`fn_my_permissions`](https://learn.microsoft.com/en-us/sql/t-sql/functions/fn-my-permissions-transact-sql)  
  - [SQL Server Audit](https://learn.microsoft.com/en-us/sql/relational-databases/security/auditing/sql-server-audit-database-engine)

---

### 2.12 | Azure/AD-Integration (Überblick)
> **Kurzbeschreibung:** Windows/AD-Gruppen nutzen; Azure SQL: **Azure AD Principals**, RBAC, `CREATE USER FROM EXTERNAL PROVIDER`.

- 📓 **Notebook:**  
  [`08_12_ad_integration_azure_overview.ipynb`](08_12_ad_integration_azure_overview.ipynb)
- 🎥 **YouTube:**  
  - [Azure AD Authentication for SQL](https://www.youtube.com/results?search_query=azure+sql+azure+ad+authentication)
- 📘 **Docs:**  
  - [Azure AD Auth (Azure SQL)](https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-overview)

---

### 2.13 | Objektfeingranular: Spaltenrechte, VIEW DEFINITION
> **Kurzbeschreibung:** Spaltenweise `SELECT/UPDATE`, `VIEW DEFINITION` steuern, Metadatenzugriff einschränken.

- 📓 **Notebook:**  
  [`08_13_object_column_level_rights.ipynb`](08_13_object_column_level_rights.ipynb)
- 🎥 **YouTube:**  
  - [Column Level Permissions](https://www.youtube.com/results?search_query=sql+server+column+level+permissions)
- 📘 **Docs:**  
  - [Metadata Visibility Configuration](https://learn.microsoft.com/en-us/sql/relational-databases/security/metadata-visibility-configuration)

---

### 2.14 | Integration mit Features: RLS, DDM, AE, TDE (Kurzüberblick)
> **Kurzbeschreibung:** Wie Berechtigungen mit **Row-Level Security**, **Dynamic Data Masking**, **Always Encrypted**, **TDE** zusammenspielen.

- 📓 **Notebook:**  
  [`08_14_integration_rls_ddm_ae_tde.ipynb`](08_14_integration_rls_ddm_ae_tde.ipynb)
- 🎥 **YouTube:**  
  - [Security Features Overview](https://www.youtube.com/results?search_query=sql+server+security+features+overview)
- 📘 **Docs:**  
  - [Security Center (SQL Server)](https://learn.microsoft.com/en-us/sql/relational-databases/security/security-center-for-sql-server-database-engine-and-azure-sql-database)

---

### 2.15 | Hardening & Betrieb: Best Practices
> **Kurzbeschreibung:** Least Privilege, Passwort-/Policy, Verschlüsselung von Secrets, Endpoints/Surface Area, Trennung Dev/Prod.

- 📓 **Notebook:**  
  [`08_15_hardening_best_practices.ipynb`](08_15_hardening_best_practices.ipynb)
- 🎥 **YouTube:**  
  - [SQL Server Security Best Practices](https://www.youtube.com/results?search_query=sql+server+security+best+practices)
- 📘 **Docs:**  
  - [Best Practices – Database Engine](https://learn.microsoft.com/en-us/sql/sql-server/security-best-practice)

---

### 2.16 | Anti-Patterns & Checkliste
> **Kurzbeschreibung:** Jeder ist `db_owner`/`sysadmin`, direkte Objekt-GRANTs statt Schema, `DENY`-Wildwuchs, keine Audits, fehlendes Rollenkonzept, `EXECUTE AS` ohne `REVERT`, Cross-DB-Chaining aktiviert, Module ohne Signing.

- 📓 **Notebook:**  
  [`08_16_security_antipatterns_checkliste.ipynb`](08_16_security_antipatterns_checkliste.ipynb)
- 🎥 **YouTube:**  
  - [Common Security Mistakes in SQL Server](https://www.youtube.com/results?search_query=sql+server+security+mistakes)
- 📘 **Docs/Blog:**  
  - [Security Checklist](https://learn.microsoft.com/en-us/sql/sql-server/security-best-practice#security-checklist)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Permissions (Database Engine) – Übersicht & Matrix](https://learn.microsoft.com/en-us/sql/relational-databases/security/permissions-database-engine)  
- 📘 Microsoft Learn: [Securables – Server/DB/Schema/Object](https://learn.microsoft.com/en-us/sql/relational-databases/security/securables)  
- 📘 Microsoft Learn: [Server-Level Roles (Fixed Roles)](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/server-level-roles)  
- 📘 Microsoft Learn: [Database-Level Roles (Fixed Roles)](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/database-level-roles)  
- 📘 Microsoft Learn: [`GRANT` / `DENY` / `REVOKE` – Referenz](https://learn.microsoft.com/en-us/sql/t-sql/statements/grant-database-engine)  
- 📘 Microsoft Learn: [Ownership Chains](https://learn.microsoft.com/en-us/sql/relational-databases/security/ownership-chains)  
- 📘 Microsoft Learn: [Module Signing (Sign Stored Procedures)](https://learn.microsoft.com/en-us/sql/relational-databases/security/authentication-access/signing-stored-procedures)  
- 📘 Microsoft Learn: [Contained Databases & Users](https://learn.microsoft.com/en-us/sql/relational-databases/databases/contained-databases)  
- 📘 Microsoft Learn: [SQL Server Audit – Konfiguration](https://learn.microsoft.com/en-us/sql/relational-databases/security/auditing/sql-server-audit-database-engine)  
- 📘 Microsoft Learn: [Metadata Visibility & `VIEW DEFINITION`](https://learn.microsoft.com/en-us/sql/relational-databases/security/metadata-visibility-configuration)  
- 📘 Microsoft Learn: [`fn_my_permissions` / `HAS_PERMS_BY_NAME`](https://learn.microsoft.com/en-us/sql/t-sql/functions/fn-my-permissions-transact-sql)  
- 📘 Microsoft Learn: [Security Best Practices (Engine + Azure SQL)](https://learn.microsoft.com/en-us/sql/sql-server/security-best-practice)  
- 📝 SQLSkills (Kimberly Tripp): *Security & Schemas – Design Patterns* – https://www.sqlskills.com/  
- 📝 SQLPerformance: *Permission Sets, Ownership Chains & Performance* – https://www.sqlperformance.com/?s=permissions  
- 📝 Brent Ozar: *Stop Granting db_owner to Everyone* – https://www.brentozar.com/  
- 📝 Erik Darling: *Module Signing vs EXECUTE AS* – https://www.erikdarlingdata.com/  
- 📝 Redgate Simple Talk: *SQL Server Security – Practical Guide* – https://www.red-gate.com/simple-talk/  
- 🎥 YouTube (Data Exposed): *Security & Permissions Deep Dive* – Suchlink  
- 🎥 YouTube: *Ownership Chains, EXECUTE AS & Module Signing* – Suchlink  
