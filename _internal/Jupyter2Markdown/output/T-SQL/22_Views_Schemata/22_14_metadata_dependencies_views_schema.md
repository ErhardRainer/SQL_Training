# 22_14_metadata_dependencies_views_schema

**Quelle:** `T-SQL\22_Views_Schemata\22_14_metadata_dependencies_views_schema.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 16  
**SQL-Zellen:** 4  

---

# 🧩 Dependencies in Microsoft SQL Server

Dieses Notebook erklärt ausführlich:
- Was bedeutet **„abhängig von“ (Depends On)**?
- Was bedeutet **„abhängig für“ (Required By)**?
- Wie SQL Server Abhängigkeiten speichert und analysiert
- DB-übergreifende Dependencies: *werden sie erkannt?*
- Dynamisches SQL: *was wird erkannt – was nicht?*
- Wo liegen die technischen Limitationen?
- Best Practices für Data Warehouses, SSIS, Stored Procedures
- Übungen und Beispielabfragen



**<u>Inhaltsverzeichnis</u>**

- 1 | Grundlagen: Arten von Dependencies
- 2 | Systemtabellen für Dependency Analyse
- 3 | Depends on
- 4 | Required by
- 5 | Werden db-übergreifende Dependencies erkannt?
- 6 | Dynamisches SQL - werden Dependencies erkannt?
- 7 | Limitierung der Dependency-Erkennung
- 8 | Best Practice


# 1️⃣ Grundlagen: Arten von Dependencies in SQL Server

SQL Server unterscheidet zwei Richtungen bei Abhängigkeiten:

### ✔️ **1. "Abhängig von" (Depends On)**
Bedeutet: Ein Objekt **benötigt ein anderes Objekt**, um zu funktionieren.

Beispiele:
- Eine View benötigt Tabellen
- Eine Stored Procedure benötigt Views und Tabellen
- Ein Trigger benötigt die Tabelle, an der er hängt

### ✔️ **2. "Abhängig für" (Used By / Required By)**
Ein Objekt wird von anderen Objekten **verwendet**.

Beispiele:
- Eine Tabelle wird von Views, SPs oder Funktionen referenziert
- Eine View wird von einer SSRS-Query verwendet

**SQL Server speichert beides, aber nicht immer vollständig.**


# 2️⃣ Systemtabellen für Dependency-Analyse

SQL Server nutzt folgende Views und Tabellen:

| View | Beschreibung |
|------|--------------|
| `sys.objects` | Jedes Objekt in der DB |
| `sys.sql_expression_dependencies` | Parst SQL-Code und erkennt Referenzen |
| `sys.dm_sql_referenced_entities` | Live-Analyse „abhängig von“ |
| `sys.dm_sql_referencing_entities` | Live-Analyse „abhängig für“ |

**Wichtig:** Diese Tabellen basieren auf dem SQL-Parser – nicht auf einer echten Laufzeitauswertung.


# 3️⃣ Depends On / Abhängig von

Wenn man sagt:

> _Objekt A hängt ab von Objekt B_,  
> dann heißt das:
> 
> **Objekt A kann ohne Objekt B nicht funktionieren.**

Typische Beispiele:

- Eine **View** hängt von Tabellen oder anderen Views ab
    
- Eine **Stored Procedure** hängt von Views, Tabellen oder Funktionen ab
    
- Eine **Funktion** hängt von Tabellen oder Konfigurationsviews ab
    

**„Depends on“ beschreibt also alle Objekte, die A intern aufruft oder referenziert.**

* * *

## 🎯 **Wie SQL Server „Depends On“ technisch ermittelt**

SQL Server verwendet dafür im Wesentlichen zwei Mechanismen:

* * *

### **1️⃣ Während der Objekterstellung: SQL-Code wird statisch geparst**

Wenn du eine View oder Prozedur erstellst, z. B.:

```
CREATE VIEW dbo.vwCustomer AS
SELECT c.CustomerName, o.OrderDate
FROM dbo.Customer c
JOIN dbo.Orders o ON c.CustomerID = o.CustomerID;

```

Dann passiert Folgendes:

#### ✔ SQL Server parst den Code, ohne ihn auszuführen

Dabei versucht er zu erkennen:

- Welche Tabellen werden angesprochen?
    
- Welche Views oder Funktionen werden genutzt?
    
- Welche Spalten werden referenziert?
    

#### ✔ Diese Referenzen werden in Metadaten gespeichert

Insbesondere in:

- `sys.sql_expression_dependencies`
    
- `sys.dm_sql_referenced_entities` (beim Auslesen)
    

Damit entsteht eine Liste:

| Objekt | Depends On |
| --- | --- |
| vwCustomer | dbo.Customer |
| vwCustomer | dbo.Orders |

Das ist der Kern.

* * *

### **2️⃣ Nachfrage über DMV: `sys.dm_sql_referenced_entities`**

Wenn du später wissen willst:

> „Wovon hängt Objekt X ab?“

Dann fragst du:

```
SELECT *
FROM sys.dm_sql_referenced_entities('dbo.vwCustomer', 'OBJECT');

```

Diese DMV:

### ✔ liest den SQL-Code erneut

### ✔ parst ihn „on demand“

### ✔ prüft, ob die referenzierten Objekte existieren

### ✔ gibt alle Dependencies zurück

Dabei kann sie Fehler werfen, z. B.:

```
Invalid column name ...

```

Denn der Parser versucht, alles **live** aufzulösen.

* * *

## ⚠️ **Wichtige Einschränkungen**

SQL Server findet Dependencies **nur**, wenn:

- der Name im Code **statisch** steht
    
- das Objekt in derselben Datenbank liegt
    
- das Objekt beim Parsing **existiert**
    
- der Code syntaktisch gültig ist
    

SQL Server _findet keine_ Dependencies bei:

❌ dynamischem SQL  
❌ Cross-Database-Referenzen  
❌ Temp-Tabellen  
❌ nicht existierenden Objekten  
❌ ungültigen Spalten  
❌ CTEs  
❌ Variablentabellen

* * *

## 🧠 **Wie SQL Server intern entscheidet: Schritt für Schritt**

Hier die interne Logik in Kurzform:

1. **SQL-Code wird tokenisiert**  
    → Schlüsselwörter, Objektbezeichner, Aliase etc. werden extrahiert.
    
2. **Der Parser baut einen Referenz-Baum**  
    → Tabellen, Views, Funktionen werden erkannt.
    
3. **Objektauflösung (Binding)**  
    → Der Parser schaut in `sys.objects`, um das referenzierte Objekt zu finden.
    
4. **Validierung**  
    → Wenn Tabelle oder Spalte nicht existiert → Fehler / Warnung.
    
5. **Speichern der Referenz**  
    → In `sys.sql_expression_dependencies`.
    
6. **Nutzung in DMVs**  
    → `dm_sql_referenced_entities` kombiniert statische Abhängigkeiten + Live-Parsen.
    

* * *

## 🖼 **Mermaid-Diagramm zur Visualisierung**

#### **„Depends On“ / Outbound Dependencies**

```
flowchart LR

    A[Objekt A<br>(View/SP/Funktion)] --> B[Objekt B<br>(Tabelle/View)]
    A --> C[Objekt C<br>(Funktion)]
    A --> D[Objekt D<br>(View)]
    
    subgraph Erklärung
    direction TB
    E[Objekt A kann ohne B,C,D nicht ausgeführt werden]
    end

```

* * *

#### **Parser-Perspektive (technisch präziser)**

```
sequenceDiagram
    participant Dev as Entwickler
    participant SQL as SQL Parser
    participant Meta as Metadaten-System

    Dev->>SQL: CREATE VIEW dbo.vw AS SELECT * FROM dbo.Customer;
    SQL->>SQL: Tokenize & Parse Code
    SQL->>Meta: Abhängigkeit erkannt: vw → Customer
    SQL->>Dev: View gespeichert

```

* * *

#### **Dependency-Auflösung über DMVs**

```
sequenceDiagram
    participant User as Benutzer
    participant DMV as sys.dm_sql_referenced_entities
    participant Meta as Metadaten + Parser

    User->>DMV: Abfrage: Dependencies für View X
    DMV->>Meta: Hole Metadaten
    DMV->>Meta: Parser führt Live-Prüfung durch
    Meta->>DMV: Ergebnis / Fehler / Warnung
    DMV->>User: Liste aller 'Depends On' Objekte

```

* * *

## ✨ **Kurzfassung für Schulungsfolien**

> **„Depends On“ bedeutet: Das Objekt benötigt andere Objekte, um ausgeführt werden zu können.  
> SQL Server erkennt diese Abhängigkeiten durch statisches Parsen des SQL-Codes und speichert sie in Metadaten.  
> Mit `sys.dm_sql_referenced_entities` können diese Abhängigkeiten abgefragt werden.**


```sql
-- Dependencies einer View anzeigen
SELECT 
    referenced_entity_name AS ReferencedObject,
    referenced_class_desc AS Type
FROM sys.dm_sql_referenced_entities ('dbo.MyView', 'OBJECT');
```

Ergebnis: Welche Tabellen, Views, Funktionen werden verwendet?


```sql
USE BI_STAGE
GO 
;WITH AllObjects AS (
    SELECT 
          o.object_id,
          QUOTENAME(s.name) + '.' + QUOTENAME(o.name) AS FullObjectName
    FROM sys.objects o
    JOIN sys.schemas s ON o.schema_id = s.schema_id
    WHERE o.type IN ('V','U','P','FN','IF','TF')  -- Views, Tables, Procs, Functions
)
SELECT 
      s.name AS [Schema],
      o.name AS [Table],
      d.referenced_entity_name AS [DependentOnObject],
      d.referenced_class_desc  AS [DependentOnType],
      ao.FullObjectName        AS ReferencingObject
FROM AllObjects ao
CROSS APPLY sys.dm_sql_referenced_entities(ao.FullObjectName, 'OBJECT') d
LEFT JOIN sys.objects o 
       ON o.name = d.referenced_entity_name
LEFT JOIN sys.schemas s 
       ON s.schema_id = o.schema_id
ORDER BY ao.FullObjectName, s.name, o.name;
```

# 4️⃣ Required By / Abhängig für

Wenn man sagt:

> _Objekt A wird benötigt von Objekt B_,  
> bedeutet das:

**Objekt B verwendet Objekt A.**

* * *

Beispiel:

- Eine View nutzt eine Tabelle  
    → die Tabelle ist _„required by“_ die View
    
- Eine Stored Procedure nutzt eine Funktion  
    → die Funktion ist _„required by“_ die SP
    
- Ein Report nutzt eine View  
    → die View ist _„required by“_ den Report
    

**„Required By“ zeigt immer INBOUND-Dependencies an.**

* * *

## 🎯 **Wie SQL Server „Required By“ ermittelt**

Das ist technisch anders als bei „Depends On“.

Wichtig:

* * *

### **1️⃣ SQL Server speichert „Referencing“ Abhängigkeiten nur als Metadaten**

Im Unterschied zu „Depends On“ (Outbound), bei dem SQL Server aktiv parst, gilt hier:

> **SQL Server speichert keine vollständige Liste der Objekte, die auf ein Objekt zugreifen.**

Warum?

- SQL Server müsste sonst ständig prüfen, welche Objekte auf ein anderes Objekt zeigen
    
- das wäre extrem teuer und unskalierbar
    
- daher wird nur gespeichert, was beim Erstellen eines Objekts erkannt wurde
    

Beispiel:

```
CREATE VIEW dbo.vwCustomerOrders AS
SELECT *
FROM dbo.Customer c
JOIN dbo.Orders o ON c.CustomerID = o.CustomerID;

```

SQL Server erkennt beim Erstellen der **View**:

- View → Customer (Depends On)
    
- View → Orders (Depends On)
    

Er speichert NOTHING auf Seite der Tabellen.  
dh. bei `Customer` steht NICHT:

- required by: vwCustomerOrders
    

Er berechnet es erst _on demand_.

* * *

### **2️⃣ Nachfrage über DMV: `sys.dm_sql_referencing_entities`**

Um herauszufinden:

> „Welche Objekte verwenden dieses Objekt?“

fragt man:

```
SELECT *
FROM sys.dm_sql_referencing_entities('dbo.Customer', 'OBJECT');

```

Diese DMV:

#### ✔ reagiert _passiv_

Sie liest aus:

- `sys.sql_expression_dependencies`
    
- `sys.objects`
    
- `sys.schemas`
    

#### ✔ baut daraus die Liste aller Objekte, die Customer referenzieren

#### ✔ wirft KEINE Fehler

Warum?

- Es wird kein SQL-Code geparst
    
- Es wird nichts kompiliert
    
- Es wird nur Metadaten gelesen
    

Das bedeutet:

❌ invalid column name → wird ignoriert  
❌ kaputte Views → erscheinen trotzdem  
❌ dynamisches SQL → bleibt unsichtbar  
❌ Cross-DB → wird nicht aufgelöst

* * *

## 🧠 **Wie SQL Server intern entscheidet: Schritt für Schritt**

1. Du fragst:  
    _„Wer referenziert Objekt X?“_
    
2. SQL Server durchsucht **alle gespeicherten Dependencies** in:
    
    - `sys.sql_expression_dependencies`
        
3. Dort sind alle Outbound-Dependencies gespeichert  
    (also „A hängt ab von B“)
    
4. SQL Server kehrt die Beziehung um  
    und liefert:
    
    - B wird referenziert von A
        

* * *

## 💡 Beispiel

Wenn diese View existiert:

```
CREATE VIEW dbo.vwA AS SELECT * FROM dbo.Customer;

```

Dann:

`sys.dm_sql_referenced_entities('dbo.vwA')` → zeigt **Customer**

`sys.dm_sql_referencing_entities('dbo.Customer')` → zeigt **vwA**

* * *

## 🖼 **Mermaid-Grafik 1 – Konzept: Inbound Dependencies**

```
flowchart LR

    B[Objekt B<br>View/SP] --> A[Objekt A<br>Tabelle]

    subgraph Erklärung
    direction TB
    T[„Required By“ zeigt alle Objekte,<br>die Objekt A verwenden]
    end

```

Interpretation:

- **A** = Customer
    
- **B** = vwCustomer
    

→ Customer ist _required by_ vwCustomer

* * *

## 🖼 **Mermaid-Grafik 2 – Technischer Ablauf der DMV**

```
sequenceDiagram
    participant User as Benutzer
    participant DMV as sys.dm_sql_referencing_entities
    participant Meta as Metadaten-System

    User->>DMV: Frage: Wer referenziert Objekt X?
    DMV->>Meta: Suche Outbound-Dependencies aller Objekte
    Meta->>DMV: Abhängigkeitsliste (Referencing → Referenced)
    DMV->>User: Liefere alle Objekte zurück, die X referenzieren

```

* * *

## 🔍 **Warum wirft diese DMV keine Fehler?**

Das ist ein wichtiger Unterschied zu „Depends On“:

| DMV | Verhalten |
| --- | --- |
| **Depends On** = `dm_sql_referenced_entities` | PARST SQL-Code → kann Fehler erzeugen |
| **Required By** = `dm_sql_referencing_entities` | liest nur Metadaten → keine Fehler |

`dm_sql_referencing_entities`:

- öffnet NICHT die SP/View
    
- parst NICHT den SQL-Text
    
- validiert NICHT Tabellen/Spalten
    

Daher:

- keine Fehlermeldungen
    
- aber ggf. unvollständige Ergebnisse
    

* * *

## ⚠️ Grenzen der „Required By“-Analyse

SQL Server kann NICHT erkennen:

❌ dynamisches SQL  
❌ Cross-DB Referenzen  
❌ Objekte in anderen Schemas mit gleichen Namen  
❌ Objekte, die kaputt sind (fehlerhafte Views)  
❌ falsche Spaltennamen

Warum?

Weil die DMV sich vollständig auf _nur teilweise vollständige_ Metadaten stützt.

* * *

## ✨ **Kurzfassung für Schulungsfolien**

> **„Required By / Abhängig für“ zeigt alle Objekte, die ein bestimmtes Objekt verwenden.  
> SQL Server ermittelt dies passiv über gespeicherte Metadaten in `sys.sql_expression_dependencies`.  
> Die DMV `sys.dm_sql_referencing_entities` erzeugt dabei keine Fehler und keine vollständige Validierung.**


```sql
-- Welche Objekte referenzieren eine Tabelle?
SELECT 
    referencing_schema_name,
    referencing_entity_name,
    referencing_class_desc
FROM sys.dm_sql_referencing_entities ('dbo.Customer', 'OBJECT');
```

```sql
USE BI_STAGE;
GO

;WITH AllObjects AS (
    SELECT 
          o.object_id,
          QUOTENAME(s.name) + '.' + QUOTENAME(o.name) AS FullObjectName,
          s.name AS SchemaName,
          o.name AS ObjectName
    FROM sys.objects o
    JOIN sys.schemas s ON o.schema_id = s.schema_id
    WHERE o.type IN ('V','U','P','FN','IF','TF')  -- Views, Tables, Procs, Functions
)
SELECT
      ao.SchemaName       AS [Schema],
      ao.ObjectName       AS [Table],
      r.referencing_schema_name AS ReferencingSchema,
      r.referencing_entity_name AS ReferencingObject,
      r.referencing_class_desc  AS ReferencingType
FROM AllObjects ao
CROSS APPLY sys.dm_sql_referencing_entities(ao.FullObjectName, 'OBJECT') r
ORDER BY ao.FullObjectName, r.referencing_schema_name, r.referencing_entity_name;
```

## Unterschied zwischen sys.dm\_sql\_referenced\_entities und sys.dm\_sql\_referencing\_entities

Kurz gesagt:

> **`sys.dm_sql_referenced_entities` muss intern den SQL-Code PARSEN, um herauszufinden, auf welche Objekte verwiesen wird → und dabei entstehen Fehler.**
> 
> **`sys.dm_sql_referencing_entities` arbeitet ausschließlich mit bereits gespeicherten Metadaten → und erzeugt deswegen KEINE Fehler.**

Jetzt die ausführliche Erklärung:

* * *

### ✅ 1. **Warum `sys.dm_sql_referenced_entities` Fehler wirft**

`sys.dm_sql_referenced_entities` beantwortet folgende Frage:

> **“Auf welche Objekte greift dieses Objekt zu?”**  
> → also: _Dependencies OUTBOUND_

Um diese Frage beantworten zu können, **muss SQL Server den SQL-Code des Objekts PARSEN** (auch wenn nicht vollständig kompilieren!).

Beispiel:

```
CREATE VIEW dbo.v AS SELECT DivisionCluster FROM Customer;

```

Wenn `DivisionCluster` nicht existiert:

- Die View wird zwar erstellt (lazy compilation)
    
- Aber die DMV muss den Code parsen, um herauszufinden:
    
    - Welche Tabellen werden verwendet?
        
    - Welche Spalten werden verwendet?
        

Dabei versucht SQL Server, die Spaltennamen **aufzulösen**.

Wenn das nicht geht → entsteht die Fehlermeldung:

```
Invalid column name 'DivisionCluster'.

```

oder

```
The dependencies reported for entity ... might not include all columns.

```

**Warum?**  
Weil die Spalte oder Tabelle nicht existiert und der Parser diese Information nicht extrahieren kann.

**Das Parsing ist der Grund, warum Fehler entstehen.**

* * *

### ✅ 2. **Warum `sys.dm_sql_referencing_entities` KEINE Fehler wirft**

`sys.dm_sql_referencing_entities` beantwortet die Gegenfrage:

> **“Welche Objekte greifen auf dieses Objekt zu?”**  
> → also: _Dependencies INBOUND_

Und hier ist der entscheidende Unterschied:

#### 👉 Diese DMV parst keinen SQL-Code.

#### 👉 Sie liest nur **vorhandene, bereits gespeicherte Metadaten** aus folgenden Tabellen:

- `sys.sql_expression_dependencies`
    
- `sys.objects`
    
- `sys.schemas`
    

Diese Metadaten werden gespeichert:

- beim Erstellen von Views, SPs, Funktionen
    
- wenn SQL Server eine Referenz extrahieren _kann_
    

Aber:

#### ❌ Die DMV versucht nicht, Spaltennamen aufzulösen

#### ❌ Sie überprüft nicht, ob Objekte existieren

#### ❌ Sie führt den SQL-Code nicht aus

#### ❌ Sie kompiliert ihn nicht nach

#### ❌ Sie überprüft keine Syntax

Wenn eine SP eine ungültige Spalte enthält, passiert Folgendes:

1. Die View wird trotzdem gespeichert.
    
2. SQL Server extrahiert evtl. nur **Teilinformationen**.
    
3. Diese Teilinformationen werden in einer Meta-Tabelle abgelegt.
    
4. `sys.dm_sql_referencing_entities` liest nur diese Meta-Tabelle.
    

→ Daher **keine Fehlermeldung**, selbst wenn das Objekt eigentlich fehlerhaft ist.

* * *

## 🧠 3. Der fundamentale Unterschied in einem Satz

| DMV | Arbeitet wie? | Resultat |
| --- | --- | --- |
| **`dm_sql_referenced_entities`** | PARST SQL-Code (Outbound) | **wirft Fehler**, wenn Spalten/Tabelle fehlen |
| **`dm_sql_referencing_entities`** | liest _nur gespeicherte Metadaten_ (Inbound) | **keine Fehler**, Metadaten evtl. unvollständig |

* * *

## 📌 4. Beispiel zur Verdeutlichung

### Situation:

```
CREATE VIEW v AS SELECT WrongColumn FROM Customer;

```

### Auswertung:

#### ❌ `sys.dm_sql_referenced_entities('dbo.v', 'OBJECT')`

→ SQL Server muss im Code nachsehen:

- Welche Objekte?
    
- Welche Spalten?
    

Beim Auflösen entsteht:

```
Invalid column name 'WrongColumn'.

```

#### ✔ `sys.dm_sql_referencing_entities('dbo.Customer', 'OBJECT')`

SQL Server verwendet nur gespeicherte Dependency-Infos.

Wenn beim View-Erstellen wenigstens die Tabellen-Referenz extrahiert wurde:

- Gibt es Customer als referenziert zurück
    
- Ohne Prüfung der Spalte
    
- Ohne Fehlermeldung
    

* * *

## 🧩 5. Warum SQL Server das genau so macht

### Wenn beide DMVs beim Parsen Fehler werfen würden:

- Viele SPs/Views wären gar nicht analysierbar
    
- Die Metadata-Engine wäre extrem langsam
    
- Jede Abfrage, jeder Deployment-Prozess wäre potenziell blockiert
    

Daher:

- **Parsing nur beim OUTBOUND-Check** (`referenced_entities`)
    
- **Keine Validierung beim INBOUND-Check** (`referencing_entities`)
    

Ein klassisches Beispiel für Performance vs. Korrektheit.

* * *

## 🎯 6. Fazit

> **`dm_sql_referenced_entities` analysiert aktiv SQL-Code → kann Fehler erzeugen.**
> 
> **`dm_sql_referencing_entities` liest nur bereits erfasste Metadaten → erzeugt keine Fehler.**

Das ist **kein Bug**, sondern ein **Designprinzip**.


# 5️⃣ Werden DB-übergreifende Dependencies erkannt?

### ❌ **Nein – in den meisten Fällen nicht.**

SQL Server erkennt *nur innerhalb derselben Datenbank* automatisch Abhängigkeiten.

Beispiel:
```sql
SELECT * FROM AndereDB.dbo.Kunden;
```
- `AndereDB` wird **nicht** automatisch als Dependency registriert.

### Gründe:
1. Cross-DB Queries können zur Laufzeit andere Rechte erfordern
2. SQL Server möchte keine *impliziten Kopplungen* über DB-Grenzen hinweg erzwingen
3. Der SQL-Parser wertet externe Referenzen **nicht vollständig** aus

### ✔️ Ausnahmen (teilweise erkannt):
- Wenn `REFERENCES` oder `FOREIGN KEY` über Datenbanken hinweg gesetzt werden *(selten erlaubt)*
- Wenn Objekte mit `SCHEMABINDING` referenziert werden

### 💡 Best Practice bei Cross-DB Dependencies
- **Synonyme verwenden** (dbo.Customer → SYNONYM auf andere DB)
- **Dokumentation im Repository erzwingen**
- **tSQLt-Tests**, die Cross-DB-Abhängigkeiten simulieren
- **Deployment-Pipelines**, die referenzierte DB-Versionen prüfen



# 6️⃣ Dynamisches SQL – werden Dependencies erkannt?

❌ **NEIN – dynamische SQL-Referenzen können NICHT automatisch erkannt werden.**

Beispiel:
```sql
DECLARE @sql NVARCHAR(MAX) = 'SELECT * FROM dbo.Customer';
EXEC(@sql);
```
SQL Server sieht in der SP:
- kein `dbo.Customer`
- keine Referenz in `sys.sql_expression_dependencies`

**Warum?**
- Der Parser wertet nur **statische SQL-Anweisungen** aus
- Strings können alles Mögliche enthalten (auch User-Input)
- Exec() wird erst zur Laufzeit ausgewertet

**✔️ Workaround:**
1. **Code-Parser in CI/CD** einsetzen (z. B. SonarQube)
2. **Namenskonventionen** (z. B. `usp_Dyn_`) um Risiko zu kennzeichnen
3. **Logging**, das dynamische Queries mitschreibt
4. **SCHEMABINDING**, wo möglich
5. Für Unit-Tests: tSQLt FakeTables + ExpectException

**Limitation bei sp_executesql:**
Auch hier: **keine automatische Dependency-Erkennung**.


# 7️⃣ Limitierungen der Dependency-Erkennung

❌ 1. Dynamisches SQL wird nicht erkannt
❌ 2. Cross-DB Queries werden kaum erfasst
❌ 3. Verweise in Funktionen mit TRY/CATCH können fehlen
❌ 4. SCHEMABINDING wird nur für Views/Functions unterstützt
❌ 5. Temp-Tabellen (#) werden **nie** in Dependencies aufgenommen
❌ 6. SELECT INTO erstellt neue Tabellen – Dependency entsteht nachträglich
❌ 7. Abhängigkeiten in CLR-Objekten werden nur sehr begrenzt erkannt
❌ 8. CTEs sind *virtuell* – keine eigenen Dependencies

**✔️ SQL Server zeigt eine Dependency nur, wenn:**
- ein Objekt im Code **statisch** genannt wird
- der SQL-Parser die Referenz versteht
- die Referenz derselben **Datenbank** angehört



## Warum in SQL-Dependency-Analysen Schema und Table NULL sein können

Dieses Dokument erklärt, warum bei Abfragen über `sys.dm_sql_referenced_entities` und ähnlichen Dependency-Funktionen in SQL Server manchmal **Schema** und **Table** als **NULL** erscheinen.

Dies ist ein essenzieller Teil der Schulung für Jupyter-Notebooks zum Thema "Dependencies in Microsoft SQL Server".

* * *

### 1\. Cross-Database Referenzen

Wird ein Objekt aus einer anderen Datenbank referenziert, z. B.:

SELECT \* FROM AndereDB.dbo.Customer;

Dann erkennt SQL Server zwar, **dass etwas referenziert wird**, aber die Dependency-Engine beschränkt sich auf die aktuelle Datenbank.

**Folge:**

- Schema = NULL
    
- Table = NULL
    

SQL Server löst _keine DB-übergreifenden Referenzen_ auf.

* * *

### 2\. Dynamisches SQL

Beispiel:

DECLARE @sql NVARCHAR(MAX) = 'SELECT \* FROM Customer';

EXEC(@sql);

Dynamisches SQL wird erst **zur Laufzeit** ausgewertet. Der Dependency-Parser analysiert jedoch nur **statische SQL-Anweisungen**.

**Folge:** Der Parser erkennt keine echte Objekt-Referenz.

- Schema = NULL
    
- Table = NULL
    

* * *

### 3\. Mehrdeutige Objekt-Namen

Beispiel:

SELECT \* FROM Customer;

Wenn mehrere Schemas potenziell das Objekt enthalten könnten, oder das Objekt beim Parsing (noch) nicht existiert, wird keine korrekte Zuordnung getroffen.

**Folge:**

- SQL Server liefert nur den Namen
    
- Schema bleibt NULL
    

* * *

### 4\. Nicht auflösbare oder gelöschte Objekte

Wenn eine View noch auf eine Tabelle verweist, die inzwischen gelöscht wurde:

SELECT \* FROM OldTable;

Dann existiert `OldTable` nicht mehr in `sys.objects`.

**Resultat:**

- Objektname wird zurückgegeben
    
- Schema = NULL (weil Objekt nicht existiert)
    

* * *

### 5\. Temporäre Tabellen (#temp) und Variablentabellen (@t)

Beispiel:

SELECT \* FROM #TempA;

Temporäre Tabellen existieren **nicht** in `sys.objects`. Dasselbe gilt für Tabellendefinitionen in Variablen wie:

DECLARE @T TABLE (...)

**Folge:**

- Keine Matching-Zeile in `sys.objects`
    
- Schema/Table sind NULL
    

* * *

### 6\. CTEs (Common Table Expressions)

Beispiel:

WITH CTE AS (...)

SELECT \* FROM CTE;

CTEs sind **keine Objekte im Systemkatalog**.

**Folge:**

- Sie tauchen als Referential-Entity auf
    
- Haben aber weder Schema noch zugehörige Tabelle
    

* * *

### 7\. Zusammenhang mit typischen Fehlermeldungen

Bestimmte Fehlermeldungen hängen **direkt** mit den zuvor beschriebenen Ursachen zusammen, insbesondere wenn SQL Server Dependencies nicht korrekt auflösen kann.

#### 🔧 7.1 Fehlermeldung:

**"The dependencies reported for entity ... might not include references to all columns."**

Diese Meldung entsteht, wenn SQL Server beim Parsen einer View, Funktion oder Stored Procedure feststellt:

- dass Objekte referenziert werden, die **nicht existieren**, oder
    
- dass Teile des Codes syntaktisch **nicht eindeutig interpretierbar** sind.
    

Das tritt typischerweise auf bei:

- Cross-DB Referenzen
    
- dynamischem SQL
    
- gelöschten oder umbenannten Objekten
    
- CTEs mit Namenskollisionen
    
- fehlerhaften Spaltennamen
    
- CASE-Ausdrücken oder dynamisch konstruierten Spalten
    

**Warum hängt das mit NULL-Schema/Table zusammen?** Wenn SQL Server ein Objekt **nicht eindeutig auflösen kann**, kann auch die Dependency-Engine es nicht korrekt zuordnen:

- Schema = NULL
    
- Table = NULL
    
- Warnung, dass Dependencies ggf. unvollständig sind
    

#### 🔧 7.2 Fehlermeldung:

**Msg 207 – Invalid column name 'DivisionCluster'**

Dieser Fehler weist darauf hin, dass in einer View, SP oder Funktion eine **Spalte referenziert wird, die nicht mehr existiert** oder falsch geschrieben ist.

Typische Ursachen:

- Tabelle wurde geändert → Spalte entfernt/umbenannt
    
- Schreibfehler im Code
    
- dynamisches SQL mit falscher Spaltendefinition
    
- Referenz zeigt auf eine andere Tabelle als erwartet (Schema drift)
    

**Verbindung zur Dependency-Analyse:** Wenn ein Objekt eine ungültige Spalte referenziert, entsteht in der Analyse:

- `referenced_entity_name` möglicherweise falsch
    
- Schema/Table = NULL
    
- Warnhinweis, dass nicht alle Spalten gefunden wurden
    

SQL Server versucht weiterhin, die übrigen Dependencies zu ermitteln, kann aber keine verlässliche Auflösung durchführen.


## Dependency-Errors in SQL Server - Behebung


### ✅ **Was dieses Script für dich sichtbar macht**

| Kategorie | Bedeutung | Was du korrigieren musst |
| --- | --- | --- |
| ❌ XML Parse Error | SQL-Code fehlerhaft (z. B. Invalid column name) | SP/View korrigieren |
| ❌ Missing Object | Tabelle/View existiert nicht | Objekt anlegen oder Code anpassen |
| 🔶 Cross-DB Reference | SQL Server kann Dependency nie auflösen | Synonym + SchemaBinding nutzen |
| ❌ Missing Column | Spalte existiert nicht | Rechtschreibfehler, Rename, Schema-Drift |
| 🔶 Dynamic SQL | Dependency wird nie vollständig | Möglichst statisch schreiben |
| 🔶 Temp/CTE/TableVar | Keine echten Objekte | Kein Fehler, aber bewusst akzeptieren |


### 🎯 **Ergebnis**

Wenn dieses Script läuft, bekommst du eine **komplette Checkliste**, warum die Dependency-Analyse unvollständig ist.

Damit kannst du dann:

- die fehlerhaften Objekte gezielt reparieren
    
- fehlende Tabellen/Spalten identifizieren
    
- falsch geschriebene Spaltennamen finden
    
- Cross-DB-Abhängigkeiten bereinigen
    
- dynamisches SQL kennzeichnen
    
- Schema-Drift analysieren


# 8️⃣ Best Practices (Zusammenfassung)

### ✔️ Verwende SCHEMABINDING für Views/Funktionen
### ✔️ Verwende Synonyme für Cross-DB Queries
### ✔️ Vermeide dynamisches SQL, wo nicht zwingend notwendig
### ✔️ Nutze tSQLt-Unit-Tests für kritische Objekte
### ✔️ Document Dependencies in Git (z. B. im gleichen Ordner wie SP)
### ✔️ Nutze Deployment-Pipelines mit Pre-Checks für Objektversionen

