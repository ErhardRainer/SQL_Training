---
title: Sortierbare Tabelle – Demo
---

# Demo: Sortierbare Tabelle (GitHub Pages)

<table class="sortable">
  <thead>
    <tr><th>Kapitel</th><th>Punkte</th><th>Datum</th></tr>
  </thead>
  <tbody>
    <tr><td>02_Select.md</td><td>12</td><td>2025-09-06</td></tr>
    <tr><td>03_Join.md</td><td>7</td><td>2025-09-01</td></tr>
    <tr><td>04_GroupBy.md</td><td>19</td><td>2025-08-30</td></tr>
  </tbody>
</table>

<style>
table { border-collapse: collapse; width: 100%; }
th, td { padding: .5rem .65rem; border: 1px solid #ddd; }
th { cursor: pointer; background: #f6f8fa; }
tbody tr:nth-child(odd){ background: #fcfcfd; }
</style>

<script src="sorttable.js"></script>
