# Index Disable + Rebuild vs. Drop + Create: Wann welche Strategie sinnvoll ist

# Einleitungsgeschichte
Sam - ich wollte ein Update auf einer 40Millionen Zeilen Tabelle machen wobei 13 Millionen Zeilen aktualisiert werden sollen. NAch ein paar Stunden wurde abgebrochen und analytisch analysiert. Selbst 10.000 Zeilen haben 1 Minute gedauert. Nach einer Analyse des Execution-Plans hat sich herausgestellt, dass das Update selbst kaum Zeit braucht, aber die Pflege der Indizes. 


## Warum das stark ist

* Erfüllt fast alles, was du für die Reihe brauchst.
* Klingt zunächst wie eine kleine DBA-Entscheidung, ist aber...
  * eine Frage von Metadaten, Wiederherstellbarkeit, Skriptbarkeit,
    Abhängigkeiten, Constraint‑Verhalten,
    Online/Offline‑Fähigkeit, Bulk‑Load‑Strategie und Betriebsrisiko.
* Genug Tiefgang für echte „was passiert intern?“‑Kapitel.
* Kernspannung:
  * **Disable + Rebuild** wirkt pragmatisch und näher an der bestehenden Definition.
  * **Drop + Create** wirkt radikaler, aber manchmal kontrollierbarer oder sauberer.

## Die fachliche Leitfrage

Ein guter Artikel sollte nicht heißen:

> „Was ist besser: Disable oder Drop?“

sondern eher:

> **„Index temporär entfernen: Definition behalten oder bewusst neu aufbauen?“**

oder noch schärfer:

> **„Index Disable + Rebuild vs. Drop + Create:
> Wann welche Strategie sinnvoll ist?“**

Das ist die eigentliche Denkfrage.

## Warum das ein gutes SQL‑Server‑Lead‑Thema ist

Für SQL Server ist das besonders ergiebig, weil die offizielle Doku die Unterschiede
recht klar hergibt:

* Ein deaktivierter Index bleibt als Definition im Katalog erhalten, die zugrunde
  liegenden Indexdaten sind aber nicht verfügbar.  Er kann später per
  `ALTER INDEX … REBUILD` oder
  `CREATE INDEX … WITH DROP_EXISTING` wieder aktiviert werden.
* Ein deaktivierter *clustered* Index blockiert den Benutzerzugriff auf die
  zugrunde liegenden Tabellendaten; abhängige nonclustered Indexes und bestimmte
  View‑Indizes sind ebenfalls betroffen.
* Microsoft empfiehlt für Reorganisieren/Rebuilden `ALTER INDEX`.  Insbesondere
  bei clustered Indexes sei das effizienter als Drop/Neuaufbau, weil es
  Optimierungen enthält, die Overhead bei nonclustered Indexes vermeiden.
* `CREATE INDEX … WITH DROP_EXISTING` eignet sich, wenn du die Definition ändern
  willst (Spalten, Sortierreihenfolge, Optionen, Filegroup/Partition Scheme).

Zusätzlich liefern unterschiedliche RDBMS zusätzliche Blickwinkel:

* In anderen Systemen (Oracle, PostgreSQL) gibt es keine direkte Entsprechung zum
  DISABLE; hier ist Drop/neu Create oft der einzige Weg.
* Vergleichende Hinweise machen den Artikel noch universeller.

## Die eigentliche Hauptthese des Artikels

* Disable + Rebuild und Drop + Create lösen **nicht exakt dasselbe Problem**.
* **Disable + Rebuild** ist stark, wenn du dieselbe Indexdefinition behalten und
  später kontrolliert wieder aktivieren willst (z. B. temporäre Wartung).
* **Drop + Create** lohnt sich, wenn du Definition, Eigenschaften oder
  Platzierung des Indexes bewusst neu festlegen willst – oder das gesamte Objekt
  ohnehin neu aufgebaut werden soll.
* Weitere Thesen:
  * Die Wahl sollte auch von Skript‑/Versionierungs‑Workflow abhängen.
  * Rollback‑Strategien unterscheiden sich deutlich.

## Besonders gute Unterfragen für den Artikel

1. Was bleibt bei `DISABLE` erhalten, was nicht?
2. Wann ist `REBUILD` fachlich wirklich „Reaktivierung derselben Definition“?
3. Wann ist `DROP + CREATE` kontrollierbarer, weil ich sowieso neu designen will?
4. Welche Unterschiede gibt es bei:
   * *clustered* vs. *nonclustered*,
   * Constraints,
   * Views,
   * Online/Offline‑Fähigkeit,
   * Bulk‑Load‑Szenarien,
   * Skriptwartung?
5. Wann ist Disable nur scheinbar bequemer und birgt operative Risiken?
6. Wann ist Drop zwar aufwändiger, aber ehrlicher und sauberer?
7. Welche Auswirkungen haben Dateigruppen/Partitionierung?
8. Wie verhält es sich mit Replikation/Log‑Shipping?
9. Welche Monitoring‑/Auditing‑Pfadinformationen gehen verloren?

## Besonders wichtig: clustered vs. nonclustered

Das sollte im Artikel eine zentrale praktische Hauptunterscheidung sein.

* Nonclustered Indexes lassen sich deaktivieren und später explizit rebuilden; wenn
  der zugehörige clustered Index deaktiviert ist, bleiben sie ebenfalls deaktiviert,
  bis der clustered Index wiederhergestellt oder entfernt wurde.
* Ein deaktivierter clustered Index macht die Tabellendaten für normalen Benutzerzugriff unzugänglich.
* Ein deaktivierter clustered Index kann nur **offline** per
  `ALTER INDEX REBUILD` oder `CREATE INDEX WITH DROP_EXISTING` wieder aufgebaut
  werden.
* Operative Folgen:
  * Blockierte Abfragen,
  * zusätzlicher Aufwand für berechtigte Benutzer,
  * Auswirkungen auf Replikation und Backups.

## Risikoklassen

* **robust**
  * temporäres Deaktivieren eines nonclustered Index.
  * Definition bleibt unverändert.
  * später gezielt rebuilden.
  * Bulk-/Wartungsszenario mit klarer Rückkehrlogik.
* **conditionally_safe**
  * Drop + Create mit sauber versioniertem Erzeugungsskript.
  * Bewusst neue Definition oder Optionen.
  * Gutes Deployment‑/Rollback‑Modell.
* **risky**
  * Clustered Index deaktivieren, ohne Zugriffssperre und Folgewirkungen zu beachten.
  * Disable nutzen, obwohl Definition eigentlich geändert werden müsste.
  * Drop + Create ohne vollständige Recreate‑Skripte und Optionensicherung.
* **avoid**
  * Deaktivieren oder Droppen „auf Verdacht“.
  * Constraint‑gebundene Indizes unsauber behandeln.
  * Online/Offline‑Auswirkungen ignorieren.
  * Bulk‑Optimierung ohne vollständiges Wiederherstellungsmodell.

## Kapitelstruktur (Entwurf)

1. Dialog‑Einstieg
2. Leserleitfaden
3. Versions‑ und Geltungsbereich
4. Methodischer Status
5. TL;DR gesamt und pro System
6. Was DISABLE und DROP fachlich überhaupt bedeuten
7. Warum beide Strategien nicht dieselbe Frage beantworten
8. Was intern erhalten bleibt – und was verloren geht
9. Die wichtigste praktische Unterscheidung: clustered vs. nonclustered
10. Constraints, Views und abhängige Objekte
11. Online/Offline und Rebuild‑/Create‑Pfade
12. Bulk Load, Wartungsfenster und operative Motive
13. Wann Drop + Create besser ist
14. Wann Disable + Rebuild besser ist
15. Vorprüfung vor produktiver Anwendung
16. Entscheidungsmodell
17. Fazit
18. Kurzform für die Praxis
19. Schlussdialog

## Demo‑/Testpotenzial

Gut geeignet für Container‑basierte Tests:

* nonclustered index disable + rebuild
* clustered index disable und Folgen
* drop + create mit identischer Definition
* drop + create mit geänderter Definition
* constraint‑gebundene Indizes
* Verhalten bei View‑Abhängigkeiten
* Online/Offline‑Einschränkungen
* Bulk‑Load‑Szenario
* Replikations‑/Failover‑Szenarien
* Versions‑/Rollback‑Tests

## Mein Urteil

Ja, unbedingt aufnehmen.  
Für die Serie ist das ein sehr starkes SQL‑Server‑zentriertes Thema mit genug
technischer Tiefe und sehr klarem Praxisnutzen.


Meine Einordnung wäre:

Lead-System: SQL Server

Reihung: ungefähr Top 20

Stärke für Demo-/Containerphase: hoch

Ein guter finaler Titel wäre:

Index Disable + Rebuild vs. Drop + Create: Wann welche Strategie sinnvoll ist