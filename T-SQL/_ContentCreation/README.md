# T-SQL / ContentCreation

Diese Dateien definieren einen mehrstufigen Workflow zur Erzeugung von T-SQL-Jupyter-Notebooks in der didaktischen Form von `T-SQL/02_Select`.

Die Pipeline ist aus zwei Beobachtungen abgeleitet:
- `T-SQL/02_Select` zeigt das Zielbild fuer fertige Notebooks.
- Die meisten anderen Kapitel besitzen bereits eine saubere Notebook-Roadmap in ihrer jeweiligen `*.md`-Uebersichtsdatei, aber noch nicht die dazugehoerigen `.ipynb`.

## Was als Zielbild gilt
- Ein Notebook pro Unterabschnitt aus `## 2 | Struktur` der Kapiteldatei.
- Dateiname exakt wie im Kapitel genannt, auch wenn der Prefix ungewoehnlich ist.
- SQL-Kernel-Metadaten: `name = SQL`, `display_name = SQL`, `language = sql`.
- Unausgefuehrte Codezellen: `execution_count = null`, `outputs = []`.
- Wiederkehrende Dramaturgie: Titelkarte, Einstieg, Inhaltsblock, Kernel-Hinweis, Setup/Lab-Voraussetzungen, Kernsektionen, Optimizer/Diagnostik, Fallstricke, Best Practices, Uebungen, Loesungen, Querverweise, optional Cleanup.
- Idempotente, sichere Demo-Skripte oder explizite Lab-Voraussetzungen fuer Themen, die sich nicht lokal "einfach mal" aufbauen lassen.

## Betriebsmodi
- `full_chapter` = alle Notebook-Eintraege eines Kapitels erzeugen oder auffrischen.
- `single_notebook` = genau einen Eintrag aus dem Kapitel erzeugen.
- `refresh_existing` = vorhandenes Notebook an das Zielbild angleichen, ohne Dateiname oder Kerninhalt willkuerlich zu aendern.

## Empfohlene Arbeitsartefakte
Die Zwischenartefakte muessen nicht committed werden. Empfohlen ist ein temporarer Arbeitsordner im Zielkapitel:
- `<chapter-folder>/_work_notebooks/chapter_inventory.yaml`
- `<chapter-folder>/_work_notebooks/chapter_assets.yaml`
- `<chapter-folder>/_work_notebooks/<notebook-stem>.blueprint.yaml`
- `<chapter-folder>/_work_notebooks/<notebook-stem>.demo_assets.yaml`
- `<chapter-folder>/_work_notebooks/<notebook-stem>.cell_plan.yaml`

Die finalen `.ipynb` gehoeren immer direkt in den Kapitelordner.

## Reihenfolge des Workflows
1. `00_notebook_canon.md`
2. `01_chapter_inventory_builder.md`
3. `01a_repo_asset_scan.md`
4. `02_notebook_blueprint_builder.md`
5. `03_notebook_blueprint_validator.md`
6. `04_demo_assets_builder.md`
7. `05_notebook_cell_plan_builder.md`
8. `06_notebook_markdown_writer.md`
9. `07_sql_cells_generator.md`
10. `08_notebook_assembler.md`
11. `09_crosslink_planning.md`
12. `10_self_review.md`
13. `11_master_job_prompt_template.md`

## Nicht Teil des Master-Workflows
- Ein echter Ausfuehrungstest der Notebooks gegen eine SQL-Server-Lab-Umgebung ist ein separater manueller oder CI-gestuetzter Schritt.
- Massenhafte Uebersetzung in andere SQL-Dialekte ist nicht Teil dieser Pipeline. Der Fokus hier ist T-SQL.

## Leitregeln
- Primaere fachliche Quelle ist immer die Kapiteldatei des Zielthemas.
- Repo-lokale SQL-Skripte, vorhandene Notebooks und Hilfsdateien werden bevorzugt wiederverwendet statt neu erfunden.
- `T-SQL/02_Select` ist Stil- und Struktur-Referenz, nicht inhaltliche Schablone fuer jedes Thema.
- Fuer Admin-/Betriebsthemen darf `Setup & Demo-Daten` in `Setup & Lab-Voraussetzungen` oder `Setup & Umgebung` uebergehen.
- Lesertext im Notebook soll normales UTF-8-Deutsch sein. Die Pipeline-Dateien selbst bleiben ASCII.
