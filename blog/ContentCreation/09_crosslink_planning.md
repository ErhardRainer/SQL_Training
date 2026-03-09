# 09 — Crosslink Planning

## Aufgabe
Plane die Querverlinkung zwischen Blog und Trainingsunterlagen auf Basis von `Templates/crosslinks_plan.template.yaml`.

## Ziel
Für jede Episode soll automatisch ermittelt werden:
- welche Trainingskapitel fachlich passen
- welche verwandten Blog-Artikel passen
- wo Rückverlinkungen gesetzt werden sollen

## Ausgabe
`crosslinks_plan.yaml` mit:
- `metadata`
- `blog_to_training`
- `blog_to_blog`
- `training_backlinks`
- `render_rules`
- `validation`
- `quality_gates`

## Regeln
1. Nur fachlich passende Links.
2. Keine Linkblöcke ohne echten Mehrwert.
3. Pfade repo-konform und relativ vorbereiten.
4. Root-Ziele liegen in `blog`, `T-SQL`, `PostgreSQL`, `Oracle`, `MySQL` oder `SQLHana`.
5. Verfügbare Schulungsunterlagen im Repository und weitere Dialekte in dieser Episode werden redaktionell getrennt geplant.
6. Wenn keine verwandten Blog-Artikel existieren, wird kein leerer Blog-Block geplant.
