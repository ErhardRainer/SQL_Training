# 03 - Notebook Blueprint Validator

## Aufgabe
Pruefe jedes Blueprint-YAML gegen Kapiteldatei, Asset-Scan und Notebook-Canon.

## Ziel
Vor der Zellplanung sollen strukturelle Luecken, unklare Lab-Annahmen und inkonsistente Dateinamen entfernt werden.

## Validierungspflicht
Jedes Blueprint muss diese Fragen sauber beantworten:
- Stimmt der Notebook-Dateiname exakt mit der Kapiteldatei ueberein?
- Ist Titel und Kurzbeschreibung aus dem Kapitel korrekt uebernommen?
- Ist die Notebook-Klasse plausibel?
- Ist die Setup-Strategie realistisch fuer das Thema?
- Sind Voraussetzungen, Berechtigungen und Risiken sichtbar?
- Gibt es mindestens 3 gute Uebungen?
- Gibt es genug Fallstricke fuer das Thema?
- Ist ein Diagnostik-/Optimizer- oder Internals-Block eingeplant, falls fachlich sinnvoll?
- Sind Querverweise vorgesehen oder bewusst leer dokumentiert?

## Muss-Korrekturen
- fehlende `lab_profile`-Details
- fehlende Session-Modellierung bei Konkurrenz-/Blocking-Themen
- fehlende Cleanup- oder Reset-Strategie
- fehlende Sicherheits- oder Berechtigungshinweise bei Admin-Themen
- Blueprint behauptet Demo-Faehigkeit, obwohl nur `prereq_only` realistisch ist

## Regeln fuer Admin-Themen
- Keine kuenstlichen Demo-Setups erzwingen, wenn das Thema real eine Instanzrolle, SQL Agent, CDC, Replikation oder Backup-Historie benoetigt.
- Stattdessen muessen Voraussetzungen, Beobachtungsqueries und sichere Lab-Hinweise ins Blueprint.

## Regeln fuer Refresh-Laeufe
- Wenn ein Ziel-Notebook bereits existiert, darf das Blueprint dessen brauchbare Substanz uebernehmen.
- Es darf aber nicht unhinterfragt alte Fehler, veraltete Beispiele oder abweichende Dateinamen festschreiben.

## Ergebnis
Das Ergebnis ist ein korrigiertes, freigegebenes Blueprint mit Status `validated`.
