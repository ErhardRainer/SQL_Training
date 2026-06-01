# SQL-Row-Level-Security

**Quelle:** `T-SQL\62_Row_Level_Security\SQL-Row-Level-Security.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 29  
**SQL-Zellen:** 35  

---

# einfache Datenbank ohne Security

Steps:

1. Vorbereitung: Datenbank anlegen
2. 2 SQL User anlegen
3. Tabelle anlegen + Daten einfügen
4. Berechtigungen setzten


## (1) Vorbereitung: Datenbank anlegen


```sql
use master 
go
alter database [TEST_RLS_SQL]
set single_user with rollback immediate
GO
Drop DATABASE if exists [TEST_RLS_SQL]
GO
CREATE DATABASE [TEST_RLS_SQL]
GO
USE [TEST_RLS_SQL]
GO
```

## (2) SQL User anlegen


```sql
-- User 1: Uster mit eingeschränkten Rechten user_RLS_limited
CREATE LOGIN user_RLS_limited   
    WITH PASSWORD = '8fdKJl3$nlNv3049jsKK';  
GO

USE [TEST_RLS_SQL];  
GO

CREATE USER user_RLS_limited FOR LOGIN user_RLS_limited   
    WITH DEFAULT_SCHEMA = dbo; 
GO
```

```sql
-- User 2: User mit uneingeschränkten Rechten user_RLS_unlimited
CREATE LOGIN user_RLS_unlimited   
    WITH PASSWORD = '8fdKJl3$oiuioukljlkdj';  
GO

USE [TEST_RLS_SQL];  
GO

CREATE USER user_RLS_unlimited FOR LOGIN user_RLS_unlimited   
    WITH DEFAULT_SCHEMA = dbo; 
GO
```

```sql
-- Ausgabe der User der Datenbank
USE [TEST_RLS_SQL]
GO

SELECT name as username, create_date, 
       modify_date, type_desc as type
FROM sys.database_principals
WHERE type not in ('A', 'G', 'R', 'X')
      and sid is not null
      and name != 'guest'
```

## (3) Tabelle anlegen & Daten einfügen

Es wird nun eine Tabelle erstellt, die die Turnovers zu den Ländenr beinhaltet. Weiters hat die Tabelle einen PK und ist autoincrement.


```sql
USE [TEST_RLS_SQL]
GO

-- Löschen der Tabelle [dbo].[Turnover]
DROP TAble if EXISTS [dbo].[Turnover]
GO

-- Erstellen der Tabelle [dbo].[Turnover]
CREATE TABLE [dbo].[Turnover](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Country] [varchar](50) NULL,
	[Turnover] [decimal](18, 4) NULL,
 CONSTRAINT [PK_Turnover] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

```

```sql
-- Leeren der Tabelle
Truncate Table [dbo].[Turnover]
GO

-- Befüllen der Tabelle
INSERT INTO [dbo].[Turnover]([Country],[Turnover])
Values ('China', 157.8),('Russia',111.0),('Austria',1111),('Germany',9900)
Go 

-- Ausgabe der Tabelle
Select * from [dbo].[Turnover]
```

## (4) Berechtigungen setzen

So wie die SQL User derzeit angelegt sind, sehen sie zwar die Datenbank und können auf diese zugreifen, sehen aber darin keine Tabellen und auch sonst keine Objekte. Nun muss man Leserechte (SELECT) auf die Tabelle einräumen.

![](attachment:image.png)


```sql
GRANT SELECT ON dbo.Turnover TO user_RLS_limited;
GRANT SELECT ON dbo.Turnover TO user_RLS_unlimited;
```

Nun haben beide User uneingeschränkte Leserechte auf die Tabelle

![](attachment:image.png)


```sql
USE [TEST_RLS_SQL]
GO

EXEC sp_table_privileges   
   @table_name = 'Turnover'
Go  
```

# "Klassischer" Weg

Der Klassische Weg wäre es, dass man 

- eine Stored Procedure
- eine Table Valued Function 

um den Parameter @Username erweitert und danach filtert. 

In diesem Fall müsste man die Datenbank anders absichern, dass der der User selbst keine Rechte auf der Datenbank hat und die Kommunikation zwischen "Middleware" und Datenbank mittels Serviceuser passiert. Weiters muss sichergestellt werden, dass der übergebenen User nicht beeinflusst werden kann und dem tatsächlichen User des Frontends entspricht.


**<u>Ziel:</u>** Einschränkung von "user\_RLS\_limited" auf "Germany"; "user\_RLS\_unlimited" darf alles sehen.


```sql
DROP PROCEDURE if EXISTS dbo.usp_Turnover
GO

cREATE PROCEDURE dbo.usp_Turnover (@username as VARCHAR(50))
AS
BEGIN
	SET NOCOUNT ON;
	SELECT [ID]
      ,[Country]
      ,[Turnover] 
	  from [dbo].[Turnover]
	    WHERE ([Country] = 'Germany' and @username = 'user_RLS_limited')
	    OR (@username = 'user_RLS_unlimited');
END
GO

```

```sql
EXEC dbo.usp_Turnover @username = 'user_RLS_unlimited';
EXEC dbo.usp_Turnover @username = 'user_RLS_limited';
```

# Erweiterung um ein Filter Predicate (simple)

Nun ist es Ziel den Zugriff von user "user\_RLS\_limited" auf "Germany" einzuschräken und den zweiten User "user\_RLS\_unlimited" weiter uneingeschränkte Rechte zu gewähren.

Hierzu sind folgende Schritte notwendig:

(1) Erstellen einer Inline Table-Valued Function (Predicate Function) in der Form eines Filter Predicates

(2) Erstellen einer Security Policy


![](https://erhard-rainer.com/wp-content/uploads/2022/06/sql-server-2016-row-level-security-04.png)


## (1) Erstellen eines Filter Predicates

Die Funktion liefert 1 zurück, wenn .. erfüllt ist.

- @Country = 'Germany' & user = 'user\_RLS\_limited'
- der User 'user\_RLS\_unlimited'


```sql
Drop FUNCTION if EXISTS dbo.tvf_Tunover_Security1;
GO
CREATE FUNCTION dbo.tvf_Tunover_Security1(@Country as VARCHAR(50))
    RETURNS TABLE
WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS tvf_Tunover_Security1_Result
    -- Logic for filter predicate
    WHERE (@Country = 'Germany' and USER_NAME() = 'user_RLS_limited')
    OR (USER_NAME() = 'user_RLS_unlimited');
GO
```

## (2) Erstellen des Security Policy

![Parts of Row Level Security](https://sqlhints.com/wp-content/uploads/2016/01/Parts-of-Row-Level-Security.jpg)  

Quelle: https://sqlhints.com/tag/block-predicate/


```sql
CREATE SECURITY POLICY TurnoverFilter1  
ADD FILTER PREDICATE dbo.tvf_Tunover_Security1([Country])
ON dbo.Turnover
WITH (STATE = ON);  
GO
```

```sql
-- Security Policy deaktivieren
ALTER SECURITY POLICY TurnoverFilter1
WITH (STATE = OFF); 
```

# Erweiterung um ein Filter Predicate (Berechtigungen direkt in der Tabelle)

In der ersten Ausbaustufe ist die Logik des Filter Predicates direkt in der Funktion beheimatet. In der nächsten Ausbaustufe kommt eine Spalte User hinzu über die gesteuert wird, welcher User Zugriff auf die Zeile hat. Für den User mit uneingeschränkten Rechten muss die Logik in weiter in der Funktion sein. 

Nachteil dieser Vorgehensweise hat jedoch den Nachteil, dass nur ein Benutzer pro Zeile berechtigt werden kann.


## (0) Vorbereitung: Tabelle + Daten


```sql
-- Erweitern der TAbelle um eine Spalte 'Username'
ALTER TABLE dbo.Turnover
ADD username nvarchar(255);
```

```sql
-- Befüllen der Spalte 'Username'
Update dbo.Turnover
Set username = 'user_RLS_limited'
where Country = 'Germany'

Select * from dbo.Turnover
```

## (1) Erstellen eines Filter Predicates

Die Funktion liefert 1 zurück, wenn .. erfüllt ist.

- @Country = 'Germany' & user = 'user\_RLS\_limited'
- der User 'user\_RLS\_unlimited'


```sql
Drop FUNCTION if EXISTS dbo.tvf_Tunover_Security2;
GO
CREATE FUNCTION dbo.tvf_Tunover_Security2(@username as VARCHAR(50))
    RETURNS TABLE
WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS tvf_Tunover_Security2_Result
    -- Logic for filter predicate
    WHERE (USER_NAME() = @username)
    OR (USER_NAME() = 'user_RLS_unlimited');
GO
```

## (2) Erstellen des Security Policy


```sql
CREATE SECURITY POLICY TurnoverFilter2  
ADD FILTER PREDICATE dbo.tvf_Tunover_Security2([username])
ON dbo.Turnover
WITH (STATE = ON);  
GO
```

```sql
-- Security Policy löschen
Drop SECURITY POLICY TurnoverFilter2
```

## Exkurs: mehrere User pro Zeile berechtigen


Es gibt für die Einschränkung, dass nur ein Benutzer pro Zeile berechtigt werden kann, eine Lösung, wenngleich ich tunlichst davon abrate.


```sql
Update dbo.Turnover
Set username = null
GO

Update dbo.Turnover
Set username = 'user_RLS_limited'
where Country = 'Germany'
GO

UPDATE dbo.Turnover 
Set username = case when [username] is null then 'user_RLS_unlimited' else [username] + '|' + 'user_RLS_unlimited' end 

Select * from dbo.Turnover
```

```sql
Drop FUNCTION if EXISTS dbo.tvf_Tunover_Security2;
GO
CREATE FUNCTION dbo.tvf_Tunover_Security2(@username as VARCHAR(50))
    RETURNS TABLE
WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS tvf_Tunover_Security2_Result
    -- Logic for filter predicate
    WHERE (USER_NAME() in (Select Value from string_split(@username,'|')))
GO
```

```sql
CREATE SECURITY POLICY TurnoverFilter2  
ADD FILTER PREDICATE dbo.tvf_Tunover_Security2([username])
ON dbo.Turnover
WITH (STATE = ON);  
GO
```

## Nacharbeiten: Tabelle bereinigen


```sql
-- Security Policy löschen
DROP SECURITY POLICY if EXISTS [dbo].[TurnoverFilter2]
-- Function löschen
Drop FUNCTION if EXISTS dbo.tvf_Tunover_Security2;
```

```sql
-- Spalte wieder löschen
ALTER TABLE dbo.Turnover
Drop COLUMN username;
```

# Erweiterung um ein Filter Predicate (mit Config-Tabelle)

Da die zuletzt beschreibene Methode mit mehrerne Usern in einem Feld nicht empfehlenswert hinsichtlich Performance ist,  braucht man eine schneller Methode. 

1. Hierzu legen wir eine zusätzliche Tabelle an \[dbo\].\[Permissions\]
2. danach erstellen wir ein Filter Predicate 
3. und eine Security Policy


## Vorbereitung: Setzen der Berechtigungen

Über eine weitere Tabelle \[dbo\].\[Permissions\] sollen die Rechte gesteuert werden. Grundsätzlich soll der user "user\_RLS\_limited" nur Germany sehen dürfen und der User User 'user\_RLS\_unlimited' soll alles sehen dürfen. Die Rechte von user\_RLS\_unlimited soll aber nicht über die Tabelle sondern über den Filter Predicate gesteuert werden.


```sql
DROP TAble if EXISTS [dbo].[Permisisons]
GO

CREATE TABLE [dbo].[Permisisons](
    [Country] [varchar](50) not NULL,
    [Username] [varchar](50) not null
)
```

```sql
Truncate Table [dbo].[Permisisons]
GO
Insert into [dbo].[Permisisons](Country,Username)
Values ('Germany','user_RLS_limited')
```

## (1) Erstellen eines Filter Predicates

Die Funktion liefert 1 zurück, wenn .. erfüllt ist.

- @Country = 'Germany' & user = 'user\_RLS\_limited'
- der User 'user\_RLS\_unlimited'


```sql
-- Möglichkeit 1
Drop FUNCTION if EXISTS dbo.tvf_Tunover_Security3;
GO
CREATE FUNCTION dbo.tvf_Tunover_Security3(@Country as VARCHAR(50))
    RETURNS TABLE
WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS tvf_Tunover_Security3_Result
    -- Logic for filter predicate
    WHERE (@Country in (Select [Country] from [dbo].[Permisisons] where [Username] = USER_NAME()))
    OR (USER_NAME() = 'user_RLS_unlimited');
GO
```

```sql
-- Möglichkeit 2 -- funktioniert 
Drop SECURITY POLICY if exists TurnoverFilter3
GO
Drop FUNCTION if EXISTS dbo.tvf_Tunover_Security3;
GO
CREATE FUNCTION dbo.tvf_Tunover_Security3(@Country as VARCHAR(50))
    RETURNS TABLE
WITH SCHEMABINDING
AS
    RETURN (SELECT 1 AS tvf_Tunover_Security3_Result
    from dbo.Turnover as t
    inner join dbo.Permisisons as p 
    on t.Country = p.Country 
    Where p.Username = USER_NAME()
    and t.Country = @Country);
GO
```

## (2) Erstellen des Security Policy


```sql
Drop SECURITY POLICY if exists TurnoverFilter1
Drop SECURITY POLICY if exists TurnoverFilter3
GO
CREATE SECURITY POLICY TurnoverFilter3
ADD FILTER PREDICATE dbo.tvf_Tunover_Security3([Country])
ON dbo.Turnover
WITH (STATE = ON);  
GO
```

# Limitieren der Schreibrechte

BLOCK Predicates funktionieren ähnlich den FILTER PREDICATES, was dazu führt, dass man bereits entwickelte FILTER PREDICATES wiederverwenden kann.

Beispiel ohen konkrete Einschränkung auf eine Operation

```
CREATE SECURITY POLICY Security.userAccessPolicy
 ADD FILTER PREDICATE Security.userAccessPredicate(UserId) ON dbo.MyTable,
 ADD BLOCK PREDICATE Security.userAccessPredicate(UserId) ON dbo.MyTable
```


Wenn keine Operation festgelegt wird, wirkt sich auf jeder Operation aus. Man kann aber auch den Block Predicate auf einzelne Operationen einschränken:

- AFTER INSERT and AFTER UPDATE - prüft gegen die neue Zeile
- BEFORE UPDATE and BEFORE DELETE - prüft gegen die alte Zeile

```
CREATE SECURITY POLICY Security.tenantPolicy
 ADD FILTER PREDICATE Security.tenantAccessPredicate(TenantId) ON dbo.Sales,
 ADD BLOCK PREDICATE Security.tenantAccessPredicate(TenantId) ON dbo.Sales AFTER INSERT
go
```


Anmerkung:  

- Wird ein Filter-predicate verwendet, benötigt man keine BEFORE UPDATE oder BEFORE DELETE Block Predicate. 
- Hat man eine Spalten Permission, benötigt man auch keinen AFTER UPDATE


## INSERT, UPDATE , DELTE


```sql
DROP SECURITY POLICY IF EXISTS [dbo].[TurnoverFilter1]
DROP SECURITY POLICY IF EXISTS [dbo].[TurnoverFilter2]
DROP SECURITY POLICY IF EXISTS [dbo].[TurnoverFilter3]
DROP SECURITY POLICY IF EXISTS [dbo].[TurnoverFilter5]

Drop Function if exists [dbo].[tvf_Tunover_Security1]
Drop Function if exists [dbo].[tvf_Tunover_Security2]
Drop Function if exists [dbo].[tvf_Tunover_Security3]
Drop Function if exists [dbo].[tvf_Tunover_Security5]


CREATE FUNCTION [dbo].[tvf_Tunover_Security5](@Country as VARCHAR(50))
    RETURNS TABLE
WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS tvf_Tunover_Security5_Result
    -- Logic for filter predicate
    WHERE (@Country in (Select [Country] from [dbo].[Permisisons] where [Username] = USER_NAME()))
    OR (USER_NAME() = 'user_RLS_unlimited');
GO

CREATE SECURITY POLICY [dbo].[TurnoverFilter5]
 ADD FILTER PREDICATE [dbo].[tvf_Tunover_Security5]([Country]) ON [dbo].[Turnover],
 ADD BLOCK PREDICATE [dbo].[tvf_Tunover_Security5]([Country]) ON [dbo].[Turnover] 
go

```

```sql
GRANT INSERT ON dbo.Turnover TO user_RLS_limited;
GRANT DELETE ON dbo.Turnover TO user_RLS_limited;
GRANT UPDATE ON dbo.Turnover TO user_RLS_limited;
```

## UPDATE, DELETE


```sql
-- auszuführen mit einem User mit eingeschränkten Rechten
-- FILTER PREDICATE => nur Germany
Select * from [dbo].[Turnover]
-- nicht zulässig, da 'Austria'
INSERT INTO [dbo].[Turnover]([Country],[Turnover])
Values ('Austria','1558')

-- zulässig, da 'Germany'
INSERT INTO [dbo].[Turnover]([Country],[Turnover])
Values ('Germany','1558')

-- Ausgabe
Select * from [dbo].[Turnover]

-- zulässig, aber 0 rows affected, da die anderen nicht sichbar für den User sind
Delete [dbo].[Turnover]
Where Country = 'Austria'

-- zulässig
Delete [dbo].[Turnover]
Where Turnover = 1558.0000
and Country = 'Germany'

-- nichts passiert, da dieser Datensatz nicht für user sichtbar
Update [dbo].[Turnover]
Set Turnover = 100000
where ID = 3
-- ok, da es sich um einen Germany DS handelt
Update [dbo].[Turnover]
Set Turnover = 500
where ID = 4

```

```sql
DROP SECURITY POLICY IF EXISTS [dbo].[TurnoverFilter1]
DROP SECURITY POLICY IF EXISTS [dbo].[TurnoverFilter2]
DROP SECURITY POLICY IF EXISTS [dbo].[TurnoverFilter3]
DROP SECURITY POLICY IF EXISTS [dbo].[TurnoverFilter5]

Drop Function if exists [dbo].[tvf_Tunover_Security1]
Drop Function if exists [dbo].[tvf_Tunover_Security2]
Drop Function if exists [dbo].[tvf_Tunover_Security3]
Drop Function if exists [dbo].[tvf_Tunover_Security5]


CREATE FUNCTION [dbo].[tvf_Tunover_Security5](@Country as VARCHAR(50))
    RETURNS TABLE
WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS tvf_Tunover_Security5_Result
    -- Logic for filter predicate
    WHERE (@Country in (Select [Country] from [dbo].[Permisisons] where [Username] = USER_NAME()))
    OR (USER_NAME() = 'user_RLS_unlimited');
GO

CREATE SECURITY POLICY [dbo].[TurnoverFilter5]
 ADD FILTER PREDICATE [dbo].[tvf_Tunover_Security5]([Country]) ON [dbo].[Turnover],
 ADD BLOCK PREDICATE [dbo].[tvf_Tunover_Security5]([Country]) ON [dbo].[Turnover] Before Update,
 ADD BLOCK PREDICATE [dbo].[tvf_Tunover_Security5]([Country]) ON [dbo].[Turnover] Before Delete
go
```

```sql

GRANT INSERT ON dbo.Turnover TO user_RLS_limited;
GRANT DELETE ON dbo.Turnover TO user_RLS_limited;
GRANT UPDATE ON dbo.Turnover TO user_RLS_limited;
```

```sql
-- auszuführen mit einem User mit eingeschränkten Rechten
-- FILTER PREDICATE => nur Germany
Select * from [dbo].[Turnover]
-- zulässig, da kein AFTER IMPORT
INSERT INTO [dbo].[Turnover]([Country],[Turnover])
Values ('Austria','1558')

-- zulässig, da 'Germany'
INSERT INTO [dbo].[Turnover]([Country],[Turnover])
Values ('Germany','1558')

-- Ausgabe
Select * from [dbo].[Turnover]

-- zulässig, aber 0 rows affected, da die anderen nicht sichbar für den User sind
Delete [dbo].[Turnover]
Where Country = 'Austria'

-- zulässig
Delete [dbo].[Turnover]
Where Turnover = 1558.0000
and Country = 'Germany'

-- nichts passiert, da dieser Datensatz nicht für user sichtbar
Update [dbo].[Turnover]
Set Turnover = 100000
where ID = 3
-- ok, da es sich um einen Germany DS handelt
Update [dbo].[Turnover]
Set Turnover = 500
where ID = 4
```

# Datenbank löschen


```sql
use master 
go
alter database [TEST_RLS_SQL]
set single_user with rollback immediate
GO
Drop DATABASE if exists [TEST_RLS_SQL]
GO
```
