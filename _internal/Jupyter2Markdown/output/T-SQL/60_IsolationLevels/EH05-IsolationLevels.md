# EH05-IsolationLevels

**Quelle:** `T-SQL\60_IsolationLevels\EH05-IsolationLevels.ipynb`  
**Generiert:** 2026-04-18 21:13:31  
**Markdown-Zellen:** 1  
**SQL-Zellen:** 0  

---

# ISOLATION LEVELS

Beschreibt wie 2 oder mehrere Transactions voneinander isoliert wird.

![](attachment:image.png)  

Violations:

- Dirty read - Daten werden gelesen (T2) bevor sie committed werden (T1). Im Falle eines Rollbacks stimmen die verwendeten Daten von T2 nicht mit den jetztigen Daten überein.
- Nonrepatable Read - Daten werden geändert (T2) während die andere Tansaction (T1) noch läuft
- Phantom

Isolation Levels:

- Read Uncommitted
- Read Committed
- Repeatable Read
- Serializable
- Read Committed Snapshot
- Snapshot

