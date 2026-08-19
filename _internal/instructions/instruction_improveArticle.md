# Instruction: T-SQL-Übersichtsartikel didaktisch und praktisch aufwerten

## Ziel

Überarbeite eine vorhandene T-SQL-Übersichtsseite (`*.md`) so, dass sie nicht nur ein Linkverzeichnis ist, sondern einen vollständigen, gut navigierbaren Lern- und Praxisleitfaden bildet. Orientiere dich in Tiefe und Struktur an:

- `T-SQL/02_Select/02_Select.md`
- `T-SQL/03_JOIN/03_Join.md`

Die fachliche Aussage des vorhandenen Artikels bleibt erhalten. Ergänze und präzisiere sie; entferne keine sinnvollen bestehenden Inhalte ohne Ersatz.

## Vorarbeit

1. Lies den vollständigen Zielartikel, nicht nur den Anfang.
2. Ermittle alle Überschriften, vorhandene Notebooks, interne Links und Ressourcenblöcke. Erkenne besonders eine flache Folge gleichrangiger `### 2.x`-Kapitel, die in Themenblöcke überführt werden soll.
3. Prüfe verwandte Kapitel im Repository und verlinke nur Dateien, die tatsächlich existieren.
4. Recherchiere externe Ressourcen, wenn sie ergänzt oder ersetzt werden müssen. Bevorzuge Microsoft Learn für die Referenz und etablierte, fachlich passende Blogs für Praxis und Performance.
5. Erhalte die bestehende Sprache des Artikels: Deutsch für Erläuterungen, T-SQL-Begriffe und Code in ihrer üblichen Schreibweise.

## Zielstruktur und fachliche Hierarchie

Ein guter Übersichtsartikel ist **kein flaches Verzeichnis gleichrangiger Einzelthemen**. Bilde zuerst wenige fachliche Hauptblöcke und ordne Detailthemen darunter ein. Die Gliederung soll die Denk- und Lernreihenfolge sichtbar machen: Grundlagen → Kernmuster → Sonderfälle → Performance, Qualität und Betrieb.

Verwende für umfangreiche Artikel mindestens zwei Ebenen innerhalb von Kapitel 2:

```markdown
## 2 | Struktur

### 2.1 | Grundlagen und Kernkonzepte

Kurze Einordnung des Themenblocks.

#### 2.1.1 | Konkretes Unterthema
#### 2.1.2 | Konkretes Unterthema

### 2.2 | Zentrale Sprachmittel und Muster

#### 2.2.1 | Konkretes Unterthema

### 2.3 | Spezialfälle und Datenformate

### 2.4 | Performance, Qualität und Betrieb
```

Die Anzahl der Hauptblöcke richtet sich nach dem Thema; meist sind drei bis fünf sinnvoll. Verwende `###` für einen fachlichen Themenblock und `####` für ein konkretes Lern- oder Praxisthema. Behalte nur dann eine flache Struktur bei, wenn der Artikel höchstens vier eng zusammengehörende Unterthemen enthält.

Überführe bestehende gleichrangige Kapitel in diese Hierarchie, ohne Inhalte oder Notebook-Verweise zu verlieren. Passe Kapitelnummern, Inhaltsverzeichnis, Mermaid-Knoten und interne Abschnittsverweise vollständig an.

Verwende – sofern der Artikel keine gleichwertige, bewusst bessere Gliederung besitzt – diese Struktur:

```markdown
# T-SQL <Thema> – Übersicht

*Kurze Unterzeile: fachlicher Nutzen und Anwendungskontext*

## Inhaltsverzeichnis
…

## 1 | Begriffsdefinition
…

## 2 | Struktur

### 2.0 | Lernpfad, Ressourcen und Entscheidungshilfen
…

### 2.1 | Fachlicher Hauptblock
…

#### 2.1.1 | Konkretes Unterthema
…

## 3 | Häufige Fehler & Merksätze
…

## 4 | Weiterführende Informationen
…
```

Passe Kapitelnummern konsequent an, falls ein neuer Abschnitt eingefügt wird. Verweise und Inhaltsverzeichnis müssen anschließend auf die neuen Nummern zeigen.

## 1. Inhaltsverzeichnis und Navigation

- Füge unmittelbar nach Titel und Unterzeile ein Inhaltsverzeichnis mit funktionierenden Markdown-Ankern ein.
- Nenne alle Hauptkapitel, Themenblöcke `2.x` und Detailabschnitte `2.x.y`.
- Halte die Einträge lesbar; verkürze Titel im Inhaltsverzeichnis nur, wenn der Anker weiterhin korrekt auf die tatsächliche Überschrift zeigt.
- Ergänze in `2.0` drei bis fünf interne Verweise zu fachlich benachbarten, vorhandenen Kapiteln. Erkläre pro Link in einem kurzen Halbsatz, weshalb er relevant ist.

## 2. Lernpfad und Ressourcen

Ergänze Abschnitt `2.0` mit:

- Zielgruppe und fachlichen Voraussetzungen;
- sinnvoller Lernreihenfolge (Grundlagen → Muster → Performance/Spezialfälle);
- klarer Ressourcennutzung: Notebook als Praxis, Video als Einstieg, erster Learn-Link als Referenz, weitere Learn-Links als Vertiefung, Blogbeiträge als Praxis/Performance;
- einer kompakten Tabelle mit einem Mini-Beispiel für jedes Unterkapitel. Jedes Beispiel muss syntaktisch plausibles T-SQL sein und darf nur eine Kernidee zeigen.

## 3. Ausführliche Beschreibung pro Detailabschnitt

Nach jeder vorhandenen Kurzbeschreibung ergänzen:

```markdown
> **Ausführliche Beschreibung:** …
```

Die Beschreibung umfasst üblicherweise 3–6 präzise Sätze und beantwortet:

1. Was leistet das Konstrukt?
2. Wann wird es eingesetzt?
3. Welche Semantik oder Voraussetzung ist entscheidend?
4. Welcher typische Fehler, Grenzfall oder Performance-Aspekt ist relevant?

Vermeide leere Allgemeinplätze. Beschreibe insbesondere `NULL`-Verhalten, Reihenfolge, Kardinalität, Datentypen, Isolation oder Indexauswirkungen, wenn sie für das Thema wichtig sind.

## 4. Ressourcen je Unterkapitel

Behalte vorhandene Notebooks, Videos und Dokumentationslinks. Formatiere sie einheitlich:

```markdown
- 📓 **Notebook – Praxis:**
  - [`<datei>.ipynb`](<datei>.ipynb)

- 🎥 **Video – Einstieg:**
  - [Titel](https://…)

- 📘 **Microsoft Learn – Referenz & Vertiefung:**
  - [Einstiegsdokument](https://learn.microsoft.com/…)
  - [Weitere, direkt passende Dokumente](https://learn.microsoft.com/…)

- 📝 **Blogs & Praxis:**
  - [Konkreter Beitrag – Autor/Publikation](https://…)
  - [Konkreter Beitrag – Autor/Publikation](https://…)
```

Regeln:

- Die folgenden Elemente sind **verpflichtend**: ein funktionierender Notebook-Link als Unter-Aufzählungspunkt, konkrete Video-Links sowie konkrete weiterführende externe Quellen.
- Pro Unterkapitel insgesamt **5–10 hilfreiche Links** (Notebook und Video dürfen mitzählen); vermeide reine Duplikate.
- Ergänze mindestens **zwei konkrete externe Blog-/Praxisbeiträge** je Unterkapitel. Keine bloßen Startseiten, Tag-Seiten oder Suchseiten, sofern ein direkt passender Artikel verfügbar ist.
- Microsoft Learn ist die primäre Referenz; externe Quellen ergänzen sie und ersetzen sie nicht.
- Linktitel beschreiben Inhalt und Quelle. Nutze keine unkommentierten URLs.
- Verwende bei YouTube **konkrete Videos** mit direkter Video-URL (`youtube.com/watch?...` oder gleichwertig), keine YouTube-Suchseiten, Kanal-Startseiten oder Playlists als Ersatz für ein thematisches Video.
- Prüfe jeden neuen **und jeden bereits vorhandenen** externen Link im bearbeiteten Artikel auf Erreichbarkeit und fachliche Passung. Kennzeichne keine Suchergebnisse, Tag-Seiten, Kategorieübersichten oder Kanal-Startseiten als konkrete Artikel bzw. Videos.
- Ersetze vorhandene Suchseiten oder Playlists durch konkrete Zielressourcen, auch wenn der Link bereits vor der Überarbeitung existierte. Beispiel für einen ungültigen Video-Link: `https://www.youtube.com/results?search_query=...`; verwende stattdessen eine direkte Video-URL wie `https://www.youtube.com/watch?v=...`.
- Halte je Ressource den Einzug konsistent. Insbesondere ist der Notebook-Link zwingend ein eigener Unter-Aufzählungspunkt, also exakt nach diesem Muster: `- 📓 **Notebook – Praxis:**` gefolgt von `  - [\`<datei>.ipynb\`](<datei>.ipynb)`.

## 5. Mermaid-Entscheidungshilfen

Füge in `2.0` zwei oder drei kleine Mermaid-Flowcharts ein, wenn sie eine Entscheidung sichtbar leichter machen als Text. Gute Muster sind:

- Lernpfad durch die Unterkapitel;
- Auswahl zwischen verwandten Sprachmitteln;
- Diagnose eines häufigen Fehlerbilds oder einer Ergebnisabweichung.

Anforderungen:

- Jeder Knoten besitzt eine kurze, fachlich eindeutige Beschriftung.
- Diagramme sind statisch, klein und ohne dekorative Farben oder komplexe Formatierung.
- Verweise in Knoten auf die passenden Abschnitte, z. B. `2.4–2.5`.
- Keine Diagramme nur zur Dekoration und keine Inhalte, die in einer zweizeiligen Liste klarer wären.

## 6. Häufige Fehler & Merksätze

Füge vor den weiterführenden Informationen eine prägnante Tabelle ein:

```markdown
## 3 | Häufige Fehler & Merksätze

| Thema | Häufiger Fehler | Merksatz |
|---|---|---|
| … | … | … |
```

Ergänze 6–10 echte Fehlerbilder zum jeweiligen Thema. Schließe mit einer kurzen, fachlich passenden Prüfreihenfolge für Produktivcode ab, zum Beispiel: Semantik → Randfälle/`NULL` → Datentypen → Plan/Indizes → Nebenläufigkeit.

## Qualitätskriterien

- Alle Beschreibungen sind fachlich präzise, praxisorientiert und in gutem Deutsch formuliert.
- Jeder Detailabschnitt `#### 2.x.y` besitzt Kurzbeschreibung, ausführliche Beschreibung, Notebook, Ressourcen und passende Links. Ein Hauptblock `### 2.x` besitzt eine kurze fachliche Einordnung und bündelt seine Detailabschnitte.
- Jeder Detailabschnitt enthält mindestens einen konkreten Microsoft-Learn-Link, zwei konkrete externe Blog-/Praxisbeiträge und mindestens einen direkten YouTube-Video-Link.
- Kein Notebook-Link steht als bloße eingerückte Textzeile: jeder ist ein Unter-Aufzählungspunkt unter dem Notebook-Label.
- Code in Mini-Beispielen ist kompakt, formatiert und ohne erfundene Ergebnisbehauptungen.
- Neue relative Links verweisen auf vorhandene Dateien.
- Inhaltsverzeichnis, Überschriftennummern und interne Abschnittsverweise sind konsistent.
- Markdown ist sauber: keine unbeabsichtigten Leerzeichen am Zeilenende, korrekt geschlossene Code-Fences, gültige Tabellen und Listen.
- Führe nach der Bearbeitung mindestens `git diff --check -- <zielartikel>` aus und behebe alle Befunde.

## Verbindliche Abnahme vor der Übergabe

Beende die Überarbeitung erst, nachdem diese Prüfungen dokumentiert und bestanden sind:

1. **Struktur:** Jedes ursprüngliche Fachthema ist genau einem fachlich passenden Hauptblock und Detailabschnitt zugeordnet. Kein Thema und kein Notebook ging beim Umnummerieren verloren.
2. **Vollständigkeit:** Zähle die Detailabschnitte. Für jeden existieren Kurzbeschreibung, ausführliche Beschreibung, Notebook-Unterpunkt, mindestens ein konkretes Video, mindestens ein Learn-Link und zwei konkrete externe Blog-/Praxisbeiträge.
3. **Lokale Ziele:** Prüfe jeden Notebook-Link und jeden neu eingefügten relativen Markdown-Link gegen das Dateisystem. Entferne oder korrigiere ungültige Ziele; verwende keine Platzhalter.
4. **Externe Ziele:** Öffne bzw. prüfe jeden neuen und vorhandenen externen Link im bearbeiteten Artikel. Er muss direkt zum angekündigten Artikel, Video oder Microsoft-Learn-Dokument führen und darf keine Suche, Startseite, Kategorie- oder Tag-Übersicht sein. Führe zusätzlich `rg -n 'youtube\.com/results|youtube\.com/c/|youtube\.com/playlist' <zielartikel>` aus: Jeder Treffer ist ein Regelverstoß und muss durch eine konkrete Video-URL ersetzt werden.
5. **Navigation:** Prüfe, dass jeder Eintrag des Inhaltsverzeichnisses zu einer vorhandenen Überschrift führt und dass Nummern in Text, Tabellen, Mermaid-Knoten und Überschriften übereinstimmen.
6. **Mermaid:** Prüfe jeden Mermaid-Codeblock auf geschlossene Fences, verständliche Knotenbeschriftungen und Verweise auf vorhandene Abschnitte. Das Diagramm muss eine echte Auswahl- oder Diagnoseentscheidung unterstützen.
7. **Markdown:** Führe `git diff --check -- <zielartikel>` aus. Prüfe zusätzlich Listenebenen, Tabellen und Code-Fences; alle Befunde sind vor der Übergabe zu beheben.
8. **Änderungsumfang:** Prüfe `git diff -- <zielartikel>` inhaltlich. Die Änderung muss die beabsichtigte Qualitätssteigerung zeigen, ohne unbeteiligte Inhalte umzuschreiben oder Ressourcen zu entfernen.

Berichte bei der Übergabe kurz und konkret: Anzahl der Haupt- und Detailabschnitte, Anzahl ergänzter Mermaid-Diagramme, geprüfte interne Links, Ressourcenabdeckung sowie Ergebnis von `git diff --check`.

## Abgrenzung

- Erstelle keine Übungen, Aufgabenserien oder Lösungen, sofern dies nicht ausdrücklich beauftragt ist.
- Pflege keine Linkdatenbanken oder Veröffentlichungsjahre nach, sofern dies nicht ausdrücklich beauftragt ist.
- Ändere keine anderen Artikel außer den für interne Links zwingend nötigen, lokalen Verweisen.
- Erfinde weder Notebook-Dateien noch interne Dokumente. Fehlt eine Ressource, schreibe keinen Platzhalter-Link.
