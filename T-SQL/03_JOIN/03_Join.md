# T-SQL JOIN – Übersicht

## 1 | Begriffsdefinition

| SQL-Term | Beschreibung |
|---|---|
| JOIN (allgemein) | Verknüpft Zeilen aus zwei (oder mehr) Tabellen basierend auf einer Bedingung in der `ON`-Klausel. |
| INNER JOIN | Liefert nur übereinstimmende Zeilen beider Seiten. `INNER` kann weggelassen werden. |
| LEFT/RIGHT OUTER JOIN | Liefert alle Zeilen der linken/rechten Tabelle plus passende Zeilen der anderen Tabelle; fehlende Werte als `NULL`. |
| FULL OUTER JOIN | Liefert alle Zeilen beider Tabellen; bei fehlenden Matches `NULL`-Werte. |
| CROSS JOIN | Kartesisches Produkt beider Eingaben (jede Zeile links mit jeder Zeile rechts). |
| SELF JOIN | Eine Tabelle wird mit sich selbst verknüpft (erfordert Aliasse). |
| APPLY (CROSS/OUTER) | Lateral Join in T-SQL: führt eine TVF/abgeleitete Tabelle pro linker Zeile aus; `CROSS` wie `INNER`, `OUTER` wie `LEFT`. |
| ON-Klausel | Definiert die Join-Prädikate (Schlüssel/Spalten, ggf. mehrere Bedingungen). |
| WHERE-Klausel | Filtert **nach** dem Join; bei OUTER JOINs kann ein Filter in `WHERE` den OUTER-Effekt aufheben. |
| Join-Bedingung | Ausdrücke, die Zeilen matchen; ideal: Gleichheit auf Schlüsseln/indizierten Spalten. |
| Semi-Join / Anti-Join | Existenzprüfungen: `EXISTS/IN` (semi), `NOT EXISTS`/`EXCEPT` (anti); liefern nur Zeilen der linken Seite. |
| Join-Kardinalität | 1:1, 1:n, n:m; Joins können Duplikate erzeugen – ggf. mit Aggregaten/`DISTINCT` behandeln. |
| Join-Reihenfolge | Der Optimizer ordnet assoziativ/kommutativ um; kann mit Hinweisen beeinflusst werden. |
| Join-Algorithmen | Physische Operatoren: Nested Loops, Merge, Hash; Wahl basiert auf Kardinalität, Sortierung, Indizes. |
| Join-Hints | `LOOP`, `MERGE`, `HASH` auf Join-Ebene bzw. `OPTION(LOOP|MERGE|HASH JOIN)` global. Sparsam einsetzen. |
| SARGability | Funktionen/Konvertierungen auf Join-Spalten verhindern Index-Seeks → schlechtere Pläne. |
| Indizes & FK | Passende (komposite) Indizes/FKs verbessern Kostenmodell & Kardinalitätsschätzung. |
| Collation | Unterschiedliche Kollationen bei String-Joins führen zu Fehlern oder impliziten Konvertierungen (`COLLATE`). |
| OUTER-Null-Semantik | Bei OUTER JOINs sind Werte einer Seite ggf. `NULL`; Bedingungen entsprechend formulieren (`IS NULL`). |
| Set-Operatoren vs JOIN | `UNION/INTERSECT/EXCEPT` kombinieren vertikal; Joins kombinieren horizontal. |
| `rowversion`/`timestamp` | Binärer Zähler pro Zeile. Nützlich für Änderungsdetektion/optimistische Sperrung in Join-Szenarien. |

---

## 2 | Struktur

### 2.1 | Join-Grundlagen & Syntax
> **Kurzbeschreibung:** Überblick über `FROM … JOIN … ON …`, INNER/OUTER/CROSS, Aliasse und die logische Lesereihenfolge der Abfrage.

- 📓 **Notebook:**  
  [`08_01_join_grundlagen.ipynb`](08_01_join_grundlagen.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Joins Tutorial (Grundlagen)](https://www.youtube.com/watch?v=iwP_adDNUPQ)  
  - [Combining multiple tables with JOINs in T-SQL (MS Learn Video)](https://www.youtube.com/watch?v=oKgFNNadCNY)

- 📘 **Docs:**  
  - [FROM + JOIN (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql?view=sql-server-ver17)  
  - [Joins (SQL Server) – Grundlagen](https://learn.microsoft.com/en-us/sql/relational-databases/performance/joins?view=sql-server-ver17)

---

### 2.2 | ON vs WHERE bei OUTER JOINs
> **Kurzbeschreibung:** Warum Filter in `WHERE` nach dem Join wirken und einen LEFT OUTER faktisch zum INNER machen können; korrekte Platzierung von Filtern.

- 📓 **Notebook:**  
  [`08_02_outer_join_on_vs_where.ipynb`](08_02_outer_join_on_vs_where.ipynb)

- 🎥 **YouTube:**  
  - [LEFT OUTER JOIN mit Ausschlüssen](https://www.youtube.com/watch?v=RFPT4aCQaSA)  
  - [SQL Joins anschaulich erklärt](https://www.youtube.com/watch?v=Yh4CrPHVBdE)

- 📘 **Docs:**  
  - [FROM + JOIN – Logik & Beispiele](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql?view=sql-server-ver17)  
  - [Query Processing Architecture (logische Verarbeitung)](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide?view=sql-server-ver17)

---

### 2.3 | Self-Join & Aliasierung
> **Kurzbeschreibung:** Selbstverknüpfungen für Hierarchien/Beziehungen; saubere Aliasse und mehrfache Joins derselben Tabelle.

- 📓 **Notebook:**  
  [`08_03_self_join_aliases.ipynb`](08_03_self_join_aliases.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Joins (Beispiele)](https://www.youtube.com/watch?v=duAkYyKMgfE)  
  - [SQL Joins Tutorial (Einsteiger)](https://www.youtube.com/watch?v=0OQJDd3QqQM)

- 📘 **Docs:**  
  - [FROM + JOIN (Self-Join Hinweise)](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql?view=sql-server-ver17)  
  - [Showplan Operator Reference (Pläne lesen)](https://learn.microsoft.com/en-us/sql/relational-databases/showplan-logical-and-physical-operators-reference?view=sql-server-ver17)

---

### 2.4 | APPLY (CROSS/OUTER) – Lateral Joins
> **Kurzbeschreibung:** Zeilenweise Auswertung mit TVFs/abgeleiteten Tabellen; Muster wie JSON/XML-Parsing, Top-N-pro-Gruppe, „per row Top 1“.

- 📓 **Notebook:**  
  [`08_04_apply_lateral_joins.ipynb`](08_04_apply_lateral_joins.ipynb)

- 🎥 **YouTube:**  
  - [Itzik Ben-Gan – Creative Uses of APPLY](https://www.youtube.com/watch?v=-m426WYclz8)  
  - [Boost Your T-SQL with APPLY](https://www.youtube.com/watch?v=VMH2y_3XBa0)

- 📘 **Docs:**  
  - [APPLY (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql?view=sql-server-ver17)  
  - [XML `nodes()` + `CROSS APPLY`](https://learn.microsoft.com/en-us/sql/t-sql/xml/nodes-method-xml-data-type?view=sql-server-ver17)

---

### 2.5 | Semi-/Anti-Joins: EXISTS, IN, NOT EXISTS, EXCEPT
> **Kurzbeschreibung:** Effiziente Existenzprüfungen/Ausschlüsse ohne Duplikatsvervielfältigung; typische Fehlerbilder und Performance.

- 📓 **Notebook:**  
  [`08_05_semi_anti_joins.ipynb`](08_05_semi_anti_joins.ipynb)

- 🎥 **YouTube:**  
  - [Joins vs EXISTS – Set-basiertes Denken](https://www.youtube.com/watch?v=LFqbtk-Mi-M)  
  - [Join-Methoden kompakt](https://www.youtube.com/watch?v=MFazkaZKs1s)

- 📘 **Docs:**  
  - [`EXISTS` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/exists-transact-sql?view=sql-server-ver17)  
  - [`EXCEPT`/`INTERSECT`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-except-and-intersect-transact-sql?view=sql-server-ver17)

---

### 2.6 | Physische Join-Algorithmen & Hints
> **Kurzbeschreibung:** Nested Loops, Merge, Hash – wann welcher Operator; gezielte Nutzung von Join-/Query-Hints und Risiken.

- 📓 **Notebook:**  
  [`08_06_join_algorithmen_hints.ipynb`](08_06_join_algorithmen_hints.ipynb)

- 🎥 **YouTube:**  
  - [How do Nested Loop, Hash & Merge Joins work?](https://www.youtube.com/watch?v=pJWCwfv983Q)  
  - [Merge Join Internals](https://www.youtube.com/watch?v=IFUB8iw46RI)

- 📘 **Docs:**  
  - [Join Hints (Join-Ebene)](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-join?view=sql-server-ver17)  
  - [Query Hints `OPTION(... JOIN)`](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query?view=sql-server-ver17)

---

### 2.7 | Performance: Indizes, Kardinalität, IQP
> **Kurzbeschreibung:** SARGability, passende (komposite) Indizes, Kardinalitätsschätzung & Intelligent Query Processing; typische Fallstricke.

- 📓 **Notebook:**  
  [`08_07_performance_indexes_ce.ipynb`](08_07_performance_indexes_ce.ipynb)

- 🎥 **YouTube:**  
  - [How to Think Like the SQL Server Engine](https://www.youtube.com/watch?v=SMw2knRuIlE)  
  - [Watch Brent Tune Queries](https://www.youtube.com/watch?v=IVqvwNlwXuI)

- 📘 **Docs:**  
  - [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide?view=sql-server-ver17)  
  - [IQP & CE-Feedback](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing-cardinality-estimation-feedback?view=sql-server-ver17)

---

### 2.8 | Collation & JOINs (Strings)
> **Kurzbeschreibung:** Kollationskonflikte in String-Joins erkennen/beheben (`COLLATE`, `DATABASE_DEFAULT`, tempdb-Fallen).

- 📓 **Notebook:**  
  [`08_08_collation_in_joins.ipynb`](08_08_collation_in_joins.ipynb)

- 🎥 **YouTube:**  
  - [Joins & Text – typische Fehler (Allgemein)](https://www.youtube.com/watch?v=xGuAAp4J3UE)  
  - [Joins Tutorial (Joey Blue)](https://www.youtube.com/%40joeyblue1)

- 📘 **Docs:**  
  - [Collation Precedence](https://learn.microsoft.com/en-us/sql/t-sql/statements/collation-precedence-transact-sql?view=sql-server-ver17)  
  - [`COLLATE` / Collation & Unicode Support](https://learn.microsoft.com/en-us/sql/relational-databases/collations/collation-and-unicode-support?view=sql-server-ver17)

---

### 2.9 | Joins mit JSON/XML/TVFs
> **Kurzbeschreibung:** Typische Muster mit `CROSS APPLY OPENJSON`, `CROSS APPLY … nodes()` und Table-Valued Functions.

- 📓 **Notebook:**  
  [`08_09_apply_json_xml_tvf.ipynb`](08_09_apply_json_xml_tvf.ipynb)

- 🎥 **YouTube:**  
  - [cross apply – coole Tricks](https://www.youtube.com/watch?v=eVsG9oQsr-c)  
  - [APPLY Use-Cases (Itzik)](https://www.youtube.com/watch?v=goyWzAu-AA0)

- 📘 **Docs:**  
  - [`OPENJSON` + `CROSS APPLY`](https://learn.microsoft.com/en-us/sql/t-sql/functions/openjson-transact-sql?view=sql-server-ver17)  
  - [XML `nodes()`](https://learn.microsoft.com/en-us/sql/t-sql/xml/nodes-method-xml-data-type?view=sql-server-ver17)

---

### 2.10 | Set-Operatoren vs JOIN
> **Kurzbeschreibung:** Wann `UNION/UNION ALL/INTERSECT/EXCEPT` statt Join sinnvoll ist; kombinierte Strategien.

- 📓 **Notebook:**  
  [`08_10_set_operatoren_vs_joins.ipynb`](08_10_set_operatoren_vs_joins.ipynb)

- 🎥 **YouTube:**  
  - [SQL Set Operators kompakt](https://www.youtube.com/watch?v=KwMOfV0GVbs)  
  - [SQL Joins & Set Ops (Einsteiger)](https://www.youtube.com/watch?v=dkUquiko2Pg)

- 📘 **Docs:**  
  - [`UNION` (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-union-transact-sql?view=sql-server-ver17)  
  - [`EXCEPT`/`INTERSECT`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-except-and-intersect-transact-sql?view=sql-server-ver17)

---

### 2.11 | Transaktionen, Isolation & Sperren bei Joins
> **Kurzbeschreibung:** Wie Isolation Levels, Blocking und Versioning (RCSI/SI) Join-Abfragen beeinflussen; Deadlocks vermeiden.

- 📓 **Notebook:**  
  [`08_11_isolation_locking_joins.ipynb`](08_11_isolation_locking_joins.ipynb)

- 🎥 **YouTube:**  
  - [SQL Server Q&A (Blocking/Isolation häufig)](https://www.brentozar.com/archive/2024/11/video-office-hours-sql-server-questions-and-answers/)  
  - [Joins in Ausführungsplänen](https://www.youtube.com/watch?v=Roubv_TpXYY)

- 📘 **Docs:**  
  - [Locking & Row Versioning Guide](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide?view=sql-server-ver16)  
  - [Nie endende Abfragen analysieren](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/troubleshoot-never-ending-query)

---

### 2.12 | Best Practices & Anti-Patterns
> **Kurzbeschreibung:** Saubere Join-Schlüssel, passende Indizes, keine Funktionen auf Join-Spalten, `RIGHT JOIN` selten nötig, Hints nur gezielt.

- 📓 **Notebook:**  
  [`08_12_best_practices_joins.ipynb`](08_12_best_practices_joins.ipynb)

- 🎥 **YouTube:**  
  - [Brent Ozar – Free SQL Server Training](https://www.brentozar.com/free-sql-server-training-videos/)  
  - [SQL Server Engine – Denkweise](https://www.youtube.com/watch?v=SMw2knRuIlE)

- 📘 **Docs:**  
  - [Showplan Operator Reference](https://learn.microsoft.com/en-us/sql/relational-databases/showplan-logical-and-physical-operators-reference?view=sql-server-ver17)  
  - [Query Hints – `OPTION`-Klausel](https://learn.microsoft.com/en-us/sql/t-sql/queries/option-clause-transact-sql?view=sql-server-ver17)

---

## 3 | Weiterführende Informationen

- 📘 Microsoft Learn: [Joins (SQL Server) – Überblick & Beispiele](https://learn.microsoft.com/en-us/sql/relational-databases/performance/joins?view=sql-server-ver17)  
- 📘 Microsoft Learn: [FROM + JOIN, APPLY, PIVOT (T-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/queries/from-transact-sql?view=sql-server-ver17)  
- 📘 Microsoft Learn: [Join Hints (LOOP/MERGE/HASH)](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-join?view=sql-server-ver17)  
- 📘 Microsoft Learn: [Query Hints – `OPTION(... JOIN)`](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query?view=sql-server-ver17)  
- 📘 Microsoft Learn: [Query Processing Architecture Guide](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-architecture-guide?view=sql-server-ver17)  
- 📘 Microsoft Learn: [Cardinality Estimation & IQP](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing-cardinality-estimation-feedback?view=sql-server-ver17)  
- 📘 Microsoft Learn: [Collation Precedence & `COLLATE`](https://learn.microsoft.com/en-us/sql/t-sql/statements/collation-precedence-transact-sql?view=sql-server-ver17)  
- 📘 Microsoft Learn: [`EXISTS` (Semi-Join)](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/exists-transact-sql?view=sql-server-ver17)  
- 📝 Blog: Kendra Little – [Using APPLY for calculations](https://kendralittle.com/2011/03/29/crossapplycolumn/)  
- 🎥 YouTube: Itzik Ben-Gan – [Creative Uses of the APPLY Operator](https://www.youtube.com/watch?v=-m426WYclz8)  
- 🎥 YouTube: Brent Ozar Unlimited – [SQL Server Trainings (Playlist)](https://www.youtube.com/c/BrentOzarUnlimited/playlists)  
- 📘 Docs: [`OPENJSON` + `CROSS APPLY` Beispiel](https://learn.microsoft.com/en-us/sql/t-sql/functions/openjson-transact-sql?view=sql-server-ver17)  
- 📘 Docs: [Set Operators – `UNION` / `EXCEPT` / `INTERSECT`](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/set-operators-union-transact-sql?view=sql-server-ver17)
