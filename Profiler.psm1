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
        $script:lastEntry = $null

        try
        {
            $null = & $ScriptBlock
        } catch { }

        $now = [datetime]::UtcNow
        if ($null -ne $script:lastEntry)
        {
            $script:lastEntry.TotalMS += ($now - $script:LastTimestamp).TotalMilliseconds
        }

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

    foreach ($lineInfo in $ExecutionLog.Values)
    {
        [pscustomobject] @{
            File              = $lineInfo.File
            Line              = $lineInfo.Line
            TotalMilliseconds = [int]$lineInfo.TotalMS
            PercentTime       = [math]::Round(100 * $lineInfo.TotalMS / $totalMS, 2)
            HitCount          = $lineInfo.HitCount
            PercentHitCount   = [math]::Round(100 * $lineInfo.HitCount / $TotalCount, 2)
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

        $lineNumbers = @(
            for ($i = 1; $i -le $lineCount; $i++)
            {
                if ($lines[$i - 1] -notmatch '^\s*(?:#\.*)?$')
                {
                    $i
                }
            }
        )

        if ($lineNumbers.Count -gt 0)
        {
            New-ProfilerBreakpoint -Path $filePath -LineNumber $lineNumbers
        }
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

            $key = "$($_.Script):$($_.Line)"
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

            if ($null -ne $script:lastEntry)
            {
                $script:lastEntry.TotalMS += ($now - $script:lastTimestamp).TotalMilliseconds
            }

            $object.HitCount++

            $script:TotalCount++
            $script:lastEntry = $object
            $script:lastTimestamp = $now
        }
    }

    Set-PSBreakpoint @params
}

Export-ModuleMember -Function Get-ScriptPerfData
