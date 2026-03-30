# 01a - Repo Asset Scan

## Aufgabe
Erzeuge aus dem Zielkapitel ein `chapter_assets.yaml`.
Nutze dafuer `Templates/chapter_assets.template.yaml`.

## Ziel
Der Asset-Scan identifiziert alles, was fuer neue Notebooks wiederverwendet, adaptiert oder nur referenziert werden sollte.

## Zu scannende Pfade
- der gesamte Ziel-Kapitelordner
- typische Unterordner wie `SQLScript`, `SQLScripts`, `scripts`, `images`, `assets`
- vorhandene `.ipynb`
- `.sql`, `.md`, `.txt`, `.csv`, `.json`, `.xml`, `.xel`, `.png`, `.jpg`, `.svg`, `.drawio`

## Zu klassifizierende Asset-Typen
- `sql_script`
- `script_folder`
- `existing_notebook`
- `diagram_or_image`
- `dataset`
- `notes`
- `admin_runbook`
- `ignore`

## Reuse-Strategien
- `reuse_direct` = kann fast unveraendert in ein Notebook uebernommen werden
- `adapt` = fachlich nuetzlich, aber fuer Notebook-Zellen umzuarbeiten
- `reference_only` = nur als Hintergrund oder Querverweis nutzen
- `ignore` = fuer die Pipeline nicht relevant

## Was besonders wichtig ist
- Setup-Skripte
- Demo-Daten
- DMVs und Troubleshooting-Queries
- mehrstufige Admin-Skripte
- Session-A/B-Skripte
- bereits vorhandene Legacy-Notebooks wie `EH2_Beispiele_UPDATE.ipynb`
- sicherheitsrelevante oder destruktive Skripte, die nur kommentiert oder in Voraussetzungen genannt werden duerfen

## Pflichtfelder
- `chapter_assets.chapter_markdown`
- `chapter_assets.scanned_paths`
- `chapter_assets.reusable_assets`
- `chapter_assets.operational_constraints`
- `chapter_assets.crosslink_candidates`
- `chapter_assets.missing_assets`

## Regeln
- Bevorzuge lokale Assets vor neu erfundenen Beispielen.
- Uebernimm keine Legacy-Notebooks blind. Markiere klar, ob sie Stilreferenz, Inhaltsreferenz oder nur Historie sind.
- Wenn ein Thema instanzweite Features braucht, dokumentiere die reale Lab-Anforderung in `operational_constraints`.
- Wenn ein Asset sicherheits- oder produktionskritisch ist, vermerke das explizit.
