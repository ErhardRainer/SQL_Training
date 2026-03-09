# 03 - Demo Spec Builder

## Aufgabe
Erzeuge eine systemneutrale Demo-Spezifikation fuer die Episode.

## Modusregel
Dieser Schritt entfaellt bei `pipeline_mode: article_only`.

## Vorlage
Nutze `Templates/demo_spec.template.yaml`.

## Ziel
Eine gemeinsame fachliche Demo-Welt, aus der danach dialektspezifische SQL-Beispiele erzeugt werden.

## Pflichtbestandteile
- `dataset`
- `global_rules`
- `logical_model`
- `scenarios`
- `precheck_intents`
- `visual_storylines`
- `physical_assets`
- `per_system_mapping`
- `required_examples`
- `expected_artifacts`
- `quality_gates`

## Regeln
1. Die Demo-Welt ist systemneutral.
2. Sie beschreibt Fachlogik, nicht Produktsyntax.
3. Das Datenset muss die Kernaussagen der Episode tragen.
4. Sichere und riskante Szenarien muessen enthalten sein.
5. Randfaelle wie Duplikate, Nullwerte, Kollisionen oder Kardinalitaetsprobleme muessen modelliert werden, wenn sie fuer die Episode relevant sind.
6. Die kanonischen Szenarioklassen sind `robust`, `conditionally_safe`, `risky` und `avoid`.
7. Verfeinerungen duerfen in `notes` beschrieben werden, aber `expected_behavior` bleibt auf die kanonischen Klassen abgebildet.
8. Die Demo-Spezifikation bleibt systemneutral, muss aber Precheck-Intents definieren, die spaeter pro System idiomatisch ausformuliert werden koennen.
9. Precheck-Intents beschreiben Problem, Signal und fachlichen Zweck, nicht schon eine SQL-Server-nahe Standardquery.
10. Pro Precheck-Intent muss erkennbar sein, welche natuerliche Schutz- oder Vorbereitungslogik spaeter je Dialekt sichtbar werden soll.
11. Die Demo-Spezifikation definiert mindestens eine `visual_storyline` fuer eine merkfaehige Hauptvisualisierung, zum Beispiel `Rohquelle -> vorbereitete Quelle -> Schreiboperation` oder `Leselogik vs. Schreiblogik`.

## Optional
- CSV-Dateien als gemeinsame Quelle
- Snapshot-Hinweise
