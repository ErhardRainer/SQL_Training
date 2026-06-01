# EH04-01-00 numerische Funktionen

**Quelle:** `T-SQL\05_Funktionen\EH04-01-00 numerische Funktionen.ipynb`  
**Generiert:** 2026-04-18 21:13:30  
**Markdown-Zellen:** 19  
**SQL-Zellen:** 21  

---

# Numerische Funktionen

- isNumeric 
- Zufallszahlen (zB RAND)
- Runden
- Absolutbetrag & Vorzeichen
- Potenzen und Wurzeln
- Winkelfunktionen (eigenes File)
- Exponential- und Logarithmische Funktionen (eignes File)


## isNumeric

Prüfen, ob ein Text eine Zahl ist  

<span class="hljs-keyword" style="box-sizing: inherit; outline-color: inherit; color: rgb(1, 1, 253); font-family: SFMono-Regular, Consolas, &quot;Liberation Mono&quot;, Menlo, Courier, monospace; white-space: pre; background-color: rgb(250, 250, 250);">ISNUMERIC</span> <span style="color: rgb(23, 23, 23); font-family: SFMono-Regular, Consolas, &quot;Liberation Mono&quot;, Menlo, Courier, monospace; white-space: pre; background-color: rgb(250, 250, 250);">( expression ) =&gt; int: </span> 0 nein | 1 = ja

Anmerkungen:

- Texte mit Währungssymbolen werden nicht als Zahl erkannt
- Exponential-Schreibweise wird als Zahl erkannt


```sql
Select isNumeric('5')
Select isNumeric(5)
Select isNumeric('-5')
Select isNumeric('5$')
Select isNumeric('-5$')
Select isNumeric('5e10')
```

Prüfen Sie, ob die Spalte \[PostalCode\] in der Tabelle \[Person\].\[Address\] numerisch ist?


```sql
SELECT [AddressID]
      ,[PostalCode]
	  ,Isnumeric([PostalCode]) as [Isnumeric] -- => int: 0 nein | 1 = ja
  FROM [Person].[Address]
  order by 3 asc
```

Geben Sie die Zeilen zurück, bei denen der PostalCode nicht numerisch ist


```sql
  SELECT [AddressID]
      ,[PostalCode]
	  ,Isnumeric([PostalCode]) as [Isnumeric]
  FROM [Person].[Address]
  Where Isnumeric([PostalCode]) = 0
```

## Zufallszahlen (zB RAND)

RAND(Seed) =\> Float Pseudozufallswert zw 0-1


```sql
Select RAND(), RAND()
```

für einen bestimmten Seed (Ausgangswert) ist der zurückgegebene Ergebnis immer gleich


```sql
  Select RAND(55), RAND(55)  -- immer gleich (alle 2 Werte)
  SELECT RAND(100), RAND(100), RAND(100)  -- immer gleich (alle 3 Werte)
  SELECT RAND(), RAND(), RAND()  -- immer unterschiedlich (alle 3 Werte)
```

### Zufallszahlen innerhalb von bestimmter Grenzen


**<u>Allgemeine Methode zum Ermitteln einer Zahl innerhalb eines Bereiches</u>**

a = Untergrenze

b = Obergrenze

Anmerkung: alternative Methode im Abschnittt \[Round\] mit Cast


```sql
	Declare @a as int = 100
	Declare @b as int = 1000
	SELECT Cast(RAND()*(@b-@a)+@a as int);
```

```sql
	Declare @min as int = 5
	Declare @max as int = 15
	Select round(@min + rand() * (@max - @min),0)
```

andere Möglichkeiten zum Generieren von zufälligen Zahlen:


weitere Methode zum Generieren von Zufallszahlen mittels newid()


```sql
	Declare @i as decimal(38,10) = rand()
	Select @i
	Select Cast(@i as int) 
	Select Floor(@i)
```

## Runden von Zahlen
ROUND(<mark>Zahl, length</mark>, \[function:0 (default)\]) =\> Runden
Floor(Zahl) =\> größte ganze Zahl zurück, die kleiner oder gleich dem angegebenen numerischen Ausdruck 
Ceiling(Zahl) =\> kleinste ganze Zahl zurück, die größer oder gleich dem angegebenen numerischen Ausdruck ist


```sql
  Declare @Zahl as decimal(38,10) = 15.66666969464
  print Round(@Zahl,0)   -- > ganze Zahl
  print Round(@Zahl,3)   -- > 3. Nachkommerstelle
  print Round(@Zahl,-1)  -- > auf ganze Zehner
```

Funktionsparameter der Round Funktion


```sql
  Declare @Zahl as decimal(38,10) = 15.66666969464
  print Round(@Zahl,0,0) -- rundet das Ergebnis [Funktion:0]
  print Round(@Zahl,0,1) -- schneidet das Ergebnis ab [Funktion:1]
```

### nächst gelegene Integer Zahl

größer: Ceiling

kleiner: Floor


```sql
	Select Ceiling(-501.555) -- -501
	Select Ceiling(+501.555) -- +502
```

```sql
    Select Floor(-501.555)   -- -502
	Select Floor(+501.555)   -- +501
```

```sql
  Declare @Zahl as decimal(38,10) = 15.66666969464
  print Round(@Zahl,0,1) -- bleibt der DAtentyp gleich =>  decimal(38,10)
  print floor(@Zahl) -- es wird daraus ein INT
```

Ein Alternative zum Round/Ceiling/Floor stellt das CAST dar


```sql
	Declare @i as decimal(38,10) = rand()*100
	Select @i
	Select Cast(@i as int) 
	Select Floor(@i)
```

### Performance Vergleich:

keine nennenswerten Unterschiede


# Absolut Betrag / Vorzeichen

<span class="hljs-keyword" style="box-sizing: inherit; outline-color: inherit; color: rgb(1, 1, 253); font-family: SFMono-Regular, Consolas, &quot;Liberation Mono&quot;, Menlo, Courier, monospace; white-space: pre; background-color: rgb(250, 250, 250);">ABS</span> <span style="color: rgb(23, 23, 23); font-family: SFMono-Regular, Consolas, &quot;Liberation Mono&quot;, Menlo, Courier, monospace; white-space: pre; background-color: rgb(250, 250, 250);">( </span> <span class="hljs-variable" style="box-sizing: inherit; outline-color: inherit; color: rgb(23, 23, 23); font-family: SFMono-Regular, Consolas, &quot;Liberation Mono&quot;, Menlo, Courier, monospace; white-space: pre; background-color: rgb(250, 250, 250);">numeric_expression</span> <span style="color: rgb(23, 23, 23); font-family: SFMono-Regular, Consolas, &quot;Liberation Mono&quot;, Menlo, Courier, monospace; white-space: pre; background-color: rgb(250, 250, 250);">) =&gt; Absolutbetrag</span>

<span class="hljs-keyword" style="box-sizing: inherit; outline-color: inherit; color: rgb(1, 1, 253); font-family: SFMono-Regular, Consolas, &quot;Liberation Mono&quot;, Menlo, Courier, monospace; white-space: pre; background-color: rgb(250, 250, 250);">SIGN</span> <span style="color: rgb(23, 23, 23); font-family: SFMono-Regular, Consolas, &quot;Liberation Mono&quot;, Menlo, Courier, monospace; white-space: pre; background-color: rgb(250, 250, 250);">( </span> <span class="hljs-variable" style="box-sizing: inherit; outline-color: inherit; color: rgb(23, 23, 23); font-family: SFMono-Regular, Consolas, &quot;Liberation Mono&quot;, Menlo, Courier, monospace; white-space: pre; background-color: rgb(250, 250, 250);">numeric_expression</span> <span style="color: rgb(23, 23, 23); font-family: SFMono-Regular, Consolas, &quot;Liberation Mono&quot;, Menlo, Courier, monospace; white-space: pre; background-color: rgb(250, 250, 250);">) =&gt; Vorzeichen</span><span style="color: rgb(23, 23, 23); font-family: SFMono-Regular, Consolas, &quot;Liberation Mono&quot;, Menlo, Courier, monospace; white-space: pre; background-color: rgb(250, 250, 250);"><br></span>

    <span style="color: #008000;">--&nbsp;Vorzeichen&nbsp;+1&nbsp;positive&nbsp;/&nbsp;-1&nbsp;negativ&nbsp;/&nbsp;0&nbsp;</span>


```sql
Select ABS(-15)
```

```sql
Select SIGN(-15)
Select SIGN(+15)
Select SIGN(-100)
Select SIGN(+100)
```

# Potenzen und Wurzeln

SQRT(x) =\> Wurzel

SQUARE(x) =\> x^2 (Quadart)

Power(x,y) =\> x^y


```sql
Select SQRT(4) -- Wurzel aus 4 = 2
Select SQRT(16) -- Wurzel aus 16 = 4
```

```sql
Select Square(4) -- 4x4 = 4^2
Select Square(2) -- 2x2 = 2^2
```

```sql
Select Power(2,10) -- 2^10
```

## Wurzelziehen

Wurzeln in Potenzform umformen

![](data:image/png;base64,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)


```sql
DECLARE @My1 FLOAT = 16
DECLARE @My2 FLOAT = 4
SELECT POWER(@My1, 1/@My2)
```

Achtung bei den **Datentypen**


```sql
SELECT POWER(16, (1/4))
SELECT POWER(Cast(16 as float), (1/Cast(4 as float)))
```
