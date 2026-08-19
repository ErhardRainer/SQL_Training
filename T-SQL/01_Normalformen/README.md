# Normalformen in relationalen Datenbanken

Normalformen sind Regeln für den Entwurf relationaler Tabellen. Sie helfen dabei,
Daten **eindeutig, konsistent und ohne unnötige Wiederholungen** zu speichern.
Das Ziel ist nicht, möglichst viele Tabellen zu erzeugen, sondern eine Struktur zu
finden, in der Änderungen sicher und verständlich bleiben.

Diese Anleitung erklärt die Idee von Grund auf, führt ein Beispiel schrittweise
durch die wichtigsten Normalformen und zeigt, wann eine bewusste Denormalisierung
sinnvoll sein kann.

## Lernziele

Nach diesem Kapitel kannst du:

- Redundanzen und typische Änderungsanomalien erkennen,
- Primär-, Fremd- und fachliche Schlüssel unterscheiden,
- eine unstrukturierte Tabelle bis zur dritten Normalform zerlegen,
- die Normalformen 1NF, 2NF, 3NF, BCNF sowie 4NF und 5NF einordnen,
- entscheiden, wann ein normalisiertes Modell und wann eine gezielte
  Denormalisierung geeignet ist.

## Warum gibt es Normalformen?

In einer kleinen Excel-Liste wirkt es bequem, alle Informationen in einer Zeile
zu speichern. Wächst die Datenmenge, entstehen jedoch Wiederholungen: Der Name
eines Kunden, seine Adresse und der Name eines Produkts stehen dann in vielen
Datensätzen. Wird eine dieser Angaben geändert, muss sie überall korrekt
aktualisiert werden.

Dadurch entstehen drei klassische Anomalien:

| Anomalie | Beispiel |
|---|---|
| **Einfügeanomalie** | Ein neues Produkt kann nicht gespeichert werden, solange noch keine Bestellung dafür existiert. |
| **Änderungsanomalie** | Ändert ein Kunde seine E-Mail-Adresse, bleibt möglicherweise eine von vielen Bestellzeilen mit der alten Adresse zurück. |
| **Löschanomalie** | Wird die letzte Bestellung eines Kunden gelöscht, gehen unbeabsichtigt auch seine Stammdaten verloren. |

Normalisierung trennt Sachverhalte so, dass jede Tatsache möglichst an genau
einer Stelle gepflegt wird. In der Praxis verbessert das Datenqualität,
Wartbarkeit und die Durchsetzbarkeit fachlicher Regeln.

## Zentrale Begriffe

- **Relation**: eine Tabelle im relationalen Modell.
- **Tupel**: eine Tabellenzeile (Datensatz).
- **Attribut**: eine Tabellenspalte.
- **Primärschlüssel (PK)**: identifiziert eine Zeile eindeutig, etwa
  `KundeID`.
- **Fremdschlüssel (FK)**: verweist auf einen Schlüssel in einer anderen
  Tabelle und bildet eine Beziehung ab.
- **Kandidatenschlüssel**: jede minimale Attributkombination, die eine Zeile
  eindeutig identifizieren kann. Einer davon wird meist Primärschlüssel.
- **Funktionale Abhängigkeit**: Aus einem Wert lässt sich ein anderer eindeutig
  bestimmen, notiert als `A → B`. Beispielsweise gilt normalerweise
  `KundeID → Kundenname, EMail`.

Wichtig: Normalformen sind Eigenschaften eines **Schemas zusammen mit seinen
fachlichen Abhängigkeiten**. Eine Datenbank kann die Fachregel „PLZ bestimmt
Ort“ nicht zuverlässig erraten; sie muss im Modell korrekt berücksichtigt werden.

## Durchgängiges Beispiel: Bestellungen

Folgende Tabelle speichert zunächst alles in einer einzigen Bestellposition:

```text
Bestellposition(
  BestellNr, Bestelldatum,
  KundeID, Kundenname, KundenEMail,
  ProduktNr, Produktname, Listenpreis,
  Menge
)
```

Der Schlüssel einer Position ist hier `(BestellNr, ProduktNr)`. Für das Beispiel
gelten diese Abhängigkeiten:

```text
BestellNr             → Bestelldatum, KundeID
KundeID               → Kundenname, KundenEMail
ProduktNr             → Produktname, Listenpreis
(BestellNr, ProduktNr) → Menge
```

Das Schema enthält offensichtliche Wiederholungen: Kunden- und Bestelldaten
kommen je Produktposition erneut vor; Produktname und Listenpreis erscheinen in
jeder Bestellung dieses Produkts. Genau solche Abhängigkeiten führen durch die
Normalformen.

## Die Normalformen im Überblick

| Normalform | Kernfrage | Typische Maßnahme |
|---|---|---|
| **1NF** | Ist jeder Wert atomar und jede Zeile eindeutig? | Wiederholungsgruppen und Listen in einer Spalte auflösen. |
| **2NF** | Hängt jedes Nichtschlüsselattribut vom gesamten zusammengesetzten Schlüssel ab? | Teilabhängigkeiten in eigene Tabellen verschieben. |
| **3NF** | Hängen Nichtschlüsselattribute nur vom Schlüssel, nicht voneinander ab? | Transitive Abhängigkeiten auslagern. |
| **BCNF** | Ist jede Determinante ein Kandidatenschlüssel? | Sonderfälle mit mehreren überlappenden Schlüsseln auflösen. |
| **4NF** | Gibt es unabhängige Mehrwertabhängigkeiten? | Unabhängige Mehrfachbeziehungen getrennt speichern. |
| **5NF** | Entstehen durch weitere Zerlegung keine falschen Kombinationen? | Komplexe Join-Abhängigkeiten getrennt modellieren. |
| **6NF** | Ist jede nichttriviale Join-Abhängigkeit aufgelöst? | Vor allem bei zeitlich veränderlichen Daten/Spezialmodellen relevant. |

Für die meisten OLTP-Anwendungen ist **3NF** ein sehr gutes Ziel. BCNF ist
strenger; 4NF bis 6NF sind Spezialfälle und keine Pflichtübung für jedes Schema.

## Erste Normalform (1NF)

Eine Tabelle erfüllt die erste Normalform, wenn:

1. jede Zelle genau einen Wert enthält (keine Listen wie `"Rot, Blau, Grün"`),
2. es keine wiederholenden Spaltengruppen wie `Produkt1`, `Produkt2`, `Produkt3`
   gibt und
3. jede Zeile durch einen Schlüssel identifizierbar ist.

Ein häufiger Verstoß wäre diese Spalte in einer Bestellung:

```text
Produktnummern = 'P10, P24, P31'
```

Stattdessen erhält jede Position eine eigene Zeile. Unser Ausgangsschema kann
bereits 1NF erfüllen, wenn jede Produktposition separat gespeichert wird und
`(BestellNr, ProduktNr)` tatsächlich eindeutig ist.

**Praxisregel:** Eine Spalte enthält einen Wert desselben Typs und derselben
Bedeutung. Eine durch Komma getrennte Liste ist fast immer ein Zeichen für eine
eigene Tabelle mit mehreren Zeilen.

## Zweite Normalform (2NF)

Die zweite Normalform setzt 1NF voraus. Sie ist besonders bei
**zusammengesetzten Schlüsseln** wichtig: Jedes Nichtschlüsselattribut muss vom
gesamten Schlüssel abhängen, nicht nur von einem Teil davon.

In `Bestellposition` ist `(BestellNr, ProduktNr)` der Schlüssel. Doch:

- `Bestelldatum` und `KundeID` hängen nur von `BestellNr` ab.
- `Produktname` und `Listenpreis` hängen nur von `ProduktNr` ab.
- Nur `Menge` hängt von der Kombination aus Bestellung und Produkt ab.

Die Tabelle wird deshalb zerlegt:

```text
Bestellung(BestellNr PK, Bestelldatum, KundeID, Kundenname, KundenEMail)
Produkt(ProduktNr PK, Produktname, Listenpreis)
Bestellposition(BestellNr PK/FK, ProduktNr PK/FK, Menge)
```

Jetzt wird eine Produktbeschreibung nur einmal gespeichert. Die
Bestellpositionsmenge bleibt genau dort, wo sie hingehört: bei der Beziehung
zwischen Bestellung und Produkt.

## Dritte Normalform (3NF)

Die dritte Normalform setzt 2NF voraus. Kein Nichtschlüsselattribut darf von
einem anderen Nichtschlüsselattribut abhängen. Anders formuliert: Jedes
Nichtschlüsselattribut soll direkt vom Schlüssel abhängen, „vom Schlüssel, dem
ganzen Schlüssel und nichts als dem Schlüssel“.

In der Tabelle `Bestellung` gilt:

```text
BestellNr → KundeID
KundeID → Kundenname, KundenEMail
```

`Kundenname` und `KundenEMail` hängen somit **indirekt** über `KundeID` von der
Bestellnummer ab. Das ist eine transitive Abhängigkeit. Die 3NF-Struktur lautet:

```text
Kunde(KundeID PK, Kundenname, KundenEMail)
Bestellung(BestellNr PK, Bestelldatum, KundeID FK)
Produkt(ProduktNr PK, Produktname, Listenpreis)
Bestellposition(BestellNr PK/FK, ProduktNr PK/FK, Menge)
```

Damit hat jede Tabelle eine klare fachliche Aufgabe: Kunden sind Stammdaten,
Bestellungen sind Kopfdaten und Bestellpositionen sind die Zuordnung von
Bestellungen zu Produkten.

> Hinweis: Ein Preis in einer Bestellposition ist oft absichtlich sinnvoll.
> `Listenpreis` beschreibt den aktuellen Produktstamm, während `Einzelpreis`
> in der Position den zum Bestellzeitpunkt vereinbarten Preis festhält. Das ist
> keine fehlerhafte Redundanz, sondern fachliche Historie.

## Boyce-Codd-Normalform (BCNF)

BCNF verschärft die 3NF: Für jede nichttriviale funktionale Abhängigkeit
`X → Y` muss `X` ein Superschlüssel sein. BCNF wird vor allem relevant, wenn es
mehrere mögliche Schlüssel und spezielle Geschäftsregeln gibt.

Beispiel: In `Raumbelegung(Dozent, Raum, Zeitfenster)` gilt möglicherweise
`Raum, Zeitfenster → Dozent`, weil ein Raum zu einem Zeitpunkt nur von einer
Person belegt sein darf. Ist `(Dozent, Zeitfenster)` zugleich ein Schlüssel,
bestimmt aber `(Raum, Zeitfenster)` auch einen Wert, liegt ein BCNF-Thema vor.

BCNF-Zerlegungen können in seltenen Fällen eine Abhängigkeit nicht mehr direkt
in einer einzelnen Tabelle erzwingbar machen. Daher wird in der Praxis zwischen
strenger Redundanzfreiheit und gut prüfbaren Geschäftsregeln abgewogen.

## Vierte Normalform (4NF)

4NF behandelt **Mehrwertabhängigkeiten**: Zwei unabhängige Mengen von Werten
dürfen sich nicht gegenseitig künstlich vervielfachen.

Angenommen, ein Dozent kann mehrere Sprachen sprechen und mehrere Fachgebiete
haben. Die Tabelle `Dozent(DozentID, Sprache, Fachgebiet)` erzeugt für zwei
Sprachen und drei Fachgebiete sechs Kombinationen, obwohl nur fünf Fakten
existieren. Die passende Zerlegung ist:

```text
DozentSprache(DozentID FK, Sprache)
DozentFachgebiet(DozentID FK, Fachgebiet)
```

## Fünfte und sechste Normalform (5NF, 6NF)

Die **5NF** (Project-Join-Normalform) behandelt Fälle, in denen eine Tabelle
nur durch die Kombination mehrerer Beziehungen korrekt rekonstruiert wird.
Ein klassisches, aber seltenes Beispiel ist die Beziehung zwischen Lieferant,
Teil und Projekt. Eine Zerlegung ist nur dann richtig, wenn sie keine
unzulässigen Kombinationen erzeugt.

Die **6NF** zerlegt weiter in irreduzible Fakten. Sie ist insbesondere bei
temporalen Daten interessant, bei denen sich einzelne Eigenschaften zu
unterschiedlichen Zeitpunkten ändern. Für typische Anwendungsdatenbanken ist
sie selten erforderlich und führt häufig zu sehr vielen Tabellen.

## Umsetzung in T-SQL

Die Normalform beschreibt das Modell; `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`
und `CHECK` helfen, dessen Regeln in SQL Server durchzusetzen.

```sql
CREATE TABLE dbo.Kunde
(
    KundeID     int           NOT NULL PRIMARY KEY,
    Kundenname  nvarchar(200) NOT NULL,
    KundenEMail nvarchar(320) NOT NULL UNIQUE
);

CREATE TABLE dbo.Produkt
(
    ProduktNr   int            NOT NULL PRIMARY KEY,
    Produktname nvarchar(200)  NOT NULL,
    Listenpreis decimal(10, 2) NOT NULL CHECK (Listenpreis >= 0)
);

CREATE TABLE dbo.Bestellung
(
    BestellNr   int  NOT NULL PRIMARY KEY,
    Bestelldatum date NOT NULL,
    KundeID     int  NOT NULL,
    CONSTRAINT FK_Bestellung_Kunde
        FOREIGN KEY (KundeID) REFERENCES dbo.Kunde (KundeID)
);

CREATE TABLE dbo.Bestellposition
(
    BestellNr int NOT NULL,
    ProduktNr int NOT NULL,
    Menge     int NOT NULL CHECK (Menge > 0),
    Einzelpreis decimal(10, 2) NOT NULL CHECK (Einzelpreis >= 0),
    CONSTRAINT PK_Bestellposition PRIMARY KEY (BestellNr, ProduktNr),
    CONSTRAINT FK_Bestellposition_Bestellung
        FOREIGN KEY (BestellNr) REFERENCES dbo.Bestellung (BestellNr),
    CONSTRAINT FK_Bestellposition_Produkt
        FOREIGN KEY (ProduktNr) REFERENCES dbo.Produkt (ProduktNr)
);
```

Bei realen Bestellungen kann dasselbe Produkt mehrfach vorkommen (z. B. bei
getrennten Rabatten). Dann ist eine eigene `PositionNr` oft der bessere Teil
des Primärschlüssels: `PRIMARY KEY (BestellNr, PositionNr)`.

## Vorgehen beim Normalisieren

1. **Fachliche Fakten sammeln:** Was soll dauerhaft gespeichert werden? Welche
   Aussage beschreibt jede Spalte?
2. **Schlüssel bestimmen:** Was identifiziert eine Instanz fachlich eindeutig?
   Technische IDs ergänzen, aber fachliche Eindeutigkeit gegebenenfalls mit
   `UNIQUE` absichern.
3. **Abhängigkeiten notieren:** Welche Attribute werden durch welchen Schlüssel
   bestimmt?
4. **Wiederholungen auflösen:** Listen in einer Spalte und wiederholende
   Spaltengruppen in Zeilen bzw. eigene Tabellen überführen (1NF).
5. **Teil- und transitive Abhängigkeiten entfernen:** Tabellen entlang ihrer
   fachlichen Verantwortung schneiden (2NF, 3NF).
6. **Beziehungen absichern:** PKs, FKs und passende Constraints definieren.
7. **Mit echten Fällen testen:** Einfügen, Ändern und Löschen dürfen keine
   widersprüchlichen oder verlorenen Fakten verursachen.

## Normalisierung ist kein Selbstzweck

Ein gut normalisiertes OLTP-Modell ist meist die richtige Ausgangsbasis. Für
Auswertungen, Data Warehouses oder sehr leselastige Spezialabfragen kann eine
kontrollierte **Denormalisierung** sinnvoll sein, etwa eine voraggregierte
Reporting-Tabelle. Diese Kopien brauchen dann eine klare Aktualisierungsstrategie
und eine dokumentierte Quelle der Wahrheit.

Nicht jedes wiederholte Feld ist ein Fehler: historische Werte, bewusst
materialisierte Berechnungen und Auditdaten können fachlich notwendig sein.
Die entscheidende Frage lautet: *Ist dieselbe fachliche Tatsache mehrfach
unabhängig pflegbar?* Wenn ja, spricht das meist für Normalisierung.

## Kontrollfragen

1. Kann ein Kunde ohne Bestellung angelegt werden?
2. Muss eine E-Mail-Adresse an mehr als einer Stelle aktualisiert werden?
3. Was passiert mit Kunden- und Produktdaten, wenn die letzte Bestellposition
   gelöscht wird?
4. Hängt jede Nichtschlüsselspalte von dem gesamten Schlüssel ab?
5. Beschreibt jede Tabelle genau einen fachlichen Gegenstand oder eine klare
   Beziehung?

## Weiterführende Quellen

- [Microsoft: Description of the database normalization basics](https://learn.microsoft.com/en-us/office/troubleshoot/access/database-normalization-description)
- [Microsoft Learn: Primary and foreign key constraints (SQL Server)](https://learn.microsoft.com/en-us/sql/relational-databases/tables/primary-and-foreign-key-constraints)
- [Microsoft Learn: UNIQUE constraints and check constraints](https://learn.microsoft.com/en-us/sql/relational-databases/tables/unique-constraints-and-check-constraints)
- [PostgreSQL Documentation: Constraints](https://www.postgresql.org/docs/current/ddl-constraints.html)
- [MySQL Reference Manual: PRIMARY KEY and UNIQUE indexes](https://dev.mysql.com/doc/refman/8.4/en/constraint-primary-key.html)
- [IBM Informix: Normalized database design](https://www.ibm.com/docs/en/informix-servers/14.10.0?topic=design-normalized-database)
- [Oracle Database SQL Language Reference: Constraints](https://docs.oracle.com/en/database/oracle/oracle-database/23/sqlrf/constraint.html)
- [Wikipedia: Database normalization](https://en.wikipedia.org/wiki/Database_normalization) – guter Überblick mit Verweisen auf die Fachliteratur
- [Wikipedia: Boyce-Codd normal form](https://en.wikipedia.org/wiki/Boyce%E2%80%93Codd_normal_form) – Vertiefung zu BCNF
- [Wikipedia: Fourth normal form](https://en.wikipedia.org/wiki/Fourth_normal_form) – Mehrwertabhängigkeiten und 4NF
- [Wikipedia: Fifth normal form](https://en.wikipedia.org/wiki/Fifth_normal_form) – Join-Abhängigkeiten und 5NF
- [C. J. Date: *Database Design and Relational Theory*](https://www.oreilly.com/library/view/database-design-and/9781449328017/) – anspruchsvolle, fundierte Vertiefung

## Empfehlenswerte YouTube-Videos

Die meisten hochwertigen Erklärvideos zu diesem Thema sind auf Englisch. Die
unten stehende Reihenfolge führt vom kompakten Gesamtüberblick über 1NF bis 3NF
zu BCNF. Für Einsteiger sind besonders die ersten beiden Videos geeignet.

1. [Learn Database Normalization – 1NF, 2NF, 3NF, 4NF, 5NF (Decomplexify)](https://www.youtube.com/watch?v=GFQaEYEc8_8) – anschaulicher Gesamtüberblick mit vielen Beispielen; behandelt auch 4NF und 5NF.
2. [Database Normalization Explained: 1NF, 2NF & 3NF With SQL Examples (Engineering Digest)](https://www.youtube.com/watch?v=suKHq3ZLPmU) – durchgängiges Buchhandlungsbeispiel mit SQL-Umsetzung.
3. [Database Normalization Explained: 1NF to 3NF with SQL Example (TBK CareerPoint)](https://www.youtube.com/watch?v=1urhaY8yh6k) – kompaktes Bestellbeispiel inklusive `CREATE TABLE`, Daten und Abfragen.
4. [Database Design 36 – 1NF (Caleb Curry)](https://www.youtube.com/watch?v=JjwEhK4QxRo) – fokussierte Einführung in atomare Werte und Wiederholungsgruppen.
5. [Database Design 37 – 2NF (Caleb Curry)](https://www.youtube.com/watch?v=WSKuxoAN35g) – Erklärung von zusammengesetzten Schlüsseln und Teilabhängigkeiten.
6. [First Normal Form (1NF) – Database Normalization (Studytonight)](https://www.youtube.com/watch?v=mUtAPbb1ECM) – alternative, kurze Erklärung der Voraussetzungen der 1NF.
7. [Second Normal Form (2NF) – Database Normalization (Studytonight)](https://www.youtube.com/watch?v=R7UblSu4744) – zeigt, wie Teilabhängigkeiten erkannt und entfernt werden.
8. [Third Normal Form (3NF) – Database Normalization (Studytonight)](https://www.youtube.com/watch?v=aAx_JoEDXQA) – Vertiefung zu transitiven Abhängigkeiten.
9. [Boyce-Codd Normal Form (BCNF) – Database Normalization (Studytonight)](https://www.youtube.com/watch?v=NNjUhvvwOrk) – gut geeignet als nächster Schritt nach 3NF.
10. [Easy Explanation of Normalization: 1NF, 2NF, 3NF (Relational Database Design for Beginners)](https://www.youtube.com/watch?v=Ipr9ws2bPEU) – einsteigerfreundliche Wiederholung der drei wichtigsten Normalformen.

## Passende Materialien in diesem Ordner

- [Normalformen.ipynb](Normalformen.ipynb) enthält das begleitende Notebook.
- [Merkblatt Normalformen.xlsx](Merkblatt%20Normalformen.xlsx) fasst die Regeln
  kompakt zusammen.
- [Übungen.xlsx](%C3%9Cbungen.xlsx) bietet Aufgaben zum selbstständigen Üben.
