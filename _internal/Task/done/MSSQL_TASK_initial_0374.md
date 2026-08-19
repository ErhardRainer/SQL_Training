---
task_id: MSSQL_TASK_initial_0374
repository: SQL_Training
domain: MSSQL
title: "Script ProcedureDynamicSqlFinder.sql fuer 23_StoredProcedures erstellen"
status: done
priority: 627
priority_class: normal
created_at: "2026-04-18T22:47:53Z"
updated_at: "2026-04-17T14:12:19Z"

responsible_type: ai
assignee: ai-agent
reviewer: erhard
agent:
  allowed: true
  review_required: true

acceptance_criteria_status: verified

source:
  type: repository
  reference: "T-SQL/Script.md#upcomming-scripts; queue: sql-0374"
  url: null
  author: null
  published_at: null

affected_paths:
  - path: "T-SQL/23_StoredProcedures/SQLScripts/ProcedureDynamicSqlFinder.sql"
    change: "SQL-Skript erstellen oder pruefen"
  - path: "T-SQL/23_StoredProcedures/SQLScripts/ProcedureDynamicSqlFinder.md"
    change: "Zugehoerige Markdown-Dokumentation erstellen oder pruefen"

related_tasks: []
depends_on: []
blocks: []

planning:
  effort_class: small
  estimated_effort_hours: 4

execution_context:
  required_guides:
    - path: "ai_agents.md"
      purpose: "Verweist auf die fuer die Umsetzung geltenden Arbeitsanweisungen."
    - path: "_internal/instructions/legacy_task_queue/01_Skill.md"
      purpose: "Definiert den Standard fuer SQL-Skript und Markdown-Dokumentation."
---

# MSSQL_TASK_initial_0374 - Script ProcedureDynamicSqlFinder.sql fuer 23_StoredProcedures erstellen

## Anlass und Relevanz

Findet Prozeduren, die dynamisches SQL verwenden.

## Bereits vorhandene Abdeckung

Status aus der Artefaktpruefung: SQL- und Markdown-Artefakt vorhanden und strukturell gegen den Repository-Standard geprueft.

Gepruefte Zielpfade:

- T-SQL/23_StoredProcedures/SQLScripts/ProcedureDynamicSqlFinder.sql
- T-SQL/23_StoredProcedures/SQLScripts/ProcedureDynamicSqlFinder.md

## Umsetzungsauftrag

Erzeuge `ProcedureDynamicSqlFinder.sql` und die zugehoerige Markdown-Dokumentation gemaess `_internal/SQL-Script/instruction_SQL_Script.md`. Verwende Kapitel `23_StoredProcedures` und diese fachliche Kurzbeschreibung als Rahmen: Findet Prozeduren, die dynamisches SQL verwenden. Lege fehlende Ordner an, dokumentiere Annahmen neutral und halte YAML-Header, SQLDOC-Marker sowie Mermaid-Block ein.

## Akzeptanzkriterien

- [x] SQL-Datei vorhanden
- [x] Markdown-Datei vorhanden
- [x] YAML-Header vorhanden
- [x] script_version gesetzt
- [x] Markdown-Sync-Marker vorhanden
- [x] Mermaid-Block vorhanden
- [x] SQL-Codeblock synchronisiert
- [x] Annahmen sachlich dokumentiert
- [x] didaktische oder sichere diagnostische Umsetzung erstellt

## Agentenprotokoll

### Analyse und Entscheidungen

Task aus T-SQL/Script.md und der stabilen Queue Task.rebuilt.json rekonstruiert.
SQL- und Markdown-Artefakt vorhanden und strukturell gegen den Repository-Standard geprueft.

### Implementierungsfortschritt

Strukturelle Rekonstruktionspruefung abgeschlossen. SQL-Server-Ausfuehrung war nicht Teil der Rekonstruktion.

### Offene Punkte und Uebergabe

Keine offenen Punkte aus der strukturellen Rekonstruktion.
