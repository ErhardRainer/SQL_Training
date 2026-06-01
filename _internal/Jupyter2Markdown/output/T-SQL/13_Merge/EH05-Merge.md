# EH05-Merge

**Quelle:** `T-SQL\13_Merge\EH05-Merge.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 9  
**SQL-Zellen:** 3  

---

# Merge

eingeführt SQL Server 2008

**<u>vereinfachte Syntax:</u>**

<span class="crayon-i" style="margin:0px;padding:0px;border:0px;vertical-align:baseline;font-family:inherit;color:rgb(0, 128, 128);">MERGE</span> <span class="crayon-k" style="margin:0px;padding:0px;border:0px;vertical-align:baseline;font-family:inherit;color:rgb(0, 0, 255);">TOP</span> <span class="crayon-sy" style="margin:0px;padding:0px;border:0px;vertical-align:baseline;font-family:inherit;color:rgb(51, 51, 51);">(</span><span class="crayon-k" style="margin:0px;padding:0px;border:0px;vertical-align:baseline;font-family:inherit;color:rgb(0, 0, 255);">value</span><span class="crayon-sy" style="margin:0px;padding:0px;border:0px;vertical-align:baseline;font-family:inherit;color:rgb(51, 51, 51);">)</span> <span class="crayon-o" style="margin:0px;padding:0px;border:0px;vertical-align:baseline;font-family:inherit;color:rgb(128, 128, 128);">&lt;</span><span class="crayon-i" style="margin:0px;padding:0px;border:0px;vertical-align:baseline;font-family:inherit;color:rgb(0, 128, 128);">target_table</span><span class="crayon-o" style="margin:0px;padding:0px;border:0px;vertical-align:baseline;font-family:inherit;"><font color="#808080">&gt;<br></font></span><span class="crayon-k" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">USING</span> <span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&lt;</span><span class="crayon-i" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 128, 128);">table_source</span><span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;"><font color="#808080">&gt;<br></font></span><span class="crayon-k" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">ON</span> <span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&lt;</span><span class="crayon-i" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 128, 128);">merge_search_condition</span><span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;"><font color="#808080">&gt;<br></font></span><span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">[</span> <span class="crayon-k" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">WHEN</span> <span class="crayon-i" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 128, 128);">MATCHED</span> <span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">[</span> <span class="crayon-k " style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">AND</span> <span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&lt;</span><span class="crayon-i" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 128, 128);">clause_search_condition</span><span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&gt;</span> <span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;"><font color="#333333">]<br></font></span><span class="crayon-k" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">THEN</span> <span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&lt;</span><span class="crayon-i" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 128, 128);">merge_matched</span><span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&gt;</span> <span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">]<br></span><span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">[</span> <span class="crayon-k" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">WHEN</span> <span class="crayon-k " style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">NOT</span> <span class="crayon-i" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 128, 128);">MATCHED</span> <span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">[</span> <span class="crayon-k" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">BY</span> <span class="crayon-i" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 128, 128);">TARGET</span> <span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">]</span> <span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">[</span> <span class="crayon-k " style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">AND</span> <span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&lt;</span><span class="crayon-i" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 128, 128);">clause_search_condition</span><span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&gt;</span> <span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;"><font color="#333333">]<br></font></span><span class="crayon-k" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">THEN</span> <span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&lt;</span><span class="crayon-i" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 128, 128);">merge_not_matched</span><span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&gt;</span> <span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">]<br></span><span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">[</span> <span class="crayon-k" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">WHEN</span> <span class="crayon-k " style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">NOT</span> <span class="crayon-i" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 128, 128);">MATCHED</span> <span class="crayon-k" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">BY</span> <span class="crayon-i" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 128, 128);">SOURCE</span> <span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">[</span> <span class="crayon-k " style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">AND</span> <span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&lt;</span><span class="crayon-i" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 128, 128);">clause_search_condition</span><span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&gt;</span> <span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;"><font color="#333333">]<br></font></span><span class="crayon-k" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">THEN</span> <span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&lt;</span><span class="crayon-i" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 128, 128);">merge_matched</span><span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&gt;</span> <span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">]<br></span><span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">[</span> <span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&lt;</span><span class="crayon-i" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 128, 128);">output_clause</span><span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&gt;</span> <span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">]<br></span><span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">[</span> <span class="crayon-k" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 0, 255);">OPTION</span> <span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">(</span> <span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&lt;</span><span class="crayon-i" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(0, 128, 128);">query_hint</span><span class="crayon-o" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(128, 128, 128);">&gt;</span> <span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">)</span> <span class="crayon-sy" style="font-family:inherit;margin:0px;padding:0px;border:0px;vertical-align:baseline;color:rgb(51, 51, 51);">]<br></span><span style="color:rgb(51, 51, 51);font-family:inherit;">;</span>

[https://docs.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql?view=sql-server-ver15](https://docs.microsoft.com/en-us/sql/t-sql/statements/merge-transact-sql?view=sql-server-ver15)

**<u>UseCase:</u>** Man hat eine neue Tabelle (Quelle) und man möche diese mit den bestehenden Daten (Target) abgleichen.  

Hierbei gibt es 3 Fälle:

- neue Datensätze (Quelle) sollen in der Zieltabelle (Target) ergänzt werden
- veraltete Datensätze (Target) sollen gelöscht werden, da sie in der Quelle (Source) nicht mehr vorkommen
- Datensaätze die sich verändert haben sollen entsprechend der Werte in der Quelle (Source) in der Zieltabelel (Target) aktualisiert werden.

![SQL Server MERGE](https://www.sqlservertutorial.net/wp-content/uploads/SQL-Server-MERGE.png)  

Grafik: [https://www.sqlservertutorial.net/sql-server-basics/sql-server-merge/](https://www.sqlservertutorial.net/sql-server-basics/sql-server-merge/)


**<u>Beispiel 1:</u>** Vorbereitung


```sql
USE MASTER
GO
DROP DATABASE IF EXISTS MERGETEST
GO
CREATE DATABASE MERGETEST
GO

USE MERGETEST
GO
-- TAbellen befüllen
-- Drop Table dbo.category
-- Drop Table dbo.category_staging
CREATE TABLE dbo.category (
    category_id INT PRIMARY KEY,
    category_name VARCHAR(255) NOT NULL,
    amount DECIMAL(10 , 2 )
);
 
INSERT INTO dbo.category(category_id, category_name, amount)
VALUES(1,'Children Bicycles',15000),
    (2,'Comfort Bicycles',25000),
    (3,'Cruisers Bicycles',13000),
    (4,'Cyclocross Bicycles',10000);
 
 
CREATE TABLE dbo.category_staging (
    category_id INT PRIMARY KEY,
    category_name VARCHAR(255) NOT NULL,
    amount DECIMAL(10 , 2 )
);
 
 
INSERT INTO dbo.category_staging(category_id, category_name, amount)
VALUES(1,'Children Bicycles',15000),
    (3,'Cruisers Bicycles',13000),
    (4,'Cyclocross Bicycles',20000),
    (5,'Electric Bikes',10000),
    (6,'Mountain Bikes',10000);
```

```sql
USE MERGETEST
GO
-- Tabellen ausgeben
Select * from dbo.category
Select * from dbo.category_staging
-- 2 fehlt in STAGING
-- 4 hat ungleiche Werte
-- 5+6 ins neu in STAGING
```

## Beispiel 1.1: Angleichen der category an die category\_staging

- Löschen von DS 2
- Update von DS 4
- Einfügen von DS 5,6

![SQL Server MERGE Example](https://www.sqlservertutorial.net/wp-content/uploads/SQL-Server-MERGE-Example.png)


**<u>Anmerkung:</u>**  
Mit "**Begin Transaction**" wird eine Transaktion gestartet  
und mit "**Rollback Transaction**" wieder zurückgerollt

Innerhalb der Transaktion gemachte Änderungen können so einfach wieder rückgängigemacht werden.


## Beispiel 1.2: Angleichen der category\_staging an die category

- Einfügen von DS 2
- Update von DS 4
- Löschen von DS 5,6


**<u>Beispiel 2:</u>** Vorbereitung


```sql
USE MASTER
GO
DROP DATABASE IF EXISTS MERGETEST2
GO
CREATE DATABASE MERGETEST2
GO

USE MERGETEST2
GO

Create table StudentSource
(
     ID int primary key,
     Name nvarchar(20)
)
GO

Insert into StudentSource values (1, 'Mike')
Insert into StudentSource values (2, 'Sara')
GO

Create table StudentTarget
(
     ID int primary key,
     Name nvarchar(20)
)
GO

Insert into StudentTarget values (1, 'Mike M')
Insert into StudentTarget values (3, 'John')
GO
```

![merge statement in sql server](https://3.bp.blogspot.com/-hHq_PK6YpP8/VCsOGkMMOGI/AAAAAAAAWEA/YY4dv-kAu-4/s1600/merge%2Bstatement%2Bin%2Bsql%2Bserver.png)


![merge in sql server 2008](https://2.bp.blogspot.com/-UnpkvliwSh4/VCsPCO_T5RI/AAAAAAAAWEI/NmbIEBr1Zp4/s1600/merge%2Bin%2Bsql%2Bserver%2B2008.png)


weiterführende Links:

- [https://www.sqlservertutorial.net/sql-server-basics/sql-server-merge/](https://www.sqlservertutorial.net/sql-server-basics/sql-server-merge/)
- [https://www.sqlshack.com/sql-server-merge-statement-overview-and-examples/](https://www.sqlshack.com/sql-server-merge-statement-overview-and-examples/)
- https://csharp-video-tutorials.blogspot.com/2014/09/part-69-merge-in-sql-server.html

