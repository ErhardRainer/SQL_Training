# 05a - Micro Examples Builder

## Aufgabe
Erzeuge eine kleine, belastbare Syntax- und Micro-Examples-Sammlung fuer den Artikel auf Basis von `Templates/micro_examples.template.yaml`.

## Ziel
Zwischen abstrakter Fachlogik und vollstaendigem Demo-Run entsteht eine kleine, gut belegte Oberflaeche:
- ein konkretes Fehlersymptom oder eine kurze Ankergeschichte
- eine kurze Syntax-Galerie je relevantem System
- ein minimales Kernbeispiel je behandeltem System
- ein dialektspezifisches Sicherheits- oder Vorbereitungs-Muster je behandeltem System
- ein robustes Mini-Beispiel
- ein riskantes Mini-Beispiel
- ein explizites Fehler- oder Fallstrickbeispiel
- bei Bedarf ein historisches Kontrast-Snippet fuer relevante Altversionen
- eine sichere Alternativstrategie mit vorbereiteter Quelle
- ein minimales Code-Skelett fuer empfohlene Strategien
- mindestens eine Vergleichstabelle
- mindestens ein Warnhinweis
- mindestens ein Anti-Pattern-vs.-robuste-Form-Block
- eine visuelle Darstellung des Entscheidungsmodells
- eine zweite merkfaehige Hauptvisualisierung neben dem Entscheidungsmodell

## Pflichtausgabe
`micro_examples.yaml` mit:
- `metadata`
- `anchor_story`
- `syntax_surface`
- `dialect_min_examples`
- `dialect_preflight_blocks`
- `dialect_safety_patterns`
- `historical_contrast_snippets`
- `micro_examples`
- `strategy_snippets`
- `comparison_tables`
- `warning_boxes`
- `anti_pattern_blocks`
- `signature_visual`
- `decision_visual`
- `quality_gates`

## Modusregeln
- In `full` kann sich dieser Schritt auf Episode-YAML, `insights.yaml`, Demo-Spezifikation und Beispielpfade stuetzen.
- In `article_only` stuetzt sich dieser Schritt auf Episode-YAML, `sources.yaml` und dokumentationsbasierte oder vorsichtige inferenzbasierte Mini-Beispiele.
- In `article_only` sind kleine Syntax-Snippets und sehr kleine illustrative Beispiele erlaubt, aber keine vollstaendigen Demo- oder Benchmark-Artefakte.
- Wenn `author_notes` konkrete Randfaelle, Fallstricke oder Beispielwuensche enthaelt, sollen diese nach Moeglichkeit in `micro_examples.yaml` an der passenden Stelle sichtbar werden.

## Regeln
1. Die Syntax-Galerie bleibt kurz und oberflaechenorientiert.
2. Die Micro-Beispiele bleiben klein und argumentativ nuetzlich.
3. Jedes Micro-Beispiel traegt einen Evidenz-Level.
4. Die Beispiele duerfen die tatsaechliche Evidenzlage nicht ueberschreiten.
5. Mindestens diese drei Klassen muessen vorhanden sein:
   - `robust`
   - `risky`
   - `prepared_source`
6. Pro behandeltem System gibt es ein minimales Beispiel oder einen bewusst leeren Eintrag mit Begruendung, falls das System nur indirekt behandelt wird.
7. Mindestens ein Eintrag zeigt den wichtigsten Fehlerfall explizit.
8. Vergleichstabellen bleiben scanbar und fokussieren auf wenige Kerndimensionen.
9. Warnboxen heben nur echte Risiken hervor, nicht Selbstverstaendlichkeiten.
10. Wenn eine historische Kontrastversion aktiv erklaert wird, bekommt sie ein eigenes sichtbares Snippet oder Minimalbeispiel.
11. Wenn eine Strategie als bevorzugte Standardstrategie dient, bekommt sie ein minimales Code-Skelett.
12. Anchor Story und Strategy Snippets muessen auf die spaeteren Risikoklassen im Artikel anschlussfaehig sein.
13. Wenn Micro-Beispiele vor der formalen Einfuehrung der Risikoklassen gerendert werden, tragen sie neutrale Titel oder einen klaren Vorwaerts-Hinweis auf den spaeteren Klassifikationsabschnitt.
14. Strategie-Skelette enthalten mindestens einen operativen Caveat-Hinweis wie Flag-Reset, Terminierungsbedingung oder Idempotenzannahme.
15. Dialect-aware Preflight-Bloecke zeigen dieselbe fachliche Pruefidee pro System in natuerlicher Syntax, typischer Schutzlogik und systemtypischer Arbeitsweise.
16. Andere Systeme werden dort nicht als blosse Varianten eines SQL-Server-Musters formuliert.
17. Die Darstellung darf als eigener Query-Block pro System oder als Hauptbeispiel mit kurzen Dialekt-Varianten erfolgen, solange die natuerliche Ausdrucksform pro System sichtbar bleibt.
18. Pro behandeltem System wird mindestens ein dialekttypisches Sicherheits- oder Vorbereitungs-Muster vorbereitet, das mehr ist als eine syntaktische Uebersetzung.
19. Neben dem Entscheidungsdiagramm wird genau eine weitere merkfaehige Hauptvisualisierung vorbereitet, die den Kernkonflikt des Themas sichtbar macht.
