# Übersicht über die Artikel
## 1–20 – Die stärksten Startthemen
1. Spalten ändern – Metadatenänderung, Rewrite, Objektumbau, Logging, Locks.
2. Joined Update / UPDATE … FROM Pattern – Kardinalität, Eindeutigkeit, sichere vs. gefährliche Varianten.
3. MERGE / Upsert richtig einsetzen – Wann elegant, wann riskant, wann lieber getrennte Schritte.
4. EXISTS vs. IN vs. JOIN – Semantik, Duplikate, Lesbarkeit, Optimizer‑Mythen.
5. NOT IN vs. NOT EXISTS vs. LEFT JOIN IS NULL – NULL‑Fallen und sichere Anti‑Joins.
6. CTE vs. Temp Table vs. Derived Table – Lesbarkeit, Materialisierung, Wiederverwendung, Optimizer‑Verhalten.
7. Top 1 pro Gruppe – ROW_NUMBER, DISTINCT ON, Aggregat‑Join, korrelierte Subquery.
8. DISTINCT als Problemlöser oder Problemmaske – Wann korrekt, wann nur Join‑Fehler kaschiert werden.
9. Sargable vs. nicht sargable Filter – Warum dieselbe Fachlogik völlig andere Pläne erzeugt.
10. Datumsfilter richtig schreiben – Offene Obergrenzen, Zeitanteile, Monats‑ und Tageslogik.
11. Views vs. materialisierte Views vs. Indexed Views – gleiche Idee, sehr unterschiedliche Systeme.
12. Fensterfunktionen richtig denken – ROW_NUMBER, RANK, DENSE_RANK, LAG, LEAD.
13. UNION vs. UNION ALL – Dedup‑Kosten, Semantik und unnötige Sorts.
14. GROUP BY richtig verstehen – funktionale Abhängigkeit, Aggregationslogik, klassische Fehlbilder.
15. HAVING vs. WHERE – semantische Reihenfolge und praktische Denkhilfe.
16. CASE in SQL – Ausdrucksmittel, Sargability und Lesbarkeit.
17. Delete mit Join / mehrstufige Löschlogik – sichere Zielmengen, Kaskaden und Rückrollbarkeit.
18. ORDER BY in Unterabfragen, Views und CTEs – wo Reihenfolge gilt und wo sie Illusion ist.
19. NULL richtig verstehen – Dreiwertige Logik, Vergleichsoperatoren, Aggregation, Sortierung.
20. String‑Aggregation – STRING_AGG, LISTAGG, GROUP_CONCAT und ihre Eigenheiten.

## 21–40 – Datenmodell, Constraints, DDL
21. Primärschlüssel, Unique Constraints und echte Eindeutigkeit – Fachregel vs. technisch abgesicherte Regel.
22. Foreign Keys in der Praxis – Schutz, Ladekosten, Löschlogik und Reihenfolgenprobleme.
23. Check Constraints sinnvoll nutzen – Datenqualität an der Datenbankgrenze.
24. Default Constraints / Default‑Werte – Komfortfunktion oder versteckte Business‑Logik?
25. Identity, Sequence, Auto‑Increment – Wie Systeme IDs erzeugen und wo es knifflig wird.
26. Computed / Generated / Virtual Columns – Persistenz, Indexierung, Wartung, Semantik.
27. Spalte umbenennen – Harmlos wirkend, aber oft abhängigkeitslastig.
28. Tabelle umbenennen – Metadatenänderung, Abhängigkeiten, Deployment‑Folgen.
29. Datentypwechsel ohne Datenverlust – implizite Konvertierung, Abschneiden, Rebuild‑Risiko.
30. VARCHAR vs. NVARCHAR vs. TEXT/LOB‑ähnliche Typen – Zeichen, Speicher, Suche, Indizes.
31. DECIMAL/NUMERIC richtig wählen – Präzision, Rundung und fachliche Fallstricke.
32. CHAR vs. VARCHAR – feste vs. variable Länge, Speicher und Vergleichs­verhalten.
33. ALTER TABLE ADD COLUMN mit Default – Metadaten‑only oder teuer?
34. Tabellen splitten, normalisieren oder bewusst denormalisieren – Wann welche Richtung sinnvoll ist.
35. Surrogate Key vs. Natural Key – Theorie, Praxis und Betriebskosten.
36. Mehrspaltige Schlüssel richtig entwerfen – Selektivität, Join‑Kosten, Wartung.
37. Soft Delete vs. Hard Delete – Fachlichkeit, Historie, Indizes, Performance.
38. Audit‑Spalten und Änderungsverfolgung – CreatedAt, UpdatedAt, RowVersion & Co.
39. Historisierung / SCD‑Muster in SQL – Typ 1, Typ 2, Gültigkeitsintervalle.
40. Temporale Tabellen / Zeitreisen in Datenmodellen – Systemfeatures vs. manuelle Muster.

## 41–60 – Indizes, Pläne, Optimizer
41. Heap vs. Clustered Table vs. organisierte Speicherung – Was die Zeilenorganisation wirklich bedeutet.
42. Clustered, Nonclustered, B‑Tree & Co. – welche Indexart welches Problem löst.
43. Covering Indexes richtig einsetzen – Wann sie großartig sind und wann sie teuer werden.
44. Composite Indexes – Spaltenreihenfolge, Suchmuster und Fehlannahmen.
45. Filtered / Partial Indexes – kleines Objekt, großer Effekt.
46. Unique Index vs. Unique Constraint – formale Nähe, praktische Unterschiede.
47. Statistiken richtig verstehen – warum gute Datenverteilungsschätzung so viel entscheidet.
48. Kardinalitätsschätzungen – wo sie kippen und wie das ganze Pläne verzieht.
49. Execution Plans lesen, ohne sich selbst zu belügen – Operatoren, Schätzungen, tatsächliche Zeilen.
50. Nested Loops vs. Hash Join vs. Merge Join – wann welcher Join‑Typ plausibel ist.
51. Sorts als versteckte Kostentreiber – ORDER BY, DISTINCT, Windowing, Set‑Operationen.
52. Spools, Materialisierung und Zwischenmengen – warum der Optimizer Dinge „abstellt“.
53. Predicate Pushdown – wann Filter früh greifen und wann nicht.
54. Parameter Sniffing / planinstabile Abfragen – warum dieselbe Query heute schnell und morgen langsam ist.
55. Hints richtig einordnen – Werkzeug, Krücke oder Gefahr?
56. Index Rebuild vs. Reorganize – echte Wartung statt Ritual.
57. Fragmentierung – wann relevant, wann überschätzt.
58. Index‑Wartungskosten bei schreibintensiven Tabellen – warum „mehr Indizes“ nicht gratis ist.
59. Columnstore / spaltenorientierte Speicherung – analytischer Turbo oder falsches Werkzeug?
60. Partitionierung – Verwaltungsgrenze, Performancehebel oder beides?

## 61–80 – Transaktionen, Locks, Parallelität
61. Transaktionen sauber denken – atomar, konsistent, isoliert, dauerhaft ist nur der Anfang.
62. Isolation Levels in der Praxis – Read Committed, Repeatable Read, Serializable usw.
63. Locks vs. MVCC – warum Systeme Konflikte fundamental unterschiedlich behandeln.
64. Deadlocks – Entstehung, Erkennung, Vermeidung.
65. Blockierungen in produktiven Systemen – Leser, Schreiber, Wartungsfenster.
66. Lock Escalation / Sperrausweitung – wann kleine Änderungen groß werden.
67. Batching großer Updates und Deletes – Kontrolle, Log, Sperren, Wiederanlauf.
68. Retry‑Strategien bei Konkurrenzfehlern – wann die Anwendung reagieren muss.
69. Phantoms, Non‑Repeatable Reads und Co. – nicht nur Lehrbuch, sondern reale Effekte.
70. Optimistic vs. Pessimistic Concurrency – Denkmodelle und Systemrealität.
71. MERGE unter Parallelität – warum das Thema noch heikler wird, wenn andere mitschreiben.
72. Long‑Running Transactions – warum sie mehr kaputt machen als man denkt.
73. Savepoints und Teilrücknahmen – feines Transaktionswerkzeug richtig nutzen.
74. Read Committed Snapshot / Snapshot‑Ideen – Entlastung oder neue Komplexität?
75. Hot Rows und Hot Keys – wenn viele Prozesse dieselbe Zeile wollen.
76. Trigger und Transaktionen – versteckte Arbeit in kritischen Pfaden.
77. Referentielle Integrität unter Last – FK‑Prüfung in schreibstarken Szenarien.
78. Online vs. Offline Änderungen – was wirklich „online“ bedeutet.
79. Wartung unter laufendem Betrieb – Index, DDL, Datenumbau ohne Totalschaden.
80. Replikation und Schreibkonflikte – warum „mehrere Orte“ neue Klassen von Problemen erzeugen.

## 81–95 – Fortgeschritten, architektonisch, sehr blogstark
81. JSON in relationalen Datenbanken – Komfort, Suchbarkeit, Indizes, Anti‑Pattern.
82. Arrays, Listen, Mehrfachwerte in einer Spalte – wann es kippt und wann Systeme helfen.
83. Pivotieren / Unpivotieren – Berichtssicht vs. Datenmodell.
84. Recursive CTEs / Hierarchien – Bäume, Pfade, Stücklisten, Org‑Strukturen.
85. Adjacency List vs. Nested Sets vs. Path Enumeration – Hierarchiemodelle im Vergleich.
86. Lateral Joins / APPLY / korrelierte Tabellenausdrücke – fortgeschritten, aber extrem nützlich.
87. Korrelierte Subqueries vs. Join‑Umschreibung – wann Umschreiben hilft und wann nicht.
88. MERGE als ETL‑Werkzeug – Synchronisation von Delta‑Mengen.
89. Staging‑Tabellen richtig nutzen – kontrollierte Vorverarbeitung statt heroischer Ein‑Statement‑Lösungen.
90. Idempotente SQL‑Prozesse bauen – wiederholbar, nachvollziehbar, betriebssicher.
91. Fehlerbehandlung in SQL – Transaktionsfehler, Teilfehler, Logging, Rückbau.
92. DDL in Deployment‑Pipelines – warum Schemaänderungen anders behandelt werden müssen als Code.
93. Online‑Schema‑Migrationen – Expand/Contract, Backfill, Umschaltpunkt.
94. Datenbereinigung per SQL – Dubletten, Normierung, Konfliktregeln.
95. Suche in Textfeldern – LIKE, Full Text, funktionale Suche, Grenzen klassischer Indizes.