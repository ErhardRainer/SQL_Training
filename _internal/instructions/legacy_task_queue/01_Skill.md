# Skill fuer SQL-Script-Erstellung

Erstelle ein nutzbares SQL-Skript samt begleitender Markdown-Dokumentation, das zur Lehr- und Repo-Struktur dieses Repositorys passt, statt nur eine lose Idee oder ein Fragment zu liefern.

## Quick Start

- Lies den ausgewaehlten Task aus `_internal/Task/Task.json`.
- Nutze `title`, `topic`, `prompt`, `target_paths` und `acceptance_criteria` als direkte Arbeitsgrundlage.
- Lies `_internal/SQL-Script/instruction_SQL_Script.md` als primaeren Standard.
- Pruefe den Zielordner, das Zielkapitel, benachbarte Kapitel und vorhandene SQL-Skripte im selben Themenbereich.
- Erstelle oder erweitere genau das Dateipaar aus `target_paths`:
  - `*.sql`
  - `*.md`
- Wenn der Zielordner fehlt, lege ihn an.
- Verwende ASCII-freundliche Dateinamen, stabile Ueberschriften und gut lesbare SQL-Kommentare.

## Zielbild

Jeder bearbeitete Task soll am Ende mindestens diese Artefakte besitzen:

- eine fachlich passende SQL-Datei
- eine dazu passende Markdown-Datei
- einen YAML-Header im SQL-Skript
- SQLDOC-Marker in der Markdown-Datei
- ein Mermaid-Diagramm, das aus dem echten SQL-Ablauf abgeleitet wurde

## Arbeitsprinzip

- Das SQL-Skript ist die technische Hauptquelle.
- Die Markdown-Datei ist die lesbare Dokumentation.
- Deterministische Inhalte werden zwischen SQL und Markdown konsistent gehalten.
- Das Mermaid-Diagramm beschreibt den realen Ablauf des SQL-Codes, nicht nur eine grobe Wunschlogik.
- Wenn Informationen fehlen, entsteht eine didaktische oder diagnostische Erstversion statt erfundener produktiver Businesslogik.

## Workflow

### 1. Task und lokalen Kontext erfassen

- Lies den ausgewaehlten Task vollstaendig.
- Lies `_internal/SQL-Script/instruction_SQL_Script.md`.
- Ermittle Kapitel und Zielpfade aus `target_paths`.
- Pruefe, ob im Zielkapitel bereits `SQLScripts` existiert.
- Sieh dir vorhandene SQL-Skripte oder Markdown-Dateien im selben Kapitel an, um Namensstil, Komplexitaet und Doku-Ton zu treffen.
- Wenn im Kapitel bereits aehnliche Skripte existieren, orientiere dich an deren fachlichem Zuschnitt, ohne sie zu kopieren.

### 2. Zielstruktur sicherstellen

- Lege fehlende Ordner an, insbesondere `T-SQL/<Kapitel>/SQLScripts`.
- Lege fehlende SQL- oder Markdown-Dateien an.
- Wenn bereits Inhalte vorhanden sind, erweitere sie gezielt statt sie ohne Not komplett zu ersetzen.

### 3. Fachliche Umsetzung waehlen

Wenn nur Kapitel, Scriptname und Kurzbeschreibung vorliegen:

- waehle eine plausible didaktische, diagnostische oder template-basierte Erstversion
- verwende bevorzugt:
  - `didactic-lab`
  - `diagnostic-query`
  - `template`
- nutze Demo-Daten, CTEs, Temp-Objekte oder rein lesende Metadatenabfragen, wenn kein produktiver Kontext vorliegt
- vermeide persistente Aenderungen an fachlichen Tabellen, wenn sie nicht explizit verlangt sind

Wenn T-SQL eine Funktion nicht nativ besitzt:

- baue ein lehrreiches Ersatzmuster oder eine Emulation
- dokumentiere diese Annahme sachlich in der Markdown-Datei

### 4. SQL-Datei erstellen oder vervollstaendigen

Die SQL-Datei soll:

- mit dem YAML-Header gemaess `_internal/SQL-Script/instruction_SQL_Script.md` beginnen
- `script_version` und `version_history` konsistent fuehren
- einen passenden `script_type` und eine konservative `safety`-Stufe setzen
- lesbar in fachliche Abschnitte gegliedert sein
- klar erkennen lassen, was vorbereitet, geprueft, verarbeitet und ausgegeben wird

Bevorzuge bei Schulungsskripten:

- nachvollziehbare CTEs
- kleine Demo-Datensaetze
- deterministische Sortierung
- sprechende Aliasnamen
- moeglichst wenig implizite Annahmen

### 5. Markdown-Datei erstellen oder vervollstaendigen

Die Markdown-Datei soll:

- denselben Basenamen wie das SQL-Skript haben
- eine kurze manuelle Einordnung enthalten
- eine kompakte Uebersicht als Markdown-Tabelle enthalten
- in der Uebersichtstabelle beim Feld `Script` einen relativen Markdown-Link auf die SQL-Datei enthalten, zum Beispiel `[ScriptName.sql](ScriptName.sql)`
- einen Abschnitt fuer Annahmen oder Einordnung enthalten
- die SQLDOC-Marker gemaess `_internal/SQL-Script/instruction_SQL_Script.md` enthalten
- das Mermaid-Diagramm im vorgesehenen Marker-Block enthalten
- den aktuellen SQL-Code im SQL-Code-Block enthalten

Pflicht-Marker:

- `SQLDOC:SUMMARY_TABLE`
- `SQLDOC:PARAMETERS_TABLE`
- `SQLDOC:DEPENDENCIES_LIST`
- `SQLDOC:VERSION_HISTORY_TABLE`
- `SQLDOC:MERMAID`
- `SQLDOC:SQL_CODE`

### 6. Mermaid aus dem echten SQL ableiten

Das Mermaid-Diagramm soll aus dem realen SQL-Code entstehen.

Beruecksichtige insbesondere:

- Parameterpruefungen
- Guardrails
- Demo-Daten oder Quellmengen
- zentrale CTE- oder Temp-Table-Schritte
- dynamisches SQL
- Branches mit `IF`, `CASE`, `TRY/CATCH`
- Resultset-Ausgabe

Das Diagramm darf vereinfacht sein, muss aber den echten roten Faden des Skripts treffen.

### 7. Qualitaetscheck vor Abschluss

Pruefe vor dem Abschluss mindestens:

- Zielordner vorhanden
- SQL-Datei vorhanden
- Markdown-Datei vorhanden
- YAML-Header vorhanden und konsistent
- `documentation.markdown_file` zeigt auf die richtige Markdown-Datei
- `script_version` gesetzt
- `version_history` vorhanden
- alle SQLDOC-Marker vorhanden
- Markdown-Tabelle vorhanden
- Script-Zeile in der Markdown-Tabelle verlinkt auf die SQL-Datei
- Mermaid-Block vorhanden
- SQL-Codeblock eingefuellt
- Annahmen sachlich formuliert
- Safety-Stufe passend und moeglichst konservativ
- SQL- und Markdown-Datei passen fachlich zusammen

## Output Standard fuer die Automation

Wenn du als Automation ueber einen Task laeufst, bearbeite den Task statt nur einen Vorschlag zu schreiben.

Am Ende der Bearbeitung:

- nenne den bearbeiteten Task
- nenne die erzeugten oder geaenderten Dateien
- dokumentiere knappe Annahmen
- nenne den finalen Status fuer den Task

## Nicht tun

- keine ungesicherten produktiven Businessregeln erfinden
- keine komplett neue Queue-Datei erzeugen
- keine zusaetzlichen Tasks neben dem gewaehlten Task bearbeiten
- keine Marker weglassen, nur weil das Python-Sync-Skript spaeter kommt
- kein Mermaid aus einer erfundenen Wunschlogik bauen, wenn der echte SQL-Code etwas anderes tut

## Referenzen

- Primaerer SQL-Standard: `_internal/SQL-Script/instruction_SQL_Script.md`
- Task-Queue: `_internal/Task/Task.json`
- Generator der Queue: `_internal/Task/generate_tasks.py`
