$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonScript = Join-Path $scriptDir 'generate_tasks.py'

if (-not (Test-Path -LiteralPath $pythonScript)) {
    throw "Python-Skript nicht gefunden: $pythonScript"
}

$pyCommand = Get-Command py -ErrorAction SilentlyContinue
if (-not $pyCommand) {
    throw "Der Python-Launcher 'py' wurde nicht gefunden."
}

& $pyCommand.Source -3 $pythonScript @args
exit $LASTEXITCODE
