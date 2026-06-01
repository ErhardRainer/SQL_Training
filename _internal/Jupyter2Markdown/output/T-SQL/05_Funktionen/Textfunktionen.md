# Textfunktionen

**Quelle:** `T-SQL\05_Funktionen\Textfunktionen.ipynb`  
**Generiert:** 2026-04-18 21:13:30  
**Markdown-Zellen:** 29  
**SQL-Zellen:** 107  

---

# Textfunktionen

T-SQL bietet eine Vielzahl von Textfunktionen, um mit Zeichenketten (Strings) zu arbeiten. Hier ist eine Liste der gängigsten Textfunktionen in T-SQL:

1. <span style="border: 0px solid rgb(217, 217, 227); box-sizing: border-box; --tw-border-spacing-x: 0; --tw-border-spacing-y: 0; --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0; --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1; --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ; --tw-scroll-snap-strictness: proximity; --tw-gradient-from-position: ; --tw-gradient-via-position: ; --tw-gradient-to-position: ; --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ; --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff; --tw-ring-color: rgba(69,89,164,0.5); --tw-ring-offset-shadow: 0 0 transparent; --tw-ring-shadow: 0 0 transparent; --tw-shadow: 0 0 transparent; --tw-shadow-colored: 0 0 transparent; --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ; --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ; --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ; --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ; --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ; font-weight: 600; color: var(--tw-prose-bold);">String-Manipulation</span>:

- `LEN()`: Gibt die Länge eines Strings zurück. (Beispiel 1)
- `LEFT()`: Gibt eine bestimmte Anzahl von Zeichen vom Anfang eines Strings zurück. (Beispiel 1)
- `RIGHT()`: Gibt eine bestimmte Anzahl von Zeichen vom Ende eines Strings zurück. (Beispiel 1)
- `UPPER()`: Wandelt alle Buchstaben in einem String in Großbuchstaben um. (Beispiel 2)
- `LOWER()`: Wandelt alle Buchstaben in einem String in Kleinbuchstaben um. (Beispiel 2)
- `LTRIM()`: Entfernt Leerzeichen vom Anfang eines Strings. (Beispiel 3)
- `RTRIM()`: Entfernt Leerzeichen vom Ende eines Strings. (Beispiel 3)
- `TRIM()`: Entfernt Leerzeichen vom Anfang und Ende eines Strings. (Beispiel 3)
- `REPLACE()`: Ersetzt alle Vorkommen eines Substrings durch einen anderen Substring. (Beispiel 4)
- `STUFF()`: Setzt einen String in einen anderen String ein, beginnend an einer angegebenen Position und über eine angegebene Länge. (Beispiel 5)
- `REPLICATE()`: Wiederholt einen String eine bestimmte Anzahl von Malen. (Beispiel 6)
- `FORMAT()`: Formatiert Werte als Strings. (Beispiel 7)

2. <span style="border: 0px solid rgb(217, 217, 227); box-sizing: border-box; --tw-border-spacing-x: 0; --tw-border-spacing-y: 0; --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0; --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1; --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ; --tw-scroll-snap-strictness: proximity; --tw-gradient-from-position: ; --tw-gradient-via-position: ; --tw-gradient-to-position: ; --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ; --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff; --tw-ring-color: rgba(69,89,164,0.5); --tw-ring-offset-shadow: 0 0 transparent; --tw-ring-shadow: 0 0 transparent; --tw-shadow: 0 0 transparent; --tw-shadow-colored: 0 0 transparent; --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ; --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ; --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ; --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ; --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ; font-weight: 600; color: var(--tw-prose-bold);">Suchen und Abfragen</span>:

- `CHARINDEX()`: Gibt die Position des ersten Vorkommens eines Substrings zurück. (Beispiel 8)
- `PATINDEX()`: Gibt die Position des ersten Vorkommens eines Musters in einem String zurück. (Beispiel 8)
- `STR()`: Konvertiert einen Zahlwert in einen String. (Beispiel 9)
- `SUBSTRING()`: Gibt einen Teil eines Strings zurück. (Beispiel 9)

3. <span style="border: 0px solid rgb(217, 217, 227); box-sizing: border-box; --tw-border-spacing-x: 0; --tw-border-spacing-y: 0; --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0; --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1; --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ; --tw-scroll-snap-strictness: proximity; --tw-gradient-from-position: ; --tw-gradient-via-position: ; --tw-gradient-to-position: ; --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ; --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff; --tw-ring-color: rgba(69,89,164,0.5); --tw-ring-offset-shadow: 0 0 transparent; --tw-ring-shadow: 0 0 transparent; --tw-shadow: 0 0 transparent; --tw-shadow-colored: 0 0 transparent; --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ; --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ; --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ; --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ; --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ; font-weight: 600; color: var(--tw-prose-bold);">Konvertierung</span>:

- `ASCII()`: Gibt den ASCII-Code des ersten Zeichens eines Strings zurück. (Beispiel 10)
- `CHAR()`: Gibt das Zeichen zurück, das dem angegebenen ASCII-Code entspricht. (Beispiel 10)
- `UNICODE()`: Gibt den Unicode-Wert des ersten Zeichens eines Strings zurück. (Beispiel 10)
- `NCHAR()`: Gibt das Unicode-Zeichen zurück, das dem angegebenen Unicode-Wert entspricht. (Beispiel 10)
- `CAST()`: Wandelt einen Ausdruck in einen angegebenen Datentyp um. (Beispiel 11)
- `CONVERT()`: Wandelt einen Ausdruck in einen angegebenen Datentyp um. (Beispiel 11)

4. <span style="border: 0px solid rgb(217, 217, 227); box-sizing: border-box; --tw-border-spacing-x: 0; --tw-border-spacing-y: 0; --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0; --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1; --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ; --tw-scroll-snap-strictness: proximity; --tw-gradient-from-position: ; --tw-gradient-via-position: ; --tw-gradient-to-position: ; --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ; --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff; --tw-ring-color: rgba(69,89,164,0.5); --tw-ring-offset-shadow: 0 0 transparent; --tw-ring-shadow: 0 0 transparent; --tw-shadow: 0 0 transparent; --tw-shadow-colored: 0 0 transparent; --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ; --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ; --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ; --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ; --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ; font-weight: 600; color: var(--tw-prose-bold);">Aggregation</span>:

- `STRING_AGG()`: Kombiniert mehrere Zeilen eines Strings in einer Spalte. (Beispiel 12)

5. <span style="border: 0px solid rgb(217, 217, 227); box-sizing: border-box; --tw-border-spacing-x: 0; --tw-border-spacing-y: 0; --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0; --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1; --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ; --tw-scroll-snap-strictness: proximity; --tw-gradient-from-position: ; --tw-gradient-via-position: ; --tw-gradient-to-position: ; --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ; --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff; --tw-ring-color: rgba(69,89,164,0.5); --tw-ring-offset-shadow: 0 0 transparent; --tw-ring-shadow: 0 0 transparent; --tw-shadow: 0 0 transparent; --tw-shadow-colored: 0 0 transparent; --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ; --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ; --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ; --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ; --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ; font-weight: 600; color: var(--tw-prose-bold);">Verschiedenes</span>:

- `CONCAT()`: Verkettet zwei oder mehr Strings. (Beispiel 13)
- `CONCAT_WS()`: Verkettet Strings mit einem Trennzeichen. (Beispiel 13)
- `QUOTENAME()`: Gibt einen Unicode-String mit Klammern zurück. (Beispiel 14)
- `REVERSE()`: Kehrt einen String um. (Beispiel 15)
- `SPACE()`: Gibt einen String mit der angegebenen Anzahl von Leerzeichen zurück. (Beispiel 16)


```sql
Use [AdventureWorks2017]
Go
```

# Beispiel 1: LEN, LEFT, RIGHT


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

# Beispiel 2: UPPER / LOWER

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

- LTRIM - Die LTRIM-Funktion in T-SQL entfernt alle führenden (links stehenden) Leerzeichen aus einem gegebenen Zeichenfolgenwert.
- RTRIM - Die RTRIM-Funktion in T-SQL entfernt alle abschließenden (rechts stehenden) Leerzeichen aus einem gegebenen Zeichenfolgenwert.
- TRIM -  (verfügbar ab SQL Server 2017): Die TRIM-Funktion entfernt sowohl führende als auch abschließende Leerzeichen aus einer gegebenen Zeichenfolge. Es kann auch verwendet werden, um andere Zeichen als Leerzeichen am Anfang oder Ende einer Zeichenfolge zu entfernen, wenn diese Zeichen als Parameter übergeben werden.


```sql
Declare @teststring as char(100) = ' Test xxx ' 
-- die Leerzeichen bleiben vorne und hinten erhalten
print '''' + @teststring + ''''
print len(@teststring) -- das Leerzeichen am Ende wird automatisch entfernt
```

```sql
Declare @teststring as char(100) = ' Test xxx ' 
-- die Leerzeichen bleiben vorne und hinten erhalten
print '''' + rtrim(@teststring) + ''''
print len(rtrim(@teststring))
```

```sql
Declare @teststring as char(100) = ' Test xxx ' 
-- die Leerzeichen bleiben vorne und hinten erhalten
print '''' + ltrim(@teststring) + ''''
print len(ltrim(@teststring))
```

```sql
Declare @teststring as char(100) = ' Test xxx ' 
-- Leerzeichen am Anfang & Ende entfernen
print '''' + rtrim(ltrim(@teststring)) + ''''
print len(ltrim(rtrim(@teststring))) 
-- Seit SQL2017
print '''' + trim(@teststring) + ''''
print len(trim(@teststring))
```

```sql
Declare @teststring as char(100) = ' Test xxx ' 
print '''' + left(@teststring,6)+ ''''
print '''' + ltrim(rtrim(left(@teststring,6))) + ''''
```

## LTRIM, RTRIM, TRIM und geschützte Leerzeichen

Geschützte Leerzeichen (auch bekannt als nicht brechendes Leerzeichen und repräsentiert durch ASCII 160) werden oft verwendet, um zu verhindern, dass Zeilenumbrüche an bestimmten Stellen in Texten auftreten. Bei der Verwendung von T-SQL-Funktionen ist es wichtig zu wissen, wie diese Funktionen mit solchen Zeichen umgehen:

  

- LTRIM: Die LTRIM-Funktion in T-SQL ist darauf ausgelegt, normale Leerzeichen (ASCII 32) zu entfernen, die am Anfang einer Zeichenfolge stehen. Sie wird nicht geschützte Leerzeichen (ASCII 160) am Anfang einer Zeichenfolge entfernen.
- RTRIM: Die RTRIM-Funktion verhält sich ähnlich wie LTRIM, jedoch werden nur die am Ende einer Zeichenfolge stehenden normalen Leerzeichen entfernt. Auch hier werden geschützte Leerzeichen (ASCII 160) am Ende nicht entfernt.
- TRIM: Ab SQL Server 2017 kann die TRIM-Funktion verwendet werden, um sowohl führende als auch abschließende Zeichen zu entfernen. In seiner grundlegenden Anwendung (ohne zusätzliche Parameter) verhält es sich wie die Kombination von LTRIM und RTRIM und wird ebenso geschützte Leerzeichen nicht entfernen.

<span style="color: var(--vscode-foreground);">Wenn Sie geschützte Leerzeichen entfernen möchten, müssen Sie die REPLACE-Funktion oder eine ähnliche Methode verwenden, um sie zuerst in normale Leerzeichen zu konvertieren oder sie direkt zu entfernen.</span>


```sql
-- LTRIM/RTRIM entfernt keine geschütztes Leerzeichen ASCII 160
Declare @teststring as char(100) = ' Test xxx ' + Char(160) + ' '
print '''' + @teststring + '''' 
print len(@teststring)
print len(rtrim(@teststring))
print len(rtrim(ltrim(replace(@teststring,char(160),' '))))
```

# Beispiel 4: REPLACE & TRANSLATE

Das REPLACE und TRANSLATE ermöglichen es, Zeichenketten innerhalb eines Textes durch andere Zeichenketten zu ersetzen.

Die **REPLACE**\-Funktion in T-SQL ermöglicht es, alle Vorkommen einer bestimmten Zeichenfolge in einer anderen Zeichenfolge durch eine neue Zeichenfolge zu ersetzen. Es wird häufig verwendet, um unerwünschte Zeichen oder Wörter in einer Zeichenfolge zu entfernen oder durch andere zu ersetzen.


```sql
Declare @Var as varchar(100) = 'Beispeil 1'
Select REPLACE(@Var,'Beispeil','Beispiel')
```

Die **TRANSLATE**\-Funktion ist eine erweiterte Version der REPLACE-Funktion. Sie nimmt eine Eingabezeichenfolge und ersetzt Zeichen, die in einer angegebenen Zeichenfolge gefunden werden, durch Zeichen in einer anderen angegebenen Zeichenfolge. Jedes Zeichen in der Eingabezeichenfolge, das mit einem Zeichen in der ersten Zeichenfolge der Übersetzungstabelle übereinstimmt, wird durch das entsprechende Zeichen in der zweiten Zeichenfolge ersetzt.


```sql
SELECT TRANSLATE('1A2B3C', 'ABC', 'XYZ');
-- Ergebnis: '1X2Y3Z'
```

```sql
SELECT TRANSLATE('2*[3+4]/{7-2}', '+-', '-+');
```

```sql
SELECT TRANSLATE('2*[3+4]/{7-2}', '[]{}', '()()');
```

```sql
-- das selbe mit Replace
SELECT
REPLACE
(
      REPLACE
      (
            REPLACE
            (
                  REPLACE
                  (
                        '2*[3+4]/{7-2}',
                        '[',
                        '('
                  ),
                  ']',
                  ')'
            ),
            '{',
            '('
      ),
      '}',
      ')'
);
```

# Beispiel 5: Einfügen von Text mit STUFF

Die STUFF-Funktion in T-SQL wird verwendet, um einen Teil einer Zeichenfolge durch eine andere Zeichenfolge zu ersetzen. Sie nimmt einen Ziel-String und ersetzt ab einer bestimmten Startposition eine angegebene Anzahl von Zeichen durch einen anderen gegebenen String. Mit STUFF können Benutzer also Teile einer Zeichenfolge präzise manipulieren, was besonders nützlich ist, um bestimmte Muster oder Strukturen in Daten zu ändern.


```sql
-- Ersetzen von Zeichen bei einer bestimmten Position
Select STUFF('123456',3,2,'xxxx')
```

```sql
-- einfaches Beispiel
SELECT STUFF('Hello World', 7, 5, 'T-SQL');
-- Ergebnis: 'Hello T-SQL'
```

```sql
-- Einfügen ohne Ersetzen
SELECT STUFF('HelloWorld', 6, 0, ' ');
-- Ergebnis: 'Hello World'
```

```sql
-- Entfernen eines Teils einer Zeichenfolge
SELECT STUFF('Hello World', 7, 5, '');
-- Ergebnis: 'Hello '
```

```sql
--Ersetzen von Zeichen in einer Telefonnummer
SELECT STUFF(STUFF('1234567890', 4, 0, '-'), 8, 0, '-');
-- Ergebnis: '123-456-7890'
```

```sql
-- Beispiel SQL -Statement
SELECT STUFF('SELECT * FROM tablename', 15, 0, 'TOP 10');
-- Ergebnis: 'SELECT TOP 10 * FROM tablename'
```

# Beispel 6: Replicate

Die REPLICATE-Funktion in T-SQL wird verwendet, um eine Zeichenfolge eine bestimmte Anzahl von Malen zu wiederholen. Hier ist ein einfaches Beispiel, um zu zeigen, wie es funktioniert:


Angenommen, Sie möchten eine gestrichelte Linie erzeugen, die aus 50 Bindestrichen besteht


```sql
SELECT REPLICATE('-', 50) AS DashedLine;
```

Hier ist ein weiteres Beispiel, bei dem Sie vielleicht den Wert einer Spalte in einer Tabelle mit Sternen (\*) auf einer bestimmten Länge auffüllen möchten:


```sql
-- Angenommen, es gibt eine Tabelle namens 'Products' mit einer Spalte 'ProductName'
SELECT 
    ProductName + REPLICATE('*', 20 - LEN(ProductName)) AS PaddedProductName 
FROM 
    Products;
```

# Beispiel 7 - Format

Die FORMAT-Funktion in T-SQL wird verwendet, um den Wert eines Ausdrucks in das angegebene Format zu konvertieren. Meistens wird sie verwendet, um Datums-, Zeit- und Zahlenwerte zu formatieren.


```sql
-- (1) Formatieren eines Datums
SELECT FORMAT(GETDATE(), 'dd/MM/yyyy') AS FormattedDate;
-- Ergebnis könnte sein: "25/09/2023"
```

```sql
-- (2) Formatieren einer Zeit
SELECT FORMAT(GETDATE(), 'HH:mm:ss') AS FormattedTime;
-- Ergebnis könnte sein: "14:05:23"
```

```sql
-- (3) Lange Datums- und Zeitformate
SELECT FORMAT(GETDATE(), 'dddd, MMMM dd, yyyy HH:mm:ss') AS LongFormat;
-- Ergebnis könnte sein: "Monday, September 25, 2023 14:05:23"
```

```sql
-- (4) Kurzes Datumsformat
SELECT FORMAT(GETDATE(), 'd') AS ShortDateFormat;
-- Ergebnis könnte sein: "25.9.2023"
```

```sql
-- (5) Formatieren mit Dezimalstellen
SELECT FORMAT(12345.6789, 'N2') AS FormattedNumber;
-- Ergebnis: "12,345.68"
```

```sql
-- (6) Formatieren einer Zahl als Währung
SELECT FORMAT(12345.6789, 'C') AS FormattedCurrency;
-- Ergebnis könnte sein (abhängig von der lokalen Einstellung): "€12,345.68"
```

```sql
-- (7) Formatieren als Prozentsat
SELECT FORMAT(0.12345, 'P2') AS FormattedPercentage;
-- Ergebnis: "12.35%"

```

```sql
-- (8) Benutzerdefinierte Zahlenformate
SELECT FORMAT(1234567890, '###-###-####') AS CustomNumberFormat;
-- Ergebnis: "123-456-7890"
```

```sql
-- (9) Verwendung von kuturspezifischen Formaten
SELECT FORMAT(GETDATE(), 'D', 'de-DE') AS GermanDateFormat;
-- Ergebnis könnte sein: "25. September 2023"
```

```sql
-- (10) Formatieren von Zahlen mit Währungssymbolen basierend auf Kultur
SELECT FORMAT(12345.6789, 'C', 'en-US') AS USCurrency,
       FORMAT(12345.6789, 'C', 'ja-JP') AS JPYCurrency;
-- Ergebnis: "$12,345.68" für USCurrency und "¥12,346" für JPYCurrency
```

Es ist zu beachten, dass die FORMAT-Funktion in einigen Fällen langsamer sein kann als andere native T-SQL-Funktionen zur Datums- und Zahlenformatierung, daher sollte sie mit Bedacht eingesetzt werden, insbesondere in Abfragen mit großen Datenmengen.


# Beispiel 8: CHARINDEX & PATINDEX

PATINDEX und CHARINDEX sind T-SQL-Funktionen, die zum Suchen von Zeichenketten innerhalb anderer Zeichenketten verwendet werden. Sie geben den Startindex des ersten Vorkommens der gesuchten Zeichenkette zurück. Wenn die gesuchte Zeichenkette nicht gefunden wird, geben beide Funktionen den Wert 0 zurück.

## PATINDEX:

PATINDEX ermöglicht komplexere Suchen mit Wildcards, ähnlich wie die LIKE-Bedingung in T-SQL.

<span style="color: var(--vscode-foreground);">Syntax: PATINDEX('%Muster%', Zeichenkette)</span>

Beispiel: SELECT PATINDEX('%test%', 'Dies ist ein Test.')

Dies gibt den Wert 12 zurück, da "test" an der 12. Position beginnt.

## CHARINDEX:

CHARINDEX führt eine direkte Zeichen-für-Zeichen-Suche ohne die Unterstützung von Wildcards durch.

<span style="color: var(--vscode-foreground);">Syntax: CHARINDEX('Muster', Zeichenkette, Startposition)</span>

Beispiel: SELECT CHARINDEX('test', 'Dies ist ein Test.')

Dies gibt ebenfalls den Wert 12 zurück.

Ein Hauptunterschied zwischen den beiden Funktionen ist, dass PATINDEX Wildcards unterstützt, während CHARINDEX das nicht tut. Darüber hinaus bietet CHARINDEX die Möglichkeit, einen optionalen dritten Parameter für die Startposition anzugeben, von der aus die Suche beginnen soll.

Falls man mehrfaches Vorkommen in einem String benötigt: [https://erhard-rainer.com/2023-09/mehrfaches-vorkommen-in-string-finden/](https:\erhard-rainer.com\2023-09\mehrfaches-vorkommen-in-string-finden\)


```sql
-- Ermittle die Position von "#"
Select [AddressLine2], CHARINDEX('#',[AddressLine2]) as [Position#]
from [AdventureWorks2017].[Person].[Address]
Where [AddressLine2] is not null
order by 2 desc
```

```sql
-- können auch mehrere Zeichen sein
Select [AddressLine2], CHARINDEX('Kreditoren',[AddressLine2]) as [PositionKreditoren]
from [AdventureWorks2017].[Person].[Address]
Where [AddressLine2] like '%Kreditoren%'
```

```sql
-- Charindex ist nicht case-sensitive
Select [AddressLine2], CHARINDEX('buchhaltung',[AddressLine2]) as [Position#]
from [AdventureWorks2017].[Person].[Address]
Where [AddressLine2] like '%buchhaltung%'
```

```sql
-- Charindex kann man aber auch case-sensitive verwenden
Select [AddressLine2], CHARINDEX('buchhaltung',[AddressLine2] COLLATE Latin1_General_CS_AS) as [Position#]
from [AdventureWorks2017].[Person].[Address]
Where [AddressLine2] COLLATE Latin1_General_CS_AS like '%buchhaltung%'
```

```sql
-- PATINDEX (Syntax identisch mit like)
Select [AddressLine2], PATINDEX('%[1-9]%',[AddressLine2]) as [Position#]
from [AdventureWorks2017].[Person].[Address]
Where [AddressLine2] like '%[0]%'
```

```sql
Select [AddressLine2], PATINDEX('%[1-9]%',[AddressLine2]) as [Position#]
from [AdventureWorks2017].[Person].[Address]
Where [AddressLine2] is not null
```

# Beispiel 9: Substring & STR

Die SUBSTRING-Funktion in Transact-SQL (T-SQL) – der Anfragesprache von Microsoft SQL Server – ermöglicht es, einen Teil einer Zeichenkette basierend auf einer gegebenen Startposition und einer bestimmten Länge herauszuschneiden. Diese Funktion ist besonders nützlich, wenn nur ein bestimmter Abschnitt eines Strings benötigt wird oder wenn Daten auf eine bestimmte Weise formatiert oder analysiert werden müssen.  

  

<span class="hljs-built_in" style="border: 0px solid rgb(217, 217, 227); box-sizing: border-box; --tw-border-spacing-x: 0; --tw-border-spacing-y: 0; --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0; --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1; --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ; --tw-scroll-snap-strictness: proximity; --tw-gradient-from-position: ; --tw-gradient-via-position: ; --tw-gradient-to-position: ; --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ; --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff; --tw-ring-color: rgba(69,89,164,0.5); --tw-ring-offset-shadow: 0 0 transparent; --tw-ring-shadow: 0 0 transparent; --tw-shadow: 0 0 transparent; --tw-shadow-colored: 0 0 transparent; --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ; --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ; --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ; --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ; --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ; color: rgb(233, 149, 12); font-family: &quot;Söhne Mono&quot;, Monaco, &quot;Andale Mono&quot;, &quot;Ubuntu Mono&quot;, monospace; white-space: pre; background-color: rgb(0, 0, 0);">SUBSTRING</span> <span style="color: rgb(255, 255, 255); font-family: &quot;Söhne Mono&quot;, Monaco, &quot;Andale Mono&quot;, &quot;Ubuntu Mono&quot;, monospace; white-space: pre; background-color: rgb(0, 0, 0);"> (Ausdruck, </span> <span class="hljs-keyword" style="border: 0px solid rgb(217, 217, 227); box-sizing: border-box; --tw-border-spacing-x: 0; --tw-border-spacing-y: 0; --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0; --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1; --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ; --tw-scroll-snap-strictness: proximity; --tw-gradient-from-position: ; --tw-gradient-via-position: ; --tw-gradient-to-position: ; --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ; --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff; --tw-ring-color: rgba(69,89,164,0.5); --tw-ring-offset-shadow: 0 0 transparent; --tw-ring-shadow: 0 0 transparent; --tw-shadow: 0 0 transparent; --tw-shadow-colored: 0 0 transparent; --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ; --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ; --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ; --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ; --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ; color: rgb(46, 149, 211); font-family: &quot;Söhne Mono&quot;, Monaco, &quot;Andale Mono&quot;, &quot;Ubuntu Mono&quot;, monospace; white-space: pre; background-color: rgb(0, 0, 0);">Start</span><span style="color: rgb(255, 255, 255); font-family: &quot;Söhne Mono&quot;, Monaco, &quot;Andale Mono&quot;, &quot;Ubuntu Mono&quot;, monospace; white-space: pre; background-color: rgb(0, 0, 0);">, Länge)</span>


```sql
-- einfaches Beispiel mit einer Variable
Declare @t as nvarchar(MAX) = '123456789'
Select @t, SUBSTRING(@t,3,2)
```

```sql
-- einfaches Beispiel mit einer Query
Select [AddressLine2], substring([AddressLine2],1,4) as [Substring_1_4]
from [AdventureWorks2017].[Person].[Address]
Where [AddressLine2] is not null
```

```sql
-- was ist, wenn man einen Substring von einer NICHT-Zeichenkette benötigt wird => STR()
Declare @t as int = '123456789'
Select @t, SUBSTRING(STR(@t),3,2)
```

Zahlen in Text umwandeln =\> STR(float, length, decimal)


```sql
Select STR(15.66666, 5,3)
Select STR(15.66666, 6,3) --der punkt zählt als length
Select STR(15.66666, 9,3) -- füllt die fehlende länge mit Leerzeichen auf
-- Alternative
Select cast(round(15.66666,3) as varchar(10))
```

# Beispiel 10: Arbeiten mit UNICODE und ASCII

<span style="color: var(--vscode-foreground);">UNICODE und ASCII sind zwei verschiedene Systeme zur Codierung von Zeichen.&nbsp;</span>  Die ASCII- und UNICODE-Funktionen sind nützlich, um den numerischen Wert eines Zeichens in einem bestimmten Zeichensatz (ASCII bzw. Unicode) zu bestimmen. Umgekehrt ermöglichen die CHAR- und NCHAR-Funktionen die Umwandlung eines numerischen Codes in das entsprechende Zeichen in diesen Zeichensätzen. Es ist wichtig zu beachten, dass Unicode ein viel umfangreicherer Zeichensatz ist und Zeichen aus vielen verschiedenen Sprachen und Schriftsystemen unterstützt, während ASCII in erster Linie für englische Zeichen entwickelt wurde. In Anwendungen, die mit internationalen Daten arbeiten, werden häufig UNICODE und NCHAR verwendet.


```sql
SELECT ASCII('A') AS Result; -- Ergebnis: 65
```

```sql
SELECT CHAR(65) AS Result; -- Ergebnis: 'A'
```

```sql
SELECT UNICODE('A') AS Result; -- Ergebnis: 65
```

```sql
SELECT NCHAR(65) AS Result; -- Ergebnis: 'A'
```

```sql
Select Char(71) + Char(13) + Char(72)
Select ASCII(Char(71))
Select ASCII('Ä')
Select Char(202)
```

```sql
DECLARE @nstring nchar(8);  
SET @nstring = N'København';  
SELECT UNICODE(SUBSTRING(@nstring, 2, 1)),   
   NCHAR(UNICODE(SUBSTRING(@nstring, 2, 1)));  
```

```sql
DECLARE @nstring char(8);  
SET @nstring = N'København';  
SELECT UNICODE(SUBSTRING(@nstring, 2, 1)),   
   NCHAR(UNICODE(SUBSTRING(@nstring, 2, 1)));  
```

```sql
DECLARE @nstring char(8);  
SET @nstring = N'København';  
SELECT ASCII(SUBSTRING(@nstring, 2, 1)),   
   CHAR(ASCII(SUBSTRING(@nstring, 2, 1)));  
```

ASCII

![ASCII-Tabelle für Sonderzeichen - pctipp.ch](https://www.pctipp.ch/img/1/1/4/5/8/7/7/9706744d60bec9c8.jpg)


# Beispiel 11: CAST und CONVERT

Sowohl CAST als auch CONVERT sind leistungsstarke Werkzeuge in T-SQL, um die Datentypkonvertierung zu bewerkstelligen. Die Wahl zwischen ihnen hängt oft von den spezifischen Anforderungen der Aufgabe ab. Während CAST in den meisten Fällen ausreicht, bietet CONVERT zusätzliche Funktionen, die in bestimmten Situationen nützlich sein können. Es ist wichtig, sich mit beiden Funktionen vertraut zu machen und zu verstehen, wann man welche verwenden sollte, um effiziente und korrekte SQL-Abfragen zu schreiben.

<span class="hljs-built_in" style="border: 0px solid rgb(217, 217, 227); box-sizing: border-box; --tw-border-spacing-x: 0; --tw-border-spacing-y: 0; --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0; --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1; --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ; --tw-scroll-snap-strictness: proximity; --tw-gradient-from-position: ; --tw-gradient-via-position: ; --tw-gradient-to-position: ; --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ; --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff; --tw-ring-color: rgba(69,89,164,0.5); --tw-ring-offset-shadow: 0 0 transparent; --tw-ring-shadow: 0 0 transparent; --tw-shadow: 0 0 transparent; --tw-shadow-colored: 0 0 transparent; --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ; --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ; --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ; --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ; --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ; color: rgb(233, 149, 12); font-family: &quot;Söhne Mono&quot;, Monaco, &quot;Andale Mono&quot;, &quot;Ubuntu Mono&quot;, monospace; white-space: pre; background-color: rgb(0, 0, 0);">CAST</span> <span style="color: rgb(255, 255, 255); font-family: &quot;Söhne Mono&quot;, Monaco, &quot;Andale Mono&quot;, &quot;Ubuntu Mono&quot;, monospace; white-space: pre; background-color: rgb(0, 0, 0);">(ausdruck </span> <span class="hljs-keyword" style="border: 0px solid rgb(217, 217, 227); box-sizing: border-box; --tw-border-spacing-x: 0; --tw-border-spacing-y: 0; --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0; --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1; --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ; --tw-scroll-snap-strictness: proximity; --tw-gradient-from-position: ; --tw-gradient-via-position: ; --tw-gradient-to-position: ; --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ; --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff; --tw-ring-color: rgba(69,89,164,0.5); --tw-ring-offset-shadow: 0 0 transparent; --tw-ring-shadow: 0 0 transparent; --tw-shadow: 0 0 transparent; --tw-shadow-colored: 0 0 transparent; --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ; --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ; --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ; --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ; --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ; color: rgb(46, 149, 211); font-family: &quot;Söhne Mono&quot;, Monaco, &quot;Andale Mono&quot;, &quot;Ubuntu Mono&quot;, monospace; white-space: pre; background-color: rgb(0, 0, 0);">AS</span> <span style="color: rgb(255, 255, 255); font-family: &quot;Söhne Mono&quot;, Monaco, &quot;Andale Mono&quot;, &quot;Ubuntu Mono&quot;, monospace; white-space: pre; background-color: rgb(0, 0, 0);">zieldatentyp [länge])</span>

<span class="hljs-keyword" style="border: 0px solid rgb(217, 217, 227); box-sizing: border-box; --tw-border-spacing-x: 0; --tw-border-spacing-y: 0; --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0; --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1; --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ; --tw-scroll-snap-strictness: proximity; --tw-gradient-from-position: ; --tw-gradient-via-position: ; --tw-gradient-to-position: ; --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ; --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff; --tw-ring-color: rgba(69,89,164,0.5); --tw-ring-offset-shadow: 0 0 transparent; --tw-ring-shadow: 0 0 transparent; --tw-shadow: 0 0 transparent; --tw-shadow-colored: 0 0 transparent; --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ; --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ; --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ; --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ; --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ; color: rgb(46, 149, 211); font-family: &quot;Söhne Mono&quot;, Monaco, &quot;Andale Mono&quot;, &quot;Ubuntu Mono&quot;, monospace; white-space: pre; background-color: rgb(0, 0, 0);">CONVERT</span><span style="color: rgb(255, 255, 255); font-family: &quot;Söhne Mono&quot;, Monaco, &quot;Andale Mono&quot;, &quot;Ubuntu Mono&quot;, monospace; white-space: pre; background-color: rgb(0, 0, 0);">(zieldatentyp [länge], ausdruck [, stil])</span>


<u>Unterschiede zwischen CAST und CONVERT:</u>

- Einfachheit vs. Flexibilität: CAST hat eine einfachere Syntax und ist ANSI-SQL-konform, was bedeutet, dass sie in den meisten relationalen Datenbanksystemen funktioniert. CONVERT, hingegen, ist spezifisch für T-SQL und bietet mehr Flexibilität, insbesondere bei der Formatierung.
- Verwendungszweck: Während CAST hauptsächlich für die einfache Typumwandlung verwendet wird, ist CONVERT nützlich, wenn spezielle Formatierungsanforderungen für die konvertierten Daten benötigt werden, wie z. B. unterschiedliche Datums- und Zeitformate.


```sql
-- FLOAT zu INT
SELECT CAST(123.45 AS INT);  -- Ergebnis: 123
```

```sql
-- TEXT zu VARCHAR
SELECT CAST('T-SQL' AS VARCHAR(10));  -- Ergebnis: T-SQL
```

```sql
-- DATE zu DATETIME
SELECT CAST('2023-09-25' AS DATETIME);  -- Ergebnis: 2023-09-25 00:00:00.000
```

```sql
-- INT zu CHAR
SELECT CAST(25 AS CHAR(2));  -- Ergebnis: 25
```

```sql
-- BINARY zu INT
SELECT CAST(0x0000001A AS INT);  -- Ergebnis: 26
```

```sql
-- DATE zu speziellem VARCHAR Format
SELECT CONVERT(VARCHAR, GETDATE(), 103);  -- Ergebnis: 25/09/2023 (abhängig vom aktuellen Datum)
```

```sql
-- INT zu BINARY
SELECT CONVERT(BINARY(4), 25);  -- Ergebnis: 0x00000019
```

```sql
-- Zeit in HH:MM:SS Format
SELECT CONVERT(VARCHAR, GETDATE(), 108);  -- Ergebnis: 15:25:30 (abhängig von der aktuellen Zeit)
```

```sql
-- VARCHAR zu MONEY
SELECT CONVERT(MONEY, '12345.67');  -- Ergebnis: 12345.67
```

```sql
--  DATETIME zu DATE
SELECT CONVERT(DATE, '2023-09-25 15:25:30');  -- Ergebnis: 2023-09-25
```

```sql
-- CAST in Kombination mit CONVERT
SELECT CAST(CONVERT(VARCHAR, GETDATE(), 112) AS INT);  -- Ergebnis: 20230925 (abhängig vom aktuellen Datum)
```

```sql
-- CAST innerhalb von CONVERT
SELECT CONVERT(VARCHAR, CAST(123.45 AS INT), 112);  -- Ergebnis: 123
```

```sql
-- Geldbetrag in bestimmtem Format
SELECT CONVERT(CHAR, CAST('$123.45' AS MONEY), 1);  -- Ergebnis: 123.45
```

```sql
-- Konvertieren von FLOAT zu VARCHAR und dann zu INT
SELECT CAST(CONVERT(VARCHAR, 123.45) AS INT);  -- Ergebnis: 123
```

```sql
-- Erstellen eines Datums aus VARCHAR
SELECT CAST(CONVERT(DATETIME, '20230925') AS DATE);  -- Ergebnis: 2023-09-25
```

```sql
-- Konvertieren von VARCHAR Datum im britischen Format
SELECT CONVERT(DATETIME, '25/09/2023', 103);  -- Ergebnis: 2023-09-25 00:00:00.000
```

```sql
--Konvertieren von VARCHAR Datum im US Format
SELECT CONVERT(DATETIME, '09/25/2023', 101);  -- Ergebnis: 2023-09-25 00:00:00.000
```

```sql
--DECIMAL zu VARCHAR
SELECT CONVERT(VARCHAR, CAST(123.45 AS DECIMAL(10,2)));  -- Ergebnis: 123.45
```

```sql
-- VARCHAR Wert in einen BIT 
SELECT CONVERT(BIT, 'true');  -- Ergebnis: 1
```

```sql
-- Zahl in ein Datum
SELECT CONVERT(DATETIME, '42606');  -- Ergebnis: 2016-09-25 00:00:00.000 (abhängig von SQL Server Einstellungen)
```

# Beispiel 12: STRING\_AGG

STRING\_AGG ist eine Aggregate-Funktion in T-SQL, die verwendet wird, um Werte aus mehreren Zeilen in einen einzigen String-Wert zu kombinieren, wobei ein bestimmter Trenner zwischen den Werten eingefügt wird.


```sql
USE [AdventureWorks2017]
GO
SELECT FirstName AS csv 
FROM Person.Person
```

```sql
SELECT STRING_AGG (FirstName, CHAR(13)) AS csv 
FROM Person.Person
-- Fehler: STRING_AGG aggregation result exceeded the limit of 8000 bytes. Use LOB types to avoid result truncation.
-- Problem FirstName ist zu klein als Feld
```

```sql
SELECT STRING_AGG (FirstName, CHAR(13)) AS csv 
FROM (Select Cast(FirstName as nvarchar(max))  as FirstName from Person.Person) as q; 
-- Achtung: korrekte Ausgabe nur in Textausgabe: CTRL+T
-- Vornamen sind danach nicht eindeutig
```

```sql
-- um die Vornamen eindeutig zu haben
SELECT STRING_AGG (FirstName, CHAR(13)) AS csv 
FROM (Select Distinct Cast(FirstName as nvarchar(MaX))  as FirstName from Person.Person) as q; 
```

```sql
SELECT STRING_AGG (FirstName, ',') AS csv 
FROM (Select Cast(FirstName as nvarchar(MaX))  as FirstName from Person.Person) as q; 
```

```sql
SELECT STRING_AGG (FirstName, ',') AS csv 
FROM (Select Distinct Cast(FirstName as nvarchar(MaX))  as FirstName from Person.Person) as q; 
```

```sql
-- Umkehrfunktion:
Declare @Agg as nvarchar(MAX) = (SELECT STRING_AGG (FirstName, '|') AS csv 
FROM (Select Cast(FirstName as nvarchar(MaX))  as FirstName from Person.Person) as q)
print @Agg

SELECT * FROM STRING_SPLIT(@Agg,'|');
```

Vor der Einführung von STRING\_AGG in SQL Server 2017 mussten Entwickler oft zu umständlichen Methoden greifen, wie der Verwendung von XML-Path-Methoden oder benutzerdefinierten Funktionen, um diesen Bedarf zu erfüllen. Mit STRING\_AGG ist diese Aufgabe nun deutlich einfacher und direkter geworden.


```sql
SELECT 
    STUFF((
        SELECT CHAR(13) + Cast(FirstName as nvarchar(max))
        FROM Person.Person
        FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'), 1, 1, '') AS csv;

```

```sql
-- und nun mit eindeutigen Vornamen
SELECT 
    STUFF((
        SELECT DISTINCT CHAR(13) + Cast(FirstName as nvarchar(max))
        FROM Person.Person
        ORDER BY FirstName
        FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'), 1, 1, '') AS csv;
```

# Beispiel 13: CONCAT & CONCAT\_WS - Verknüpfen von Strings

Sowohl CONCAT als auch CONCAT\_WS bieten in T-SQL leistungsstarke Möglichkeiten zur Zeichenkettenmanipulation. Während CONCAT eine einfache Verbindung von Werten ermöglicht, bietet CONCAT\_WS zusätzliche Flexibilität durch die Verwendung eines Trennzeichens und die Fähigkeit, NULL-Werte zu ignorieren. Das macht diese Funktionen zu unverzichtbaren Werkzeugen für Entwickler, die mit SQL Server arbeiten.


```sql
SELECT CONCAT('Heute ist der ', GETDATE());
```

```sql
SELECT CONCAT_WS('-', '0049', NULL, '123456789');
```

```sql
Select Concat('Das ','ist ','ein Beispiel')
Select Concat('Das ','ist ',NULL,'ein Beispiel')
Select Concat_WS(',','Das ','ist ','ein Beispiel')
Select Concat_WS(',','Das ','ist ',NULL,'ein Beispiel') -- ignoriert NULL !
```

```sql
Select Concat([ProductNumber],[Name]) as [new_Name]
From [AdventureWorks2017].[Production].[Product]
```

```sql
Select Concat_WS(',',[ProductNumber],[Name]) as [new_Name]
From [AdventureWorks2017].[Production].[Product]
```

# Beispiel 14: QUOTENAME

QUOTENAME ist eine T-SQL-Funktion in Microsoft SQL Server, die dazu dient, einen Bezeichner oder Literal sicher in eckige Klammern zu setzen. Dies ist besonders nützlich, um SQL-Injektionsrisiken zu vermindern, indem sichergestellt wird, dass Zeichenketten, die als Objektnamen (wie Tabellen- oder Spaltennamen) verwendet werden, ordnungsgemäß formatiert sind. Die Funktion kann auch ein optionales Zeichen für die Klammerung annehmen, z. B. einfache oder doppelte Anführungszeichen.


```sql
-- Basisverwendung
SELECT QUOTENAME('ColumnName');
-- Ergebnis: [ColumnName]
```

```sql
-- Sonderzeichen
SELECT QUOTENAME('Column-Name');
-- Ergebnis: [Column-Name]
```

```sql
-- Leerzeichen
SELECT QUOTENAME('Column Name');
-- Ergebnis: [Column Name]
```

```sql
-- unterschiedliche Begrenzungszeichen
SELECT QUOTENAME('ColumnName', '''');
-- Ergebnis: 'ColumnName'
SELECT QUOTENAME('ColumnName', '"');
-- Ergebnis: "ColumnName"
```

```sql
-- Name enthält Begrenzer
SELECT QUOTENAME('Column]Name');
-- Ergebnis: [Column]]Name]
```

```sql
-- dynamisches SQL
DECLARE @TableName NVARCHAR(128) = 'MyTable';
EXEC('SELECT * FROM ' + QUOTENAME(@TableName));
```

# Beispiel 15: Reverse - String umdrehen


```sql
Select [AddressLine1], REVERSE([AddressLine1]) as [AddressLine1_REVERSE]
from [AdventureWorks2017].[Person].[Address]
```

```sql
-- letzte #
Select [AddressLine1],
REVERSE([AddressLine1]) as [AddressLine1_REVERSE]
,CharIndex('#',REVERSE([AddressLine1])) as [PositionOf#Reverse]
,Right([AddressLine1],CharIndex('#',REVERSE([AddressLine1]))) as [LastPart#]
from [AdventureWorks2017].[Person].[Address]
Where [AddressLine1] like '%#%' and CHARINDEX('#',[Addressline1]) <> 1
```

```sql
-- erste #
Select [AddressLine1]
,right([AddressLine1],len([AddressLine1])-CHARINDEX('#',[AddressLine1])+1)
from [AdventureWorks2017].[Person].[Address]
Where [AddressLine1] like '%#%' and CHARINDEX('#',[Addressline1]) <> 1
```

# Beispiel 16: SPACE - Leerzeichen hinfzufügen

Die SPACE-Funktion in T-SQL ermöglicht es, einen Zeichenfolgenwert zu erzeugen, der aus einer bestimmten Anzahl von Leerzeichen besteht. Dies kann nützlich sein, wenn Sie eine Zeichenfolge auf eine bestimmte Länge auffüllen oder zwischen Textelementen Platz lassen möchten. Als Eingabe nimmt die Funktion einen Integer-Wert, der die Anzahl der gewünschten Leerzeichen angibt.


```sql
Select 'a' + space(100) + 'b'
```

```sql
Select AddressLine1, AddressLine2 , AddressLine1 + AddressLine2
from [AdventureWorks2017].[Person].[Address]
Where AddressLine2 is null
```

```sql
Select AddressLine1, AddressLine2 , isnull(AddressLine1,'') + isnull(AddressLine2,'')
from [AdventureWorks2017].[Person].[Address]
```

```sql
Select AddressLine1, AddressLine2 , AddressLine1 + SPACE(100-len(AddressLine2)-len(AddressLine1)) + AddressLine2 as [AddressLine1+2] 
from [AdventureWorks2017].[Person].[Address]
```

```sql
Select AddressLine1, AddressLine2 , AddressLine1 + SPACE(100-len(isnull(AddressLine2,0))-len(isnull(AddressLine1,''))) + isnull(AddressLine2,'') as [AddressLine1+2] 
from [AdventureWorks2017].[Person].[Address]
```

# Arbeiten mit Leerzeichen und NULL-Werten

In SQL gibt es einen Unterschied zwischen einem NULL-Wert und einem leeren String:


```sql
-- Unterschied zwischen NULL und ''
Select NULL, isnull(NULL,''), ''
```

```sql
SELECT [AddressID]
      ,[AddressLine1]
      ,[AddressLine2] as [AddressLine2]
	  ,len([AddressLine2]) as [Len_AddressLine2]
  FROM [AdventureWorks2017].[Person].[Address]
  Where AddressLine2 is null
  order by 4 desc
```

```sql
Update [AdventureWorks2017].[Person].[Address]
Set [AddressLine2] = ''
Where AddressID = '11383'
```

```sql
SELECT [AddressID]
      ,[AddressLine1]
      ,isnull([AddressLine2],'') as [AddressLine2]
	  ,len(isnull([AddressLine2],'')) as [Len_AddressLine2]
  FROM [AdventureWorks2017].[Person].[Address]
  --Where AddressLine2 is null
  order by 4 desc
```

```sql
SELECT [AddressID]
      ,[AddressLine1]
	  ,[AddressLine2]
      ,isnull([AddressLine2],'') as [AddressLine2]
	  ,len(isnull([AddressLine2],'')) as [Len_AddressLine2]
	  ,len([AddressLine2]) as [Len_AddressLine2_2]
  FROM [AdventureWorks2017].[Person].[Address]
  Where len(isnull([AddressLine2],'')) = 0
  and AddressID in ('11383','1')
  order by 1 asc
```

### isnull(\[Spalte\],'') = replace(\[Spalte\],NULL,'')

das ist aber nur eine inhaltliche Entsprechung und die Replace-Funktion funktioniert nicht.


```sql
SELECT ISNULL([AddressLine2], '') AS 'ErgebnisSpalte'
FROM [AdventureWorks2017].[Person].[Address];
```

```sql
SELECT REPLACE([AddressLine2], NULL, '') AS 'ErgebnisSpalte'
FROM [AdventureWorks2017].[Person].[Address];
-- funktioniert nicht, das REPLACE nicht mit NULL umgehen kann und das Resultat wieder NULL ist
```
