# 00 - Series Canon

## Ziel
Die Serie erklaert SQL-Themen als fachlich tiefe, praezise Langform-Artikel mit kontrollierten narrativen Elementen.

## Figuren
- Sam = Microsoft SQL Server
- Pete = PostgreSQL
- Ora = Oracle
- My = MySQL
- Mutter ANSI-95 = SQL-Standard

## Grundregeln
1. Fachliche Praezision vor Dramaturgie.
2. Jede Episode hat ein fuehrendes System.
3. Das fuehrende System ist Hauptprotagonist, aber nicht automatisch Sieger jeder Unterfrage.
4. Keine kuenstliche Gleichverteilung.
5. Keine erfundene Syntax, Semantik, Interna oder Benchmarks.
6. Immer sauber trennen zwischen:
   - Problemklasse
   - SQL-Standard
   - Produktsyntax
   - Produktsemantik
   - interner Ausfuehrungslogik
   - operativer Praxis
7. Humor ist erlaubt, Albernheit nicht.
8. Narrative Elemente bleiben kurz.
9. Alle vier Produktsysteme werden fachlich mitgedacht; ihre Darstellungstiefe richtet sich nach der Abweichung zum fuehrenden System.
10. Leere optionale Abschnitte werden unterdrueckt statt entschuldigt.
11. Die Publikationsfassung verwendet normales UTF-8-Deutsch.
12. Interne Pipeline-Sprache gehoert nicht in den sichtbaren Lesertext.
13. Personas werden pro Episode bewusst entschieden: entweder durchgehend kurz eingesetzt oder konsequent auf Intro und Outro reduziert.
14. Das Inhaltsverzeichnis steht vor dem ersten inhaltsschweren Block.
15. Dieselbe Erklaerungsstruktur wird nicht in unmittelbar benachbarten Abschnitten doppelt formuliert.
16. Der Text darf gelebte Praxisnaehe zeigen, aber keine erfundene Autobiografie.

## Workflow-Metadaten im Artikelheader
Jede Artikeldatei `README.md` muss ein YAML-Front-Matter enthalten.

Pflichtfelder im YAML-Header:
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

Regeln:
- `workflow_phase` zeigt den zuletzt abgeschlossenen Workflow-Schritt, der den Artikel geaendert hat.
- `pipeline_mode` ist `full` oder `article_only`.
- `article_status` ist grob, `workflow_phase` ist fein granuliert.
- Der sichtbare Block `Versions- und Geltungsbereich` bleibt direkt unter dem Titel Pflicht.

## Pflichtstruktur eines Artikels
- YAML-Header
- Titel
- kurzer Leserleitfaden oder kurzes TL;DR frueh im Artikel
- sichtbarer Block `Versions- und Geltungsbereich` direkt unter dem Titel
- `Methodischer Status`
- Inhaltsverzeichnis
- Einstieg mit kurzem Dialog oder kurzer Persona-Uebergang
- kurzer Abschnitt `Warum das fuehrende System in dieser Episode fuehrt`
- TL;DR gesamt
- TL;DR pro relevantem System
- kurze Syntax-Oberflaeche je relevantem System
- mindestens eine Vergleichstabelle fuer zentrale Systemunterschiede
- kurzer ANSI-Abschnitt `Was der Standard hier leistet - und was nicht`
- mindestens ein konkretes Fehlersymptom oder eine kurze Ankergeschichte
- Hauptteil mit Tiefenlogik
- mindestens ein hervorgehobener Warnblock
- mindestens ein Block `Anti-Pattern vs. robuste Form`
- mindestens eine visuelle Darstellung des Entscheidungsmodells
- Fazit
- Kurzform fuer die Praxis
- kurzer Schlussdialog

## Versions- und Geltungsbereich
Jeder Artikel muss direkt unter dem Titel sichtbar enthalten:
- Standdatum
- fuehrendes System
- behandelte Versionen je relevantem System
- Hinweis, dass andere Releases abweichen koennen

## Mutter ANSI-95
Nur sparsam und pointiert einsetzen. Funktion: Standard von Implementierung trennen.

## Zusatzregeln fuer Kopf und Evidenz
- Der Versionsblock bleibt kurz: Standdatum, fuehrendes System, behandelte Versionen, kurzer Abweichungshinweis.
- Die Begruendung fuer das fuehrende System steht in einem eigenen Kurzabschnitt.
- Direkt unter dem Versionsblock steht ein eigener Block `Methodischer Status`.
- Interne Evidenz-Level sind `docs_based`, `inference_based`, `demo_based`, `executed_test_based`, `benchmark_based`.
- Technische Artikel zeigen pro behandeltem System mindestens ein minimales Beispiel; der wichtigste Fehlerfall wird explizit sichtbar gemacht.
- Multi-System-Unterschiede werden scanbar aufbereitet, bevorzugt als Tabelle.
- Kritische Produktionsrisiken werden mindestens einmal als Warnhinweis hervorgehoben.
- Vor dem Inhaltsverzeichnis steht eine kompakte Metadaten-Zone. Zulaessig sind nur kurze Navigations-, Scope- und Support-Bloecke wie Leserleitfaden, Versionsbereich, Methodischer Status, Fuehrungsbegruendung, Trainingslinks und Dialekt-Hinweise.
- Groessere Syntax-, Vergleichs-, Link- oder Beispielbloecke kommen erst nach dem Inhaltsverzeichnis oder in einen bewusst kompakten, kollabierbaren Support-Bereich.
- Jeder eigenstaendige Abschnitt nach dem Inhaltsverzeichnis muss darin verlinkt sein; alternativ wird er in einen anderen Abschnitt integriert.
- Persona-Dialoge stehen direkt nach dem Titel oder direkt vor dem ersten Hauptabschnitt, nicht zwischen Metadatenbloecken.
- Artikel mit Produktionsrisiken brauchen mindestens ein konkretes Fehlersymptom oder eine kurze Ankergeschichte.
- Wenn eine historische Kontrastversion aktiv erklaert wird, bekommt sie auch ein sichtbares Snippet oder Minimalbeispiel.
- Wer eine Strategie als besseren oder bevorzugten Weg empfiehlt, zeigt auch ein minimales Code-Skelett dazu.
- Eingefuehrte Risikoklassen muessen spaeter aktiv als Navigationsinstrument wiederverwendet werden.
- Wenn Beispiele oder Vergleichsbloecke vor der formalen Einfuehrung der Risikoklassen stehen, nutzen sie neutrale Titel oder einen klaren Vorwaerts-Hinweis auf den spaeteren Klassifikationsabschnitt.
- Batch- oder Staging-Skelette nennen in Kommentar oder Begleittext mindestens eine operative Annahme wie Flag-Reset, Idempotenz oder Terminierungsbedingung.
- Wenn ein ANSI- oder Standard-Abschnitt bereits eine Kernstruktur wie Problemklasse / Produktsyntax / Produktsemantik einfuehrt, wird diese Struktur im naechsten Absatz nicht noch einmal nahezu wortgleich wiederholt.
- Vorpruefungs-Queries, Schutzmuster und sichere Arbeitsweisen werden spaeter dialect-aware ausformuliert: pro System in natuerlicher Syntax, typischer Arbeitsweise, naheliegender Absicherung und mit systemtypischen Stolperstellen.
- Das meint konkret: SQL Server eher T-SQL-nahe Vorpruefung und vorbereitete Arbeitsmengen, PostgreSQL eher idiomatische `UPDATE ... FROM`-nahe oder vorbereitende Varianten, Oracle eher schutzorientierte Alternativmuster und versionsscharfe Ein-Zeilen-Logik, MySQL eher Multi-Table-Update-nahe Praxis.
- Andere Systeme werden nicht als blosse Uebersetzungen des fuehrenden Systems dargestellt, sondern als eigene Ausdrucksformen derselben Problemklasse.
- Der Artikel soll dieselbe Problemklasse als vier Datenbankkulturen lesbar machen, nicht als eine Leitform mit drei Nachuebersetzungen.
- Praxisbeobachtungen wie typische Denkfehler, haeufige Teamfehler oder operative Kippstellen sollen gezielt eingestreut werden, wenn sie fachlich tragen.
- Ein bis zwei kontrollierte fachliche Urteilssaetze in Ich-Form sind erlaubt, wenn sie praezise, begrenzt und nicht emotional sind.
- Neben dem Entscheidungsdiagramm bekommt der Artikel mindestens eine eigene merkfaehige Hauptvisualisierung, etwa `Rohquelle -> vorbereitete Quelle -> Schreiboperation`, `Leselogik vs. Schreiblogik` oder den Lebenszyklus eines joined update.
- Keine erfundenen Anekdoten, keine kuenstlich autobiografische Stimme und keine Behauptung eigener Einsaetze, wenn diese nicht belegt sind.
