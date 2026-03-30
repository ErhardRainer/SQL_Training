# 08 - Notebook Assembler

## Aufgabe
Baue aus Markdown-Texten und SQL-Zellen ein valides `.ipynb`.
Nutze dafuer `Templates/notebook_json.template.json` als technisches Minimum.

## Ziel
Der Assembler erzeugt die finale Notebook-Datei im Kapitelordner.

## Pflichtregeln
- Die Zellenreihenfolge folgt exakt dem Zellplan.
- Markdown- und Codezellen bekommen leere `metadata`.
- Codezellen bekommen:
  - `execution_count: null`
  - `outputs: []`
- Notebook-Metadaten:
  - `kernelspec.name = SQL`
  - `kernelspec.display_name = SQL`
  - `kernelspec.language = sql`
  - `language_info.name = sql`
- `nbformat = 4`
- `nbformat_minor = 5`

## JSON-Regeln
- Erzeuge valides JSON ohne Trailing Commas.
- `source` darf als String geschrieben werden, wenn der Generator damit sauber arbeitet.
- Behalte Zeilenumbrueche im Zelltext konsistent.

## Dateiregeln
- Schreibe die finale Datei in den Kapitelordner, nicht in `_ContentCreation`.
- Ueberschreibe vorhandene Dateien nur bewusst im Modus `refresh_existing`.
- Wenn ein bestehendes Notebook erhalten werden soll, zuerst vergleichen und nur gezielt angleichen.

## Minimaler Build-Check
- JSON parsebar
- richtige Dateiendung `.ipynb`
- richtige Notebook-Metadaten
- keine Outputs
- erste vier Zellen entsprechen Titelkarte, Einstieg, Inhaltsblock, Kernel-Hinweis
