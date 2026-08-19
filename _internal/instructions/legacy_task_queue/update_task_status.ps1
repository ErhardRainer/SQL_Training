param(
    [Parameter(Mandatory = $true)]
    [string]$TaskId,

    [Parameter(Mandatory = $true)]
    [ValidateSet('claim', 'done', 'blocked', 'failed')]
    [string]$Mode,

    [string]$ClaimedAt,
    [string]$CompletedAt,
    [string]$Worker = 'codex-create-sql-script',
    [string]$Note = 'Automation claim for single-task SQL artifact generation',
    [string[]]$FilesChanged = @(),
    [string[]]$Assumptions = @(),
    [string]$LastError
)

$path = Join-Path $PSScriptRoot 'Task.json'
$tempPath = Join-Path $PSScriptRoot 'Task.json.codex-update.tmp'

$reader = [System.IO.File]::OpenText($path)
$writer = New-Object System.IO.StreamWriter($tempPath, $false, [System.Text.UTF8Encoding]::new($false))

$inTarget = $false
$resultInserted = $false
$skipExistingResult = $false
$braceDepth = 0

function Write-ResultBlock {
    param(
        [System.IO.StreamWriter]$OutWriter,
        [string]$Indent,
        [string]$DoneAt,
        [string[]]$ChangedFiles,
        [string[]]$AssumptionList,
        [string]$ErrorText,
        [string]$CurrentMode
    )

    $OutWriter.WriteLine($Indent + '"result":  {')

    if ($CurrentMode -eq 'done') {
        $OutWriter.WriteLine($Indent + '               "completed_at":  "' + $DoneAt + '",')
        $OutWriter.WriteLine($Indent + '               "files_changed":  [')
        for ($idx = 0; $idx -lt $ChangedFiles.Count; $idx++) {
            $comma = if ($idx -lt $ChangedFiles.Count - 1) { ',' } else { '' }
            $OutWriter.WriteLine($Indent + '                                     "' + $ChangedFiles[$idx] + '"' + $comma)
        }
        $OutWriter.WriteLine($Indent + '                                 ],')
        $OutWriter.WriteLine($Indent + '               "assumptions":  [')
        for ($idx = 0; $idx -lt $AssumptionList.Count; $idx++) {
            $comma = if ($idx -lt $AssumptionList.Count - 1) { ',' } else { '' }
            $OutWriter.WriteLine($Indent + '                                   "' + $AssumptionList[$idx] + '"' + $comma)
        }
        $OutWriter.WriteLine($Indent + '                               ]')
    }
    else {
        $OutWriter.WriteLine($Indent + '               "last_error":  ' + ($(if ($ErrorText) { '"' + $ErrorText + '"' } else { 'null' })))
    }

    $OutWriter.WriteLine($Indent + '           }')
}

try {
    while (($line = $reader.ReadLine()) -ne $null) {
        if ($line -match '"id":  "' + [regex]::Escape($TaskId) + '"') {
            $inTarget = $true
            $resultInserted = $false
        }

        if ($inTarget) {
            if ($line -match '^\s+"lease":') {
                if ($Mode -eq 'claim') {
                    $writer.WriteLine('                      "lease":  {')
                    $writer.WriteLine('                                    "claimed_at":  "' + $ClaimedAt + '",')
                    $writer.WriteLine('                                    "worker":  "' + $Worker + '",')
                    $writer.WriteLine('                                    "note":  "' + $Note + '"')
                    $writer.WriteLine('                                },')
                }
                else {
                    $writer.WriteLine('                      "lease":  null,')
                }
                continue
            }

            if ($line -match '^\s+"status":') {
                switch ($Mode) {
                    'claim' { $writer.WriteLine('                      "status":  "in_progress"') }
                    'done' { $writer.WriteLine('                      "status":  "done",') }
                    'blocked' { $writer.WriteLine('                      "status":  "blocked",') }
                    'failed' { $writer.WriteLine('                      "status":  "failed",') }
                }

                if ($Mode -ne 'claim') {
                    if ($Mode -eq 'done') {
                        $writer.WriteLine('                      "result":  {')
                        $writer.WriteLine('                                     "completed_at":  "' + $CompletedAt + '",')
                        $writer.WriteLine('                                     "files_changed":  [')
                        for ($idx = 0; $idx -lt $FilesChanged.Count; $idx++) {
                            $comma = if ($idx -lt $FilesChanged.Count - 1) { ',' } else { '' }
                            $writer.WriteLine('                                                           "' + $FilesChanged[$idx] + '"' + $comma)
                        }
                        $writer.WriteLine('                                                       ],')
                        $writer.WriteLine('                                     "assumptions":  [')
                        for ($idx = 0; $idx -lt $Assumptions.Count; $idx++) {
                            $comma = if ($idx -lt $Assumptions.Count - 1) { ',' } else { '' }
                            $writer.WriteLine('                                                         "' + $Assumptions[$idx] + '"' + $comma)
                        }
                        $writer.WriteLine('                                                     ]')
                        $writer.WriteLine('                                 }')
                    }
                    else {
                        $writer.WriteLine('                      "result":  {')
                        $writer.WriteLine('                                     "last_error":  ' + ($(if ($LastError) { '"' + $LastError + '"' } else { 'null' })))
                        $writer.WriteLine('                                 }')
                    }
                    $resultInserted = $true
                }

                continue
            }

            if ($Mode -ne 'claim' -and $line -match '^\s+"last_error":') {
                if ($Mode -eq 'done') {
                    $writer.WriteLine('                      "last_error":  null,')
                }
                else {
                    $writer.WriteLine('                      "last_error":  "' + $LastError + '",')
                }
                continue
            }

            if ($Mode -eq 'failed' -and $line -match '^\s+"retry_count":\s+(\d+),') {
                $nextRetry = [int]$Matches[1] + 1
                $writer.WriteLine('                      "retry_count":  ' + $nextRetry + ',')
                continue
            }

            if ($line -match '^\s+"result":\s+\{') {
                $skipExistingResult = $true
                $braceDepth = 1
                continue
            }

            if ($skipExistingResult) {
                $openCount = ([regex]::Matches($line, '\{')).Count
                $closeCount = ([regex]::Matches($line, '\}')).Count
                $braceDepth += $openCount
                $braceDepth -= $closeCount
                if ($braceDepth -le 0) {
                    $skipExistingResult = $false
                }
                continue
            }

            if ($line -match '^\s+\},?$' -and $Mode -ne 'claim') {
                if (-not $resultInserted) {
                    if ($Mode -eq 'done') {
                        $writer.WriteLine('                      "result":  {')
                        $writer.WriteLine('                                     "completed_at":  "' + $CompletedAt + '",')
                        $writer.WriteLine('                                     "files_changed":  [')
                        for ($idx = 0; $idx -lt $FilesChanged.Count; $idx++) {
                            $comma = if ($idx -lt $FilesChanged.Count - 1) { ',' } else { '' }
                            $writer.WriteLine('                                                           "' + $FilesChanged[$idx] + '"' + $comma)
                        }
                        $writer.WriteLine('                                                       ],')
                        $writer.WriteLine('                                     "assumptions":  [')
                        for ($idx = 0; $idx -lt $Assumptions.Count; $idx++) {
                            $comma = if ($idx -lt $Assumptions.Count - 1) { ',' } else { '' }
                            $writer.WriteLine('                                                         "' + $Assumptions[$idx] + '"' + $comma)
                        }
                        $writer.WriteLine('                                                     ]')
                        $writer.WriteLine('                                 }')
                    }
                    elseif ($Mode -in @('blocked', 'failed')) {
                        $writer.WriteLine('                      "result":  {')
                        $writer.WriteLine('                                     "last_error":  "' + $LastError + '"')
                        $writer.WriteLine('                                 }')
                    }
                    $resultInserted = $true
                }
                $inTarget = $false
            }
        }

        $writer.WriteLine($line)
    }
}
finally {
    $reader.Close()
    $writer.Close()
}

Copy-Item -Force $tempPath $path
Remove-Item $tempPath -Force
