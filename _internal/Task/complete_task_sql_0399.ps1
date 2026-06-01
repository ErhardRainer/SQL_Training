$path = 'C:\_Git\GitHub\SQL_Training\_internal\Task\Task.json'
$tmp = 'C:\_Git\GitHub\SQL_Training\_internal\Task\Task.json.tmp'
$targetId = 'sql-0399'
$inTask = $false
$skipLeaseBody = $false
$updated = $false

$reader = [System.IO.File]::OpenText($path)
$writer = New-Object System.IO.StreamWriter($tmp, $false, [System.Text.Encoding]::UTF8)

try {
    while (($line = $reader.ReadLine()) -ne $null) {
        if ($line -match '"id":\s+"sql-0399"') {
            $inTask = $true
        }

        if ($inTask -and $line -match '"lease":\s+\{') {
            $writer.WriteLine('                      "lease":  null,')
            $skipLeaseBody = $true
            continue
        }

        if ($skipLeaseBody) {
            if ($line -match '^\s+\},$') {
                $skipLeaseBody = $false
            }
            continue
        }

        if ($inTask -and $line -match '"status":\s+"in_progress"') {
            $writer.WriteLine('                      "status":  "done",')
            $writer.WriteLine('                      "result":  {')
            $writer.WriteLine('                                     "completed_at":  "2026-04-22T18:20:09Z",')
            $writer.WriteLine('                                     "files_changed":  [')
            $writer.WriteLine('                                                           "T-SQL/24_UserDefinedFunctions/SQLScripts/FunctionSchemaBindingReadiness.sql",')
            $writer.WriteLine('                                                           "T-SQL/24_UserDefinedFunctions/SQLScripts/FunctionSchemaBindingReadiness.md"')
            $writer.WriteLine('                                                       ],')
            $writer.WriteLine('                                     "assumptions":  [')
            $writer.WriteLine('                                                         "Konservatives Readiness-Scoring statt automatischer SCHEMABINDING-Freigabe",')
            $writer.WriteLine('                                                         "Bewertung kombiniert Metadaten aus sys.sql_expression_dependencies mit einfachen Definitionstokens"')
            $writer.WriteLine('                                                     ]')
            $writer.WriteLine('                                 }')
            $updated = $true
            $inTask = $false
            continue
        }

        $writer.WriteLine($line)
    }
}
finally {
    $writer.Close()
    $reader.Close()
}

if (-not $updated) {
    Remove-Item -LiteralPath $tmp -Force
    throw 'Target task sql-0399 not completed.'
}
