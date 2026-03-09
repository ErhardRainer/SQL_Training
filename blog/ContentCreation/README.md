# Blog / ContentCreation

Diese Dateien definieren den vollstaendigen Erstellungsprozess fuer die SQL-Blog-Serie bis einschliesslich Schritt 12.

## Betriebsmodi
- `full` = kompletter Pipeline-Lauf bis Schritt 12 inklusive Demo-Spezifikation, generierter SQL-Beispiele und evidenzbasierter Insights
- `article_only` = Bypass ohne Demo-/SQL-/Insight-Artefakte; die uebersprungenen Schritte muessen im Workflow des Episode-YAML dokumentiert werden

## Reihenfolge des Master-Workflows
1. `00_series_canon.md`
2. `01_episode_yaml_builder.md`
3. `01a_sources_research.md`
4. `02_episode_yaml_validator.md`
5. `03_demo_spec_builder.md`
6. `04_code_examples_generator.md`
7. `05_insight_extraction.md`
8. `05a_micro_examples_builder.md`
9. `06_article_writer.md`
10. `07_code_examples_integrator.md`
11. `08_insight_reintegration.md`
12. `09_crosslink_planning.md`
13. `10_crosslink_integration.md`
14. `11_link_validation.md`
15. `12_self_review.md`
16. `15_master_job_prompt_template.md`

## Nicht Teil des Master-Workflows
- `13_external_review.md` wird von einer separaten KI ausgefuehrt
- `14_finalize_article.md` ist ein bewusster manueller Schritt nach dem externen Review

## Zusatzvorlagen
- `16_master_job_prompt_article_only_template.md` ist eine wiederverwendbare Komfortvorlage fuer den Bypass `pipeline_mode: article_only`

## Redaktionsregeln
- Der Block `Versions- und Geltungsbereich` bleibt knapp.
- `Methodischer Status` steht direkt darunter.
- Die Begruendung fuer das fuehrende System steht in einem eigenen Kurzabschnitt.
- Leere optionale Bereiche werden unterdrueckt statt erklaert.
- Dialektvergleiche zeigen nicht nur Oberflaechen, sondern natuerliche Sicherheits- und Arbeitsmuster pro System.
- Neben dem Entscheidungsdiagramm ist eine zweite merkfaehige Hauptvisualisierung vorgesehen.
- Wenn `blog/<topic-slug>/notes.md` existiert, wird es in Schritt 01 strukturiert uebernommen und spaeter semantisch in den Artikel integriert.

## Workflow-Metadaten im Artikel
Jede Artikeldatei als Markdown muss im YAML-Header mindestens diese Felder sichtbar fuehren:
- `title`
- `slug`
- `as_of_date`
- `workflow_phase`
- `pipeline_mode`
- `article_status`
- `leading_system`

Erlaubte Werte fuer `workflow_phase`:
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

Wenn ein Schritt den Artikel selbst veraendert, muss `workflow_phase` auf den zuletzt abgeschlossenen schreibenden Schritt aktualisiert werden.

Die Templates unter `blog/ContentCreation/Templates` sind die massgebliche Strukturvorgabe fuer YAML-Artefakte und muessen verwendet werden.
