# Horizontale Partitionierung: eine partitionierte Tabelle oder mehrere Tabellen?

Und fachlich sogar noch schärfer als das allgemeine Partitionierungs-Thema.

Die eigentliche Frage lautet dann nicht nur:

„Partitionierung: eine oder mehrere Partitionen?“

sondern besser:

„Horizontale Partitionierung: eine partitionierte Tabelle oder mehrere physisch getrennte Tabellen?“

## Warum das ein sehr guter Artikel wäre

Weil du damit zwei Dinge sauber gegeneinanderstellen kannst:

### 1. Eine logische Tabelle mit nativer Partitionierung

Das ist das Modell, das die großen Systeme offiziell unterstützen:

- **SQL Server:** eine partitionierte Tabelle, deren Daten horizontal in Partitionen aufgeteilt werden können.
- **PostgreSQL:** eine deklarativ partitionierte Tabelle, die in Partitionen unterteilt ist; die Root‑Tabelle ist dabei selbst leer und routet Zeilen in die passenden Partitionen.
- **Oracle:** Partitionierung zerlegt Tabellen oder Indizes in kleinere Stücke, die jeweils eigene Eigenschaften haben können.
- **MySQL:** Partitionierung wird ebenfalls als Aufteilung einer Tabelle in Partitionen modelliert.

### 2. Mehrere getrennte Tabellen

Das ist keine native Partitionierung im engeren Sinn, sondern eher:

- manuelle horizontale Aufteilung
- selbst gebaute Routing‑Logik
- oft anwendungs‑ oder ETL‑gesteuert
- manchmal Übergangslösung
- manchmal bewusstes Architekturmuster

Das ist genau die Art Gegensatz, die für deine Serie perfekt ist: gleiche Absicht, sehr unterschiedliche technische Konsequenzen.

## Die starke Hauptthese

Eine gute Leitthese wäre:

> Mehrere Tabellen sind nicht automatisch „Partitionierung von Hand“.  
> Native Partitionierung ist vor allem dann stark, wenn du eine logische Tabelle erhalten willst, aber Wartung, Pruning, Archivierung und Lebenszyklusmanagement auf Teilmengen brauchst.  
> Mehrere Tabellen sind eher dann sinnvoll, wenn du bewusst fachlich oder organisatorisch getrennte Datenräume willst — nicht bloß, weil eine Tabelle groß geworden ist.

## Warum das fachlich ergiebig ist

Mit diesem Thema kannst du sehr sauber unterscheiden zwischen:

- logischer Einheit
- physischer Verteilung
- Routing
- Partition Pruning / Elimination
- Wartung
- Archivierung
- Code-Komplexität
- Schema-Drift-Risiko
- Reporting‑/Union‑Aufwand

Gerade PostgreSQL und SQL Server machen dokumentiert klar, dass Partitionierung als eine Tabelle mit aufgeteilten Teilobjekten gedacht ist, nicht als Sammlung unabhängig modellierter Tabellen.

## Die spannende praktische Unterscheidung

Ich würde im Artikel diese Haupttrennlinie aufmachen:

### Eine partitionierte Tabelle

Sinnvoll, wenn:

- fachlich weiterhin eine Entität vorliegt,
- Queries überwiegend gegen das Gesamtobjekt formuliert werden,
- aber Wartung, Archivierung, Ladevorgänge oder Pruning auf Teilmengen profitieren sollen.

SQL Server, PostgreSQL, Oracle und MySQL dokumentieren Partitionierung genau in dieser Richtung: eine Tabelle, mehrere Partitionen.

### Mehrere Tabellen

Sinnvoll, wenn:

- die Trennung fachlich gewollt ist,
- verschiedene Lebenszyklen oder Besitzverhältnisse existieren,
- unterschiedliche DDL‑/Retention‑/Sicherheitsregeln gelten,
- oder du bewusst kein gemeinsames logisches Objekt willst.

Dann ist das aber eher:

- **Datenarchitektur**
- und weniger klassische native Partitionierung.

## Was du als Kernwarnung formulieren könntest

> Mehrere Tabellen sind oft kein Performance‑Konzept, sondern ein Modellierungsentscheid mit Folgekosten.  
> Wer eine Tabelle nur deshalb in viele Tabellen aufspaltet, weil sie groß geworden ist, verlagert das Problem oft aus der Storage‑/Wartungsebene in die Query‑, ETL‑ und Anwendungslogik.

Das wäre ein sehr starker Satz für den Artikel.

## Besonders gute Unterfragen

- Wann profitiert man von nativer Partitionierung, ohne die logische Einheit aufzugeben?
- Wann wird „mehrere Tabellen“ zu unnötiger Komplexität?
- Welche Rolle spielen Partition Pruning und Routing?
- Wann ist Archivierung mit Partitionen einfacher als mit separaten Tabellen?
- Wann sind mehrere Tabellen fachlich sauberer als eine partitionierte?
- Welche Folgen hat das für:
  - DDL
  - Indizes
  - Constraints
  - Reporting
  - ETL
  - Deployment?

## Welches System sollte führen?

Für dieses Thema würde ich wahrscheinlich **Oracle** oder **PostgreSQL** als Lead sehen.

### Oracle

Stark, wenn du es als reife Enterprise‑Partitionierungsdisziplin aufziehst.  
Oracle dokumentiert Partitionierung explizit als Zerlegung in kleinere verwaltbare Einheiten mit eigenen Eigenschaften und Maintenance‑Operationen auf Partitionsebene.

### PostgreSQL

Stark, wenn du den Artikel mehr auf die klare logische Idee einer partitionierten Tabelle und das Verhalten im Planner / Pruning ausrichten willst.  
PostgreSQL dokumentiert deklarative Partitionierung sehr explizit, inklusive Partition Pruning und sogar Row Movement bei Updates über Partitionsgrenzen.

### SQL Server

Wäre ebenfalls sehr gut, wenn du den Schwerpunkt stärker auf:

- Filegroups
- Verwaltung
- Archivierungsstrategien
- Sliding Window
- Betrieb und Wartung

legen willst. SQL Server beschreibt Partitionierung klar als horizontale Aufteilung einer Tabelle oder eines Index und verknüpft sie mit Partition Functions und Schemes.

## Mein Vorschlag für den Artikeltitel

Am stärksten fände ich:

**Horizontale Partitionierung: eine partitionierte Tabelle oder mehrere Tabellen?**

Alternativ:

*Eine Tabelle, viele Partitionen – oder viele Tabellen? Die eigentliche Architekturfrage*

## Mein Urteil

Ja, unbedingt aufnehmen.  
Das ist ein sehr gutes Thema, weil es nicht nur Technik erklärt, sondern eine echte Architekturentscheidung sichtbar macht.

Ich würde es sogar als separaten Artikel vom allgemeinen Partitionierungsartikel behandeln:

- **Partitionierung: Wann mehrere Partitionen wirklich helfen – und wann nicht**
- **Horizontale Partitionierung: eine partitionierte Tabelle oder mehrere Tabellen?**

Die beiden ergänzen sich perfekt:

- Artikel 1 = Wann überhaupt partitionieren
- Artikel 2 = Wie modellieren: eine Tabelle oder mehrere?

## Zusätzliche Themenpunkte

- Risikoklassen ähnlich wie beim allgemeinen Partitionierungsartikel (robust/conditionally_safe/risky/avoid) mit Fokus auf Kosten der manuellen Aufteilung
- Kapitelstruktur/Gliederung analog zum anderen Artikel (Dialog‑Einstieg, Leserleitfaden etc.)
- Demo‑Szenarien: einfache Partitionierung vs. separate Tabellen; Query‑Routing‑Code; Wartungsaufwand; Backup‑Restore Szenarien
- Archivierungs- und Löschmuster im manuellen Szenario
- Auswirkungen auf Schema‑Migrations‑Tools und ORM
- Beispiele für hybrides Modell (sowohl Partitionen als auch zusätzliche Tabellen)

