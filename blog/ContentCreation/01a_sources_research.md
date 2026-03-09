# 01a - Sources Research

## Aufgabe
Recherchiere und strukturiere die fachlichen Quellen der Episode auf Basis von `Templates/sources.template.yaml`.

## Ziel
Ein belastbares `sources.yaml`, das die geplanten Aussagen des Artikels und den Versionsscope der Episode absichert.

## Pflichtausgabe
`sources.yaml` mit:
- `metadata`
- `version_scope`
- `sources`
- `claims_register`
- `quality_gates`

## Regeln
Zusatzregeln:
- Jeder Claim im `claims_register` bekommt einen Evidenz-Level, mindestens `docs_based` oder `inference_based`.
- Wenn ANSI- oder Standardaussagen im Artikel vorkommen sollen, muss auch deren Quellenlage ausdruecklich dokumentiert oder als begrenzte Meta-Ebene markiert werden.
- Wenn `notes.md` oder `author_notes` konkrete Fragen, Behauptungen oder Schwerpunkte nennt, muessen daraus gezielte Rechercheziele und Claims abgeleitet werden.
- `notes.md` selbst ist keine Quelle. Notizen duerfen im `claims_register` nur als Input-Herkunft markiert werden, nicht als Beleg.

1. Dieser Schritt ist Pflicht in `full` und `article_only`.
2. Pro relevantem System muss mindestens eine offizielle Quelle geplant oder erfasst werden.
3. Der Versionsbezug jeder Quelle muss dokumentiert werden.
4. Zentrale fachliche Claims muessen im `claims_register` vorstrukturiert sein.
5. Unklare oder lueckenhafte Claims duerfen nicht stark formuliert werden.
6. Fehlende Quellen muessen explizit als Luecke notiert werden.

## Ausgabe
- `sources.yaml`
- kurze Liste offener Quellenluecken
