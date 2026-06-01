# EH2_Beispiele_UPDATE

**Quelle:** `T-SQL\08_Update\EH2_Beispiele_UPDATE.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 5  
**SQL-Zellen:** 4  

---

# Update

![](data:image/png;base64,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)


## Standard-Schreibweise


```sql
Select * from [Person].[Address_BAK] Where [AddressID] = 62 
/* Update eines bestimmten DS */
Update [Person].[Address_BAK]
Set [AddressLine1] = 'TEST'
Where [AddressID] = 62


Select * from [Person].[Address_BAK] Where [AddressID] = 62 
```

## Alternative Schreibweise (mit Alias)


```sql
Select * from [Person].[Address_BAK] Where [AddressID] = 62 
GO
-- andere unübliche Schreibweise
Update T
Set [AddressLine1] = '3841 Silver Oaks Place'
From [Person].[Address_BAK] as T
Where [AddressID] = 62
GO
Select * from [Person].[Address_BAK] Where [AddressID] = 62 
GO
```

## Update mehrere Spalten


```sql
Select * from [Person].[Address_BAK] Where [AddressID] = 62 
GO
Update [Person].[Address_BAK]
Set [AddressLine1] = 'TEST',
ModifiedDate = getdate()
Where [AddressID] = 62
Select * from [Person].[Address_BAK] Where [AddressID] = 62 
GO
```

## Update mit INNER JOIN


```sql
UPDATE [t] 
SET [t].[Addressline1] = [s].[Addressline1] ,
[t].[ModifiedDate] = getdate()
FROM [Person].[Address_BAK] as [s]
INNER JOIN [Person].[Address_BAK2] as [t] 
ON [s].[AddressID] = [t].[AddressID]
Where [t].[Addressline1] <> [s].[Addressline1] 
GO
Select * from [Person].[Address_BAK2] Where [AddressID] = 62 
GO
```
