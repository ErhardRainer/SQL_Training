"""
Jupyter Notebook zu Markdown Konverter
=======================================
Extrahiert Markdown- und SQL-Blöcke aus .ipynb Dateien und erstellt Markdown-Dokumente.

Autor: Erhard Rainer
Datum: 2026-04-18
"""

import json
import os
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any


class NotebookConverter:
    """Konvertiert Jupyter Notebooks zu Markdown-Dateien."""
    
    def __init__(self, root_dir: str, output_dir: str, log_dir: str = None):
        """
        Initialisiert den Converter.
        
        Args:
            root_dir: Wurzelverzeichnis für die Suche nach .ipynb Dateien
            output_dir: Zielverzeichnis für die generierten Markdown-Dateien
            log_dir: Verzeichnis für Log-Dateien (Standard: gleich wie Skript)
        """
        self.root_dir = Path(root_dir)
        self.output_dir = Path(output_dir)
        self.log_dir = Path(log_dir) if log_dir else Path(__file__).parent
        self.timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        self.log_data = {
            "timestamp": datetime.now().isoformat(),
            "root_directory": str(self.root_dir),
            "output_directory": str(self.output_dir),
            "processed_files": [],
            "errors": [],
            "statistics": {
                "total_notebooks": 0,
                "successful": 0,
                "failed": 0,
                "total_cells_extracted": 0,
                "markdown_cells": 0,
                "sql_cells": 0
            }
        }
        
    def find_notebooks(self) -> List[Path]:
        """
        Findet alle .ipynb Dateien im Wurzelverzeichnis.
        
        Returns:
            Liste der gefundenen Notebook-Pfade
        """
        notebooks = list(self.root_dir.rglob("*.ipynb"))
        # Checkpoint-Dateien ausschließen
        notebooks = [nb for nb in notebooks if not nb.name.startswith(".ipynb_checkpoints")]
        return notebooks
    
    def extract_cells(self, notebook_path: Path) -> Dict[str, Any]:
        """
        Extrahiert Markdown- und SQL-Zellen aus einem Notebook.
        
        Args:
            notebook_path: Pfad zum Notebook
            
        Returns:
            Dictionary mit extrahierten Daten
        """
        try:
            with open(notebook_path, 'r', encoding='utf-8') as f:
                notebook = json.load(f)
            
            cells_data = {
                "path": str(notebook_path),
                "relative_path": str(notebook_path.relative_to(self.root_dir)),
                "cells": [],
                "markdown_count": 0,
                "sql_count": 0
            }
            
            for idx, cell in enumerate(notebook.get('cells', []), 1):
                cell_type = cell.get('cell_type', '')
                source = cell.get('source', [])
                
                # Source kann Liste oder String sein
                if isinstance(source, list):
                    content = ''.join(source)
                else:
                    content = source
                
                # Markdown-Zellen
                if cell_type == 'markdown':
                    cells_data['cells'].append({
                        'type': 'markdown',
                        'number': idx,
                        'content': content
                    })
                    cells_data['markdown_count'] += 1
                
                # SQL-Zellen (code cells mit SQL)
                elif cell_type == 'code':
                    # Prüfen ob es sich um SQL handelt
                    # (z.B. durch Metadaten oder Inhalt)
                    metadata = cell.get('metadata', {})
                    language = metadata.get('language', '')
                    
                    # SQL-Erkennung: entweder explizit als SQL markiert
                    # oder beginnt mit typischen SQL-Keywords
                    is_sql = (
                        language.lower() == 'sql' or
                        content.strip().upper().startswith(('SELECT', 'INSERT', 'UPDATE', 
                                                            'DELETE', 'CREATE', 'DROP', 
                                                            'ALTER', 'USE', 'GO', 'SET',
                                                            'IF', 'DECLARE', 'WITH'))
                    )
                    
                    if is_sql:
                        cells_data['cells'].append({
                            'type': 'sql',
                            'number': idx,
                            'content': content
                        })
                        cells_data['sql_count'] += 1
            
            return cells_data
            
        except Exception as e:
            raise Exception(f"Fehler beim Lesen von {notebook_path}: {str(e)}")
    
    def create_markdown(self, cells_data: Dict[str, Any]) -> str:
        """
        Erstellt Markdown-Content aus den extrahierten Zellen.
        
        Args:
            cells_data: Extrahierte Zellendaten
            
        Returns:
            Markdown-String
        """
        md_lines = []
        
        # Header mit Metadaten
        md_lines.append(f"# {Path(cells_data['path']).stem}\n")
        md_lines.append(f"**Quelle:** `{cells_data['relative_path']}`  ")
        md_lines.append(f"**Generiert:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  ")
        md_lines.append(f"**Markdown-Zellen:** {cells_data['markdown_count']}  ")
        md_lines.append(f"**SQL-Zellen:** {cells_data['sql_count']}  \n")
        md_lines.append("---\n")
        
        # Zellen verarbeiten
        for cell in cells_data['cells']:
            if cell['type'] == 'markdown':
                # Markdown direkt einfügen
                md_lines.append(cell['content'])
                md_lines.append("\n")
            
            elif cell['type'] == 'sql':
                # SQL in Code-Block
                md_lines.append("```sql")
                md_lines.append(cell['content'])
                md_lines.append("```\n")
        
        return '\n'.join(md_lines)
    
    def save_markdown(self, markdown_content: str, notebook_path: Path) -> Path:
        """
        Speichert Markdown-Datei mit entsprechender Verzeichnisstruktur.
        
        Args:
            markdown_content: Markdown-Inhalt
            notebook_path: Original-Notebook-Pfad
            
        Returns:
            Pfad zur erstellten Markdown-Datei
        """
        # Relative Struktur beibehalten
        rel_path = notebook_path.relative_to(self.root_dir)
        output_path = self.output_dir / rel_path.parent / f"{notebook_path.stem}.md"
        
        # Verzeichnis erstellen falls nötig
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Markdown speichern
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(markdown_content)
        
        return output_path
    
    def process_notebook(self, notebook_path: Path) -> bool:
        """
        Verarbeitet ein einzelnes Notebook.
        
        Args:
            notebook_path: Pfad zum Notebook
            
        Returns:
            True bei Erfolg, False bei Fehler
        """
        try:
            # Zellen extrahieren
            cells_data = self.extract_cells(notebook_path)
            
            # Markdown erstellen
            markdown_content = self.create_markdown(cells_data)
            
            # Speichern
            output_path = self.save_markdown(markdown_content, notebook_path)
            
            # Log-Daten aktualisieren
            self.log_data['processed_files'].append({
                "notebook": str(notebook_path.relative_to(self.root_dir)),
                "output": str(output_path.relative_to(self.output_dir)),
                "markdown_cells": cells_data['markdown_count'],
                "sql_cells": cells_data['sql_count'],
                "total_cells": cells_data['markdown_count'] + cells_data['sql_count'],
                "status": "success"
            })
            
            self.log_data['statistics']['successful'] += 1
            self.log_data['statistics']['total_cells_extracted'] += (
                cells_data['markdown_count'] + cells_data['sql_count']
            )
            self.log_data['statistics']['markdown_cells'] += cells_data['markdown_count']
            self.log_data['statistics']['sql_cells'] += cells_data['sql_count']
            
            return True
            
        except Exception as e:
            self.log_data['errors'].append({
                "notebook": str(notebook_path.relative_to(self.root_dir)),
                "error": str(e)
            })
            self.log_data['statistics']['failed'] += 1
            print(f"Fehler bei {notebook_path.name}: {e}")
            return False
    
    def run(self):
        """Führt die Konvertierung aller Notebooks durch."""
        print(f"Starte Notebook-Konvertierung...")
        print(f"Wurzelverzeichnis: {self.root_dir}")
        print(f"Ausgabeverzeichnis: {self.output_dir}")
        
        # Output-Verzeichnis erstellen
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Notebooks finden
        notebooks = self.find_notebooks()
        self.log_data['statistics']['total_notebooks'] = len(notebooks)
        
        print(f"\nGefundene Notebooks: {len(notebooks)}")
        
        # Notebooks verarbeiten
        for notebook in notebooks:
            print(f"Verarbeite: {notebook.relative_to(self.root_dir)}")
            self.process_notebook(notebook)
        
        # Log speichern
        self.save_log()
        
        # Zusammenfassung
        print("\n" + "="*60)
        print("ZUSAMMENFASSUNG")
        print("="*60)
        print(f"Gesamt Notebooks: {self.log_data['statistics']['total_notebooks']}")
        print(f"Erfolgreich: {self.log_data['statistics']['successful']}")
        print(f"Fehler: {self.log_data['statistics']['failed']}")
        print(f"Markdown-Zellen: {self.log_data['statistics']['markdown_cells']}")
        print(f"SQL-Zellen: {self.log_data['statistics']['sql_cells']}")
        print(f"Gesamt Zellen: {self.log_data['statistics']['total_cells_extracted']}")
        print(f"\nLog-Datei: {self.log_dir / f'{self.timestamp}_log.json'}")
        print("="*60)
    
    def save_log(self):
        """Speichert die Log-Datei."""
        log_file = self.log_dir / f"{self.timestamp}_log.json"
        
        with open(log_file, 'w', encoding='utf-8') as f:
            json.dump(self.log_data, f, indent=2, ensure_ascii=False)


def main():
    """Hauptfunktion."""
    # Konfiguration
    script_dir = Path(__file__).parent
    root_dir = script_dir.parent.parent  # SQL_Training Verzeichnis
    output_dir = script_dir / "output"
    log_dir = script_dir
    
    # Converter erstellen und ausführen
    converter = NotebookConverter(
        root_dir=str(root_dir),
        output_dir=str(output_dir),
        log_dir=str(log_dir)
    )
    
    converter.run()


if __name__ == "__main__":
    main()
