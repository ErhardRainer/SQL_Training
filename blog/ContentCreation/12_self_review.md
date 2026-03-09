# 12 - Self Review

## Aufgabe
Fuehre einen vollstaendigen internen Review des Artikels durch.

## Rolle im Gesamtprozess
Dies ist der letzte Schritt des Master-Workflows.

## Pruefpunkte
1. Fuehrendes System klar erkennbar?
2. Andere Systeme nur mit echtem Mehrwert?
3. Redundanz reduziert?
4. Problemklasse, Standard, Syntax, Semantik und Interna sauber getrennt?
5. Tiefenlogik des Referenzformats erreicht?
6. Schlussdialog knapp und passend?
7. Querverlinkung vorhanden und sinnvoll?
8. YAML-Header enthaelt die korrekte Workflow-Phase?
9. Methodischer Status klar und ehrlich?
10. Versionsblock kurz genug, Fuehrungsbegruendung ausgelagert?
11. Syntax-Oberflaeche vorhanden?
12. ANSI-Abschnitt kurz und sauber getrennt?
13. Vorpruefungen enthalten konkrete Pruefpatterns?
14. Leere optionale Bereiche unterdrueckt?
15. Micro-Beispiele vorhanden und evidenzsauber?
16. Gibt es pro behandeltem System mindestens ein minimales Beispiel?
17. Wird der wichtigste Fehlerfall explizit gezeigt?
18. Gibt es mindestens eine scanbare Vergleichstabelle?
19. Gibt es eine visuelle Darstellung des Entscheidungsmodells?
20. Gibt es mindestens einen klaren Warnblock fuer den wichtigsten Risikofall?
21. Gibt es einen kurzen Block `Anti-Pattern vs. robuste Form`?
22. Ist keine interne Pipeline-Terminologie im sichtbaren Lesertext?
23. Ist die Persona-Nutzung konsequent statt halbherzig?
24. Stehen Leserleitfaden oder TL;DR frueh genug im Artikel?
25. Steht das Inhaltsverzeichnis vor dem ersten inhaltsschweren Block?
26. Sind groessere Syntax-, Vergleichs-, Link- oder Beispielbloecke erst nach dem Inhaltsverzeichnis platziert?
27. Sind alle eigenstaendigen Abschnitte nach dem Inhaltsverzeichnis darin verlinkt oder bewusst integriert?
28. Steht der Persona-Einstieg an einer sinnvollen Uebergangsstelle und nicht zwischen Metadatenbloecken?
29. Gibt es mindestens ein konkretes Fehlersymptom oder eine kurze Ankergeschichte?
30. Bekommen historische Kontrastversionen sichtbare Snippets oder Minimalbeispiele?
31. Haben empfohlene Strategien auch minimale Code-Skelette?
32. Werden die Risikoklassen spaeter aktiv als Navigationsinstrument benutzt?
33. Ist die Vor-Toc-Zone kompakt und auf Navigations-, Scope- und Support-Bloecke begrenzt?
34. Erhalten fruehe Klassifikationslabels vor ihrem Definitionsabschnitt einen Vorwaerts-Hinweis oder neutrale Titel?
35. Enthalten Batch- oder Staging-Skelette operative Caveats wie Flag-Reset, Idempotenz oder Terminierungsbedingung?
36. Werden Kernframeworks nicht in direkt benachbarten Abschnitten unnoetig doppelt formuliert?
37. Sind Vorpruefungs-Queries und Schutzmuster pro Dialekt natuerlich formuliert statt nur vom fuehrenden System abgeleitet?
38. Werden typische Schutzmechanismen und Stolperstellen je System sichtbar, wo sie fachlich relevant sind?
39. Sind auch die sicheren oder vorbereitenden Arbeitsmuster pro Dialekt idiomatisch und natuerlich statt nur uebersetzt?
40. Gibt es neben dem Entscheidungsdiagramm genau eine weitere merkfaehige Hauptvisualisierung mit fachlichem Eigenwert?
41. Wirkt der Artikel wie dieselbe Problemklasse in vier Datenbankkulturen statt wie eine Leitform mit Dialektanhaengen?
42. Sind Praxisbeobachtungen fachlich nuetzlich und nicht kuenstlich autobiografisch?
43. Gibt es hoechstens ein bis zwei fachliche Urteilssaetze in Ich-Form, und bleiben sie praezise statt emotional?
44. Sind alle `must_cover`-Notizen aus `author_notes` im Artikel fachlich passend abgearbeitet oder explizit als begruendete Abweichung markiert?
45. Wurden `notes.md`-Inhalte integriert statt als sichtbarer Roh-Notizblock oder interner Produktionshinweis ausgegeben?

## Abschlussregel
Nach erfolgreichem Self-Review muss der Artikelheader mindestens diese Werte tragen:
- `workflow_phase: 12_self_review`
- `article_status: reviewed`

## Ausgabe
- ueberarbeiteter Draft
- Liste der wichtigsten Korrekturen
