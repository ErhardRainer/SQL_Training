# 01 - Chapter Inventory Builder

## Aufgabe
Erzeuge aus der Kapiteldatei ein `chapter_inventory.yaml`.
Nutze dafuer `Templates/chapter_inventory.template.yaml`.

## Ziel
Das Inventory ist die maschinen- und menschenlesbare Liste aller Notebook-Kandidaten eines Kapitels.
Es ist der verbindliche Plan fuer Dateinamen, Titel, Kurzbeschreibungen und Prioritaeten.

## Primaere Quelle
Die Kapiteldatei des Zielordners, zum Beispiel:
- `T-SQL/12_DataTypes_Conversion/12_DataTypes_Conversion.md`

## Was geparst werden muss
- Kapitelnummer und Kapitelname
- Pfad zur Kapiteldatei
- alle Unterabschnitte unter `## 2 | Struktur`
- zu jedem Unterabschnitt:
  - Abschnittsnummer, zum Beispiel `2.4`
  - Titel
  - Kurzbeschreibung
  - genannter Notebook-Dateiname
  - Docs-Links
  - YouTube-Links
  - zusaetzliche Unterpunkte innerhalb des Abschnitts, falls vorhanden
- globale weiterfuehrende Quellen unter `## 3 | Weiterfuehrende Informationen`

## Parsing-Regeln
- Verlasse dich auf die sichtbaren Ueberschriften und Bullets, nicht auf Namensheuristiken.
- Wenn der Dateiname im Kapitel `08_...` lautet, obwohl das Kapitel `12_...` heisst, bleibt der Dateiname unveraendert.
- Wenn bereits echte `.ipynb` im Ordner liegen, markiere deren Zustand:
  - `exists_target_name`
  - `exists_other_name`
  - `missing`
- Unterpunkte wie `2.6.1`, `2.6.2` werden nicht zu eigenen Notebooks, sondern zu `subtopics` des uebergeordneten Notebooks.

## Pflichtfelder
- `chapter`
- `global_references`
- `notebooks`

## Pflichtinhalte je Notebook-Eintrag
- `section_number`
- `title`
- `short_description`
- `notebook_file`
- `existing_file_state`
- `priority`

## Priorisierung
Standard:
- `core` fuer Grundlagen, Hauptsyntax, Kernmuster
- `deep_dive` fuer spezialisierte Vertiefungen
- `advanced` fuer Betriebs- oder Randthemen
- `anti_patterns` fuer Abschluss- oder Checklisten-Notebooks

## Zusatzregeln
- Wenn eine Kapiteldatei Notebook-Dateien nennt, die alle noch fehlen, ist das kein Fehler, sondern genau das erwartete Zielbild fuer die Pipeline.
- Dokumentiere Inkonsistenzen als Notiz, korrigiere die Kapiteldatei aber in diesem Schritt nicht.
- Falls das Kapitel bereits ein grosses Legacy-Notebook oder `EH...`-Notebook enthaelt, fuehre es unter `global_references.related_notebooks_seen` auf, aber leite daraus keine automatische 1:1-Struktur ab.
