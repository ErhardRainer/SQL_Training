<#
.SYNOPSIS
    Wrapper-Skript zum Starten des Jupyter Notebook zu Markdown Konverters.

.DESCRIPTION
    Dieses PowerShell-Skript startet den Python-basierten Notebook-Konverter
    und prueft vorab die Voraussetzungen (Python-Installation).

.PARAMETER ShowOutput
    Zeigt das Output-Verzeichnis nach erfolgreicher Ausfuehrung im Explorer an.

.PARAMETER OpenLog
    Oeffnet die generierte Log-Datei nach der Ausfuehrung.

.EXAMPLE
    .\run_converter.ps1
    Fuehrt die Konvertierung aus.

.EXAMPLE
    .\run_converter.ps1 -ShowOutput
    Fuehrt die Konvertierung aus und oeffnet das Output-Verzeichnis.

.EXAMPLE
    .\run_converter.ps1 -OpenLog
    Fuehrt die Konvertierung aus und oeffnet die Log-Datei.

.NOTES
    Autor: Erhard Rainer
    Datum: 2026-04-18
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [switch]$ShowOutput,
    
    [Parameter(Mandatory=$false)]
    [switch]$OpenLog
)

# Fehlerbehandlung
$ErrorActionPreference = "Stop"

# Variablen
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonScript = Join-Path $ScriptDir "convert_notebooks.py"
$OutputDir = Join-Path $ScriptDir "output"
$LogPattern = "*_log.json"
$PythonCommand = "python"  # Default, wird von Test-PythonInstallation ueberschrieben

# Header ausgeben
Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host " Jupyter Notebook zu Markdown Konverter" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""

# Funktion: Python-Version pruefen
function Test-PythonInstallation {
    # Verschiedene Python-Befehle versuchen
    $pythonCommands = @('python', 'python3', 'py', 'py3')
    $pythonFound = $null
    
    foreach ($cmd in $pythonCommands) {
        try {
            $pythonVersion = & $cmd --version 2>&1
            if ($pythonVersion -match "Python (\d+)\.(\d+)") {
                $major = [int]$Matches[1]
                $minor = [int]$Matches[2]
                
                Write-Host "[OK] Python gefunden ($cmd): " -ForegroundColor Green -NoNewline
                Write-Host $pythonVersion
                
                if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 7)) {
                    Write-Host "[WARNUNG] Python 3.7+ wird benoetigt, aber " -ForegroundColor Yellow -NoNewline
                    Write-Host "$major.$minor gefunden" -ForegroundColor Yellow
                    continue
                }
                
                # Gefundenen Befehl global speichern
                $script:PythonCommand = $cmd
                return $true
            }
        }
        catch {
            # Befehl nicht gefunden, naechsten versuchen
            continue
        }
    }
    
    # Kein Python gefunden
    Write-Host "[FEHLER] Python ist nicht installiert oder nicht im PATH!" -ForegroundColor Red
    Write-Host "  Versuchte Befehle: $($pythonCommands -join ', ')" -ForegroundColor Yellow
    Write-Host "  Bitte installieren Sie Python von https://www.python.org/" -ForegroundColor Yellow
    return $false
}

# Funktion: Skript-Existenz pruefen
function Test-ScriptExists {
    if (Test-Path $PythonScript) {
        Write-Host "[OK] Konverter-Skript gefunden: " -ForegroundColor Green -NoNewline
        Write-Host "convert_notebooks.py"
        return $true
    }
    else {
        Write-Host "[FEHLER] Skript nicht gefunden: $PythonScript" -ForegroundColor Red
        return $false
    }
}

# Funktion: Neueste Log-Datei finden
function Get-LatestLogFile {
    $logFiles = Get-ChildItem -Path $ScriptDir -Filter $LogPattern -ErrorAction SilentlyContinue | 
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
    
    if ($logFiles) {
        return $logFiles.FullName
    }
    return $null
}

# Hauptausfuehrung
try {
    # Voraussetzungen pruefen
    Write-Host "Pruefe Voraussetzungen..." -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-PythonInstallation)) {
        exit 1
    }
    
    if (-not (Test-ScriptExists)) {
        exit 1
    }
    
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""
    
    # Python-Skript ausfuehren
    Write-Host "Starte Konvertierung..." -ForegroundColor Yellow
    Write-Host ""
    
    $startTime = Get-Date
    
    # Python-Skript im gleichen Verzeichnis ausfuehren
    Push-Location $ScriptDir
    try {
        & $PythonCommand $PythonScript
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""
    
    if ($exitCode -eq 0 -or $null -eq $exitCode) {
        Write-Host "[ERFOLG] Konvertierung erfolgreich abgeschlossen!" -ForegroundColor Green
        Write-Host "  Dauer: $($duration.ToString('mm\:ss')) Minuten" -ForegroundColor Gray
        Write-Host ""
        
        # Output-Verzeichnis anzeigen
        if (Test-Path $OutputDir) {
            $fileCount = (Get-ChildItem -Path $OutputDir -Recurse -File -Filter "*.md" -ErrorAction SilentlyContinue | Measure-Object).Count
            Write-Host "  Generierte Dateien: $fileCount" -ForegroundColor Gray
            Write-Host "  Output-Verzeichnis: $OutputDir" -ForegroundColor Gray
        }
        
        # Log-Datei anzeigen
        $latestLog = Get-LatestLogFile
        if ($latestLog) {
            Write-Host "  Log-Datei: $latestLog" -ForegroundColor Gray
        }
        
        Write-Host ""
        
        # Optional: Output-Verzeichnis oeffnen
        if ($ShowOutput -and (Test-Path $OutputDir)) {
            Write-Host "Oeffne Output-Verzeichnis..." -ForegroundColor Cyan
            explorer.exe $OutputDir
        }
        
        # Optional: Log-Datei oeffnen
        if ($OpenLog -and $latestLog) {
            Write-Host "Oeffne Log-Datei..." -ForegroundColor Cyan
            Start-Process $latestLog
        }
    }
    else {
        Write-Host "[FEHLER] Fehler bei der Konvertierung (Exit Code: $exitCode)" -ForegroundColor Red
        exit $exitCode
    }
}
catch {
    Write-Host ""
    Write-Host "[FEHLER] Unerwarteter Fehler:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}
finally {
    Write-Host ""
}
