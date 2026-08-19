---
task_id: MSSQL_TASK_0001
repository: SQL_Training
domain: MSSQL
title: "Datenverlustschutz bei DacPac-Bereitstellungen erklären"
status: idea
priority: 500
priority_class: normal
created_at: "2026-08-19T11:00:00+00:00"
updated_at: "2026-08-19T11:43:47+00:00"
responsible_type: ai
assignee: ai-agent
reviewer: erhard
agent:
  allowed: true
  review_required: true
acceptance_criteria_status: draft
source:
  type: reddit
  post_id: t3_1vnlxno
  url: "https://www.reddit.com/r/SQLServer/comments/1vnlxno/sqls_best_feature_blockonpossibledataloss/"
  author: "/u/Jerry-Nixon"
  published_at: "2026-08-13T20:12:49+00:00"
affected_paths:
  - path: "T-SQL/"
    change: "Neues Lernmodul zur sicheren DacPac-/DacFx-Schemabereitstellung"
  - path: "T-SQL/README.md"
    change: "Navigation zum neuen Modul ergänzen"
related_tasks: []
depends_on: []
blocks: []
planning:
  effort_class: medium
  estimated_effort_hours: 8
execution_context:
  required_guides:
    - path: "ai_agents.md"
      purpose: "Verweist auf die für die Umsetzung geltenden Arbeitsanweisungen."
    - path: "_internal/instructions/instruction_improveArticle.md"
      purpose: "Definiert die didaktischen Anforderungen, falls ein Übersichtsartikel erstellt oder erweitert wird."
---

# MSSQL_TASK_0001 – Datenverlustschutz bei DacPac-Bereitstellungen erklären

## Anlass und Relevanz

`BlockOnPossibleDataLoss` verhindert bei DacFx-/DacPac-Publishing potenziell
destruktive Schemaänderungen. Das ist ein übertragbares Thema für sichere
SQL-Server-Deployments: Lernende sollen den Schutz verstehen, nicht durch eine
blinde Deaktivierung umgehen und einen kontrollierten Migrationsweg kennen.

## Bereits vorhandene Abdeckung

Im Repository wurde keine didaktische Abdeckung zu DacPac, DacFx oder
`BlockOnPossibleDataLoss` gefunden. Das Kapitel
`T-SQL/20_Create_Database/20_Create_Database.md` behandelt Datenbankobjekte,
aber keine sichere projektbasierte Schema-Bereitstellung.

## Umsetzungsauftrag

Erstelle ein neues, passend in die T-SQL-Navigation integriertes Lernmodul zur
sicheren DacPac-/DacFx-Schemabereitstellung. Erkläre die Auslöser des
BlockOnPossibleDataLoss-Schutzes anhand kleiner, reproduzierbarer Beispiele
(etwa Spaltenverkleinerung oder -entfernung). Stelle sichere Alternativen wie
expand/contract-Migrationen, Datenmigration vor dem Schemawechsel, Backup und
Staging-Validierung gegenüber. Ergänze nachvollziehbare T-SQL-Beispiele,
eine Checkliste für Deployment-Reviews und Links zu vorhandenen Kapiteln über
Datentypen, Transaktionen und Backup/Restore.

## Akzeptanzkriterien

- [ ] Das Modul grenzt `BlockOnPossibleDataLoss` eindeutig von einer allgemeinen
  SQL-Server-Datenbankoption ab und erklärt dessen Wirkung im DacFx-Kontext.
- [ ] Mindestens zwei potenziell verlustbehaftete Änderungen und jeweils ein
  sicherer Migrationsweg sind mit plausiblen Beispielen dokumentiert.
- [ ] Die Anleitung enthält keine Empfehlung, den Schutz pauschal zu deaktivieren,
  und verlinkt nur vorhandene interne Dateien.

## Agentenprotokoll

### Analyse und Entscheidungen

_Bei der Umsetzung fachliche Entscheidungen, Abgrenzungen und geprüfte Quellen dokumentieren._

### Implementierungsfortschritt

_Umgesetzte Schritte mit betroffenen Dateien und Validierungen dokumentieren; zugehörige Akzeptanzkriterien erst nach Prüfung abhaken._

### Offene Punkte und Übergabe

_Risiken, bewusst nicht umgesetzte Punkte, Folgeaufgaben oder Hinweise für die Review dokumentieren._
