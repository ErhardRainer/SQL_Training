# QUOTED_IDENTIFIER

**Quelle:** `T-SQL\21_QUOTED_IDENTIFIER\QUOTED_IDENTIFIER.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 9  
**SQL-Zellen:** 7  

---

# Quoted Identifyer

In relationalen Datenbanksystemen, insbesondere in SQL Server, gibt es bestimmte Schlüsselwörter, die spezielle Bedeutungen haben. Wenn man versucht, Tabellen oder Spalten mit diesen Schlüsselwörtern zu benennen, kann das zu Problemen führen. Das QUOTED\_IDENTIFIER Setting ist eine Möglichkeit, solche Schlüsselwörter als Identifier (z.B. Tabellen- oder Spaltennamen) zu verwenden.


## Datenbank Vorbereitung

Dieser Abschnitt stellt sicher, dass die Datenbank "QUOTED\_IDENTIFIER" verwendet wird. Zunächst wird zur MASTER-Datenbank gewechselt, dann die QUOTED\_IDENTIFIER-Datenbank gelöscht (falls sie bereits existiert), und schließlich neu erstellt.


```sql
-- Use MASTER
-- Drop Database [QUOTED_IDENTIFIER]
Create Database [QUOTED_IDENTIFIER]
GO
```

## QUOTED\_IDENTIFIER OFF  

Hier wird das QUOTED\_IDENTIFIER-Setting auf OFF gesetzt. Wenn es ausgeschaltet ist, interpretiert SQL Server doppelte Anführungszeichen (" ") als Zeichenkettenbegrenzer und eckige Klammern (\[ \]) als Begrenzer für Identifier.


```sql
SET QUOTED_IDENTIFIER OFF
GO
```

## Tabelle mit Schlüsselwörtern erstellen

In diesem Abschnitt wird versucht, eine Tabelle mit dem Namen "select" zu erstellen. Aufgrund des eingeschalteten QUOTED\_IDENTIFIER OFF-Settings schlägt dieser Versuch fehl.


```sql
-- Create statement fails.
CREATE TABLE "select" ("identity" INT IDENTITY NOT NULL, "order" INT NOT NULL);
GO
```

## Korrekte Tabelle erstellen

Hier wird erfolgreich eine Tabelle mit dem Namen "select" erstellt, indem eckige Klammern als Identifier-Begrenzer verwendet werden.


```sql
-- was aber geht:
CREATE TABLE [select] ([identity] INT IDENTITY NOT NULL, [order] INT NOT NULL);
```

## QUOTED\_IDENTIFIER ON  

Jetzt wird QUOTED\_IDENTIFIER auf ON gesetzt. Das bedeutet, dass doppelte Anführungszeichen als Identifier-Begrenzer verwendet werden.


```sql
SET QUOTED_IDENTIFIER ON;
GO
```

## Tabelle mit Schlüsselwörtern erstellen und abfragen  

Mit dem QUOTED\_IDENTIFIER ON-Setting kann man erfolgreich eine Tabelle namens "select" erstellen. Danach wird die Tabelle abgefragt und die Ergebnisse nach der Spalte "order" sortiert.


```sql
-- Create statement succeeds.
Drop Table "select"

CREATE TABLE "select" ("identity" INT IDENTITY NOT NULL, "order" INT NOT NULL);
GO

SELECT "identity","order"
FROM "select"
ORDER BY "order";
GO
```

## Aufräumen

Zum Schluss wird die Tabelle "SELECT" gelöscht und das QUOTED\_IDENTIFIER-Setting zurück auf OFF gesetzt.


```sql
DROP TABLE "SELECT";
GO

SET QUOTED_IDENTIFIER OFF;
GO
```

# Ergänzungen

- Standardwert: Standardmäßig ist QUOTED\_IDENTIFIER in SQL Server auf ON gesetzt.
- Ansi-Standard: Das Verhalten von QUOTED\_IDENTIFIER ON entspricht dem ANSI-Standard für SQL.
- Verhalten bei Indexen: Mit QUOTED\_IDENTIFIER OFF können keine indizierten Sichten oder indizierte berechnete Spalten erstellt werden.
- Kompatibilitätsprobleme: Einige ältere Anwendungen und Tools funktionieren möglicherweise nicht korrekt, wenn QUOTED\_IDENTIFIER auf ON gesetzt ist.
- Tipp zum Best-Practice: Es sollte vermieden werden, SQL-Schlüsselwörter als Tabellen- oder Spaltennamen zu verwenden.
- Connection String: Das QUOTED\_IDENTIFIER-Setting kann über den Connection String festgelegt werden.

