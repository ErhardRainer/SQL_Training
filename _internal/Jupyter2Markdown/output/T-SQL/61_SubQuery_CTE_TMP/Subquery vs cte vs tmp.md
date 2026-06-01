# Subquery vs cte vs tmp

**Quelle:** `T-SQL\61_SubQuery_CTE_TMP\Subquery vs cte vs tmp.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 4  
**SQL-Zellen:** 3  

---

# CTE - Common Table Expression

## Allgemeines

\* eingeführt mit SQL Server 2015

## recursive CTE

Eine rekursive CTE ist eine CTE, die sich selbst referenziert. Hierbei wird die CTE wiederholt ausgeführt bis das ResultSet fertig ist.

![SQL Server Recursive CTE execution flow](https://www.sqlservertutorial.net/wp-content/uploads/SQL-Server-Recursive-CTE-execution-flow.png)


Für Hierachien:


```sql
USE [OLTP_Northwind]
GO
;With CTE_Org as (
Select [EmployeeID], [LastName] + ' ' + [FirstName] as [EmployeeName],  [ReportsTo]from [dbo].[Employees] where [ReportsTo] is null
union all
Select e.[EmployeeID], e.[LastName] + ' ' + e.[FirstName]  as [ManagerName], e.[ReportsTo] from [dbo].[Employees]  as e
inner join CTE_Org as o on o.EmployeeId = e.[ReportsTo])

Select * from CTE_Org
```

Fortlaufende summen / Consecutive Sum / Running Total


```sql
WITH  consecutive_number_sum (i, consecutive_sum) AS (
  SELECT 0, 0
  UNION ALL
  SELECT i + 1, (i + 1) + consecutive_sum
  FROM consecutive_number_sum
  WHERE i < 50
)
SELECT i, consecutive_sum
FROM consecutive_number_sum
```

## Wiederverwendbarkeit von CTE


```sql
USE [OLTP_Northwind]
GO
;With CTE as (
SELECT [EmployeeID]
      ,[LastName]
      ,[FirstName]
      ,[ReportsTo]
  FROM [dbo].[Employees])

Select c1.EmployeeID as [ManagerID], c1.LastName as [Manager_LastName], c1.Firstname as [Manager_FirstName]
, c2.EmployeeID as [EmployeeID],  c2.LastName as [Employee_LastName], c2.Firstname as [Employee_FirstName]
from CTE as c1
inner join CTE as c2
on c1.EmployeeID = c2.ReportsTo
```
