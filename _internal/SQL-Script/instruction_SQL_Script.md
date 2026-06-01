# Instruction SQL Script

Diese Datei dient als wiederverwendbare Instruction fuer die Erstellung und Pflege neuer SQL-Skripte in diesem Repository.

## Ziel

Bei jedem neuen fachlichen SQL-Skript sollen immer zwei Artefakte entstehen:

1. eine SQL-Datei mit dem eigentlichen Skript
2. eine begleitende Markdown-Datei mit Dokumentation

Die SQL-Datei ist die technische Hauptquelle. Die Markdown-Datei ist die lesbare Dokumentation. Inhalte, die aus dem SQL-Skript eindeutig ableitbar sind, sollen nicht doppelt manuell gepflegt werden.

## Grundprinzip

- Das SQL-Skript ist die fachlich-technische Source of Truth.
- Die Markdown-Datei enthaelt erklaerenden Text und definierte Sync-Bloecke.
- Ein Python-Skript synchronisiert deterministische Inhalte aus dem SQL-Skript in die Markdown-Datei.
- Das Mermaid-Diagramm wird nicht von Python erzeugt.
- Das Mermaid-Diagramm wird von einem KI-Agenten aus dem echten SQL-Skript erstellt und in den dafuer vorgesehenen Marker-Block geschrieben.

## Didaktischer Schwerpunkt

Dieses Repository dient vorrangig dazu, SQL zu unterrichten.

- Der Standardfall ist daher eine didaktische, nachvollziehbare und sichere Umsetzung.
- Wenn kein konkreter Produktionskontext vorliegt, soll der Agent ein lehrreiches, gut erklaerbares Skript erstellen.
- Die Dokumentation soll Annahmen sachlich festhalten, ohne die Eingabe oder Scriptbeschreibung zu bewerten.
- Formulierungen wie "die Beschreibung ist knapp", "die Vorgaben sind ausreichend" oder aehnliche Beurteilungen sollen in der erzeugten Dokumentation vermieden werden.

## Dateikonvention

- Fuer jedes neue Skript werden nach Moeglichkeit zwei Dateien mit gleichem Basenamen angelegt:
  - `ScriptName.sql`
  - `ScriptName.md`
- Beide Dateien liegen bevorzugt im gleichen fachlichen Ordner, typischerweise in `SQLScripts`.
- Dateinamen sollen ASCII-basiert, stabil und ohne Leerzeichen sein.
- Das Markdown-Dokument beschreibt genau dieses eine SQL-Skript.

## Ordner- und Dateierstellung

Die Erstellung fehlender Ordner und Dateien ist Bestandteil der Aufgabe.

- Wenn der Zielordner `T-SQL/<Kapitel>/SQLScripts` noch nicht existiert, soll er angelegt werden.
- Wenn die SQL-Datei fehlt, soll sie neu erstellt werden.
- Wenn die zugehoerige Markdown-Datei fehlt, soll sie neu erstellt werden.
- Wenn ein Eintrag aus einer Scriptliste vorliegt, soll der Agent daraus ein vollstaendiges erstes Artefaktpaar erzeugen.
- Vorhandene Dateien duerfen erweitert und vereinheitlicht werden, sollen aber nicht ohne Not komplett ersetzt werden.

## Mindestinput fuer die Umsetzung

Ein Agent kann ein fehlendes Skript bereits dann umsetzen, wenn mindestens diese Informationen vorliegen:

- Kapitel
- Scriptname
- Kurzbeschreibung

Beispiel:

```md
| [11_WindowFunctions](11_WindowFunctions/11_WindowFunctions.md) | [WindowNthValueLab.sql](11_WindowFunctions/SQLScripts/WindowNthValueLab.sql) | Labor fuer `NTH_VALUE`-aehnliche Muster in T-SQL. |
```

Mit diesem Mindestinput erstellt der Agent eine erste didaktische oder diagnostische Umsetzung.

## Umgang mit vorliegenden Informationen

Wenn nur Kapitel, Scriptname und Kurzbeschreibung vorliegen, gelten diese Regeln:

- Der Agent soll die Aufgabe nicht blockieren, sondern eine plausible Erstversion erstellen.
- Der Agent soll fehlende fachliche Details nicht als produktive Businesslogik erfinden.
- Wenn keine echten Quell- und Zieltabellen vorgegeben sind, soll bevorzugt ein didaktisches, selbst erklaerendes Demo-Skript gebaut werden.
- Die getroffenen Annahmen sollen in der Markdown-Datei explizit dokumentiert werden.
- Die Umsetzung soll so angelegt sein, dass sie spaeter leicht in ein produktives Skript ueberfuehrt werden kann.

## Standard fuer Erstumsetzungen

Wenn nur Kapitel, Scriptname und Kurzbeschreibung vorliegen, soll der Agent standardmaessig wie folgt vorgehen:

- `script_type` auf einen sicheren, passenden Typ setzen, zum Beispiel:
  - `didactic-lab`
  - `diagnostic-query`
  - `template`
- ein in sich lauffaehiges Beispiel mit Demo-Daten oder tempdb-basierten Objekten erstellen
- keine persistenten Aenderungen an produktiven Tabellen voraussetzen
- den didaktischen Fokus sichtbar machen
- in der Markdown-Datei einen Abschnitt fuer Annahmen oder Einordnung anlegen

## Script-Typen

Die folgenden Typen haben sich als sinnvoll erwiesen:

- `didactic-lab`
  - Lern- und Demo-Skript mit Beispiel- oder Temp-Daten
- `diagnostic-query`
  - rein lesendes Analyse- oder Pruefskript
- `template`
  - Vorlage fuer spaetere Anpassungen
- `admin-report`
  - Administratives Report-Skript ohne dauerhafte Aenderung
- `admin-change`
  - Administratives Skript mit moeglichen persistenten Aenderungen
- `data-load-procedure`
  - produktionsnahe Lade- oder Verarbeitungskomponente

Wenn kein konkreter Produktionskontext vorliegt, soll bevorzugt `didactic-lab`, `diagnostic-query` oder `template` verwendet werden.

## Safety-Stufen

Die Safety-Stufe soll bewusst und passend gewaehlt werden:

- `read-only`
  - nur lesend, keine Writes
- `read-only-tempdb`
  - nur Demo- oder Temp-Objekte, keine persistenten Writes
- `demo-write-tempdb`
  - schreibt nur in temporaere oder explizit als Demo markierte Objekte
- `admin-change`
  - kann persistente Admin-Aenderungen ausfuehren
- `data-change`
  - kann fachliche Daten dauerhaft veraendern

Wenn kein konkreter Produktionskontext vorliegt, soll moeglichst eine nicht-destruktive Safety-Stufe verwendet werden.

## Pflichtaufbau des SQL-Skripts

Jedes neue SQL-Skript beginnt mit einem kommentierten YAML-Header in diesem Format:

```sql
/*
BEGIN:SQL-HEADER v1
---
sql_header: v1
script_name: "ScriptName.sql"
script_version: "1.0"
script_type: "diagnostic-query"
chapter: "12_DataTypes_Conversion"

purpose: >
  Kurze fachliche Beschreibung des Skripts.

parameters:
  - name: "@Parameter1"
    sql_type: "sysname"
    direction: "IN"
    required: false
    description: "Beschreibung des Parameters"

result_sets:
  - name: "default"
    description: "Beschreibung des Resultsets"

dependencies:
  - "sys.tables"
  - "sys.columns"

safety:
  level: "read-only"
  writes_data: false

documentation:
  markdown_file: "T-SQL/<Kapitel>/SQLScripts/ScriptName.md"
  sync_blocks:
    - "SUMMARY_TABLE"
    - "PARAMETERS_TABLE"
    - "DEPENDENCIES_LIST"
    - "VERSION_HISTORY_TABLE"
    - "SQL_CODE"
  mermaid:
    mode: "ai-agent-from-sql"
    source: "script-body"

main_responsible:
  name: "Erhard Rainer"
  initials: "ER"

version_history:
  - version: "1.0"
    date: "2026-04-16"
    user: "ER"
    description: "Erstversion"
---
END:SQL-HEADER v1
*/
```

## Bedeutung der Versionen

Es gibt zwei getrennte Versionsebenen:

- `sql_header`
  - Version des YAML-Header-Schemas
  - aktuell `v1`
- `script_version`
  - Version des eigentlichen SQL-Skripts
  - Beispiel: `1.0`, `1.1`, `2.0`

## Versionsregel

- Kleine Aenderungen erhoehen die Minor-Version.
  - Beispiel: `1.0` auf `1.1`
- Groessere fachliche oder strukturelle Aenderungen erhoehen die Major-Version.
  - Beispiel: `1.4` auf `2.0`
- Es gibt keine getrennte Liste fuer `last_modifications`.
- Es gibt nur `version_history`.
- `version_history` ist die einzige fachliche Aenderungshistorie im YAML-Header.

## Mindestinhalte im SQL-YAML-Header

Die folgenden Felder sollen immer vorhanden sein:

- `sql_header`
- `script_name`
- `script_version`
- `script_type`
- `chapter`
- `purpose`
- `parameters`
- `result_sets`
- `dependencies`
- `safety`
- `documentation`
- `main_responsible`
- `version_history`

## Empfehlungen fuer den SQL-Code

Nach dem YAML-Header soll das SQL-Skript selbst klar strukturiert sein:

- optionaler Parameterblock
- Guardrails und Validierungen
- Hauptlogik
- Ergebnis-Ausgabe
- bei Bedarf Beispiele oder Hinweise zur Ausfuehrung

Wenn nur wenige Vorgaben vorliegen, soll das Skript zusaetzlich diese Eigenschaften haben:

- selbsterklaerende Demo-Daten oder tempdb-basierte Testbasis
- deterministische Sortierung bei Window Functions und Ranking-Logik
- moeglichst keine Abhaengigkeit von nicht vorhandenen produktiven Tabellen
- ein klarer roter Faden fuer Lern- und Review-Zwecke

Wenn moeglich, soll das Skript lesbar in Abschnitte gegliedert werden, zum Beispiel mit Kommentaren wie:

```sql
-- 1. Parameter vorbereiten
-- 2. Kandidaten ermitteln
-- 3. Hauptlogik ausfuehren
-- 4. Ergebnis ausgeben
```

## Pflichtaufbau der Markdown-Datei

Die Markdown-Datei ist die zugehoerige Dokumentation desselben Skripts. Sie soll aus manuell gepflegten Teilen und Sync-Bloecken bestehen.

Empfohlene Struktur:

- Titel
- Kurzbeschreibung
- Einordnung oder Annahmen
- Anwendungsfall
- Hinweise oder Grenzen
- automatisch synchronisierte Tabellen und Code-Bloecke
- Mermaid-Workflow

## Kurzbeschreibung als Tabelle

Die kompakte Uebersicht im Markdown soll als Tabelle formatiert werden. Beispiel:

```md
| Feld | Wert |
|---|---|
| Script | `ScriptName.sql` |
| Version | `1.0` |
| Typ | `diagnostic-query` |
| Kapitel | `12_DataTypes_Conversion` |
| Sicherheit | `read-only` |
| Zweck | Kurze fachliche Beschreibung des Skripts |
```

## Marker in der Markdown-Datei

Die Markdown-Datei soll Marker enthalten, damit Inhalte gezielt aktualisiert werden koennen, ohne den restlichen Text zu ueberschreiben.

Empfohlene Marker:

```md
<!-- SQLDOC:SUMMARY_TABLE:BEGIN -->
<!-- SQLDOC:SUMMARY_TABLE:END -->

<!-- SQLDOC:PARAMETERS_TABLE:BEGIN -->
<!-- SQLDOC:PARAMETERS_TABLE:END -->

<!-- SQLDOC:DEPENDENCIES_LIST:BEGIN -->
<!-- SQLDOC:DEPENDENCIES_LIST:END -->

<!-- SQLDOC:VERSION_HISTORY_TABLE:BEGIN -->
<!-- SQLDOC:VERSION_HISTORY_TABLE:END -->

<!-- SQLDOC:MERMAID:BEGIN -->
<!-- SQLDOC:MERMAID:END -->

<!-- SQLDOC:SQL_CODE:BEGIN -->
<!-- SQLDOC:SQL_CODE:END -->
```

## Verantwortlichkeiten von Python und KI-Agent

### Python synchronisiert

Python darf nur deterministische Inhalte synchronisieren, insbesondere:

- Zusammenfassung aus dem YAML-Header
- Parametertabelle
- Abhaengigkeiten
- Versionshistorie
- eingebetteten SQL-Code

Python soll das Mermaid-Diagramm nicht erzeugen.

Wenn das Python-Sync-Skript noch nicht vorhanden ist, darf die erste Fuellung der Sync-Bloecke einmalig manuell erfolgen. Die Marker muessen trotzdem bereits korrekt angelegt werden, damit spaetere Synchronisation moeglich bleibt.

### KI-Agent erzeugt Mermaid

Das Mermaid-Diagramm wird aus dem echten SQL-Code abgeleitet, nicht aus einer vereinfachten Workflow-Liste im YAML.

Der KI-Agent soll:

- den realen Ablauf des SQL-Skripts analysieren
- wesentliche Verzweigungen und Hauptschritte erkennen
- daraus ein passendes Mermaid-Workflow-Diagramm erzeugen
- nur den Bereich zwischen `SQLDOC:MERMAID:BEGIN` und `SQLDOC:MERMAID:END` aktualisieren

Das Diagramm soll die reale Logik abbilden, zum Beispiel:

- Parameterpruefung
- Guardrails
- Ermittlung von Quellmengen
- dynamisches SQL
- Merge, Insert, Update oder Delete
- Fehlerbehandlung
- Resultset-Ausgabe

## Beispiel fuer einen Markdown-Rahmen

```md
# ScriptName.sql

Kurze manuelle Einordnung des Skripts in das Kapitel und den fachlichen Kontext.

## Uebersicht

<!-- SQLDOC:SUMMARY_TABLE:BEGIN -->
<!-- SQLDOC:SUMMARY_TABLE:END -->

## Einordnung

Hier stehen Annahmen, Grenzen und die fachliche Einordnung des Skripts.

## Parameter

<!-- SQLDOC:PARAMETERS_TABLE:BEGIN -->
<!-- SQLDOC:PARAMETERS_TABLE:END -->

## Abhaengigkeiten

<!-- SQLDOC:DEPENDENCIES_LIST:BEGIN -->
<!-- SQLDOC:DEPENDENCIES_LIST:END -->

## Versionshistorie

<!-- SQLDOC:VERSION_HISTORY_TABLE:BEGIN -->
<!-- SQLDOC:VERSION_HISTORY_TABLE:END -->

## Ablauf

<!-- SQLDOC:MERMAID:BEGIN -->
<!-- SQLDOC:MERMAID:END -->

## SQL-Code

<!-- SQLDOC:SQL_CODE:BEGIN -->
<!-- SQLDOC:SQL_CODE:END -->
```

## Arbeitsanweisung fuer neue Skripte

Wenn ein neues SQL-Skript erstellt wird, ist nach folgendem Ablauf zu arbeiten:

1. Bestimme Kapitel, Scriptname, Kurzbeschreibung und den vermuteten Skripttyp.
2. Pruefe, ob der Zielordner bereits existiert.
3. Lege fehlende Ordner an, insbesondere `T-SQL/<Kapitel>/SQLScripts`.
4. Waehle im Trainingsrepo standardmaessig eine didaktische Erstumsetzung, sofern kein konkreter Produktionskontext vorliegt.
5. Lege die SQL-Datei mit YAML-Header nach diesem Standard an.
6. Fuehre `script_version` und `version_history` konsistent.
7. Lege die zugehoerige Markdown-Datei mit identischem Basenamen an.
8. Baue in der Markdown-Datei die definierten Marker ein.
9. Dokumentiere die getroffenen Annahmen explizit.
10. Synchronisiere alle deterministischen Inhalte aus dem SQL-Skript in die Markdown-Datei.
11. Erzeuge das Mermaid-Diagramm durch einen KI-Agenten aus dem echten SQL-Code.
12. Trage das Mermaid-Diagramm in den vorgesehenen Marker-Block ein.
13. Pruefe, ob SQL-Datei und Markdown-Datei fachlich zusammenpassen.

## Entscheidungsregel fuer Scriptlisten-Eintraege

Wenn ein Agent nur einen Scriptlisten-Eintrag erhaelt, soll er nach dieser Heuristik arbeiten:

- Ist die Beschreibung eher lernorientiert oder technisch allgemein?
  - dann `didactic-lab` oder `diagnostic-query`
- Fehlen konkrete Zieltabellen, Businessregeln und produktive Abhaengigkeiten?
  - dann keine produktive Businesslogik erfinden
- Ist die Funktion in T-SQL nicht direkt vorhanden?
  - dann ein Labor fuer Ersatzmuster oder Emulation bauen und das offen dokumentieren
- Gibt es mehrere fachlich plausible Umsetzungen?
  - dann die naheliegendste didaktische Variante umsetzen und die Annahmen dokumentieren

## Dokumentation von Annahmen

Wenn Annahmen getroffen wurden, sollen sie in der Markdown-Datei in einem eigenen Abschnitt festgehalten werden.

Typische Annahmen sind:

- didaktische statt produktive Umsetzung
- Demo-Daten statt echter Tabellen
- emuliertes Verhalten statt nativer T-SQL-Funktion
- angenommene Sortierung oder Partitionierung
- angenommene Safety-Stufe

## Qualitaetscheck

Vor Abschluss ist zu pruefen:

- Wurde der Zielordner bei Bedarf angelegt?
- Gibt es genau eine SQL-Datei und eine passende Markdown-Datei?
- Ist der YAML-Header gueltig und vollstaendig?
- Ist `script_version` gesetzt?
- Ist `version_history` vorhanden und aktuell?
- Verweist `documentation.markdown_file` auf die richtige Datei?
- Sind alle Sync-Marker in der Markdown-Datei vorhanden?
- Ist ein Abschnitt mit Annahmen oder Einordnung vorhanden?
- Wurde der SQL-Codeblock aus dem aktuellen Skript synchronisiert?
- Wurde das Mermaid-Diagramm aus dem echten SQL-Skript abgeleitet?
- Ist die Kurzbeschreibung als Tabelle vorhanden?
- Ist die Safety-Stufe passend und konservativ gewaehlt?
- Wurden bei didaktischen Skripten moeglichst keine persistenten produktiven Writes vorausgesetzt?

## Zielbild

Am Ende soll jedes relevante SQL-Skript standardisiert aufgebaut sein:

- technisch sauber im SQL-Skript beschrieben
- lesbar in einer Markdown-Datei dokumentiert
- ohne doppelte manuelle Pflege deterministischer Inhalte
- mit einem KI-erzeugten Mermaid-Diagramm, das den realen Ablauf des echten SQL-Codes visualisiert
