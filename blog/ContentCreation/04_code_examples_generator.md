# 04 - Code Examples Generator

## Aufgabe
Erzeuge pro relevantem System vollstaendige, kommentierte SQL-Beispiele auf Basis der Demo-Spezifikation.

## Modusregel
Dieser Schritt entfaellt bei `pipeline_mode: article_only`.

## Pro System erzeugen
- 01_schema.sql
- 02_load_data.sql
- 03_examples.sql
- 04_validation.sql
- 05_cleanup.sql

## Regeln
1. Keine universelle Pseudosyntax erfinden.
2. Nur echte produktspezifische Syntax verwenden.
3. Immer kommentieren, welche Variante `robust`, `conditionally_safe`, `risky` oder `avoid` ist.
4. Validierungsabfragen vorsehen.
5. Wo sinnvoll Negativbeispiele aufnehmen.
6. Die Beispiele werden in diesem Workflow nur generiert, nicht ausgefuehrt.
7. Pro behandeltem System mindestens ein minimales, lauffaehiges Kernbeispiel vorsehen.
8. Der wichtigste Fehlerfall wird als explizites Gegenbeispiel oder Fehlerszenario sichtbar gemacht.
9. Beispiele bleiben illustrativ und fokussieren auf die Problemklasse, nicht auf Vollstaendigkeit.
10. Wenn eine historische Kontrastversion aktiv im Artikelscope erklaert wird, bekommt sie ein eigenes kompaktes Kontrastbeispiel oder eine klar markierte Minimalvariante.
11. Wenn eine Strategie als bevorzugter Weg fuer produktive Faelle gilt, wird dafuer auch ein minimales ausfuehrbares Muster erzeugt.
12. Vorpruefungs-Queries werden pro System in natuerlicher Syntax und typischer Arbeitsweise formuliert, nicht nur als leicht angepasste Uebersetzung des fuehrenden Systems.
13. Pro System werden, wo relevant, idiomatische Schutzmechanismen und naheliegende Stolperstellen sichtbar gemacht.
14. Pro System wird mindestens ein natuerliches Sicherheits- oder Vorbereitungs-Muster erzeugt, das in der jeweiligen Datenbankkultur als robuste Form gelten kann.
15. Die Beispielsammlung soll das Thema als vier Datenbankkulturen zeigen, nicht als ein SQL-Server-Muster mit Syntaxvarianten.
16. SQL Server zeigt dabei eher T-SQL-nahe Vorpruefung und vorbereitete Arbeitsmengen, PostgreSQL eher idiomatische `UPDATE ... FROM`-nahe oder vorbereitende Varianten, Oracle eher schutzorientierte Alternativmuster und MySQL eher natuerliche Multi-Table-Update-Praxis.

## Ziel
Die Codebeispiele sollen nicht nur demonstrieren, wie etwas geschrieben wird, sondern auch, wo die Unterschiede und Risiken liegen.
