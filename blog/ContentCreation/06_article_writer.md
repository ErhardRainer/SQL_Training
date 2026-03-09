# 06 - Article Writer

## Aufgabe
Schreibe den vollstaendigen Blog-Artikel auf Basis von Serienkanon, Episode-YAML, `sources.yaml`, `author_notes` aus dem Episode-YAML und, falls vorhanden, `insights.yaml`.

## Ausgabedatei
`README.md` des Artikels

## Pflichtbestandteile
- YAML-Header
- Titel
- Leserleitfaden oder TL;DR gesamt frueh im Artikel
- Versions- und Geltungsbereich
- Methodischer Status
- Inhaltsverzeichnis
- kurzer Abschnitt `Warum das fuehrende System in dieser Episode fuehrt`
- Dialog-Einstieg
- TL;DR gesamt
- TL;DR pro relevantem System
- kurze Syntax-Oberflaeche je relevantem System
- mindestens eine Vergleichstabelle
- Inhaltsverzeichnis
- kurzer ANSI-Abschnitt `Was der Standard hier leistet - und was nicht`
- Hauptteil
- Deep Dives
- Vorpruefungen
- mindestens ein Warnblock
- mindestens ein Block `Anti-Pattern vs. robuste Form`
- Entscheidungsmodell
- visuelle Darstellung des Entscheidungsmodells
- eine eigene merkfaehige Hauptvisualisierung neben dem Entscheidungsmodell
- Fazit
- Kurzform fuer die Praxis
- Schlussdialog

## Pflichtfelder im YAML-Header
- `title`
- `slug`
- `as_of_date`
- `workflow_phase`
- `pipeline_mode`
- `article_status`
- `leading_system`

## Regeln fuer den YAML-Header
- `workflow_phase` ist beim ersten Artikeldraft `06_article_writer`.
- `pipeline_mode` wird aus dem Episode-YAML uebernommen.
- `article_status` ist hier `draft`.
- Jeder spaetere Schritt, der den Artikel veraendert, muss `workflow_phase` aktualisieren.

## Tiefenregeln
Der Artikel muss beantworten:
- Was ist das Problem wirklich?
- Warum ist die naive Sicht zu kurz?
- Welche internen Klassen gibt es?
- Wovon haengen Risiko, Kosten und Komplexitaet ab?
- Was passiert intern?
- Welche Varianten sind robust, bedingt sicher, riskant oder zu vermeiden?
- Welche Rolle spielen Indizes, Constraints, Logging, Locks und Kardinalitaet?
- Welche Strategie ist praktisch sinnvoll?

## Modusregeln
- In `full` muss der Artikel evidenzbasiert auf `insights.yaml` und den generierten Beispielen aufbauen.
- In `article_only` stuetzt sich der Artikel auf Serienkanon, Episode-YAML und `sources.yaml`.
- In `article_only` duerfen keine scheinbar codevalidierten Aussagen suggeriert werden.

## Zusaetzliche Redaktionsanforderungen
- Direkt unter dem Versionsblock steht ein eigener Block `Methodischer Status`.
- Die Begruendung fuer das fuehrende System steht in einem eigenen kurzen Abschnitt und nicht im Versionsblock.
- Frueh im Artikel steht eine kurze `Syntax-Oberflaeche` der relevanten Systeme.
- Der Artikel enthaelt einen kurzen ANSI-Abschnitt `Was der Standard hier leistet - und was nicht`.
- Der Abschnitt `Vor jeder produktiven Umsetzung` zeigt konkrete Pruefpatterns, nicht nur Fragen.
- Der Abschnitt `Vor jeder produktiven Umsetzung` zeigt die fachlichen Pruefideen spaeter dialect-aware: pro System in passender Syntax, typischer Arbeitsweise und mit naheliegenden Schutzmechanismen.
- Der Artikel zeigt pro relevantem Dialekt nicht nur Vorpruefungen, sondern auch natuerliche Sicherheits- oder Vorbereitungs-Muster in der jeweiligen Datenbankkultur.
- Konkret soll SQL Server eher T-SQL-nahe Vorpruefung und vorbereitete Arbeitsmengen zeigen, PostgreSQL idiomatische Varianten, Oracle schutzorientierte Alternativmuster und MySQL Multi-Table-Update-nahe Praxis.
- Die Darstellung kann dabei aus einem eigenen Query-Block pro System oder aus einem Hauptbeispiel mit kurzen Dialekt-Varianten bestehen.
- Der Artikel enthaelt mindestens drei kleine Micro-Beispiele: `robust`, `risky`, `prepared_source`.
- Leere optionale Bereiche werden nicht gerendert.
- In `article_only` sind kleine dokumentationsbasierte Syntax-Snippets und Micro-Beispiele erlaubt, aber keine vollstaendigen Demo-Skriptstrecken.
- Inhaltliche Punkte aus `notes.md` werden an der fachlich passenden Stelle des Artikels eingearbeitet und nicht als eigener Roh-Notizblock abgeladen.
- `must_cover`-Notizen aus `author_notes` muessen sichtbar abgearbeitet werden; `should_cover`-Notizen sollen nach Moeglichkeit einfliessen oder spaeter im Review begruendet werden.
- Wenn eine historische Kontrastversion aktiv erklaert wird, bekommt sie ein eigenes sichtbares Snippet oder Minimalbeispiel.
- Wenn eine Strategie als bessere oder bevorzugte Form empfohlen wird, zeigt der Artikel auch ein minimales Code-Skelett dazu.
- Eingefuehrte Risikoklassen werden spaeter in Strategie- und Entscheidungsabschnitten explizit wiederverwendet.
- Kernframeworks wie Problemklasse / Produktsyntax / Produktsemantik werden nicht in direkt benachbarten Abschnitten nahezu wortgleich wiederholt.
- Gezielte Praxisbeobachtungen zu typischen Denkfehlern, Teammustern oder operativen Kippstellen werden an passenden Stellen eingestreut.
- Ein bis zwei fachliche Urteilssaetze in Ich-Form sind erlaubt, wenn sie praezise, ruhig und begrenzt bleiben.
- Der Artikel soll dieselbe Problemklasse als vier Datenbankkulturen lesbar machen, nicht als ein Fuehrungssystem mit Uebersetzungen.

## Leserorientierung und Darstellungsregeln
- Fuer technische Artikel gibt es mindestens ein minimales, lauffaehiges Beispiel pro behandeltem System.
- Der wichtigste Fehlerfall wird explizit gezeigt, nicht nur beschrieben.
- Artikel mit Produktionsrisiken enthalten mindestens ein konkretes Fehlersymptom oder eine kurze Ankergeschichte.
- Multi-System-Unterschiede werden mindestens einmal in einer scanbaren Vergleichstabelle dargestellt.
- Das Entscheidungsmodell bekommt mindestens eine visuelle Darstellung, zum Beispiel als Flowchart, Mermaid-Diagramm oder ASCII-Baum.
- Zusaetzlich gibt es genau eine merkfaehige Hauptvisualisierung fuer den Kernkonflikt des Themas, zum Beispiel `Rohquelle -> vorbereitete Quelle -> Schreiboperation` oder `Leselogik vs. Schreiblogik`.
- Kritische Risiken werden mindestens einmal als hervorgehobener Warnblock dargestellt.
- Es gibt mindestens einen kurzen Block `Anti-Pattern vs. robuste Form`.
- Vor dem Inhaltsverzeichnis stehen nur kurze Navigations- und Scope-Bloecke; groessere Syntax-, Vergleichs-, Link- oder Beispielbloecke kommen danach.
- Vor dem Inhaltsverzeichnis duerfen als kompakte Metadaten-Zone auch Fuehrungsbegruendung, Trainingslinks und ein kurzer Dialekt-Hinweis stehen.
- Jeder eigenstaendige Abschnitt nach dem Inhaltsverzeichnis wird darin verlinkt oder bewusst als Unterabschnitt integriert.
- Interne Pipeline-Sprache wie `article_only`, `Serienkanon` oder `in diesem Lauf` gehoert nicht in den sichtbaren Lesertext.
- Personas werden pro Episode bewusst entschieden: entweder nur Intro/Outro oder kurze Einwuerfe an Uebergaengen. Halbherzige Zwischenformen sind zu vermeiden.
- Persona-Dialoge stehen direkt nach dem Titel oder direkt vor dem ersten Hauptabschnitt, nicht zwischen Metadatenbloecken.
- Wenn Beispiele oder Vergleichsbloecke vor der formalen Einfuehrung der Risikoklassen erscheinen, nutzen sie neutrale Titel oder einen klaren Vorwaerts-Hinweis auf den spaeteren Klassifikationsabschnitt.
- Batch- oder Staging-Skelette nennen in Kommentar oder Begleittext mindestens eine operative Annahme wie Flag-Reset, Idempotenz oder Terminierungsbedingung.
- Dialektvarianten werden nicht als blosse Uebersetzung eines SQL-Server-Musters gerendert; sie sollen natuerliche Ausdrucksformen des jeweiligen Systems zeigen.
- Dialektvarianten sollen auch die natuerliche sichere Arbeitsweise des jeweiligen Systems zeigen, nicht nur dessen Oberflaeche.
- Praxisbeobachtungen sollen nach gelebter Erfahrung klingen, aber keine erfundene Autobiografie behaupten.
- Fachliche Urteilssaetze sind sparsam zu verwenden und sollen Kontrollierbarkeit, Robustheit oder Pflichtschritte schaerfen, nicht Emotion simulieren.
- Sichtbare Verweise auf `notes.md`, `Notizen des Autors` oder interne Abarbeitungslogik gehoeren nicht in den Lesertext.

## Stil
- praezises Deutsch
- technisch ruhig
- narrativ sparsam
- keine Marketing-Sprache
