#requires -Version 3.0

Remove-Module [P]rofiler
Import-Module $PSScriptRoot\Profiler.psm1 -ErrorAction Stop

Describe 'Get-ScriptPerfData' {
    Context 'Timing sanity checks' {
        Set-Content -LiteralPath TestDrive:\test.ps1 -Value @'
            Write-Verbose Hello
            Start-Sleep -Milliseconds 200
            Write-Verbose World
            Start-Sleep -Milliseconds 100
'@

        $report = Get-ScriptPerfData -Path TestDrive:\test.ps1 -ScriptBlock { TestDrive:\test.ps1 } |
                  Sort-Object Line

        It 'Assigns timing values to the correct lines' {
            $report[0].TotalMilliseconds | Should BeLessThan 10
            $report[1].TotalMilliseconds | Should BeGreaterThan 150
            $report[1].TotalMilliseconds | Should BeLessThan 250
            $report[2].TotalMilliseconds | Should BeLessThan 10
            $report[3].TotalMilliseconds | Should BeGreaterThan 50
            $report[3].TotalMilliseconds | Should BeLessThan 150
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
