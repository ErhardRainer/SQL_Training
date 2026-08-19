# Automation Instruction fuer SQL-Script-Tasks

Diese Datei enthaelt eine direkt verwendbare Automation-Instruction fuer wiederkehrende Runs, die jeweils genau ein SQL-Skript samt Markdown-Dokumentation aus der Task-Queue umsetzen.

## Ziel

- Pro Run genau einen Task bearbeiten
- Task-Status sauber pflegen
- `Task.json` inkrementell aktualisieren, nicht neu erzeugen
- SQL-Datei und Markdown-Datei nach dem Standard aus `_internal/SQL-Script/instruction_SQL_Script.md` erstellen oder vervollstaendigen

## Statusmodell

Empfohlene Task-Status fuer die Automation:

- `pending`
  Offener Task, noch nicht begonnen
- `in_progress`
  Vom aktuellen Run bereits reserviert und in Bearbeitung
- `done`
  Erfolgreich abgeschlossen
- `blocked`
  Inhaltlich oder strukturell nicht sinnvoll bearbeitbar
- `failed`
  Bearbeitung technisch oder fachlich fehlgeschlagen

Legacy-Eintraege mit `status = open` sollen wie `pending` behandelt werden.

## Bearbeitbar bedeutet

Ein Task ist genau dann bearbeitbar, wenn alle folgenden Bedingungen erfuellt sind:

- `status` ist `pending` oder `open`
- `depends_on` ist leer oder alle referenzierten Tasks haben `status = done`
- der Task ist nicht `blocked`
- der Task ist nicht `failed`
- der Task ist nicht `done`
- der Task ist nicht bereits in Bearbeitung
- `lease` ist `null`, leer oder abgelaufen

## Claiming-Regel

Damit parallele oder zeitversetzte Runs denselben Task nicht doppelt bearbeiten, soll der Agent vor der fachlichen Bearbeitung den gewaehlten Task sofort reservieren:

- `status = in_progress`
- `lease` setzen, zum Beispiel mit:
  - `claimed_at`
  - `worker`
  - `note`
- `Task.json` direkt nach dem Claim speichern

Nach Abschluss oder Abbruch ist `lease` wieder auf `null` zu setzen.

## Auswahlregel

Wenn mehrere bearbeitbare Tasks vorliegen, gilt diese Reihenfolge:

1. hoechste `priority`
2. bei gleicher `priority` der aelteste `created_at`
3. wenn weiterhin Gleichstand besteht, die kleinere `id`

## Zu verwendende Quellen

- Queue: `_internal/Task/Task.json`
- Skill: `_internal/Task/01_Skill.md`
- SQL-Standard: `_internal/SQL-Script/instruction_SQL_Script.md`

## Direkt nutzbare Automation-Instruction

```md
-- Automation Instruction

Lies `_internal/Task/Task.json`.

Waehle genau einen offenen und bearbeitbaren Task aus.

Bearbeitbar bedeutet:
- `status` ist `pending` oder `open`
- alle `depends_on` sind erledigt oder leer
- der Task ist nicht `blocked`
- der Task ist nicht `failed`
- der Task ist nicht `done`
- der Task ist nicht bereits in Bearbeitung
- `lease` ist `null`, leer oder abgelaufen

Wenn mehrere bearbeitbare Tasks vorhanden sind, waehle genau einen Task nach dieser Reihenfolge:
1. hoechste `priority`
2. aeltestes `created_at`
3. kleinste `id`

Bearbeite in diesem Run genau diesen einen Task und keinen weiteren.

Bevor du mit der fachlichen Umsetzung beginnst:
- setze bei diesem Task `status = in_progress`
- setze `lease` auf ein kompaktes Objekt mit mindestens `claimed_at`, `worker` und `note`
- speichere `Task.json` sofort

Verwende fuer die Umsetzung:
- `_internal/Task/01_Skill.md`
- `_internal/SQL-Script/instruction_SQL_Script.md`
- die Felder `title`, `topic`, `prompt`, `target_paths` und `acceptance_criteria` des gewaehlten Tasks

Setze die Aufgabe nur im Zielpfad des gewaehlten Tasks um.
Lege fehlende Ordner und Dateien an, wenn sie fuer die Umsetzung benoetigt werden.
Erfinde keine ungesicherten produktiven Fachdetails.
Wenn Informationen fehlen, erstelle eine didaktische oder diagnostische Erstversion gemaess Repository-Standard und dokumentiere Annahmen sachlich.

Wenn der Task erfolgreich bearbeitet wurde:
- setze `status = done`
- setze `lease = null`
- setze `last_error = null`
- dokumentiere in `result.completed_at` den Abschlusszeitpunkt
- dokumentiere in `result.files_changed` die erzeugten oder geaenderten Dateien
- dokumentiere in `result.assumptions` wichtige Annahmen knapp

Wenn Voraussetzungen fuer eine sinnvolle Bearbeitung fehlen:
- setze `status = blocked`
- setze `lease = null`
- schreibe den Blocker klar und knapp nach `last_error`
- dokumentiere den Blocker optional zusaetzlich in `result`

Wenn die Bearbeitung scheitert:
- setze `status = failed`
- setze `lease = null`
- erhoehe `retry_count`
- schreibe die Fehlursache nach `last_error`

Ueberschreibe nicht die gesamte Queue-Datei mit einer neu erzeugten Struktur.
Aktualisiere nur den gewaehlten Task und notwendige Felder in der bestehenden `Task.json`.

Gib am Ende eine kurze strukturierte Zusammenfassung aus:
- bearbeiteter Task
- erzeugte oder geaenderte Dateien
- neuer Status
- wichtige Annahmen oder Blocker
```

## Hinweise fuer robuste Runs

- Wenn `target_paths` bereits existieren, sollen vorhandene Dateien bevorzugt erweitert statt komplett ersetzt werden.
- Wenn SQL-Datei und Markdown-Datei bereits in guter Form vorhanden sind, darf der Task nach einer kurzen Qualitaetspruefung direkt auf `done` gesetzt werden.
- Wenn ein Claim gesetzt wurde und die Bearbeitung spaeter fehlschlaegt, muss `lease` trotzdem wieder entfernt werden.
- Wenn ein Task ungueltige oder fehlende Zielpfade hat, ist das ein valider `blocked`-Fall.
