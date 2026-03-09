# 05 - Insight Extraction

## Aufgabe
Leite aus den erzeugten Codebeispielen strukturierte Erkenntnisse ab.

## Modusregel
Dieser Schritt entfaellt bei `pipeline_mode: article_only`.

## Ziel
Aus Beispielen werden belastbare Aussagen fuer den Artikel.

## Pflichtausgabe
`insights.yaml` auf Basis von `Templates/insights.template.yaml` mit:
- `metadata`
- `insights`
- `must_include`
- `must_not_claim`
- `open_uncertainties`
- `risk_class_support`
- `dialect_idiom_hints`
- `visualization_hints`
- `crosslink_hints`
- `quality_gates`

## Regeln
1. Belastbare Aussagen von unsicheren Aussagen trennen.
2. Jede wichtige Aussage nach Moeglichkeit mit konkreten Beispielpfaden belegen.
3. Aussagen, die nicht ausreichend gedeckt sind, abschwaechen oder als unsicher markieren.
4. Explizit festhalten, welche Behauptungen der Artikel nicht machen darf.
5. Ohne erzeugte Codebeispiele duerfen keine pseudo-empirischen Insights erfunden werden.
6. Festhalten, wenn ein System fuer dieselbe fachliche Vorpruefung eine andere natuerliche Ausdrucksform, Schutzstrategie oder Stolperstelle hat.
7. Pro System auch die natuerliche robuste oder vorbereitende Arbeitsweise verdichten, nicht nur den Precheck.
8. Mindestens einen belastbaren Visual-Hinweis fuer eine merkfaehige Hauptvisualisierung ableiten, wenn die Evidenz dafuer traegt.
