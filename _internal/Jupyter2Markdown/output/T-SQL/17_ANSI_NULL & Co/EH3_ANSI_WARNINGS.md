# EH3_ANSI_WARNINGS

**Quelle:** `T-SQL\17_ANSI_NULL & Co\EH3_ANSI_WARNINGS.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 5  
**SQL-Zellen:** 5  

---

# ANSI\_WARNINGS

... steuert das Verhalten in Bezug auf verschiedene Fehlermeldungen, wie 

- NULL Values bei Aggregationen
- Divisionen durch NULL
- STRING TRUNCATION

Default ON (1) - sollte nicht geändert werden !


```sql
USE master
GO
Drop Database if exists [ANSI_WARNINGS_TEST]
CREATE DATABASE [ANSI_WARNINGS_TEST]
GO
```

## Vorbereitung der Datenbank


```sql
USE [ANSI_WARNINGS_TEST]

CREATE TABLE [dbo].[ANSI_Warnings_Test] ([Test] int null)

INSERT INTO [dbo].[ANSI_Warnings_Test]([Test])
Values (NULL),(5),(7),(8)

Select * from [dbo].[ANSI_Warnings_Test]
```

**<u>Beispiel 1:</u>** ANSI\_WARNINGS ON =\> Fehlermeldung beim Aggregieren, wenn ein NULL Wert enthalten ist


```sql
SET ANSI_WARNINGS ON;
Select sum([Test]) from [dbo].[ANSI_Warnings_Test]
-- Warning: Null value is eliminated by an aggregate or other SET operation.
```

**<u>Beispiel 2:</u>** ANSI\_WARNINGS OFF=\> keine Fehlermeldung beim Aggregieren, wenn ein NULL Wert enthalten ist


```sql
SET ANSI_WARNINGS OFF;
Select sum([Test]) from [dbo].[ANSI_Warnings_Test]
-- keine Warning
```

**<u>Beispiel 3:</u>** ANSI\_WARNINGS ON =\> Division durch NULL


```sql
SET ARITHABORT OFF 
SET ANSI_WARNINGS OFF
Declare @i as int = 5
Declare @j as int = 0 
Select @i/@j
```
