# 07 - SQL Cells Generator

## Aufgabe
Schreibe die T-SQL-Codezellen fuer Setup, Kernsektionen, Diagnostik, Fallstricke, Uebungen und Cleanup.

## Ziel
Die Codezellen muessen fachlich korrekt, didaktisch sauber und fuer einen SQL-Kernel geeignet sein.

## Pflichtregeln
- Jede Codezelle enthaelt nur T-SQL.
- `execution_count` bleibt spaeter leer; die Pipeline generiert keine Outputs.
- Setup-Zellen muessen idempotent oder klar manuell markiert sein.
- Fachlich falsche Beispiele in Fallstricken sollen bevorzugt kommentiert sein, wenn sie den Lauf sonst abbrechen wuerden.
- Direkt danach folgt die Korrektur.
- Uebungsloesungen mit `-- Loesung zu Frage N` kennzeichnen.

## Muster fuer Fallstrick-Code
- harmlos falsches Verhalten: ausfuehrbare Problemzelle plus Korrektur
- echter Fehlerfall: problematische Zeile kommentieren und den erwarteten Fehler beschreiben
- hypothetischer Pattern-Fall: Problem als kommentiertes Skelett, Korrektur als ausfuehrbares Muster

## Muster fuer Diagnostik-/Optimizer-Bloecke
- kleine, gut lesbare Referenzabfrage
- bei Bedarf Hinweise auf:
  - `STATISTICS IO`
  - `STATISTICS TIME`
  - Ausfuehrungsplan
  - relevante Operatoren, DMVs oder Locks
- keine unbelegten Performance-Versprechen

## Setup-Regeln
- Datenorientierte Themen: kleine, bewusst kuratierte Beispieltabellen
- DML-Themen: Ruecksetzbarkeit mitdenken
- Admin-Themen: Beobachtungsqueries, Kataloge, DMVs und manuelle Voraussetzungen statt kuenstlicher Scheindemos
- Multi-Session-Themen: Session A/B direkt im Kommentar oder in getrennten Bloeken markieren

## Cleanup-Regeln
- Optionales Cleanup klar kennzeichnen
- Gefaehrliche Rueckbauten nur fuer Demo-Objekte
- Wenn kein Cleanup sinnvoll ist, nicht kuenstlich erzwingen
