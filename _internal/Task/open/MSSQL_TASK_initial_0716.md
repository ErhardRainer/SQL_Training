---
task_id: MSSQL_TASK_initial_0716
repository: SQL_Training
domain: MSSQL
title: "Script BrokerDialogCleanupPlanner.sql fuer 69_ServiceBroker_Queues erstellen"
status: open
priority: 285
priority_class: normal
created_at: "2026-04-18T22:47:53Z"
updated_at: "2026-04-18T22:47:53Z"

responsible_type: ai
assignee: ai-agent
reviewer: erhard
agent:
  allowed: true
  review_required: true

acceptance_criteria_status: draft

source:
  type: repository
  reference: "T-SQL/Script.md#upcomming-scripts; queue: sql-0716"
  url: null
  author: null
  published_at: null

affected_paths:
  - path: "T-SQL/69_ServiceBroker_Queues/SQLScripts/BrokerDialogCleanupPlanner.sql"
    change: "SQL-Skript erstellen oder pruefen"
  - path: "T-SQL/69_ServiceBroker_Queues/SQLScripts/BrokerDialogCleanupPlanner.md"
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

# MSSQL_TASK_initial_0716 - Script BrokerDialogCleanupPlanner.sql fuer 69_ServiceBroker_Queues erstellen

## Anlass und Relevanz

Plant das Aufraeumen alter Broker-Dialoge.

## Bereits vorhandene Abdeckung

Noch nicht umgesetzt; beide Zielartefakte fehlen.

Gepruefte Zielpfade:

- T-SQL/69_ServiceBroker_Queues/SQLScripts/BrokerDialogCleanupPlanner.sql
- T-SQL/69_ServiceBroker_Queues/SQLScripts/BrokerDialogCleanupPlanner.md

## Umsetzungsauftrag

Erzeuge `BrokerDialogCleanupPlanner.sql` und die zugehoerige Markdown-Dokumentation gemaess `_internal/SQL-Script/instruction_SQL_Script.md`. Verwende Kapitel `69_ServiceBroker_Queues` und diese fachliche Kurzbeschreibung als Rahmen: Plant das Aufraeumen alter Broker-Dialoge. Lege fehlende Ordner an, dokumentiere Annahmen neutral und halte YAML-Header, SQLDOC-Marker sowie Mermaid-Block ein.

## Akzeptanzkriterien

- [ ] SQL-Datei vorhanden
- [ ] Markdown-Datei vorhanden
- [ ] YAML-Header vorhanden
- [ ] script_version gesetzt
- [ ] Markdown-Sync-Marker vorhanden
- [ ] Mermaid-Block vorhanden
- [ ] SQL-Codeblock synchronisiert
- [ ] Annahmen sachlich dokumentiert
- [ ] didaktische oder sichere diagnostische Umsetzung erstellt

## Agentenprotokoll

### Analyse und Entscheidungen

Task aus T-SQL/Script.md und der stabilen Queue Task.rebuilt.json rekonstruiert.
Weder SQL- noch Markdown-Artefakt vorhanden.

### Implementierungsfortschritt

Keine Umsetzung im Rahmen der Rekonstruktion vorgenommen.

### Offene Punkte und Uebergabe

Task ist zur Umsetzung in der offenen Ablage vorgesehen.
