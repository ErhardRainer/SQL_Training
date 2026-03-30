# 05 - Notebook Cell Plan Builder

## Aufgabe
Erzeuge aus Blueprint und Demo-Assets einen vollstaendigen Zellplan.
Nutze dafuer `Templates/notebook_cell_plan.template.yaml`.

## Ziel
Der Zellplan definiert die Reihenfolge und Absicht jeder einzelnen Notebook-Zelle, bevor Text oder SQL im Detail ausformuliert wird.

## Pflichtfelder
- `notebook_file`
- `metadata`
- `cells`

## Pflichtfelder je Zell-Eintrag
- `order`
- `cell_type`
- `section_id`
- `required`
- `title`
- `intent`
- `source_inputs`

## Kernregel
Jede fachliche Hauptsektion braucht mindestens:
- eine Markdown-Zelle mit Kontext oder Fragestellung
- eine dazu passende Codezelle oder bewusst markierte reine Theorie-Zelle

## Empfohlene Zellstruktur
1. `title_card`
2. `intro`
3. `contents`
4. `kernel_note`
5. `setup_intro`
6. `setup_code`
7. `baseline_intro`
8. `baseline_code`
9. mehrere `core_*`-Bloeke
10. `optimizer_intro`
11. `optimizer_code` oder `diagnostics_code`
12. `pitfalls_intro`
13. pro Fallstrick mindestens:
  - eine Markdown-Zelle
  - eine problematische oder kommentierte Problem-Codezelle
  - eine Korrektur-Codezelle oder Korrektur-Erklaerung
14. `best_practices`
15. `exercises`
16. mehrere `solution_*`-Codezellen
17. `crosslinks`
18. optional `cleanup_intro`
19. optional `cleanup_code`

## Besondere Regeln
- Kernsektionen duerfen mehrere Codezellen haben, wenn ein Vorher/Nachher oder Vergleich benoetigt wird.
- Reine Theorie-Zellen ohne Code sind fuer logische Verarbeitungsreihenfolge oder Konzeptblenden erlaubt.
- Uebungen stehen als Markdown-Liste vor den Loesungszellen.
- Der Zellplan muss auch explizit markieren, wenn ein Notebook bewusst keinen Cleanup-Block bekommt.

## Ergebnis
Der Zellplan ist die verbindliche Struktur fuer Schritt 06 bis 08.
