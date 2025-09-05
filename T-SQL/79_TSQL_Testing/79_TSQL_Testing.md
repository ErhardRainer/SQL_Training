# T-SQL – Unit-Testing mit tSQLt – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| **tSQLt** | Open-Source-Framework für Unit-Tests direkt in T-SQL; Tests sind Stored Procedures, gruppiert in **Testklassen** (Schemas). |
| **Testklasse (`tSQLt.NewTestClass`)** | Erstellt ein Schema als Container für Tests und Hilfsobjekte. Test-Prozeduren müssen mit `test` beginnen. |
| **Testausführung (`tSQLt.Run`, `tSQLt.RunAll`)** | Führt Tests einer Klasse bzw. alle Tests aus; optional mit konfigurierbarem Ergebnis-Formatter. |
| **`SetUp`-Prozedur (klassenspezifisch)** | Optionale Prozedur in der Testklasse; wird **vor jedem** Test der Klasse ausgeführt (Arrange-Teil vorbereiten). |
| **AAA-Muster** | **Arrange–Act–Assert**: Testdaten und Doubles vorbereiten, Code ausführen, Ergebnis prüfen. |
| **Transaktion/Rollback pro Test** | Jeder Test läuft in einer eigenen Transaktion und wird am Ende zurückgerollt → isolierte, wiederholbare Tests. |
| **Assertions** | Prüf-APIs wie `tSQLt.AssertEquals`, `...AssertEqualsTable`, `...AssertEmptyTable`, `...AssertLike`, `...Fail`. |
| **Erwartungen** | Fehlerverhalten prüfen mit `tSQLt.ExpectException` bzw. `tSQLt.ExpectNoException`. |
| **`tSQLt.FakeTable`** | Ersetzt eine Tabelle temporär durch eine leere Version ohne Constraints (Isolation von DML/Views). |
| **`tSQLt.ApplyConstraint` / `tSQLt.ApplyTrigger`** | Fügt **gezielt** einen Constraint bzw. Trigger zur gefakten Tabelle hinzu, um ihn isoliert zu testen. |
| **`tSQLt.SpyProcedure`** | Ersetzt eine Prozedur durch einen „Spy“, der Aufrufe/Parameter protokolliert (Verhaltensprüfung ohne Seiteneffekte). |
| **`tSQLt.FakeFunction`** | Ersetzt eine Funktion (z. B. Wrapper um `GETDATE()`) durch eine einfache Fake-Variante mit determinierter Rückgabe. |
| **Mehr-Resultsets** | `tSQLt.ResultSetFilter` extrahiert ein bestimmtes Resultset; `AssertResultSetsHaveSameMetaData` vergleicht Metadaten. |
| **Ergebnis-Formatter** | Ausgabe als Text oder XML/JUnit-kompatibel, z. B. via `SetTestResultFormatter` / `XmlResultFormatter` → CI/CD. |
| **Installation (Quick Start)** | Bereitstellung via Skripte (z. B. `PrepareServer.sql`, `tSQLt.class.sql`) in der **Dev**-Datenbank. |
| **Deinstallation** | `tSQLt.Uninstall` entfernt alle tSQLt-Objekte aus der Datenbank. |
| **Tool-Integrationen** | Z. B. Redgate SQL Test, JetBrains DataGrip, SSDT/DevOps, Flyway – erleichtern Ausführung/Reporting. |

---

## 2 | Struktur

### 2.1 | Setup & Installation (Dev-Datenbank)
> **Kurzbeschreibung:** tSQLt für die Entwicklungsdatenbank einrichten (Server vorbereiten, Framework installieren), erster Testlauf.

- 📓 **Notebook:**  
  [`08_01_tsqlt_setup_install.ipynb`](08_01_tsqlt_setup_install.ipynb)

- 🎥 **YouTube:**  
  - [Unit Testing in SQL Server with tSQLt (Redgate)](https://www.youtube.com/watch?v=byf7QRCtOu0)  
  - [SQL Server Database Unit Testing in your DevOps pipeline](https://www.youtube.com/watch?v=t3Lc9LRDZQ4)

- 📘 **Docs:**  
  - [tSQLt – Quick Start](https://tsqlt.org/user-guide/quick-start/)  
  - [tSQLt – Home/Überblick](https://tsqlt.org/)

---

### 2.2 | Testklassen & Testprozeduren (Namenskonventionen, Ausführung)
> **Kurzbeschreibung:** Tests als Stored Procedures in Klassen; `SetUp`-Hook, `tSQLt.Run`/`RunAll`, Benennung `test …`.

- 📓 **Notebook:**  
  [`08_02_tsqlt_klassen_und_tests.ipynb`](08_02_tsqlt_klassen_und_tests.ipynb)

- 🎥 **YouTube:**  
  - [Get testing with tSQLt – Steve Jones](https://www.youtube.com/watch?v=3MZOvTN9ZGE)  
  - [Start to See With tSQLt (SQLBits)](https://www.youtube.com/watch?v=tDKVMLOgCvc)

- 📘 **Docs:**  
  - [`tSQLt.NewTestClass`](https://tsqlt.org/user-guide/test-creation-and-execution/newtestclass/)  
  - [`tSQLt.Run` & `tSQLt.RunAll`](https://tsqlt.org/user-guide/test-creation-and-execution/run/)

---

### 2.3 | AAA-Muster & Basis-Assertions
> **Kurzbeschreibung:** Arrange–Act–Assert sauber trennen; Werte prüfen mit `AssertEquals`, Strings mit `AssertEqualsString`, Muster mit `AssertLike`.

- 📓 **Notebook:**  
  [`08_03_arrange_act_assert_assertions.ipynb`](08_03_arrange_act_assert_assertions.ipynb)

- 🎥 **YouTube:**  
  - [Effective Unit Testing for SQL Server (G. Campbell)](https://www.youtube.com/watch?v=zF6tmUwwkuo)  
  - [T-SQL Stored Procedures Unit Testing – Teil 1](https://www.youtube.com/watch?v=2owQtxW7a20)

- 📘 **Docs:**  
  - [Assertions – Übersicht](https://tsqlt.org/user-guide/assertions/)  
  - [`tSQLt.AssertEquals`](https://tsqlt.org/user-guide/assertions/assertequals/)

---

### 2.4 | Set-Prüfungen: Tabelleninhalt & Schema vergleichen
> **Kurzbeschreibung:** Ergebnismengen robust prüfen: `AssertEqualsTable` (Daten), `AssertEmptyTable` (leer?), `AssertEqualsTableSchema` (Struktur).

- 📓 **Notebook:**  
  [`08_04_assert_tablevergleich.ipynb`](08_04_assert_tablevergleich.ipynb)

- 🎥 **YouTube:**  
  - [Code Coverage Using tSQLt and SQLCop](https://www.youtube.com/watch?v=K-uwdqAghVM)  
  - [Start to See With tSQLt (SQLBits)](https://www.youtube.com/watch?v=tDKVMLOgCvc)

- 📘 **Docs:**  
  - [`AssertEqualsTable`](https://tsqlt.org/user-guide/assertions/assertequalstable/)  
  - [`AssertEmptyTable`](https://tsqlt.org/user-guide/assertions/assertemptytable/) / [`AssertEqualsTableSchema`](https://tsqlt.org/user-guide/assertions/assertequalstableschema/)

---

### 2.5 | Abhängigkeiten isolieren: Fakes & Spies
> **Kurzbeschreibung:** Seiteneffekte abkoppeln: `FakeTable` (Constraints loslösen), `FakeFunction` (deterministische Zeit/Werte), `SpyProcedure` (Aufrufe protokollieren).

- 📓 **Notebook:**  
  [`08_05_isolation_fakes_spies.ipynb`](08_05_isolation_fakes_spies.ipynb)

- 🎥 **YouTube:**  
  - [How to Incorporate TDD with tSQLt](https://www.youtube.com/watch?v=3miDKOU-7Mw)  
  - [Unit Testing in SQL Server with tSQLt (Redgate)](https://www.youtube.com/watch?v=byf7QRCtOu0)

- 📘 **Docs:**  
  - [`FakeTable`](https://tsqlt.org/user-guide/isolating-dependencies/faketable/) / [`FakeFunction`](https://tsqlt.org/user-guide/isolating-dependencies/fakefunction/)  
  - [`SpyProcedure`](https://tsqlt.org/user-guide/isolating-dependencies/spyprocedure/)

---

### 2.6 | Fehlerfälle testen: `ExpectException` & `ExpectNoException`
> **Kurzbeschreibung:** Negative/positive Pfade sicher prüfen: erwartete Fehler ab Testzeitpunkt zulassen bzw. Fehlerfreiheit sicherstellen.

- 📓 **Notebook:**  
  [`08_06_expect_exception.ipynb`](08_06_expect_exception.ipynb)

- 🎥 **YouTube:**  
  - [Unleashing Confidence in SQL Development through Unit Testing](https://www.youtube.com/watch?v=YRVTWwFFd8c)  
  - [Get testing with tSQLt – Steve Jones](https://www.youtube.com/watch?v=3MZOvTN9ZGE)

- 📘 **Docs:**  
  - [`ExpectException`](https://tsqlt.org/user-guide/expectations/expectexception/)  
  - [`ExpectNoException`](https://tsqlt.org/user-guide/expectations/expectnoexception/)

---

### 2.7 | DDL-Objekte gezielt testen: Constraints & Trigger
> **Kurzbeschreibung:** Mit `FakeTable` neutralisieren, danach gezielt `ApplyConstraint`/`ApplyTrigger` hinzufügen und Verhalten isoliert prüfen.

- 📓 **Notebook:**  
  [`08_07_constraints_trigger_testing.ipynb`](08_07_constraints_trigger_testing.ipynb)

- 🎥 **YouTube:**  
  - [Unit Testing in SQL Server with tSQLt (Redgate)](https://www.youtube.com/watch?v=byf7QRCtOu0)  
  - [SQL Server Database Unit Testing in your DevOps pipeline](https://www.youtube.com/watch?v=t3Lc9LRDZQ4)

- 📘 **Docs:**  
  - [`ApplyConstraint`](https://tsqlt.org/user-guide/isolating-dependencies/applyconstraint/)  
  - [`ApplyTrigger`](https://tsqlt.org/user-guide/isolating-dependencies/applytrigger/)

---

### 2.8 | Mehrere Resultsets prüfen
> **Kurzbeschreibung:** Einzelne Resultsets extrahieren/prüfen (z. B. Systemprozeduren): `ResultSetFilter` und `AssertResultSetsHaveSameMetaData`.

- 📓 **Notebook:**  
  [`08_08_resultset_testing.ipynb`](08_08_resultset_testing.ipynb)

- 🎥 **YouTube:**  
  - [Master Database Unit Testing for SQL Server](https://www.youtube.com/watch?v=MxWC17XypA8)  
  - [Effective Unit Testing for SQL Server](https://www.youtube.com/watch?v=zF6tmUwwkuo)

- 📘 **Docs:**  
  - [`ResultSetFilter` (Artikel)](https://tsqlt.org/201/using-tsqlt-resultsetfilter/)  
  - [Assertions – `AssertResultSetsHaveSameMetaData`](https://tsqlt.org/user-guide/assertions/)

---

### 2.9 | Testausgabe & CI/CD (Formatter, XML/JUnit, Tools)
> **Kurzbeschreibung:** Testergebnisse als Text/XML ausgeben, in Pipelines einsammeln; Run-APIs, `SetTestResultFormatter`, `XmlResultFormatter`, Tool-Integrationen.

- 📓 **Notebook:**  
  [`08_09_run_report_cicd.ipynb`](08_09_run_report_cicd.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Database Unit Testing in your DevOps pipeline](https://www.youtube.com/watch?v=t3Lc9LRDZQ4)  
  - [Workflow mit tSQLt & SQL Change Automation](https://www.youtube.com/watch?v=IxY08HC8dZg)

- 📘 **Docs:**  
  - [`Run`/`RunAll` + Formatter-Hinweise](https://tsqlt.org/user-guide/test-creation-and-execution/run/)  
  - [CI-Integration/Formatter (Release Notes & Blog)](https://tsqlt.org/121/tsqlt-build-7-release-notes/)

---

### 2.10 | Best Practices & Patterns
> **Kurzbeschreibung:** Deterministische Tests (Zeit/IDs), Datenfabriken, kleine fokussierte Tests, Views/TVFs isolieren (`SetFakeViewOn`-Pattern), „Given–When–Then“.

- 📓 **Notebook:**  
  [`08_10_best_practices.ipynb`](08_10_best_practices.ipynb)

- 🎥 **YouTube:**  
  - [Start to See With tSQLt (SQLBits)](https://www.youtube.com/watch?v=tDKVMLOgCvc)  
  - [Unit Testing in SQL Server with tSQLt (Redgate)](https://www.youtube.com/watch?v=byf7QRCtOu0)

- 📘 **Docs:**  
  - [tSQLt Tutorial (End-to-End)](https://tsqlt.org/user-guide/tsqlt-tutorial/)  
  - [FakeFunction (Zeit/Abhängigkeiten mocken)](https://tsqlt.org/user-guide/isolating-dependencies/fakefunction/)

---

## 3 | Weiterführende Informationen

- 📘 tSQLt – [Full User Guide (Referenz)](https://tsqlt.org/full-user-guide/)  
- 📘 tSQLt – [Quick Start (Installation, Beispiele)](https://tsqlt.org/user-guide/quick-start/)  
- 📘 tSQLt – [Assertions (Übersicht)](https://tsqlt.org/user-guide/assertions/)  
- 📘 tSQLt – [Test Creation & Execution](https://tsqlt.org/user-guide/test-creation-and-execution/)  
- 📝 Simple-Talk (Redgate): [Getting Started Testing Databases with tSQLt](https://www.red-gate.com/simple-talk/databases/sql-server/t-sql-programming-sql-server/getting-started-testing-databases-with-tsqlt/)  
- 📝 Simple-Talk (Redgate): [SQL Server Unit Testing with tSQLt](https://www.red-gate.com/simple-talk/databases/sql-server/t-sql-programming-sql-server/sql-server-unit-testing-with-tsqlt/)  
- 📝 The Agile SQL Club: [Running tSQLt tests & JUnit XML](https://the.agilesql.club/2014/11/running-tsqlt-tests-from-c/vb.net/java/whatever/)  
- 📘 Microsoft Learn (SSDT): [Walkthrough – Creating and Running a SQL Server Unit Test](https://learn.microsoft.com/en-us/sql/ssdt/walkthrough-creating-and-running-a-sql-server-unit-test)  
- 📘 Redgate Flyway: [Database Unit Testing (tSQLt in CI/CD)](https://documentation.red-gate.com/fd/database-unit-testing-149127232.html)  
- 📘 JetBrains DataGrip: [Run tSQLt tests](https://www.jetbrains.com/help/datagrip/run-tsqlt-tests.html)  
- 📝 SQLShack: [SQL unit testing with the tSQLt framework (Einführung)](https://www.sqlshack.com/sql-unit-testing-with-the-tsqlt-framework-for-beginners/)  
- 📝 Blog: [Faking Views & SetFakeViewOn-Pattern](https://sqlity.net/en/70/faking-views/)  
