# Arbeitsweise von Agenten

Diese Datei beschreibt die im Repository hinterlegten Arbeitsanweisungen für
KI-Agenten. Vor einer passenden Aufgabe ist die jeweilige Anweisung vollständig
zu lesen und während der Arbeit einzuhalten.

## Artikel didaktisch verbessern

Die [Arbeitsanweisung zum Verbessern von Übersichtsartikeln](_internal/instructions/instruction_improveArticle.md)
definiert die Qualitätsanforderungen für bestehende T-SQL-Artikel. Sie umfasst
unter anderem die Analyse vorhandener Inhalte, eine klare fachliche Hierarchie,
Navigation, Mini-Beispiele, interne Verweise, geprüfte externe Quellen und die
didaktische Aufbereitung von Detailabschnitten.

Nutze diese Anweisung, wenn ein vorhandener Artikel inhaltlich und strukturell
aufgewertet werden soll. Bestehende sinnvolle Inhalte bleiben dabei erhalten
und werden präzisiert oder sinnvoll ergänzt.

## Reddit-Themen prüfen und in Aufgaben überführen

Der Ordner [Reddit-Arbeitsablauf](_internal/instructions/reddit/) enthält zwei
zusammengehörende Bestandteile:

- [RSS-Downloadskript](_internal/instructions/reddit/download_sqlserver_rss.py)
  lädt neue Beiträge aus `r/SQLServer` in die lokale JSON-Ablage.
- [Bewertungsanweisung](_internal/instructions/reddit/instruction_reddit.md)
  prüft noch nicht klassifizierte Posts gegen den vorhandenen Repository-Inhalt.

Die Bewertung setzt je Post genau einen Status: `idea` für ein relevantes, noch
nicht ausreichend abgedecktes Thema, `done` für ausreichende bestehende
Abdeckung oder `ignore` für nicht geeignete Themen. Für jeden Post mit
`idea` entsteht eine eindeutig nummerierte Umsetzungsaufgabe unter
`_internal/Task/idea/MSSQL_TASK_XXXX.md`. Bereits bewertete Posts werden bei
weiteren Durchläufen nicht erneut bearbeitet.
