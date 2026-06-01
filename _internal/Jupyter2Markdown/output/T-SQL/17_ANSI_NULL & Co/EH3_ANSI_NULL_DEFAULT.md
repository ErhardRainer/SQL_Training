# EH3_ANSI_NULL_DEFAULT

**Quelle:** `T-SQL\17_ANSI_NULL & Co\EH3_ANSI_NULL_DEFAULT.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 6  
**SQL-Zellen:** 6  

---

# ANSI NULL DEFAULT

Steuern des NULL Verhaltens in Spalten (Standard: 0)

- ANSI\_NULL\_DEFAULT OFF = 0 =\> eine neue Spalte, muss explizit als NULLABLE definiert sein, damit man NULL Values reinschreiben kann
- ANSI\_NULL\_DEFAULT ON = 1 =\> eine neue Spalte lässt NULL zu // entspricht SQL-92 Rules for Nullability

Dieses Verhalten  greift jedoch nur, wenn innerhalb der Session auch ANSI\_NULL\_DFLT\_ON OFF gesetzt wurde


```sql
USE master
GO
Drop Database if exists [ANSI_TEST]
CREATE DATABASE [ANSI_TEST]
GO
Alter Database [ANSI_TEST]  SET ANSI_NULL_DEFAULT ON;
GO
```

**<u>Beispiel 1:</u>** ANSI\_NULL\_DEFAULT OFF & ANSI\_NULL\_DFLT\_ON OFF =\> keine NULL Values möglich (_**funktioniert nicht**_)


```sql
DROP Table if EXISTS [Table_1];
Alter Database [ANSI_TEST]  SET ANSI_NULL_DEFAULT OFF;
SET ANSI_NULL_DFLT_ON OFF;
Create Table Table_1 (Column_1 Int)
INSERT INTO Table_1 (Column_1) VALUES (NULL);
```

**<u>Beispiel 2:</u>** ANSI\_NULL\_DEFAULT OFF & ANSI\_NULL\_DFLT\_ON OFF - wenn bei der Tabellenerstellung explizit angegeben wird, dass NULL Values zulässig sind, **_funktioniert_** es auch mit OFF


```sql
DROP Table if EXISTS [Table_1];
Alter Database [ANSI_TEST]  SET ANSI_NULL_DEFAULT OFF;
SET ANSI_NULL_DFLT_ON OFF;
Create Table Table_1 (Column_1 Int NULL)
INSERT INTO Table_1 (Column_1) VALUES (NULL);
Select * from [Table_1]
```

**<u>Beispiel 3:</u>** ANSI\_NULL\_DEFAULT OFF & ANSI\_NULL\_DFLT\_ON ON =\> ANSI\_NULL\_DFLT\_ON überschreibt ANSI\_NULL\_DEFAULT (**_funktioniert_**)


```sql
Alter Database [ANSI_TEST]  SET ANSI_NULL_DEFAULT OFF;
DROP TABLE Table_1
SET ANSI_NULL_DFLT_ON ON;
Create Table Table_1 (Column_1 Int)
INSERT INTO Table_1 (Column_1) VALUES (NULL);
Select * from Table_1
```

**<u>Beispiel 4:</u>** ANSI\_NULL\_DEFAULT ON & ANSI\_NULL\_DFLT\_ON OFF =\>  ANSI\_NULL\_DFLT\_ON wird ignoriert, da ANSI\_NULL\_DEFAULT ON (_**funktioniert nicht**_)


```sql
Alter Database [ANSI_TEST]  SET ANSI_NULL_DEFAULT ON;
DROP TABLE Table_1
SET ANSI_NULL_DFLT_ON OFF;
Create Table Table_1 (Column_1 Int)
INSERT INTO Table_1 (Column_1) VALUES (NULL);
```

**<u>Beispiel 5:</u>** ANSI\_NULL\_DEFAULT ON & ANSI\_NULL\_DFLT\_ON ON (**_funktioniert_**)


```sql
Alter Database [ANSI_TEST]  SET ANSI_NULL_DEFAULT ON;
DROP TABLE Table_1
SET ANSI_NULL_DFLT_ON ON;
Create Table Table_1 (Column_1 Int)
INSERT INTO Table_1 (Column_1) VALUES (NULL);
Select * from Table_1
```
