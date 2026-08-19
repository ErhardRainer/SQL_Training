---
task_id: MSSQL_TASK_initial_0337
repository: SQL_Training
domain: MSSQL
title: "Script LegacyQuotedIdentifierModules.sql fuer 21_QUOTED_IDENTIFIER erstellen"
status: done
priority: 664
priority_class: normal
created_at: "2026-04-18T22:47:53Z"
updated_at: "2026-04-22T09:38:08Z"

responsible_type: ai
assignee: ai-agent
reviewer: erhard
agent:
  allowed: true
  review_required: true

acceptance_criteria_status: verified

source:
  type: repository
  reference: "T-SQL/Script.md#upcomming-scripts; queue: sql-0337"
  url: null
  author: null
  published_at: null

affected_paths:
  - path: "T-SQL/21_QUOTED_IDENTIFIER/SQLScripts/LegacyQuotedIdentifierModules.sql"
    change: "SQL-Skript erstellen oder pruefen"
  - path: "T-SQL/21_QUOTED_IDENTIFIER/SQLScripts/LegacyQuotedIdentifierModules.md"
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

# MSSQL_TASK_initial_0337 - Script LegacyQuotedIdentifierModules.sql fuer 21_QUOTED_IDENTIFIER erstellen

## Anlass und Relevanz

Findet aeltere Module mit problematischen `QUOTED_IDENTIFIER`-Settings.

## Bereits vorhandene Abdeckung

Status aus der Artefaktpruefung: SQL- und Markdown-Artefakt vorhanden und strukturell gegen den Repository-Standard geprueft.

Gepruefte Zielpfade:

- T-SQL/21_QUOTED_IDENTIFIER/SQLScripts/LegacyQuotedIdentifierModules.sql
- T-SQL/21_QUOTED_IDENTIFIER/SQLScripts/LegacyQuotedIdentifierModules.md

## Umsetzungsauftrag

Erzeuge `LegacyQuotedIdentifierModules.sql` und die zugehoerige Markdown-Dokumentation gemaess `_internal/SQL-Script/instruction_SQL_Script.md`. Verwende Kapitel `21_QUOTED_IDENTIFIER` und diese fachliche Kurzbeschreibung als Rahmen: Findet aeltere Module mit problematischen `QUOTED_IDENTIFIER`-Settings. Lege fehlende Ordner an, dokumentiere Annahmen neutral und halte YAML-Header, SQLDOC-Marker sowie Mermaid-Block ein.

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
