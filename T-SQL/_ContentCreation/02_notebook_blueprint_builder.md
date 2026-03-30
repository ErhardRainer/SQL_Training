# 02 - Notebook Blueprint Builder

## Aufgabe
Erzeuge fuer jeden Notebook-Eintrag aus dem Chapter Inventory ein eigenes Blueprint-YAML.
Nutze dafuer `Templates/notebook_blueprint.template.yaml`.

## Ziel
Das Blueprint ist der fachliche Bauplan eines einzelnen Notebooks.
Es verbindet Kapitelabschnitt, Demo-Strategie, Lernziele, Fallstricke und Zellen-Dramaturgie.

## Eingaben
- `chapter_inventory.yaml`
- `chapter_assets.yaml`
- die Kapiteldatei selbst
- vorhandene Ziel-Notebooks, falls `refresh_existing`

## Pflichtfelder
- `notebook`
- `sources`
- `learning_contract`
- `lab_profile`
- `section_plan`
- `optimizer_focus`
- `pitfalls`
- `exercises`
- `crosslinks`
- `quality_gates`

## Pflichtinhalte in `notebook`
- `notebook_file`
- `output_path`
- `section_number`
- `title`
- `title_card.themengebiet`
- `title_card.kapitel`
- `title_card.kurzbeschreibung`
- `title_card.stand`
- `notebook_class`
- `difficulty`
- `generation_mode`

## Pflichtinhalte in `learning_contract`
- `thesis`
- `prerequisites`
- `typical_questions`
- `learning_goals`
- `out_of_scope`

## Pflichtinhalte in `lab_profile`
- `setup_mode`
- `database_strategy`
- `environment_requirements`
- `safety_notes`
- `cleanup_strategy`
- `session_model`

## Regeln fuer `setup_mode`
- `rebuild_demo_db`
- `create_demo_objects`
- `reuse_existing_lab`
- `prereq_only`
- `multi_session_lab`
- `instance_feature_lab`

## Regeln fuer `section_plan`
Das Blueprint muss die spaetere Zellreihenfolge vorbereiten:
1. Titelkarte
2. Einstieg und typische Fragen
3. Inhaltsblock
4. SQL-Kernel-Hinweis
5. Setup oder Lab-Voraussetzungen
6. Sichtung oder Baseline
7. Kernsektionen
8. Diagnostik-/Optimizer-Block
9. Fallstricke
10. Best Practices
11. Uebungen
12. Loesungen
13. Querverweise
14. optional Cleanup

## Heuristiken fuer die Notebook-Klasse
- Datenabfragen, Funktionen, Datentypen, Windowing, GROUP BY: meist `query_lab`
- INSERT, UPDATE, DELETE, MERGE, Transaktionen: meist `dml_lab`
- CREATE DATABASE, Views, Constraints, Indexes: meist `ddl_lab`
- HA/DR, Backup, Agent, CDC, Service Broker, Troubleshooting: meist `admin_lab`
- Isolation, Blocking, Deadlocks, Snapshot, Konkurrenz: oft `multi_session_lab`

## Was aus der Kapiteldatei uebernommen werden muss
- Abschnittstitel
- Kurzbeschreibung
- genannter Notebook-Dateiname
- Kernquellen aus Docs/YouTube
- feinere Unterpunkte im Abschnitt selbst

## Zusatzregeln
- Ein Notebook darf enger sein als das gesamte Kapitel, aber nicht an der Kapitelbeschreibung vorbeigehen.
- Wenn die Kapiteldatei ein Thema als Performance- oder Sicherheitsfalle markiert, muss das Blueprint dafuer konkrete `pitfalls` und `quality_gates` anlegen.
- Wenn lokale SQL-Skripte vorhanden sind, muss das Blueprint entscheiden, ob sie inline uebernommen oder nur adaptiert werden.
