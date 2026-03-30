# 11 - Master Job Prompt Template

```text
Erzeuge fuer das Kapitel "<KAPITELPFAD>" T-SQL-Jupyter-Notebooks gemaess den Vorgaben in:

- T-SQL/_ContentCreation/00_notebook_canon.md
- T-SQL/_ContentCreation/01_chapter_inventory_builder.md
- T-SQL/_ContentCreation/01a_repo_asset_scan.md
- T-SQL/_ContentCreation/02_notebook_blueprint_builder.md
- T-SQL/_ContentCreation/03_notebook_blueprint_validator.md
- T-SQL/_ContentCreation/04_demo_assets_builder.md
- T-SQL/_ContentCreation/05_notebook_cell_plan_builder.md
- T-SQL/_ContentCreation/06_notebook_markdown_writer.md
- T-SQL/_ContentCreation/07_sql_cells_generator.md
- T-SQL/_ContentCreation/08_notebook_assembler.md
- T-SQL/_ContentCreation/09_crosslink_planning.md
- T-SQL/_ContentCreation/10_self_review.md

Verwende die Artefaktstrukturen aus:
- T-SQL/_ContentCreation/Templates/chapter_inventory.template.yaml
- T-SQL/_ContentCreation/Templates/chapter_assets.template.yaml
- T-SQL/_ContentCreation/Templates/notebook_blueprint.template.yaml
- T-SQL/_ContentCreation/Templates/demo_assets.template.yaml
- T-SQL/_ContentCreation/Templates/notebook_cell_plan.template.yaml
- T-SQL/_ContentCreation/Templates/notebook_json.template.json

Betriebsmodus:
- Standard: `full_chapter`
- Optional: `single_notebook`
- Optional: `refresh_existing`

Arbeite in dieser Reihenfolge:
- 01. Chapter Inventory erzeugen
- 01a. Repo-Assets scannen
- 02. Pro Notebook ein Blueprint erzeugen
- 03. Blueprints validieren
- 04. Demo-Assets ableiten
- 05. Zellplan erzeugen
- 06. Markdown-Zellen schreiben
- 07. SQL-Zellen schreiben
- 08. Finale `.ipynb` bauen
- 09. Querverweise einarbeiten
- 10. Self-Review durchfuehren

Pflicht:
- Die Kapiteldatei ist die primaere fachliche Quelle
- Ein Notebook pro Unterabschnitt aus `## 2 | Struktur`
- Dateinamen exakt wie in der Kapiteldatei angegeben
- Notebook-Metadaten fuer SQL-Kernel:
  - `name = SQL`
  - `display_name = SQL`
  - `language = sql`
- `nbformat = 4`, `nbformat_minor = 5`
- Alle Codezellen mit `execution_count = null` und `outputs = []`
- Titelkarte mit `Themengebiet`, `Kapitel`, `Kurzbeschreibung`, `Stand`
- Einleitung mit `Typische Fragestellungen`
- Inhaltsblock `### Inhalt dieses Notebooks ist`
- SQL-Kernel-Hinweis
- Setup/Lab-Voraussetzungen passend zur Notebook-Klasse
- Baseline oder Daten-/Zustandssichtung, sofern sinnvoll
- Kernsektionen, Diagnostik-/Optimizer-Block, Fallstricke, Best Practices, Uebungen, Loesungen, Querverweise, optional Cleanup
- Uebungsloesungen als separate Codezellen
- Fehlerhafte Beispiele so darstellen, dass der Notebook-Lauf nicht sinnlos zerbricht
- Repo-lokale Assets bevorzugt wiederverwenden
- `T-SQL/02_Select` als Stil- und Strukturreferenz nutzen, nicht als blindes Inhaltsmuster

Wenn `single_notebook`, bearbeite nur:
- `<NOTEBOOK_DATEI>`

Wenn `refresh_existing`, dann:
- vorhandene Ziel-Datei lesen
- brauchbare Substanz uebernehmen
- Dateiname, Kernstruktur und Notebook-Metadaten nicht verwildern lassen

Empfohlene Zwischenartefakte:
- `<chapter-folder>/_work_notebooks/chapter_inventory.yaml`
- `<chapter-folder>/_work_notebooks/chapter_assets.yaml`
- `<chapter-folder>/_work_notebooks/<notebook-stem>.blueprint.yaml`
- `<chapter-folder>/_work_notebooks/<notebook-stem>.demo_assets.yaml`
- `<chapter-folder>/_work_notebooks/<notebook-stem>.cell_plan.yaml`

Ziel:
- finale `.ipynb` direkt im Kapitelordner
- fachlich und dramaturgisch gleichwertig zu den Notebooks in `T-SQL/02_Select`
```
