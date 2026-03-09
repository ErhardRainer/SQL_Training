# 02 - Episode YAML Validator

## Aufgabe
Pruefe das erzeugte Episode-YAML auf Vollstaendigkeit, Konsistenz und fachliche Tragfaehigkeit.

## Pruefpunkte
1. Fuehrendes System fachlich begruendet?
2. Versionsscope vollstaendig?
3. Quellenplanung ueber `sources_expected` und `sources.yaml` anschlussfaehig?
4. `pipeline_mode` korrekt gesetzt?
5. `skip_steps` konsistent mit dem gewaehlten Modus?
6. Pflichtkapitel vorhanden?
7. Keine kuenstliche Gleichverteilung?
8. Andere Systeme nur dort praesent, wo sie nicht redundant sind?
9. Deep Dives ausreichend geplant?
10. Risikoklassen sinnvoll und auf die kanonischen Klassen zurueckfuehrbar?
11. Vorpruefungen konkret?
12. Entscheidungsmodell vorhanden?
13. Crosslinks vorbereitet?
14. `render_rules` enthalten die noetigen Unterdrueckungsregeln fuer leere Bereiche und Pipeline-Sprache?
15. `presentation` ist vollstaendig und deckt Leserleitfaden-Position, Vergleichstabelle, Warnblock, Anti-Pattern-Block, Entscheidungsvisualisierung und Persona-Modus ab?
16. Minimale Beispiele pro behandeltem System und ein expliziter Fehlerfall sind fachlich mitgeplant?
17. Das Inhaltsverzeichnis ist vor inhaltsschweren Bloecken eingeplant, und erlaubte Vor-Toc-Bloecke sind kompakt definiert?
18. Eigenstaendige Zusatzabschnitte sind entweder fuer das Inhaltsverzeichnis vorgesehen oder bewusst in Hauptabschnitte integriert?
19. Persona-Einstieg ist sinnvoll platziert und nicht zwischen Metadatenbloecken geplant?
20. Ein konkretes Fehlersymptom oder eine kurze Ankergeschichte ist vorgesehen?
21. Historische Kontrastversionen erhalten sichtbare Snippets oder Minimalbeispiele?
22. Empfohlene Strategien sind mit minimalen Code-Skeletten hinterlegt?
23. Risikoklassen werden spaeter als aktives Navigationsinstrument wiederverwendet?
24. Die Vor-Toc-Zone ist kompakt gehalten und enthaelt keine schweren Vergleichs- oder Beispielbloecke?
25. Fruehe Beispiele mit Risikoklassen vor dem Klassifikationsabschnitt erhalten neutrale Titel oder einen Vorwaerts-Hinweis?
26. Strategie-Skelette enthalten operative Caveats wie Flag-Reset, Terminierungsbedingung oder Idempotenzhinweis?
27. Kernframeworks werden nicht in benachbarten Abschnitten doppelt formuliert?
28. Die Vorpruefungen sind fuer spaetere dialect-aware Ausformulierung vorbereitet und behandeln andere Systeme nicht nur als Uebersetzung des fuehrenden Systems?
29. Praxisbeobachtungen zu typischen Denkfehlern oder Teammustern sind vorbereitet, ohne kuenstlich autobiografisch zu wirken?
30. Kontrollierte fachliche Urteilssaetze sind moeglich, bleiben aber auf wenige, praezise Einsaetze begrenzt?
31. Sind pro Dialekt auch natuerliche Sicherheits- oder Vorbereitungs-Muster mitgeplant, nicht nur Precheck-Varianten?
32. Ist neben dem Entscheidungsdiagramm mindestens eine zweite merkfaehige Hauptvisualisierung vorgesehen?
33. Wird das Thema explizit als eine Problemklasse in mehreren Datenbankkulturen angelegt statt als Leitdialekt mit Uebersetzungen?
34. Ist ein vorhandenes `notes.md` in `author_notes` strukturiert uebernommen worden?
35. Haben `must_cover`- und `should_cover`-Notizen eine geplante Zielstelle im Artikel oder eine explizite Begruendung fuer Abweichungen?

## Korrekturregel
Nur minimal und zielgerichtet korrigieren. Nicht unnoetig umstrukturieren.

## Ausgabe
- validiertes YAML
- kurze Liste der vorgenommenen Korrekturen
- explizite Liste der auszufuehrenden und uebersprungenen Schritte
