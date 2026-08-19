# Arbeitsanweisung: einen offenen Markdown-Task abarbeiten

Diese Anweisung gilt für die Tasks unter `_internal/Task`. Pro Lauf wird
genau ein Task bearbeitet. Maßgeblich sind der Task selbst, die darin
genannten Zielpfade und die dort referenzierten Arbeitsanweisungen.

## Status und Ordner

| Zustand | Frontmatter `status` | Ordner |
|---|---|---|
| bereit zur Auswahl | `open` | `_internal/Task/open` |
| vom aktuellen Lauf reserviert | `pending` | `_internal/Task/open` |
| erfolgreich abgeschlossen | `done` | `_internal/Task/done` |
| blockiert oder fachlich unvollständig | `onhold` | `_internal/Task/onhold` |

Ein Task mit `status: pending` darf nicht von einem weiteren Lauf ausgewählt
werden. Er bleibt im Ordner `open`, bis der reservierende Lauf ihn abschließt
oder nachvollziehbar nach `onhold` überführt.

## Ablauf

### 1. Genau einen Task auswählen und reservieren

1. Lies die Dateien in `_internal/Task/open`.
2. Wähle nur einen Task mit `status: open`.
3. Priorisiere höhere `priority`; bei Gleichstand wähle die kleinere
   numerische Task-ID.
4. Ändere vor jeder fachlichen Arbeit im ausgewählten Task:
   - `status: pending`
   - `updated_at` auf den aktuellen UTC-Zeitstempel im Format
     `YYYY-MM-DDTHH:mmZ`
5. Ergänze sofort im Abschnitt **Implementierungsfortschritt** einen
   datierten Eintrag zur Reservierung.

Beispiel:

```markdown
- 2026-08-19T12:15Z — Task reserviert; Ausgangslage, Zielpfade und
  Akzeptanzkriterien geprüft.
```

### 2. Task umsetzen und fortlaufend dokumentieren

Lies vor der Umsetzung vollständig:

- den ausgewählten Task,
- [`ai_agents.md`](../../ai_agents.md),
- alle unter `execution_context.required_guides` genannten Anweisungen.

Setze ausschließlich die beschriebenen Zielpfade um. Bestehende Inhalte sind
gezielt zu erweitern; fachliche Produktivregeln dürfen nicht erfunden werden.

#### Pflicht: Änderungsprotokoll im Task

Im Abschnitt **Implementierungsfortschritt** muss für **jede Änderung** ein
Eintrag stehen. Das gilt insbesondere für neue oder geänderte SQL-,
Markdown-, Navigations-, Test- und Konfigurationsdateien.

Jeder Eintrag enthält:

- einen UTC-Zeitstempel mindestens bis zur Minute,
- die betroffene Datei oder den betroffenen Bereich,
- was geändert oder hinzugefügt wurde,
- bei Prüfungen das Ergebnis und die verwendete Prüfung.

Format:

```markdown
- YYYY-MM-DDTHH:mmZ — `relativer/pfad/datei.sql`: <konkrete Änderung>.
- YYYY-MM-DDTHH:mmZ — `relativer/pfad/datei.md`: <Dokumentation, Link,
  Mermaid oder sonstige Ergänzung>.
- YYYY-MM-DDTHH:mmZ — Prüfung: <Befehl oder Prüfmethode>; Ergebnis:
  <konkretes Resultat>.
```

Mehrere Änderungen dürfen nur dann in einem Eintrag zusammengefasst werden,
wenn sie dieselbe untrennbare Änderung am selben Artefakt darstellen. Vage
Einträge wie „Task bearbeitet“ oder „Dateien angepasst“ reichen nicht aus.

### 3. Abschluss prüfen

Prüfe jedes Akzeptanzkriterium des Tasks. Hake es erst nach erfolgreicher,
nachvollziehbar dokumentierter Prüfung ab. Ergänze die finale Prüfung ebenfalls
mit Zeitstempel im Implementierungsfortschritt.

Bei Erfolg:

1. Setze `status: done` und `acceptance_criteria_status: verified`.
2. Aktualisiere `updated_at`.
3. Ergänze im Abschnitt **Analyse und Entscheidungen** nur sachliche
   Annahmen oder relevante Abgrenzungen.
4. Ergänze unter **Offene Punkte und Uebergabe**, dass keine offenen Punkte
   verbleiben, oder dokumentiere bewusst verbleibende Hinweise.
5. Verschiebe die Task-Datei nach `_internal/Task/done`.

Bei einem echten Blocker oder einer unvollständigen Umsetzung:

1. Setze `status: onhold` und belasse `acceptance_criteria_status: draft`.
2. Aktualisiere `updated_at`.
3. Dokumentiere Ursache, betroffene Zielpfade und einen konkreten nächsten
   Schritt unter **Offene Punkte und Uebergabe** sowie mit Zeitstempel unter
   **Implementierungsfortschritt**.
4. Verschiebe die Datei nach `_internal/Task/onhold`.

## Nicht tun

- Nicht mehrere offene Tasks in einem Lauf reservieren oder bearbeiten.
- Nicht mit fachlicher Arbeit beginnen, bevor `status: pending` gespeichert
  und die Reservierung im Implementierungsfortschritt dokumentiert ist.
- Nicht nach `done` verschieben, wenn ein Akzeptanzkriterium ungeprüft oder
  nicht erfüllt ist.
- Nicht das Änderungsprotokoll in externe Dateien auslagern; es ist Teil des
  jeweiligen Task-Markdowns.
