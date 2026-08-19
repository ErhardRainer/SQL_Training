---
task_id: MSSQL_TASK_0002
repository: SQL_Training
domain: MSSQL
title: "TempDB-Verbrauch pro Session und Query diagnostizieren"
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
  post_id: t3_1vnjf2p
  url: "https://www.reddit.com/r/SQLServer/comments/1vnjf2p/tempdb_size_getting_high/"
  author: "/u/ManufacturerSalty148"
  published_at: "2026-08-13T18:42:24+00:00"
affected_paths:
  - path: "T-SQL/82_Troubleshooting_Sessions_Requests/"
    change: "TempDB-Diagnosepfad, Dokumentation und lesendes SQL-Skript ergänzen"
related_tasks: []
depends_on: []
blocks: []
planning:
  effort_class: medium
  estimated_effort_hours: 6
execution_context:
  required_guides:
    - path: "ai_agents.md"
      purpose: "Verweist auf die für die Umsetzung geltenden Arbeitsanweisungen."
    - path: "_internal/instructions/instruction_improveArticle.md"
      purpose: "Definiert die didaktischen Anforderungen, falls der Übersichtsartikel erweitert wird."
---

# MSSQL_TASK_0002 – TempDB-Verbrauch pro Session und Query diagnostizieren

## Anlass und Relevanz

Ein stark wachsendes TempDB ist ein häufiges Betriebs- und Performanceproblem.
Lernende benötigen eine wiederholbare Diagnose, um TempDB-Verbrauch einer
Session oder Query zuzuordnen und Spills im Ausführungsplan von reinen
Datei-Layout- oder Konfigurationsfragen zu unterscheiden.

## Bereits vorhandene Abdeckung

`T-SQL/20_Create_Database/SQLScripts/TempdbFileLayoutCheck.md` prüft die
Dateikonfiguration, nicht den laufzeitlichen Verbrauch. Die Kapitel
`T-SQL/27_ExecutionPlans_Basics/27_ExecutionPlans_Basics.md` und
`T-SQL/82_Troubleshooting_Sessions_Requests/82_Troubleshooting_Sessions_Requests.md`
erklären Spills beziehungsweise laufende Sessions, liefern aber keine
zusammenhängende TempDB-Verbrauchsdiagnose pro Session und Request.

## Umsetzungsauftrag

Erweitere das Modul `T-SQL/82_Troubleshooting_Sessions_Requests` um einen
didaktischen TempDB-Diagnosepfad. Ergänze ein sicheres, rein lesendes
T-SQL-Skript mit `sys.dm_db_session_space_usage`,
`sys.dm_db_task_space_usage`, Requests und Sessioninformationen. Zeige die
Korrelation mit tatsächlichen Ausführungsplänen, Memory Grants und Sort-/Hash-
Spills. Dokumentiere den sinnvollen Einsatz von Extended Events sowie Grenzen
der Momentaufnahme; unterscheide Benutzerobjekte, interne Objekte und Version
Store. Verlinke die vorhandenen Kapitel zu Ausführungsplänen,
Snapshot-Isolation und TempDB-Dateilayout.

## Akzeptanzkriterien

- [ ] Das neue Skript bleibt lesend, dokumentiert benötigte Berechtigungen und
  ordnet TempDB-Verbrauch mindestens nach Session und laufendem Request zu.
- [ ] Die Dokumentation erklärt, wie Spills, lange Transaktionen und Version Store
  als unterschiedliche Ursachen geprüft werden.
- [ ] Der Diagnosepfad enthält eine klare Reihenfolge von Messung, Interpretation
  und sicheren nächsten Schritten sowie funktionierende interne Links.

## Agentenprotokoll

### Analyse und Entscheidungen

_Bei der Umsetzung fachliche Entscheidungen, Abgrenzungen und geprüfte Quellen dokumentieren._

### Implementierungsfortschritt

_Umgesetzte Schritte mit betroffenen Dateien und Validierungen dokumentieren; zugehörige Akzeptanzkriterien erst nach Prüfung abhaken._

### Offene Punkte und Übergabe

_Risiken, bewusst nicht umgesetzte Punkte, Folgeaufgaben oder Hinweise für die Review dokumentieren._
