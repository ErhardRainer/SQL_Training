# EH3_ANSI_NULL

**Quelle:** `T-SQL\17_ANSI_NULL & Co\EH3_ANSI_NULL.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 7  
**SQL-Zellen:** 2  

---

# ANSI NULL

spezifiziert das ISO compliant Verhalten von = und \<\> in Bezug auf NULL Values <mark>(Standard 1 | ON)</mark>

- ANSI\_NULL OFF = 0 =\> \<\> & = funktioniert mit NULL
- ANSI\_NULL ON = 1 =\> \<\> & = funktioniert nicht mit NULL


```sql
USE master
GO
Drop Database if exists [ANSI_NULL_TEST]
CREATE DATABASE [ANSI_NULL_TEST]
GO
Alter Database [ANSI_NULL_TEST]  SET ANSI_NULL_DEFAULT ON;
GO
```

Vorbereitung: eine neue Tabelel \[Table\_1\] mit 2 Werten, wovon einer ein NULL-Value ist


```sql
USE [ANSI_NULL_TEST]
GO
Drop Table if EXISTS [Table_1]
Create Table Table_1 (Column_1 varchar(100) NULL)
INSERT INTO Table_1 (Column_1) VALUES (NULL);
INSERT INTO Table_1 (Column_1) VALUES ('Test');
Select * from Table_1
```

**<u>Beispiel 1:</u>** Wenn ANSI\_NULL <mark>ON</mark> gestellt, wird NULL nicht wie ein richiger Wert behandelt

Dh. = NULL und \<\> NULL funktionieren nicht


**<u>Beispiel 2:</u>** Wenn ANSI\_NULL <mark>OFF</mark> gestellt, wird NULL nicht wie ein richiger Wert behandelt

Dh. = NULL und \<\> NULL funktionieren


**<u>WICHTIG:</u>** Was immer geht - unabhängig von ANSI\_NULLS Settings


<span style="color: rgb(82, 89, 96); font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-size: 15px; background-color: rgb(255, 255, 255);">In a future version of SQL Server, ANSI_NULLS will always be ON and any applications that explicitly set the option to OFF will produce an error. Avoid using this feature in new development work, and plan to modify applications that currently use this feature. (Quelle:&nbsp;</span> <span style="font-size: 15px;">https://sqlenlight.com/support/help/sa0207/)</span>


| Boolean Expression | SET ANSI\_NULLS ON | SET ANSI\_NULLS OFF |
| --- | --- | --- |
| NULL = NULL | UNKNOWN | TRUE |
| 1 = NULL | UNKNOWN | FALSE |
| NULL \<\> NULL | UNKNOWN | FALSE |
| 1 \<\> NULL | UNKNOWN | TRUE |
| NULL \> NULL | UNKNOWN | UNKNOWN |
| 1 \> NULL | UNKNOWN | UNKNOWN |
| NULL IS NULL | TRUE | TRUE |
| 1 IS NULL | FALSE | FALSE |
| NULL IS NOT NULL | FALSE | FALSE |
| 1 IS NOT NULL | TRUE | TRUE |

Quelle: https://docs.microsoft.com/en-us/sql/t-sql/statements/set-ansi-nulls-transact-sql?redirectedfrom=MSDN&view=sql-server-ver15

