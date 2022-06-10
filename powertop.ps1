#########################
### General Functions ###
#########################
function Get-FormattedUptime {
<#
    .SYNOPSIS
    Returns correctly formatted uptime.
    .DESCRIPTION
    Returns correctly formatted uptime.
    .INPUTS
    None.
    .OUTPUTS
    System.String. Correctly formatted uptime.
    .EXAMPLE
    Get-FormattedUptime ----> up 90 days, 15:24,
    Get-FormattedUptime ----> up 15:25,
    Get-FormattedUptime ----> up 3:26,
    Get-FormattedUptime ----> up 27 min
#>
    $uptime = Get-Uptime
    $days   = $uptime.Days
    $hours  = $uptime.Hours
    $mins   = $uptime.Minutes

    # Format based on value
    if     ($days -gt 0)  { $formattedUptime = "up $days days, $hours" + ":" + "$mins," } 
    elseif ($hours -gt 0) { $formattedUptime = "up $hours" + ":" + "$mins," }
    else                  { $formattedUptime = "up $mins min," }

    return $formattedUptime
}

function Get-Users {
<#
    .SYNOPSIS
    Returns correctly formatted user count.
    .DESCRIPTION
    Returns correctly formatted user count.
    .INPUTS
    None.
    .OUTPUTS
    System.String. Correctly formatted user count.
    .EXAMPLE
    Get-Users ----> 1 user,
    Get-Users ----> 2 users,
#>
    $count = (query user | Select-String "Active").Count
    
    # Format based on value
    if   ($count -eq 1) { $formattedCount = "$count user," } 
    else                { $formattedCount = "$count users," }

    return $formattedCount
}

function Get-ProcUtil {
<#
    .SYNOPSIS
    Returns correctly formatted processor utilization.
    .DESCRIPTION
    Returns correctly formatted processor utilization in % rounded to 2 decimal places.
    .INPUTS
    None.
    .OUTPUTS
    System.String. Correctly formatted processor utilization.
    .EXAMPLE
    Get-ProcUtil ----> proc utilization: 72.05%
#>
    $util = (Get-Counter -Counter "\Processor(*)\% Processor Time").CounterSamples[-1].CookedValue
    $roundedUtil = [Math]::Round($util, 2)
    $string = "util: $roundedUtil %,"

    return $string
}
 
function Get-ProcIdle {
<#
    .SYNOPSIS
    Returns correctly formatted processor idle.
    .DESCRIPTION
    Returns correctly formatted processor idle in % rounded to 2 decimal places.
    .INPUTS
    None.
    .OUTPUTS
    System.String. Co rrectly formatted processor idle.
    .EXAMPLE
    Get-ProcIdle ----> proc idle: 27.95.05%
#>
    $idle = (Get-Counter -Counter "\Processor(*)\% Idle Time").CounterSamples[-1].CookedValue
    $roundedIdle = [Math]::Round($idle, 2)
    $string = "idle: $roundedIdle %,"

    return $string
}

function Get-NumCores {
<#
    .SYNOPSIS
    Returns correctly formatted processor logical core count.
    .DESCRIPTION
    Returns correctly formatted processor logical core count.
    .INPUTS
    None.
    .OUTPUTS
    System.String. Correctly formatted processor logical core count.
    .EXAMPLE
    Get-NumCores ----> core count: 4
#>
    $numCores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    $string = "core count: $numCores"

    return $string
}

function Get-TaskCounts {
<#
    .SYNOPSIS
    Returns hastable with running, ready, suspended, and wait process counts.
    .DESCRIPTION
    Returns hastable with running, ready, suspended, and wait process counts.
    .INPUTS
    System.Array of System.Diagnostics.Process.
    .OUTPUTS
    System.Collections.Hashtable. Running, ready, suspended, and wait process counts.
    .EXAMPLE
    Get-TaskCounts ----> @{ running = 2
                            ready = 0
                            suspended = 8
                            wait = 243 }
#>
    param (
        [System.Array]$Processes
    )

    # Each process with 1 or more running threads counts as a running process
    # Each process with 1 or more ready threads counts as a ready process
    # Each process with 1 or more suspended threads counts as a suspended process, all others count as a wait process
    $running = 0
    $ready = 0
    $suspended = 0
    $wait      = 0
    foreach ($process in $Processes) {
        $runningThreads   = $process.Threads | Where-Object { $_.ThreadState -eq "Running" }
        $readyThreads     = $process.Threads | Where-Object { $_.ThreadState -eq "Ready" }
        $waitThreads      = $process.Threads | Where-Object { $_.ThreadState -eq "Wait"}
        $suspendedThreads = $waitThreads     | Where-Object { $_.WaitReason -eq "Suspended" }

        if ($runningThreads.Count -gt 0)   { $running += 1 }
        if ($readyThreads.Count -gt 0)     { $ready += 1 }
        if ($suspendedThreads.Count -gt 0) { $suspended += 1 }
        else                               { $wait += 1}
    }
    $wait = $wait - $running # cheap way to not count running threads without the overhead of additional Where-Object statements

    # Create and populate hashtable
    $counts = @{} | Select-Object Running, Ready, Suspended, Wait
    $counts.Running   = $running
    $counts.Ready     = $ready
    $counts.Suspended = $suspended
    $counts.wait      = $wait

    return $counts
}

#########################
##### Line Functions ####
#########################
function Get-SummaryLine {
<#
    .SYNOPSIS
    Creates the summar line.
    .DESCRIPTION
    Creates the summar line.
    .INPUTS
    None.
    .OUTPUTS
    System.String. Correctly formatted summary line.
    .EXAMPLE
    Get-SummaryLine ----> powertop - 23:19:43 up 11 days, 1:25, 1 user, proc utilization: 1.73 %, proc idle: 97.75 %, core count: 16
#>
    $prefix = "powertop -"
    $time   = Get-Date -Format "HH:mm:ss"
    $uptime = Get-FormattedUptime
    $users  = Get-Users

    $procUtil = Get-ProcUtil
    $procIdle = Get-ProcIdle
    $numCores = Get-NumCores

    return "$prefix $time $uptime $users $procUtil $procIdle $numCores"
}

function Get-TasksLine {
<#
    .SYNOPSIS
    Creates the task line.
    .DESCRIPTION
    Creates the task line.
    .INPUTS
    None.
    .OUTPUTS
    System.String. Correctly formatted task line.
    .EXAMPLE
    Get-TaskLine ----> Tasks: 281 total, 1 running, 1 ready, 280 suspended, 10 wait
#>
    $processes = Get-Process
    $count     = $processes.Count
    $counts    = Get-TaskCounts -Processes $processes

    $running   = $counts.Running
    $ready     = $counts.Ready
    $suspended = $counts.Suspended
    $wait      = $counts.Wait

    # Format strings
    $prefix    = "Tasks:"
    $total     = "$count total,"
    $running   = "$running running,"
    $ready     = "$ready ready,"
    $suspended = "$suspended suspended,"
    $wait      = "$wait wait"

    return "$prefix $total $running $ready $suspended $wait"
}

function Get-MemoryLines {
<#
    .SYNOPSIS
    Creates the memory line.
    .DESCRIPTION
    Creates the memory line.
    .INPUTS
    None.
    .OUTPUTS
    System.String. Correctly formatted memory line.
    .EXAMPLE
    Get-MemoryLines ----> MiB Mem:    3928.7 used     499.8 total      1481.0 free    1948.0 cached
                                      2048.0 pged    2048.0 nonpged       0.0 cmit    2197.6 cmit lmt
#>
    $mbMaker = 1024 * 1024
    $gbMaker = 1024 * 1024 * 1024

    $prefix = "MiB Mem:"

    # Get values in Byes
    $total        = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum).Sum
    $free         = (Get-Counter -Counter "\Memory\Available Bytes"    ).CounterSamples.CookedValue
    $cached       = (Get-Counter -Counter "\Memory\Cache Bytes"        ).CounterSamples.CookedValue
    $pagedPool    = (Get-Counter -Counter "\Memory\Pool Paged Bytes"   ).CounterSamples.CookedValue
    $nonPagedPool = (Get-Counter -Counter "\Memory\Pool Nonpaged Bytes").CounterSamples.CookedValue
    $commited     = (Get-Counter -Counter "\Memory\Committed Bytes"    ).CounterSamples.CookedValue
    $commitLimit  = (Get-Counter -Counter "\Memory\Commit Limit"       ).CounterSamples.CookedValue
    $inUse        = $total - $free

    # Convert to MB
    $inUse        = $inUse        / $mbMaker
    $total        = $total        / $mbMaker
    $free         = $free         / $mbMaker
    $cached       = $cached       / $mbMaker
    $pagedPool    = $pagedPool    / $mbMaker
    $nonPagedPool = $nonPagedPool / $mbMaker
    $commited     = $commited     / $mbMaker
    $commitLimit  = $commitLimit  / $mbMaker

    # Convert to string and format with 1 decimal place - not rounding b/c it's faster and this is accurate enough
    $inUse        = $inUse.ToString("0.0")        
    $total        = $total.ToString("0.0")
    $free         = $free.ToString("0.0")         
    $cached       = $cached.ToString("0.0")
    $pagedPool    = $pagedPool.ToString("0.0")    
    $nonPagedPool = $nonPagedPool.ToString("0.0") 
    $commited     = $commited.ToString("0.0")     
    $commitLimit  = $commitLimit.ToString("0.0")         
    
    # Add leading spaces
    if ($inUse.Length -gt 10) { $inuse = "ERR"}
    $diff         = 10 - $inUse.Length 
    $inUse        = " " * $diff + $inUse
    

    $diff         = 10 - $total.Length 
    $total        = " " * $diff + $total

    $diff         = 10 - $free.Length 
    $free         = " " * $diff + $free

    $diff         = 10 - $cached.Length 
    $cached       = " " * $diff + $cached

    $diff         = 10 - $pagedPool.Length 
    $pagedPool    = " " * $diff + $pagedPool

    $diff         = 10 - $nonPagedPool.Length 
    $nonPagedPool = " " * $diff + $nonPagedPool

    $diff         = 10 - $commited.Length 
    $commited     = " " * $diff + $commited

    $diff         = 10 - $commitLimit.Length 
    $commitLimit  = " " * $diff + $commitLimit

    $free = "  " + $free # adjust spacing for free

    # Convert to strings and add formatting
    $inUse        = "$inUse used"
    $total        = "$total total"    
    $free         = "$free free"         
    $cached       = "$cached cached"
    $pagedPool    = "$pagedPool pged"
    $nonPagedPool = "$nonPagedPool nonpged"
    $commited     = "$commited cmit"    
    $commitLimit  = "$commitLimit cmit lmt" 
    
    return "$prefix $inUse $total $free $cached `n         $pagedPool $nonPagedPool $commited $commitLimit"
}

#################
##### Logic #####
#################
# Get line, display it, get next line, clear screen, display line, get next line, clear screen......
# This provides a faster refresh rate than:   while (1) { Render-Line1; Start-Sleep 1; Clear-Host }
$summaryLine = Get-SummaryLine
$taskLine    = Get-TasksLine
$memoryLines = Get-MemoryLines
while (1) {
    $summaryLine 
    $taskLine
    $memoryLines
    
    $summaryLine = Get-SummaryLine
    $taskLine    = Get-TasksLine
    $memoryLines = Get-MemoryLines
    
    Start-Sleep 1
    Clear-Host 
}





