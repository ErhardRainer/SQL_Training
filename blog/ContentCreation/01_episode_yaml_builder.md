# 01 - Episode YAML Builder

## Aufgabe
Erzeuge aus dem Thema ein vollstaendiges Episode-YAML.
Nutze dafuer `Templates/episode_blueprint.template.yaml`.

## Ziel des YAML
Das YAML ist der fachliche Bauplan der Episode.
Es legt auch den Betriebsmodus des Workflows fest.

## Pflichtfelder
- article
- workflow
- evidence_model
- render_rules
- presentation
- version_scope
- repository_paths
- author_notes
- systems
- chapters
- risk_classes
- preflight_checks
- decision_model
- signature_visual
- crosslinks
- ending
- quality_gates
- sources_expected

## Pflichtinhalte in `article`
- title
- slug
- topic_number
- as_of_date
- status
- language
- series
- leading_system
- canonical_label
- thesis
- summary_goal
- audience
- tone

## Pflichtinhalte in `workflow`
- allowed_phases
- pipeline_mode
- current_phase
- target_phase
- skip_steps

## Pflichtinhalte in `evidence_model`
- allowed_levels
- available_levels
- wording_rules

## Pflichtinhalte in `author_notes`
- source_path
- use_if_present
- note_items

## Pflichtinhalte in `render_rules`
- suppress_empty_related_blog_articles
- suppress_empty_training_blocks
- suppress_absent_benchmarks
- suppress_absent_demo_results
- suppress_empty_method_status_lines
- suppress_internal_pipeline_terms_in_body

## Pflichtinhalte in `presentation`
- persona_mode
- reader_guide_position
- toc_position
- allowed_pre_toc_blocks
- pre_toc_zone_style
- standalone_sections_must_appear_in_toc
- persona_entry_position
- require_comparison_table
- require_warning_box
- require_anti_pattern_block
- require_decision_visual
- require_signature_visual
- require_min_examples_per_treated_system
- require_explicit_error_case
- require_anchor_failure_story
- require_historical_contrast_snippets
- require_strategy_code_for_recommended_patterns
- require_risk_class_cross_references
- require_forward_reference_for_early_class_labels
- require_operational_caveats_in_strategy_code
- avoid_adjacent_framework_duplication
- require_dialect_aware_prechecks
- require_dialect_native_safety_patterns
- require_practical_observations
- allow_controlled_expert_judgment

## Regeln fuer `workflow`
- `allowed_phases` ist die feste Werteliste fuer `workflow_phase` im Artikel und im Workflow.
- Standard ist `pipeline_mode: full`.
- Der Bypass ist `pipeline_mode: article_only`.
- In `article_only` muessen diese Schritte in `skip_steps` stehen:
  - `03_demo_spec_builder`
  - `04_code_examples_generator`
  - `05_insight_extraction`
  - `07_code_examples_integrator`
  - `08_insight_reintegration`
- `current_phase` startet bei `01_episode_yaml_builder`.
- `target_phase` ist im Master-Workflow immer `12_self_review`.
- `final` ist der terminale Wert nach manueller Finalisierung ausserhalb des Master-Workflows.

## Regeln fuer Kapitel
Keine Prozentverteilung verwenden.
Stattdessen pro Kapitel:
- title
- purpose
- lead_system
- systems -> pro System `mode` und `depth`

## Erlaubte `mode`-Werte
- lead
- contrast
- hint
- meta
- exkurs
- deep_dive
- reference
- none

## `depth`
- 0 = kein Beitrag
- 1 = kurzer Hinweis
- 2 = normaler Absatz
- 3 = eigener Unterabschnitt
- 4 = echter Deep Dive

## Pflicht-Tiefenlogik
Das YAML muss Kapitel fuer diese Ebenen vorsehen:
1. Problemdefinition
2. Warum die intuitive Sicht zu kurz greift
3. Interne Klassen des Problems
4. Einflussfaktoren
5. Interne Ausfuehrungslogik
6. Praktische Hauptunterscheidung
7. Rolle von Indizes / Constraints / Logging / Locks
8. Vorpruefungen
9. Strategien
10. Entscheidungsmodell
11. Kurzform fuer die Praxis

## Systeme
- SQL Server, PostgreSQL, Oracle und MySQL sind grundsaetzlich fachlich im Scope.
- Die Verteilung im Artikel folgt nicht einer Gleichverteilung, sondern den Abweichungen zum fuehrenden System.
- ANSI-95 bleibt Meta-Ebene und dient der Trennung von Standard und Implementierung.

## Risikoklassen
- Die kanonischen Klassen sind `robust`, `conditionally_safe`, `risky` und `avoid`.
- Verfeinerungen sind erlaubt, muessen aber immer einer dieser vier Klassen zugeordnet bleiben.

## Crosslinks
Das YAML muss vorbereiten:
- Training-Ziele je Dialekt
- verwandte Blog-Artikel
- Backlink-Ziele in Trainingsunterlagen

## Repository-Struktur
Die Root-Struktur ist:
- `blog`
- `T-SQL`
- `PostgreSQL`
- `Oracle`
- `MySQL`
- `SQLHana`

## Quellenplanung
Zusaetzliche Planungsregeln:
- Erlaubte Evidenz-Level sind `docs_based`, `inference_based`, `demo_based`, `executed_test_based`, `benchmark_based`.
- In `article_only` muessen mindestens `docs_based` und gegebenenfalls `inference_based` modelliert werden.
- Das YAML muss die spaetere Ausarbeitung dieser Bloecke vorbereiten:
  - `Methodischer Status`
  - `Warum das fuehrende System in dieser Episode fuehrt`
  - `Syntax-Oberflaeche`
  - `Was der Standard hier leistet - und was nicht`
- Das YAML muss ausserdem diese Darstellungsentscheidungen vorbereiten:
  - Persona-Modus der Episode
  - Position von Leserleitfaden und TL;DR
  - Position des Inhaltsverzeichnisses und erlaubte Vorblaecke
  - Stil der Vor-Toc-Zone: kompakt oder kollabierbar
  - mindestens eine Vergleichstabelle
  - mindestens ein Warnblock
  - mindestens ein Block `Anti-Pattern vs. robuste Form`
  - mindestens eine visuelle Darstellung des Entscheidungsmodells
  - mindestens eine zusaetzliche merkfaehige Hauptvisualisierung neben dem Entscheidungsmodell
  - mindestens ein konkretes Fehlersymptom oder eine kurze Ankergeschichte
  - gezielte Praxisbeobachtungen zu Denkfehlern, Teammustern oder operativen Kippstellen
- Wenn fachlich hilfreich, soll das YAML ein bis zwei kontrollierte fachliche Urteilssaetze vorbereiten, aber keine autobiografische Stimme erzwingen.
- `preflight_checks` duerfen nicht nur aus Fragen bestehen, sondern sollen moeglichst auch konkrete Pruefpatterns oder Query-Patterns enthalten.
- Fuer Multi-System-Themen soll das YAML minimale Beispiele pro behandeltem System und einen expliziten Fehlerfall mitplanen.
- `preflight_checks` sollen nicht nur generische Intents enthalten, sondern die spaetere dialect-aware Ausarbeitung vorbereiten:
  - natuerliche Ausdrucksform pro System
  - typische Schutzmechanismen
  - naheliegende idiomatische Loesung
  - ein systemtypisches Sicherheits- oder Vorbereitungs-Muster
  - typische Stolperstellen des Systems
- Das YAML soll markieren, wie dieselbe Problemklasse spaeter als vier Datenbankkulturen gerendert wird, statt andere Systeme nur an SQL Server anzunaehern.
- Wenn eine historische Kontrastversion wie Oracle 19c in der Episode aktiv fuehrend oder kontrastierend vorkommt, soll das YAML auch ein sichtbares Kontrast-Snippet oder Minimalbeispiel vorsehen.
- Wenn eine Strategie als bessere oder bevorzugte Standardstrategie geplant ist, soll das YAML dafuer ein minimales Code-Skelett im Artikel vorbereiten.
- Die spaeteren Strategie- und Entscheidungsabschnitte muessen die Risikoklassen aus `risk_classes` explizit wiederverwenden.
- Wenn Beispiele oder Vergleichsbloecke vor der formalen Einfuehrung der Risikoklassen stehen, soll das YAML dafuer neutrale Bezeichnungen oder einen klaren Vorwaerts-Hinweis vorsehen.
- Strategie-Skelette sollen mindestens einen operativen Hinweis zu Terminierung, Flag-Reset, Idempotenz oder Rueckfallpfad mitplanen.
- Kernframeworks wie Problemklasse / Produktsyntax / Produktsemantik sollen nicht in benachbarten Abschnitten doppelt ausformuliert werden.
- Wenn `blog/<topic-slug>/notes.md` existiert, muss es bereits in Schritt 01 gelesen und als redaktioneller Input in `author_notes` strukturiert werden.
- Notizen aus `notes.md` sind Autoreninput, nicht Evidenz. Sie duerfen Planung, Gewichtung und Gliederung steuern, aber keine unbelegten Fachbehauptungen legitimieren.
- Jede substantielle Notiz bekommt in `author_notes.note_items` mindestens `priority`, `planned_section` und `handling`.
- `must_cover`-Notizen muessen im spaeteren Artikel an einer fachlich passenden Stelle eingeplant werden, nicht als Sammelanhang `Notizen`.

`sources_expected` muss vorbereiten:
- offizielle Produktdokumentation pro relevantem System
- Release-/Versionsdokumentation pro relevantem System
- erwartete Claims, die spaeter durch `sources.yaml` gedeckt werden muessen
