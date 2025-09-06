# Demo: Markdown-Tabelle mit Sortierung

| Kapitel        | Punkte | Datum      |
|----------------|:------:|:-----------|
| 02_Select.md   | 12     | 2025-09-06 |
| 03_Join.md     | 7      | 2025-09-01 |
| 04_GroupBy.md  | 19     | 2025-08-30 |

{: .sortable }  <!-- weist der davorstehenden Tabelle die Klasse "sortable" zu -->

<style>
table { border-collapse: collapse; width: 100%; }
th, td { padding: .5rem .65rem; border: 1px solid #ddd; }
th { cursor: pointer; background: #f6f8fa; }
tbody tr:nth-child(odd){ background: #fcfcfd; }
</style>
<script src="/assets/js/sorttable.js"></script>
