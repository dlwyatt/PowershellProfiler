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
}
