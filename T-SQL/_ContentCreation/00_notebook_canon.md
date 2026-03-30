# 00 - Notebook Canon

## Ziel
Erzeuge T-SQL-Jupyter-Notebooks, die fachlich, dramaturgisch und technisch mit den Notebooks in `T-SQL/02_Select` gleichwertig sind.

## Quellenhierarchie
1. Die Kapiteldatei des Zielthemas, zum Beispiel `T-SQL/12_DataTypes_Conversion/12_DataTypes_Conversion.md`
2. Repo-lokale Assets im Kapitelordner, zum Beispiel `.sql`, `SQLScript`, vorhandene `.ipynb`, Screenshots, Lab-Hinweise
3. Bereits existierende Ziel-Notebooks im Kapitelordner, falls `refresh_existing`
4. `T-SQL/02_Select/*.ipynb` als Stil- und Strukturreferenz
5. Die in der Kapiteldatei bereits verlinkten offiziellen Docs und ggf. kuratierten Blog-/Video-Quellen

## Harte Regeln
- Ein Notebook entspricht genau einem Unterabschnitt aus `## 2 | Struktur`.
- Verwende den in der Kapiteldatei genannten Notebook-Dateinamen exakt.
- Uebernimm Titel und Kurzbeschreibung aus der Kapiteldatei semantisch treu.
- Korrigiere ungewoehnliche Dateinamens-Prefixe nicht automatisch.
- Erfinde keine Produktfeatures, DMVs, Trace Flags oder Versionsaussagen.
- Fuehre keine Python-Zellen ein. Alle Codezellen sind T-SQL fuer einen SQL-Kernel.
- Bevorzuge idempotente Lab-Skripte. Wenn das Thema instanzweite Features benoetigt, schreibe klare Voraussetzungen statt fragiler Fake-Setups.
- Destruktive Schritte muessen sichtbar eingeschraenkt, kommentiert oder auf dedizierte Demo-Objekte begrenzt sein.
- Crosslinks im Notebook verweisen primaer auf andere Kapitel des Repos.

## Technische Notebook-Regeln
- `nbformat = 4`
- `nbformat_minor = 5`
- `metadata.kernelspec.name = SQL`
- `metadata.kernelspec.display_name = SQL`
- `metadata.kernelspec.language = sql`
- `metadata.language_info.name = sql`
- Jede Codezelle hat `execution_count = null`
- Jede Codezelle hat `outputs = []`
- Zellmetadaten bleiben leer, wenn kein zwingender Grund fuer Zusatzfelder besteht

## Standard-Dramaturgie
Die Notebooks in `02_Select` zeigen eine stabile Grundform. Diese Reihenfolge ist der Default:
1. Titelkarte mit `Themengebiet`, `Kapitel`, `Kurzbeschreibung`, `Stand`
2. Einfuehrender Absatz mit Fokus und `Typische Fragestellungen`
3. Inhaltsblock `### Inhalt dieses Notebooks ist`
4. SQL-Kernel-Hinweis
5. `## Setup & Demo-Daten` oder eine thematisch passende Lab-Variante
6. Erste Sichtung oder Baseline-Zustand
7. Mehrere fachliche Kernsektionen
8. `## Query Optimizer/Analyzer & Ausfuehrungsplan` oder ein passender Diagnostik-/Internals-Block
9. `## Typische Fallstricke`
10. `## Best Practices` oder `## Best Practices & Performance`
11. `## Uebungen`
12. Mehrere Loesungs-Codezellen
13. `## Querverweise`
14. Optional `## Cleanup (optional)` oder ein Reset-/Rueckbau-Block

## Erwartete Groessenordnung
Die beobachteten `02_Select`-Notebooks liegen grob in diesem Rahmen:
- meist 40 bis 70 Zellen
- meist 1 Setup-Codezelle
- meist 1 Sichtungs-Codezelle
- meist 5 bis 10 fachliche Kernbloeke
- meist 1 Diagnostik-/Plan-Block
- meist 4 bis 7 Fallstricke
- meist 3 bis 5 Uebungsloesungen

## Notebook-Klassen
Waehle pro Notebook genau eine Grundklasse:
- `query_lab` = SELECT-, Analyse-, Aggregations-, Filter- oder Funktions-Themen
- `dml_lab` = INSERT-, UPDATE-, DELETE-, MERGE- und Transaktions-Themen
- `ddl_lab` = CREATE-, VIEW-, INDEX-, Constraint- oder Objektdefinitions-Themen
- `admin_lab` = Agent, Backup, HA/DR, Troubleshooting, Security, CDC, Replikation
- `multi_session_lab` = Themen mit Session A/B, Blocking, Isolation, Parallelitaet

## Anpassung der Setup-Sektion je Klasse
- `query_lab`: dedizierte Demo-Datenbank und kleine Tabellen sind Standard
- `dml_lab`: Setup plus sichere Ruecksetzstrategie ist Pflicht
- `ddl_lab`: Setup kann aus dedizierten Demo-Objekten statt Beispielzeilen bestehen
- `admin_lab`: lieber Voraussetzungen, Systemobjekte, Beobachtungsqueries und Warnhinweise als kuenstliche Mini-Demos
- `multi_session_lab`: Reihenfolge, Session-Kennzeichnung und Terminierungslogik explizit machen

## Stilregeln fuer Markdown-Zellen
- Schreibe knapp, fachlich und deutschsprachig.
- Ein grosser Themenblock bekommt meist eine `*Fragestellung:*` oder ein klares Lernziel.
- Nutze Listen nur, wenn sie den Scan verbessern.
- Vermeide Marketing-Sprache und ueberlange Theorie.
- Ein Notebook ist Lehrmaterial, kein Blog-Artikel.

## Stilregeln fuer Codezellen
- Jede Codezelle muss fuer sich lesbar sein.
- `USE ...` und `GO` nur dort einsetzen, wo sie den SQL-Kernel-Lauf stabiler machen.
- Fehlerbeispiele bevorzugt kommentiert oder als sichtbar falsches, aber harmloses Verhalten demonstrieren.
- Korrekturzellen folgen direkt auf problematische Muster.
- Uebungsloesungen mit `-- Loesung zu Frage N` markieren.

## Was "gleichwertig" konkret bedeutet
Ein neues Notebook ist gleichwertig, wenn es:
- dieselbe didaktische Tiefe erreicht wie ein `02_Select`-Notebook
- denselben technischen Notebook-Standard einhaelt
- denselben Wechsel aus Erklaerung, Beispiel, Gegenbeispiel und Uebung liefert
- fuer das jeweilige Thema dieselbe Reproduzierbarkeit anstrebt, ohne unpassend kuenstliche Demo-Daten zu erzwingen
