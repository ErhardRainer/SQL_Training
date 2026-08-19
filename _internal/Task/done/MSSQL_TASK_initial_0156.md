---
task_id: MSSQL_TASK_initial_0156
repository: SQL_Training
domain: MSSQL
title: "Script AggregateGroupSkewProfile.sql fuer 10_GroupBy_Aggregate erstellen"
status: done
priority: 845
priority_class: high
created_at: "2026-04-18T22:47:52Z"
updated_at: "2026-04-18T13:47:51Z"

responsible_type: ai
assignee: ai-agent
reviewer: erhard
agent:
  allowed: true
  review_required: true

acceptance_criteria_status: verified

source:
  type: repository
  reference: "T-SQL/Script.md#upcomming-scripts; queue: sql-0156"
  url: null
  author: null
  published_at: null

affected_paths:
  - path: "T-SQL/10_GroupBy_Aggregate/SQLScripts/AggregateGroupSkewProfile.sql"
    change: "SQL-Skript erstellen oder pruefen"
  - path: "T-SQL/10_GroupBy_Aggregate/SQLScripts/AggregateGroupSkewProfile.md"
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

# MSSQL_TASK_initial_0156 - Script AggregateGroupSkewProfile.sql fuer 10_GroupBy_Aggregate erstellen

## Anlass und Relevanz

Profiling stark ungleich verteilter Gruppen.

## Bereits vorhandene Abdeckung

Status aus der Artefaktpruefung: SQL- und Markdown-Artefakt vorhanden und strukturell gegen den Repository-Standard geprueft.

Gepruefte Zielpfade:

- T-SQL/10_GroupBy_Aggregate/SQLScripts/AggregateGroupSkewProfile.sql
- T-SQL/10_GroupBy_Aggregate/SQLScripts/AggregateGroupSkewProfile.md

## Umsetzungsauftrag

Erzeuge `AggregateGroupSkewProfile.sql` und die zugehoerige Markdown-Dokumentation gemaess `_internal/SQL-Script/instruction_SQL_Script.md`. Verwende Kapitel `10_GroupBy_Aggregate` und diese fachliche Kurzbeschreibung als Rahmen: Profiling stark ungleich verteilter Gruppen. Lege fehlende Ordner an, dokumentiere Annahmen neutral und halte YAML-Header, SQLDOC-Marker sowie Mermaid-Block ein.

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
