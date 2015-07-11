#requires -Version 3.0

Remove-Module [P]rofiler
Import-Module $PSScriptRoot\Profiler.psm1 -ErrorAction Stop

Describe 'Get-ScriptPerfData' {
    Context 'Timing sanity checks' {
        Set-Content -LiteralPath TestDrive:\test.ps1 -Value @'
            Write-Verbose Hello
            Start-Sleep -Milliseconds 500
            Write-Verbose World
            Start-Sleep -Milliseconds 300
'@

        $report = Get-ScriptPerfData -Path TestDrive:\test.ps1 -ScriptBlock { TestDrive:\test.ps1 } |
                  Sort-Object Line

        # Hopefully a 100-ms window is enough to ensure these tests pass when the module
        # is behaving properly.  The original code only allowed for 50ms, and failed on the
        # new cloud-based build agents.

        It 'Assigns timing values to the correct lines' {
            $report[0].TotalMilliseconds | Should BeLessThan 100
            $report[1].TotalMilliseconds | Should BeGreaterThan 400
            $report[1].TotalMilliseconds | Should BeLessThan 600
            $report[2].TotalMilliseconds | Should BeLessThan 100
            $report[3].TotalMilliseconds | Should BeGreaterThan 200
            $report[3].TotalMilliseconds | Should BeLessThan 400
        }
    }

    Context 'Hit counts' {
        Set-Content -LiteralPath TestDrive:\test.ps1 -Value @'
            Write-Verbose Hello
            foreach ($number in 1..5)
            {
                Write-Verbose World
            }
            Start-Sleep -Milliseconds 100
'@

        $report = Get-ScriptPerfData -Path TestDrive:\test.ps1 -ScriptBlock { TestDrive:\test.ps1 }

        $hash = @{}

        foreach ($item in $report)
        {
            $hash[[int]($item.Line)] = $item
        }

        It 'Assigns the correct hit counts' {
            $hash[1].HitCount | Should Be 1
            $hash[2].HitCount | Should Be 1
            $hash[4].HitCount | Should Be 5
            $hash[6].HitCount | Should Be 1
        }
    }
}
