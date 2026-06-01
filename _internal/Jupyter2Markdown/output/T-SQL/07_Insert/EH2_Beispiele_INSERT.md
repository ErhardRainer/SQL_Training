# EH2_Beispiele_INSERT

**Quelle:** `T-SQL\07_Insert\EH2_Beispiele_INSERT.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 6  
**SQL-Zellen:** 3  

---

# INSERT DATA

![](data:image/png;base64,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)


## Einfügen einzelner Werte


## Abfragen übertragen - INSERT INTO - SELECT


**<u>Achtung:</u>** bei Calculated Columns & Autoincrement Spalten

Befüllen einer Identity-Spalte geht grds. nicht, wenn IDENTITY\_INSERT is set to OFF.


## Übertragen von Tabellen ohne, dass diese existieren - SELECT INTO


```sql
Drop Table if exists [Person].[Address_BAK]
GO
select [AddressID]
      ,[AddressLine1]
      ,[AddressLine2]
      ,[City]
      ,[StateProvinceID]
      ,[PostalCode]
      ,[SpatialLocation]
      ,[rowguid]
      ,[ModifiedDate] 
into [Person].[Address_BAK]
from [Person].[Address]
GO
Select * from [Person].[Address_BAK]
```

```sql
Drop Table if exists [Person].[Address_BAK]
GO
select [AddressID] as [AddrID]
      ,[AddressLine1] as [AddL1]
      ,[AddressLine2]
      ,[City] 
      ,[StateProvinceID]
      ,[PostalCode] as [PLZ]
   --   ,[SpatialLocation]
    --  ,[rowguid]
      ,[ModifiedDate] 
into [Person].[Address_BAK]
from [Person].[Address]
GO
Select * from [Person].[Address_BAK]
```

## Übertragen einer leeren Tabelle - SELECT TOP 0 INTO

Will man nicht die Tabelle mit den gesamten Inhalt übertragen, sondern nur eine leere Kopie der Tabelle anlegen.


```sql
Drop Table if exists [Person].[Address_BAK]
GO
select Top 0 [AddressID]
      ,[AddressLine1]
      ,[AddressLine2]
      ,[City]
      ,[StateProvinceID]
      ,[PostalCode]
      ,[SpatialLocation]
      ,[rowguid]
      ,[ModifiedDate] 
into [Person].[Address_BAK]
from [Person].[Address]
GO
Select * from [Person].[Address_BAK]
```
