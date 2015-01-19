#requires -Version 3.0
function Get-ScriptPerfData
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $Path,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )

    $breakpoints         = $null
    $script:ExecutionLog = $null
    $commandInfoTable    = @{}

    try
    {
        $resolvedPaths = Resolve-Path -Path $Path -ErrorAction Stop
        $paths = foreach ($resolvedPath in $resolvedPaths)
        {
            $item = Get-Item -LiteralPath $resolvedPath.Path
            if ($item -is [System.IO.FileInfo] -and $item.Extension -match '\.psm?1')
            {
                $item.FullName
            }
            else
            {
                Write-Error "Path resolved to non-powershell script file '$($resolvedPath.Path)'; this item will not be included in the analysis."
            }
        }

        $paths = $paths | Select-Object -Unique

        $breakpoints = @(Get-ProfilerBreakpoints -Path $paths)
        $script:ExecutionLog = @{}
        [uint64] $script:TotalCount = 0
        $script:LastTimestamp = $startTime = [datetime]::UtcNow

        try
        {
            $null = & $ScriptBlock
        } catch { }

        Get-ProfilerReport -ExecutionLog $script:ExecutionLog -TotalTime ($script:LastTimestamp - $startTime) -TotalCount $script:TotalCount
    }
    finally
    {
        if ($null -ne $breakpoints)
        {
            $breakpoints | Remove-PSBreakpoint
        }

        $breakpoints         = $null
        $script:ExecutionLog = $null
    }
}

function Get-ProfilerReport
{
    param (
        [hashtable] $ExecutionLog,
        [timespan] $TotalTime,
        [uint64] $TotalCount
    )

    if ($null -eq $ExecutionLog -or $ExecutionLog.Count -eq 0) { return }

    $totalMS = $TotalTime.TotalMilliseconds

    foreach ($group in $ExecutionLog.Values)
    {
        [pscustomobject] @{
            File              = $group.File
            Line              = $group.Line
            TotalMilliseconds = [math]::Round($group.TotalMS, 2)
            PercentTime       = [math]::Round(100 * $group.TotalMS / $totalMS, 2)
            HitCount          = $group.HitCount
            PercentHitCount   = [math]::Round(100 * $group.HitCount / $TotalCount, 2)
        }
    }
}

function Get-ProfilerBreakpoints
{
    [CmdletBinding()]
    param (
        [string[]] $Path
    )

    foreach ($filePath in $Path)
    {
        Write-Verbose "Initializing performance analysis for file '$filePath'"

        $lines = [System.IO.File]::ReadAllLines($PSCmdlet.GetUnresolvedProviderPathFromPSPath($filePath))
        $lineCount = $lines.Count

        $lineNumbers = for ($i = 1; $i -le $lineCount; $i++) { if (-not [string]::IsNullOrWhiteSpace($lines[$i-1])) { $i } }

        New-ProfilerBreakpoint -Path $filePath -LineNumber $lineNumbers
    }
}

function New-ProfilerBreakpoint
{
    param ([string] $Path, [int[]] $LineNumber)

    $params = @{
        Script = $Path
        Line   = $LineNumber
        Action = {
            $now = [datetime]::UtcNow

            $key = "$($_.File):$($_.Line)"
            $object = $script:ExecutionLog[$key]

            if ($null -eq $object)
            {
                $object = [pscustomobject] @{
                    File     = $_.Script
                    Line     = $_.Line
                    TotalMS  = [double] 0
                    HitCount = [uint64] 0
                }

                $script:ExecutionLog.Add($key, $object)
            }

            $object.TotalMS += ($now - $script:lastTimestamp).TotalMilliseconds
            $object.HitCount++
            $script:TotalCount++

            $script:lastTimestamp = $now
        }
    }

    Set-PSBreakpoint @params
}

Export-ModuleMember -Function Get-ScriptPerfData
