# 11 — Link Validation

## Aufgabe
Prüfe alle automatisch eingefügten Links.

## Prüfpunkte
- Zielpfad existiert?
- Relativer Pfad korrekt?
- README als Ziel korrekt?
- Linkblock vollständig?
- Keine doppelten oder widersprüchlichen Links?
- Leere optionale Abschnitte wurden nicht fälschlich gerendert?

## Ausgabe
Ein `link-report.md` mit:
- geprüften Links
- fehlerhaften Links
- fehlenden Zielen
- vorgenommenen Korrekturen

## Zusatzregel
Wenn bei der Korrektur der Artikel selbst geändert wird, setze `workflow_phase` auf `11_link_validation`.
