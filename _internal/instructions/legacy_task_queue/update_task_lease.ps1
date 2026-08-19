$path = 'C:\_Git\GitHub\SQL_Training\_internal\Task\Task.json'
$tmp = 'C:\_Git\GitHub\SQL_Training\_internal\Task\Task.json.tmp'
$targetId = 'sql-0399'
$inTask = $false
$updated = $false

$reader = [System.IO.File]::OpenText($path)
$writer = New-Object System.IO.StreamWriter($tmp, $false, [System.Text.Encoding]::UTF8)

try {
    while (($line = $reader.ReadLine()) -ne $null) {
        if ($line -match '"id":\s+"sql-0399"') {
            $inTask = $true
        }

        if ($inTask -and $line -match '"claimed_at":') {
            $line = '                                    "claimed_at":  "2026-04-22T18:15:21Z",'
            $updated = $true
        }
        elseif ($inTask -and $line -match '"note":') {
            $line = '                                    "note":  "Automation reclaim for stale single-task SQL artifact generation"'
        }

        $writer.WriteLine($line)

        if ($inTask -and $line -match '"status":\s+"in_progress"') {
            $inTask = $false
        }
    }
}
finally {
    $writer.Close()
    $reader.Close()
}

if (-not $updated) {
    Remove-Item -LiteralPath $tmp -Force
    throw 'Target task sql-0399 not updated.'
}

Move-Item -LiteralPath $tmp -Destination $path -Force
