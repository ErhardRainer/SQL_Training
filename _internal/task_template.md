# Task-Template

Dieses Dokument ist das allgemeine Konzept für neue Aufgaben im Repository.
Eine konkrete Arbeitsanweisung kann Werte ergänzen oder einschränken, soll aber
die Grundstruktur und die Bedeutung der Felder beibehalten.

## YAML-Frontmatter

Jede Task beginnt mit einem YAML-Header. Er enthält nur Metadaten, die für
Planung, Umsetzung, Prüfung oder Nachverfolgung im Repository tatsächlich
benötigt werden.

```yaml
---
task_id: "<DOMAIN>_TASK_XXXX"
repository: SQL_Training
domain: "<fachlicher Bereich>"
title: "<präziser deutscher Titel>"
status: draft
priority: 500
priority_class: normal
created_at: "<ISO-8601-Zeitstempel in UTC>"
updated_at: "<ISO-8601-Zeitstempel in UTC>"

responsible_type: ai
assignee: ai-agent
reviewer: erhard
agent:
  allowed: true
  review_required: true

acceptance_criteria_status: draft

source:
  type: "<z. B. reddit, repository, manual>"
  reference: "<stabile Kennung oder null>"
  url: "<Quell-URL oder null>"
  author: "<Autor oder null>"
  published_at: "<ISO-8601-Zeitstempel oder null>"

affected_paths:
  - path: "<relativer Repository-Pfad>"
    change: "<konkrete Änderung>"

related_tasks: []
depends_on: []
blocks: []

planning:
  effort_class: small
  estimated_effort_hours: 4

execution_context:
  required_guides:
    - path: "ai_agents.md"
      purpose: "Verweist auf die für die Umsetzung geltenden Arbeitsanweisungen."
---
```

Nicht verwendete, integrationsspezifische Metadaten – etwa für externe
Tickets, Zeiterfassung, Synchronisierung oder Sperren – werden nicht
vorsorglich aufgenommen.

## Inhalt nach dem YAML-Header

```markdown
# <TASK_ID> – <präziser deutscher Titel>

## Anlass und Relevanz

<Problem, Lernfrage und Nutzen für das Repository.>

## Bereits vorhandene Abdeckung

<Geprüfte Dateien und klare Abgrenzung zur geplanten Änderung.>

## Umsetzungsauftrag

<Eigenständige, konkrete Anweisung mit Zielpfaden, Inhalten und erwarteten
Artefakten.>

## Akzeptanzkriterien

- [ ] <fachlich prüfbares Ergebnis 1>
- [ ] <fachlich prüfbares Ergebnis 2>
- [ ] <Tests, Links oder Formatprüfung soweit passend>

## Agentenprotokoll

### Analyse und Entscheidungen

_Fachliche Entscheidungen, Abgrenzungen und geprüfte Quellen während der Umsetzung dokumentieren._

### Implementierungsfortschritt

_Umgesetzte Schritte mit betroffenen Dateien und Validierungen dokumentieren. Akzeptanzkriterien nur nach erfolgreicher Prüfung abhaken._

### Offene Punkte und Übergabe

_Risiken, bewusst nicht umgesetzte Punkte, Folgeaufgaben oder Hinweise für die Review dokumentieren._
```

Der umsetzende Agent pflegt das Agentenprotokoll fort und hakt
Akzeptanzkriterien nur ab, wenn deren Erfüllung überprüft wurde.
