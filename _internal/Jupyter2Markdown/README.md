# Jupyter Notebook zu Markdown Konverter

Dieses Python-Skript extrahiert Markdown- und SQL-Blöcke aus Jupyter Notebooks (`.ipynb`) und konvertiert sie in Markdown-Dateien.

## Features

- ✅ Rekursive Suche nach allen `.ipynb` Dateien im Workspace
- ✅ Extraktion von Markdown-Zellen
- ✅ Extraktion von SQL-Code-Zellen
- ✅ Beibehaltung der Verzeichnisstruktur
- ✅ Detailliertes JSON-Logging mit Zeitstempel
- ✅ Fehlerbehandlung und Statistiken

## Verwendung

### Empfohlen: PowerShell-Wrapper

```powershell
cd C:\_Git\GitHub\SQL_Training\_internal\Jupyter2Markdown
.\run_converter.ps1
```

**Mit Optionen:**
```powershell
# Output-Verzeichnis nach der Konvertierung öffnen
.\run_converter.ps1 -ShowOutput

# Log-Datei nach der Konvertierung öffnen
.\run_converter.ps1 -OpenLog

# Beides kombinieren
.\run_converter.ps1 -ShowOutput -OpenLog
```

### Alternativ: Direkt mit Python

```powershell
cd C:\_Git\GitHub\SQL_Training\_internal\Jupyter2Markdown
python convert_notebooks.py
```

### Was das Skript tut

1. Sucht rekursiv alle `.ipynb` Dateien im `SQL_Training` Verzeichnis
2. Extrahiert Markdown- und SQL-Zellen
3. Erstellt Markdown-Dateien im `output/` Unterordner
4. Generiert eine Log-Datei: `yyyymmddhhmmss_log.json`

### Output-Struktur

```
_internal/Jupyter2Markdown/
├── convert_notebooks.py          # Hauptskript
├── README.md                      # Diese Datei
├── 20260418120000_log.json       # Log-Datei (Beispiel)
└── output/                        # Generierte Markdown-Dateien
    └── T-SQL/
        └── 02_Select/
            └── 02_01_select_grundlagen.md
```

## Log-Datei

Jede Ausführung erstellt eine Log-Datei mit folgendem Format:

```json
{
  "timestamp": "2026-04-18T12:00:00.123456",
  "root_directory": "C:\\_Git\\GitHub\\SQL_Training",
  "output_directory": "C:\\_Git\\GitHub\\SQL_Training\\_internal\\Jupyter2Markdown\\output",
  "processed_files": [
    {
      "notebook": "T-SQL/02_Select/02_01_select_grundlagen.ipynb",
      "output": "T-SQL/02_Select/02_01_select_grundlagen.md",
      "markdown_cells": 25,
      "sql_cells": 15,
      "total_cells": 40,
      "status": "success"
    }
  ],
  "errors": [],
  "statistics": {
    "total_notebooks": 1,
    "successful": 1,
    "failed": 0,
    "total_cells_extracted": 40,
    "markdown_cells": 25,
    "sql_cells": 15
  }
}
```

## SQL-Erkennung

Das Skript erkennt SQL-Code-Zellen anhand von:
- Expliziten Metadaten (`language: sql`)
- SQL-Keywords am Anfang: `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `CREATE`, `DROP`, `ALTER`, `USE`, `GO`, `SET`, `IF`, `DECLARE`, `WITH`

## Anpassungen

Sie können das Skript anpassen, indem Sie die `main()`-Funktion bearbeiten:

```python
def main():
    script_dir = Path(__file__).parent
    root_dir = script_dir.parent.parent  # Anpassen für andere Verzeichnisse
    output_dir = script_dir / "output"   # Anpassen für anderen Output
    log_dir = script_dir                 # Anpassen für Log-Verzeichnis
    
    converter = NotebookConverter(
        root_dir=str(root_dir),
        output_dir=str(output_dir),
        log_dir=str(log_dir)
    )
    
    converter.run()
```

## Voraussetzungen

- Python 3.7+
- Keine externen Pakete erforderlich (nur Standard-Bibliothek)

## Autor

Erhard Rainer  
Datum: 2026-04-18
