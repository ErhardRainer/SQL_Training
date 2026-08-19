# Reddit-Posts für das SQL-Training bewerten

## Ziel

Bewerte alle noch nicht klassifizierten Beiträge aus
`_internal/instructions/reddit/sqlserver_posts.json` darauf, ob ihr Thema für
dieses Repository fachlich relevant ist und noch nicht ausreichend behandelt
wird. Die Bewertung ist im JSON zu speichern. Für jedes neue, relevante Thema
ist genau eine umsetzbare Ideen-Task anzulegen.

Das Ziel ist die Themenpflege des Repositories; es werden in diesem Ablauf
keine Artikel, Notebooks oder Kapitel geändert.

## Eingabe und Auswahl

1. Lies die gesamte JSON-Datei. Die Beiträge liegen im Array `posts`.
2. Bearbeite ausschließlich Posts ohne Feld `status`. Ein Post mit einem der
   Statuswerte `idea`, `done` oder `ignore` ist bereits bearbeitet und darf bei
   späteren Läufen nicht erneut bewertet oder mit einer weiteren Task versehen
   werden.
3. Nutze mindestens `title`, `url`, `published`, `author` und `content_html`.
   Falls vorhanden, nutze `content_feed` als ergänzenden Kontext für die
   Diskussion. Eine Antwort oder ein Kommentar allein ist jedoch kein Grund,
   den fachlichen Fokus des Startbeitrags zu verändern.

## Abgleich mit dem Repository

1. Verschaffe dir einen Überblick über die vorhandenen Markdown-Dateien,
   Kapitel, Übungen und Notebooks. Suche mit `rg` nach Synonymen und wichtigen
   Fachbegriffen aus dem Reddit-Post.
2. Lies die fachlich nächstliegenden Dateien vollständig. Ein ähnlicher
   Dateiname oder bloßer Treffer reicht nicht aus, um ein Thema als abgedeckt
   einzustufen.
3. Beurteile die Passung zum Schwerpunkt des Repositories: SQL Server, T-SQL,
   Datenmodellierung, Administration, Performance, Sicherheit, Betrieb und
   didaktisch sinnvolle SQL-Praxis sind grundsätzlich relevant.
4. Bevorzuge nachhaltige Lern- und Praxisthemen. Reine Meinungsfragen,
   personenbezogene Supportfälle, Ankündigungen ohne übertragbaren Lerninhalt
   und nicht aufbereitbare Produktneuigkeiten sind keine Ideen-Tasks.

## Statusentscheidung

Setze pro bearbeitetem Post genau einen dieser Werte:

| Status | Bedeutung |
| --- | --- |
| `idea` | Das Thema ist relevant und im Repository noch nicht ausreichend behandelt. |
| `done` | Das relevante Thema wird bereits ausreichend und fachlich korrekt behandelt. |
| `ignore` | Das Thema ist für dieses Repository nicht geeignet oder nicht nachhaltig genug. |

Speichere zusätzlich die folgenden Felder am jeweiligen Post:

```json
{
  "status": "idea",
  "analyzed_at": "<ISO-8601-Zeitstempel in UTC>",
  "analysis": "Kurze, konkrete Begründung der Entscheidung.",
  "related_repository_paths": ["Pfad/zur/geprüften/Datei.md"]
}
```

Bei `ignore` darf `related_repository_paths` leer sein. Bei `done` müssen die
Pfade die bestehende Abdeckung belegen. Die Analyse ist knapp, konkret und auf
Deutsch zu formulieren.

## Ideen-Task erzeugen

Erzeuge für jeden Post mit Status `idea` eine neue Markdown-Datei unter
`_internal/Task/idea` mit dem Namen `MSSQL_TASK_XXXX.md`.

- `XXXX` ist eine vierstellige, fortlaufende Nummer.
- Ermittle die höchste vorhandene Nummer aus allen Dateien, die dem Muster
  `MSSQL_TASK_*.md` entsprechen, und verwende die nächste freie Nummer.
- Überschreibe keine vorhandene Datei.
- Erzeuge genau eine Task pro `idea`-Post und speichere ihren relativen Pfad
  zusätzlich im Feld `task_path` des Posts.

Jede Task basiert auf dem verbindlichen [allgemeinen
Task-Template](../../task_template.md). Es enthält die Grundstruktur für
YAML-Metadaten, Akzeptanzkriterien und Agentenprotokoll. Für Reddit-Ideen
gelten die folgenden Konkretisierungen: `task_id` beginnt mit
`MSSQL_TASK_`, `domain` ist `MSSQL`, `status` ist `idea` und die Quelle ist der
bewertete Reddit-Post. Verwende keine integrationsspezifischen Felder für
externe Tickets, Zeiterfassung oder Synchronisation, solange sie im Repository
nicht tatsächlich genutzt werden.

```yaml
---
task_id: MSSQL_TASK_XXXX
repository: SQL_Training
domain: MSSQL
title: "<präziser deutscher Titel>"
status: idea
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
  type: reddit
  post_id: <Reddit-Post-ID>
  url: "<Reddit-Post-URL>"
  author: "<Reddit-Autor>"
  published_at: "<Zeitstempel des Posts>"
affected_paths:
  - path: "<relativer Pfad>"
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

Darauf folgt mindestens diese fachliche Struktur:

```markdown
# MSSQL_TASK_XXXX – <präziser deutscher Titel>

## Anlass und Relevanz

<Warum ist das Thema für das SQL-Training wertvoll und welche konkrete
Lernfrage soll beantwortet werden?>

## Bereits vorhandene Abdeckung

<Geprüfte Dateien und die konkrete Abgrenzung; „keine ausreichende Abdeckung"
ist zulässig, wenn dies begründet wird.>

## Umsetzungsauftrag

<Konkrete Änderung: Zielkapitel bzw. neues Kapitel, didaktische Inhalte,
T-SQL-Beispiele, Übungen/Notebook und erforderliche interne Verlinkungen.>

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

Der Task muss eine eigenständige, umsetzbare Anweisung sein. Er darf nicht nur
den Reddit-Post paraphrasieren und darf keine ungeprüften Aussagen aus der
Diskussion als Tatsachen übernehmen. Der umsetzende Agent führt das
`Agentenprotokoll` fort und aktualisiert die Checkliste nachvollziehbar.

## Sichere Reihenfolge und Abschluss

1. Triff die Entscheidung und formuliere die Analyse.
2. Bei `idea`: Erstelle zuerst die eindeutige Task-Datei.
3. Aktualisiere danach den zugehörigen Post im JSON mit `status`, Analyse,
   Zeitstempel, Referenzpfaden und bei `idea` mit `task_path`.
4. Schreibe die vollständige JSON-Datei gültig und UTF-8-kodiert zurück; alle
   unveränderten Posts und ihre vorhandenen Felder bleiben erhalten.
5. Prüfe abschließend, dass jeder zuvor statuslose Post genau einen gültigen
   Status hat, jede `idea` genau eine existierende Task-Datei referenziert und
   keine Task-Datei überschrieben wurde.
