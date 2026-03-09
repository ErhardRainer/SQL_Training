# 16 - Master Job Prompt Article Only Template

```text
Schreibe mir einen Blog-Artikel zum Thema "<THEMA>" gemaess den Vorgaben in:

- blog/ContentCreation/00_series_canon.md
- blog/ContentCreation/01_episode_yaml_builder.md
- blog/ContentCreation/01a_sources_research.md
- blog/ContentCreation/02_episode_yaml_validator.md
- blog/ContentCreation/03_demo_spec_builder.md
- blog/ContentCreation/04_code_examples_generator.md
- blog/ContentCreation/05_insight_extraction.md
- blog/ContentCreation/05a_micro_examples_builder.md
- blog/ContentCreation/06_article_writer.md
- blog/ContentCreation/07_code_examples_integrator.md
- blog/ContentCreation/08_insight_reintegration.md
- blog/ContentCreation/09_crosslink_planning.md
- blog/ContentCreation/10_crosslink_integration.md
- blog/ContentCreation/11_link_validation.md
- blog/ContentCreation/12_self_review.md

Verwende die Artefaktstrukturen aus:
- blog/ContentCreation/Templates/episode_blueprint.template.yaml
- blog/ContentCreation/Templates/sources.template.yaml
- blog/ContentCreation/Templates/demo_spec.template.yaml
- blog/ContentCreation/Templates/insights.template.yaml
- blog/ContentCreation/Templates/micro_examples.template.yaml
- blog/ContentCreation/Templates/crosslinks_plan.template.yaml

Setze den Betriebsmodus auf:
- `pipeline_mode: article_only`

Arbeite in dieser Reihenfolge:
- 01. Episode-YAML erzeugen
- 01a. Quellen recherchieren und `sources.yaml` erzeugen
- 02. Episode-YAML validieren
- 03. Demo-Spezifikation erzeugen
- 04. Codebeispiele pro relevantem System erzeugen
- 05. Erkenntnisse extrahieren
- 05a. Micro-Examples und Syntax-Oberflaeche erzeugen
- 06. Artikel schreiben
- 07. Codebeispiele einarbeiten
- 08. Erkenntnisse rueckintegrieren
- 09. Querverlinkungen planen
- 10. Querverlinkungen einarbeiten
- 11. Links validieren
- 12. Self-Review durchfuehren

Da `pipeline_mode = article_only`, muessen diese Schritte explizit uebersprungen und in `workflow.skip_steps` dokumentiert werden:
- 03
- 04
- 05
- 07
- 08

Pflichtartefakte fuer diesen Lauf:
- `episode.yaml`
- `sources.yaml`
- `micro_examples.yaml`
- Artikel-`README.md`
- `crosslinks_plan.yaml`
- `link-report.md`
- reviewed Draft nach Schritt 12

Pflicht:
- YAML-Header im Artikel mit mindestens `title`, `slug`, `as_of_date`, `workflow_phase`, `pipeline_mode`, `article_status` und `leading_system`
- Wenn `blog/<topic-slug>/notes.md` existiert, lies es bereits vor Schritt 01 als redaktionellen Input und ueberfuehre seine Punkte in `author_notes` im Episode-YAML
- Leserleitfaden oder TL;DR gesamt frueh im Artikel
- Eigenstaendiger Block `Methodischer Status` direkt unter dem sichtbaren Versionsblock
- Inhaltsverzeichnis vor dem ersten inhaltsschweren Block
- Vor dem Inhaltsverzeichnis nur eine kompakte Metadaten-Zone; zulaessig sind kurze Scope-, Fuehrungs-, Trainings- und Dialekt-Hinweise
- Kurzer Abschnitt `Warum das fuehrende System in dieser Episode fuehrt`
- Kurze `Syntax-Oberflaeche` der relevanten Systeme
- Kurzer ANSI-Abschnitt `Was der Standard hier leistet - und was nicht`
- Jeder eigenstaendige Abschnitt nach dem Inhaltsverzeichnis muss darin verlinkt sein oder bewusst in einen Hauptabschnitt integriert werden
- Mindestens eine scanbare Vergleichstabelle fuer relevante Systemunterschiede
- Mindestens ein minimales Beispiel pro behandeltem System
- Wichtigsten Fehlerfall explizit zeigen
- Mindestens ein konkretes Fehlersymptom oder eine kurze Ankergeschichte
- Mindestens ein Warnblock fuer den kritischsten Produktionsfallstrick
- Mindestens ein kurzer Block `Anti-Pattern vs. robuste Form`
- Mindestens eine visuelle Darstellung des Entscheidungsmodells
- Persona-Nutzung pro Episode bewusst waehlen: Intro/Outro-only oder kurze Uebergangseinwuerfe
- Persona-Einstieg direkt nach dem Titel oder direkt vor dem ersten Hauptabschnitt, nicht zwischen Metadatenbloecken
- Historische Kontrastversionen mit aktivem Fachgewicht bekommen sichtbare Snippets oder Minimalbeispiele
- Wenn eine Strategie als bessere Standardform empfohlen wird, zeige auch ein minimales Code-Skelett dazu
- Eingefuehrte Risikoklassen muessen spaeter in Strategie- und Entscheidungsabschnitten aktiv wiederverwendet werden
- Wenn Beispiele vor der formalen Einfuehrung der Risikoklassen stehen, nutzen sie neutrale Titel oder einen Vorwaerts-Hinweis auf den spaeteren Klassifikationsabschnitt
- Batch- oder Staging-Skelette muessen mindestens einen operativen Caveat wie Flag-Reset, Idempotenz oder Terminierungsbedingung nennen
- Kernframeworks wie Problemklasse / Produktsyntax / Produktsemantik nicht in direkt benachbarten Abschnitten doppelt ausformulieren
- Vorpruefungs-Queries und Schutzmuster pro Dialekt in natuerlicher Syntax, typischer Arbeitsweise und mit systemtypischen Schutzmechanismen ausdruecken
- Pro Dialekt auch die natuerliche sichere oder vorbereitende Arbeitsweise zeigen, nicht nur dieselbe Logik in anderer Syntax
- Das Thema soll als eine Problemklasse in vier Datenbankkulturen lesbar werden, nicht als Leitdialekt mit Uebersetzungen
- Neben dem Entscheidungsdiagramm genau eine weitere merkfaehige Hauptvisualisierung einbauen, zum Beispiel `Rohquelle -> vorbereitete Quelle -> Schreiboperation` oder `Leselogik vs. Schreiblogik`
- Andere Systeme nicht als blosse Uebersetzungen des fuehrenden Systems darstellen
- Gezielte Praxisbeobachtungen zu Denkfehlern, Teammustern oder operativen Kippstellen einstreuen
- Ein bis zwei kontrollierte fachliche Urteilssaetze in Ich-Form sind erlaubt, aber keine autobiografische Stimme erzeugen
- `notes.md`-Punkte muessen im Artikel an fachlich passenden Stellen einfliessen und duerfen nicht als sichtbarer Roh-Notizblock erscheinen
- `workflow_phase` muss einer festen Werteliste folgen:
  - `01_episode_yaml_builder`
  - `01a_sources_research`
  - `02_episode_yaml_validator`
  - `03_demo_spec_builder`
  - `04_code_examples_generator`
  - `05_insight_extraction`
  - `05a_micro_examples_builder`
  - `06_article_writer`
  - `07_code_examples_integrator`
  - `08_insight_reintegration`
  - `09_crosslink_planning`
  - `10_crosslink_integration`
  - `11_link_validation`
  - `12_self_review`
  - `13_external_review`
  - `14_finalize_article`
  - `final`
- Sichtbarer Versions- und Geltungsbereich direkt unter dem Titel
- Fuehrendes System fachlich begruenden
- Alle vier Produktsysteme fachlich mitdenken; die Darstellungstiefe folgt den Abweichungen zum fuehrenden System
- Keine kuenstliche Gleichverteilung
- Keine erfundene Syntax oder Interna
- Keine interne Pipeline-Sprache im sichtbaren Lesertext
- Keine vollstaendigen Demo- oder Beispiel-SQL-Dateien erzeugen
- Kleine dokumentationsbasierte Syntax-Snippets und Micro-Beispiele sind erlaubt
- Keine pseudo-validierten Aussagen erfinden
- Leere optionale Bereiche nicht rendern
- Ziel des Master-Jobs ist `workflow_phase: 12_self_review`
- `article_status` soll am Ende `reviewed` sein
- Gruendlichkeit vor Geschwindigkeit; der vollstaendige Lauf darf mehrere Stunden dauern

Zusatzregeln:
- Der Artikel stuetzt sich auf Serienkanon, Episode-YAML, `sources.yaml` und `micro_examples.yaml`.
- Die Schritte `03`, `04`, `05`, `07`, `08` werden nicht ausgefuehrt, nur korrekt als uebersprungen dokumentiert.
- `05a` wird trotzdem ausgefuehrt und bleibt in `article_only` strikt `docs_based` oder vorsichtig `inference_based`.
- Nicht Teil dieses Laufs sind:
  - `blog/ContentCreation/13_external_review.md`
  - `blog/ContentCreation/14_finalize_article.md`
```
