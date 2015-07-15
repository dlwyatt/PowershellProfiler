__Build Status:__ [![Build status](https://build.powershell.org/guestAuth/app/rest/builds/buildType:(id:PowerShellProfiler_PublishStatusToGitHub)/statusIcon)](https://build.powershell.org/project.html?projectId=PowerShellProfiler&tab=projectOverview&guest=1)

# PowershellProfiler

This is a script module I've been messing around with to profile other modules.  It works by setting a breakpoint on every line of the scripts that you specify; when these breakpoints are hit, they log how much time has elapsed since the previous breakpoint.  When the execution is finished, you get an array of custom objects (one for each non-whitespace line in the scripts) containing the following pieces of information:

- File Path
- Line Number
- Hit Count
- Hit Count Percent
- Total Milliseconds
- Percent Time
 
Usage looks like this:

```posh
$report = Get-ScriptPerfData -Path $arrayOfFilePathsToProfile -ScriptBlock { Do-Something }

# Let's say we want to get information about the top 20 time-consuming lines of the scripts:

$tableProperties = @(
    @{Label = 'File'; Expression = { Split-Path -Path $_.File -Leaf }}
    'Line','HitCount','PercentHitCount','TotalMilliseconds','PercentTime'
)

$report |
Sort-Object -Property TotalMilliseconds -Descending |
Select-Object -First 20 |
Format-Table -Property $tableProperties -AutoSize
```

The execution of the code that's being profiled will be a fair bit slower than usual, but this slowing effect should be roughly equal for each line of code, so it's still providing useful relative comparison data.  An earlier version of this profiler is what I used to analyze the Pester module recently, and to make some small changes that approximately doubled its overall speed.  (I then turned the profiler on a copy of itself, to produce the current version; the original was much less efficient.)

I'll polish the code up a bit more and add some default output formatting at some point, then release it.  The code currently requires PowerShell 3.0 or later (due to its use of the quick [pscustomobject] accelerator), but a 2.0-compatible version could be created that uses New-Object, at the cost of some speed.
