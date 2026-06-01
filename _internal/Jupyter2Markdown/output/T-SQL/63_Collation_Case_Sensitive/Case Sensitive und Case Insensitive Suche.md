# Case Sensitive und Case Insensitive Suche

**Quelle:** `T-SQL\63_Collation_Case_Sensitive\Case Sensitive und Case Insensitive Suche.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 21  
**SQL-Zellen:** 26  

---

# Textfunktionen

T-SQL bietet eine Vielzahl von Textfunktionen, um mit Zeichenketten (Strings) zu arbeiten. Hier ist eine Liste der gängigsten Textfunktionen in T-SQL:

1. <span style="border: 0px solid rgb(217, 217, 227); box-sizing: border-box; --tw-border-spacing-x: 0; --tw-border-spacing-y: 0; --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0; --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1; --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ; --tw-scroll-snap-strictness: proximity; --tw-gradient-from-position: ; --tw-gradient-via-position: ; --tw-gradient-to-position: ; --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ; --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff; --tw-ring-color: rgba(69,89,164,.5); --tw-ring-offset-shadow: 0 0 transparent; --tw-ring-shadow: 0 0 transparent; --tw-shadow: 0 0 transparent; --tw-shadow-colored: 0 0 transparent; --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ; --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ; --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ; --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ; --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ; font-weight: 600; color: var(--tw-prose-bold);">String-Manipulation</span>:
    
    - `LEN()`: Gibt die Länge eines Strings zurück. (Beispiel 1)
    - `LEFT()`: Gibt eine bestimmte Anzahl von Zeichen vom Anfang eines Strings zurück. (Beispiel 1)
    - `RIGHT()`: Gibt eine bestimmte Anzahl von Zeichen vom Ende eines Strings zurück. (Beispiel 1)
    - `UPPER()`: Wandelt alle Buchstaben in einem String in Großbuchstaben um. (Beispiel 2)
    - `LOWER()`: Wandelt alle Buchstaben in einem String in Kleinbuchstaben um. (Beispiel 2)
    - `LTRIM()`: Entfernt Leerzeichen vom Anfang eines Strings. (Beispiel 3)
    - `RTRIM()`: Entfernt Leerzeichen vom Ende eines Strings. (Beispiel 3)
    - `TRIM()`: Entfernt Leerzeichen vom Anfang und Ende eines Strings. (Beispiel 3)
    - `REPLACE()`: Ersetzt alle Vorkommen eines Substrings durch einen anderen Substring.
    - `STUFF()`: Setzt einen String in einen anderen String ein, beginnend an einer angegebenen Position und über eine angegebene Länge.
    - `REPLICATE()`: Wiederholt einen String eine bestimmte Anzahl von Malen.
    - `FORMAT()`: Formatiert Werte als Strings.
2. <span style="border: 0px solid rgb(217, 217, 227); box-sizing: border-box; --tw-border-spacing-x: 0; --tw-border-spacing-y: 0; --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0; --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1; --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ; --tw-scroll-snap-strictness: proximity; --tw-gradient-from-position: ; --tw-gradient-via-position: ; --tw-gradient-to-position: ; --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ; --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff; --tw-ring-color: rgba(69,89,164,.5); --tw-ring-offset-shadow: 0 0 transparent; --tw-ring-shadow: 0 0 transparent; --tw-shadow: 0 0 transparent; --tw-shadow-colored: 0 0 transparent; --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ; --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ; --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ; --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ; --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ; font-weight: 600; color: var(--tw-prose-bold);">Suchen und Abfragen</span>:
    
    - `CHARINDEX()`: Gibt die Position des ersten Vorkommens eines Substrings zurück.
    - `PATINDEX()`: Gibt die Position des ersten Vorkommens eines Musters in einem String zurück.
    - `STR()`: Konvertiert einen Zahlwert in einen String.
    - `SUBSTRING()`: Gibt einen Teil eines Strings zurück.
3. <span style="border: 0px solid rgb(217, 217, 227); box-sizing: border-box; --tw-border-spacing-x: 0; --tw-border-spacing-y: 0; --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0; --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1; --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ; --tw-scroll-snap-strictness: proximity; --tw-gradient-from-position: ; --tw-gradient-via-position: ; --tw-gradient-to-position: ; --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ; --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff; --tw-ring-color: rgba(69,89,164,.5); --tw-ring-offset-shadow: 0 0 transparent; --tw-ring-shadow: 0 0 transparent; --tw-shadow: 0 0 transparent; --tw-shadow-colored: 0 0 transparent; --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ; --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ; --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ; --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ; --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ; font-weight: 600; color: var(--tw-prose-bold);">Konvertierung</span>:
    
    - `ASCII()`: Gibt den ASCII-Code des ersten Zeichens eines Strings zurück.
    - `CHAR()`: Gibt das Zeichen zurück, das dem angegebenen ASCII-Code entspricht.
    - `UNICODE()`: Gibt den Unicode-Wert des ersten Zeichens eines Strings zurück.
    - `NCHAR()`: Gibt das Unicode-Zeichen zurück, das dem angegebenen Unicode-Wert entspricht.
    - `CAST()`: Wandelt einen Ausdruck in einen angegebenen Datentyp um.
    - `CONVERT()`: Wandelt einen Ausdruck in einen angegebenen Datentyp um.
4. <span style="border: 0px solid rgb(217, 217, 227); box-sizing: border-box; --tw-border-spacing-x: 0; --tw-border-spacing-y: 0; --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0; --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1; --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ; --tw-scroll-snap-strictness: proximity; --tw-gradient-from-position: ; --tw-gradient-via-position: ; --tw-gradient-to-position: ; --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ; --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff; --tw-ring-color: rgba(69,89,164,.5); --tw-ring-offset-shadow: 0 0 transparent; --tw-ring-shadow: 0 0 transparent; --tw-shadow: 0 0 transparent; --tw-shadow-colored: 0 0 transparent; --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ; --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ; --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ; --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ; --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ; font-weight: 600; color: var(--tw-prose-bold);">Aggregation</span>:
    
    - `STRING_AGG()`: Kombiniert mehrere Zeilen eines Strings in einer Spalte.
5. <span style="border: 0px solid rgb(217, 217, 227); box-sizing: border-box; --tw-border-spacing-x: 0; --tw-border-spacing-y: 0; --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0; --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1; --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ; --tw-scroll-snap-strictness: proximity; --tw-gradient-from-position: ; --tw-gradient-via-position: ; --tw-gradient-to-position: ; --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ; --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff; --tw-ring-color: rgba(69,89,164,.5); --tw-ring-offset-shadow: 0 0 transparent; --tw-ring-shadow: 0 0 transparent; --tw-shadow: 0 0 transparent; --tw-shadow-colored: 0 0 transparent; --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ; --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ; --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ; --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ; --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ; font-weight: 600; color: var(--tw-prose-bold);">Verschiedenes</span>:
    
    - `CONCAT()`: Verkettet zwei oder mehr Strings.
    - `CONCAT_WS()`: Verkettet Strings mit einem Trennzeichen.
    - `QUOTENAME()`: Gibt einen Unicode-String mit Klammern zurück.
    - `REVERSE()`: Kehrt einen String um.
    - `SPACE()`: Gibt einen String mit der angegebenen Anzahl von Leerzeichen zurück.
    - `ISNULL()`: Gibt den ersten Wert zurück, wenn er nicht NULL ist, sonst den zweiten Wert.
    - `IIF()`: Gibt je nach Bedingung den einen oder anderen Wert zurück.
    - `CHOOSE()`: Gibt, basierend auf einem Index, einen von mehreren Werten zurück.


```sql
Use [AdventureWorks2017]
Go
```

## Beispiel 1: LEN, LEFT, RIGHT


```sql
-- schlägt fehl, da nicht jede Spalte ein Leerzeichen hat
SELECT [AddressID]
      ,[AddressLine1]
      ,[AddressLine2]
      ,len([AddressLine2]) as [AddressLine2_len]
      ,right([AddressLine2],5) as [AddressLine2_Right5]
      ,left([AddressLine2],5) as [AddressLine2_Left5]
      -- Zusätzliche berechnete Spalten
      ,LEFT([AddressLine2], CHARINDEX(' ', [AddressLine2]) - 1) as [AddressLine2_BeforeSpace]
      ,RIGHT([AddressLine2], LEN([AddressLine2]) - CHARINDEX(' ', [AddressLine2])) as [AddressLine2_AfterSpace]
FROM [AdventureWorks2017].[Person].[Address]
where AddressLine2 is not null
```

```sql
-- geändert, damit es auch mit Spalten funktioniert, die kei Leerzeichen haben
SELECT [AddressID]
      ,[AddressLine1]
      ,[AddressLine2]
      ,len([AddressLine2]) as [AddressLine2_len]
      ,right([AddressLine2],5) as [AddressLine2_Right5]
      ,left([AddressLine2],5) as [AddressLine2_Left5]
      -- Zusätzliche berechnete Spalten
      ,CASE 
           WHEN CHARINDEX(' ', [AddressLine2]) > 0 THEN
               LEFT([AddressLine2], CHARINDEX(' ', [AddressLine2]) - 1)
           ELSE
               [AddressLine2]
       END as [AddressLine2_BeforeSpace]
      ,CASE 
           WHEN CHARINDEX(' ', [AddressLine2]) > 0 THEN
               RIGHT([AddressLine2], LEN([AddressLine2]) - CHARINDEX(' ', [AddressLine2]))
           ELSE
               ''
       END as [AddressLine2_AfterSpace]
FROM [AdventureWorks2017].[Person].[Address]
where AddressLine2 is not null

```

## Beispiel 2: UPPER / LOWER

In T-SQL konvertiert die LOWER()-Funktion alle Buchstaben eines gegebenen Zeichenkettenausdrucks in Kleinbuchstaben, während die UPPER()-Funktion alle Buchstaben in Großbuchstaben umwandelt.


```sql
Select Top 10 FirstName, LastName from [AdventureWorks2017].[Person].[Person] order by LastName
Select Top 10 FirstName, UPPER(LastName) as [LastName] from [AdventureWorks2017].[Person].[Person] order by LastName
```

## erster Buchstabe des Vornamens GROSS

Wenn Sie sicherstellen möchten, dass der Vorname mit einem Großbuchstaben beginnt und der Rest des Vornamens in Kleinbuchstaben geschrieben ist, können Sie die UPPER(), LOWER() und LEFT() Funktionen in Kombination mit der RIGHT() Funktion verwenden:


```sql
SELECT 
    TOP 10 
    UPPER(LEFT(FirstName, 1)) + LOWER(RIGHT(FirstName, LEN(FirstName) - 1)) AS [FirstName],
    UPPER(LastName) as [LastName]
FROM 
    [AdventureWorks2017].[Person].[Person]
ORDER BY 
    LastName;
```

# Beispiel 3: LTRIM, RTRIM, TRIM


```sql
Declare @teststring as char(100) = ' Test xxx ' 
print '''' + @teststring + ''''
--print '''' + @teststring + ''''
--print len(@teststring)
--print len(rtrim(@teststring))
--print len(ltrim(rtrim(@teststring)))
print '''' + ltrim(rtrim(@teststring)) + ''''
```

```sql
--print len(@teststring) -- das Leerzeichen am Ende wird automatisch entfernt
--print len(rtrim(@teststring))
print len(ltrim(rtrim(@teststring))) -- entfernt das Leerzeichen am Anfang & Ende
print '''' + left(@teststring,6)+ ''''
print '''' + ltrim(rtrim(left(@teststring,6))) + ''''
```

```sql
-- LTRIM/RTRIM entfernt keine geschütztes Leerzeichen ASCII 160
Declare @teststring as char(100) = ' Test xxx ' + Char(160) + ' '
print '''' + @teststring + '''' 
print len(@teststring)
print len(rtrim(@teststring))
print len(rtrim(ltrim(replace(@teststring,char(160),' '))))
```

## Beispiel 4: REPLACE

Das REPLACE-Statement ermöglicht es, Zeichenketten innerhalb eines Textes durch andere Zeichenketten zu ersetzen.


# Exkurs

### Case Sensitive und Case Insensitive Suche


Die Collation einer Datenbank gibt an, wie Zeichenketten (Strings) in der Datenbank verglichen und sortiert werden. Dabei steht "CI" für "Case-Insensitive", was bedeutet, dass bei einem Vergleich Groß- und Kleinschreibung nicht berücksichtigt wird.

  

Um die Collation einer Datenbank in SQL Server auszulesen, können Sie die systemeigene Funktion DATABASEPROPERTYEX verwenden. Hier ist das SQL-Statement, mit dem Sie die Collation einer Datenbank abfragen können:


```sql
SELECT DATABASEPROPERTYEX('DatenbankName', 'Collation') AS DatabaseCollation;
```

Um zu überprüfen, ob die Collation "Case-Insensitive" (CI) ist, können Sie nach dem "CI" in der Collation-Zeichenfolge suchen:


```sql
DECLARE @DBNAme nvarchar(MAX) = 'AdventureWorks2017'
DECLARE @collation NVARCHAR(255)
SET @collation = CONVERT(NVARCHAR(255), DATABASEPROPERTYEX(@DBNAme, 'Collation'))

IF CHARINDEX('CI', @collation) > 0
    PRINT 'Die Collation ist Case-Insensitive (CI)'
ELSE
    PRINT 'Die Collation berücksichtigt Groß- und Kleinschreibung'
```

## Case-Insensitive Suche

Wenn die Datenbank als CI (Case-Insensitive) eingestellt ist, dann ist es egal, ob man nach groß oder kleingeschriebenen Worten sucht


```sql
Select FirstName, UPPER(LastName) as [LastName] from [AdventureWorks2017].[Person].[Person]
where UPPER(LastName) like '%ACKER%'

Select FirstName, UPPER(LastName) as [LastName] from [AdventureWorks2017].[Person].[Person]
where UPPER(LastName) like '%acker%'
```

## Case-insensitive Filterung bei Case-sensitiven Daten

### Möglichkeit 1:

Der gegebene T-SQL-Code zeigt, wie man eine case-insensitive (Groß- und Kleinschreibung ignorierende) Filterung auf Daten durchführt, die in einer möglicherweise case-sensitiven (Groß- und Kleinschreibung beachtenden) Collation gespeichert sind.  

Diese WHERE-Klausel filtert die Ergebnisse auf der Grundlage einer Bedingung:

- <span style="color: var(--vscode-foreground);">CHARINDEX(UPPER('ACKER'),UPPER(LastName)): Die CHARINDEX-Funktion sucht nach dem ersten Vorkommen des ersten angegebenen Strings im zweiten angegebenen String und gibt die Position (beginnend bei 1) des ersten Zeichens des ersten Vorkommens zurück. Wenn der String nicht gefunden wird, gibt die Funktion 0 zurück.&nbsp;</span> In dieser Abfrage werden sowohl der gesuchte String 'ACKER' als auch die LastName-Spalte der Tabelle mit der UPPER-Funktion in Großbuchstaben umgewandelt. Das bedeutet, dass die Suche unabhängig von der Groß- und Kleinschreibung erfolgt. 
- \\> 0: Dies stellt sicher, dass nur die Datensätze ausgewählt werden, bei denen der Nachname (LastName) den String 'ACKER' (unabhängig von der Groß- und Kleinschreibung) enthält.


```sql
Select FirstName, UPPER(LastName) as [LastName] from [AdventureWorks2017].[Person].[Person]
where CHARINDEX(UPPER('ACKER'),UPPER(LastName)) > 0
```

### Möglichkeit 2:

Die T-SQL-Abfrage gibt Vornamen und Nachnamen von Personen aus der Datenbank \[AdventureWorks2017\] zurück, wobei nur die Datensätze berücksichtigt werden, bei denen der Nachname den String "ACKER" enthält. Bei der Suche wird Groß- und Kleinschreibung unterschieden, Akzente jedoch ignoriert.


```sql
-- matched nicht
Select FirstName, LastName as [LastName] from [AdventureWorks2017].[Person].[Person]
where LastName like '%ACKER%'
COLLATE Latin1_General_CS_AI
```

```sql
-- matched nicht
Select FirstName, LastName as [LastName] from [AdventureWorks2017].[Person].[Person]
where LastName like '%acker%'
COLLATE Latin1_General_CS_AI
```

```sql
-- matched
Select FirstName, LastName as [LastName] from [AdventureWorks2017].[Person].[Person]
where LastName like '%Acker%'
COLLATE Latin1_General_CS_AI
```

```sql
Select FirstName, LastName as [LastName] from [AdventureWorks2017].[Person].[Person]
where LastName = 'Ackerman'
COLLATE Latin1_General_CS_AI
```

## Case-sensitive Filterung bei case-insensitiven Daten


```sql
Select FirstName, LastName as [LastName] from [AdventureWorks2017].[Person].[Person]
where LastName like '%ACKER%'
COLLATE SQL_Latin1_General_CP1_CS_AS
```

```sql

Select FirstName, LastName as [LastName] from [AdventureWorks2017].[Person].[Person]
where LastName like '%Acker%'
COLLATE SQL_Latin1_General_CP1_CS_AS
```

```sql
Select FirstName, LastName as [LastName] from [AdventureWorks2017].[Person].[Person]
where LastName like '%ACKER%'
```

```sql
Select FirstName, LastName as [LastName] from [AdventureWorks2017].[Person].[Person]
where LastName like '%Acker%'
COLLATE SQL_Latin1_General_CP1_CS_AS
```

## Ebenen der Collation

- Datenbank-Ebene ändern (nicht empfohlen): Sie können die Collation einer Datenbank ändern, indem Sie die Datenbank offline nehmen, die Collation mit ALTER DATABASE ändern und die Datenbank wieder online nehmen. Dies ist jedoch nicht empfohlen, da es nicht alle Objekte in der Datenbank ändert und Inkonsistenzen oder Fehler verursachen kann.
- Neue Datenbank erstellen: Der sicherste Ansatz besteht darin, eine neue Datenbank mit der gewünschten Collation zu erstellen und alle Daten und Objekte aus der alten Datenbank zu dieser neuen Datenbank zu migrieren.
- Spaltenebene: Wenn Sie nur die Collation einer bestimmten Spalte ändern möchten (anstatt der gesamten Datenbank), können Sie dies mit dem ALTER TABLE-Befehl tun:


```sql
ALTER TABLE TableName
ALTER COLUMN ColumnName VARCHAR(255) COLLATE NewCollationName;
```

```sql
Declare @Var as varchar(100) = 'Beispeil 1'
Select REPLACE(@Var,'Beispeil','Beispiel')
```

**Beachten der Collation**

Collation beeinflusst die Art und Weise, wie Zeichenketten verglichen und sortiert werden. Das folgende Beispiel ersetzt Zeichen in


```sql
-- Ersetzen von # durch Number
SELECT [AddressID]
      ,[AddressLine1]
      ,[AddressLine2]
      ,Replace([AddressLine2], '#', 'Number') as [AddressLine2_Modified]
FROM [AdventureWorks2017].[Person].[Address]
Where AddressLine2 like '%#%'
```

Berücksichtigung von Case Sensitivity bei der Ersetzung

  

Das nächste Beispiel zeigt die Notwendigkeit, die Groß- und Kleinschreibung zu beachten:


# Einfügen von Text mit STUFF

Mit STUFF können Sie Text an einer bestimmten Position in einem String einfügen:


```sql
-- Ersetzen von Zeichen bei einer bestimmten Position
Select STUFF('123456',3,2,'xxxx')
```

# Arbeiten mit Leerzeichen und NULL-Werten

In SQL gibt es einen Unterschied zwischen einem NULL-Wert und einem leeren String:


```sql
-- Unterschied zwischen NULL und ''
Select NULL, isnull(NULL,''), ''
```

# Substring und Zeichenpositionen

<span style="color: var(--vscode-foreground);">Das Herausschneiden von Teilzeichenketten oder das Finden der Position bestimmter Zeichen ist mit Funktionen wie SUBSTRING und CHARINDEX möglich:</span>


```sql
-- Schneidet eine Teilzeichenkette heraus
Declare @t as nvarchar(MAX) = '123456789'
Select @t, SUBSTRING(@t,3,2)
```

# Arbeiten mit UNICODE und ASCII

<span style="color: var(--vscode-foreground);">UNICODE und ASCII sind zwei verschiedene Systeme zur Codierung von Zeichen:</span>


# Zusammenführen von Strings mit CONCAT und STRING\_AGG

<span style="color: var(--vscode-foreground);">Diese Funktionen ermöglichen das Kombinieren von Zeichenketten:</span>

