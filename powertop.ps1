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
    $string = "cores $numCores"

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

function Format-MemoryData {
<#
.SYNOPSIS
    Formats a double (bytes) for use in Get-MemoryLines
    .DESCRIPTION
    Formats a double (bytes) for use in Get-MemoryLines
    .INPUTS
    System.Double
    System.Management.Automation.SwitchParameter
    .OUTPUTS
    System.String
    .EXAMPLE
    Format-MemoryData -Number $cache -BytesToMB
    Format-MemoryData -Number $inUse
#>
    param (
        [Double]$Number,
        [Switch]$BytesToMB
    )

    # Convert to MB
    if ($BytesToMB) {
        $mbMaker = 1024 * 1024
        $Number = $Number / $mbMaker
    }

    # Convert to string and format with 1 decimal place - not rounding b/c it's faster and this is accurate enough
    $string = $Number.ToString("0.0")

    # Add leading spaces
    $diff = 10 - $string.Length
    $string = " " * $diff + $string

    return $string
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
 
    $cores = Get-NumCores

    return "$prefix  $time  $uptime  $users  $cores"
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
    $total     = " $count total,"
    $running   = " $running running,"
    $ready     = " $ready ready,"
    $suspended = " $suspended suspended,"
    $wait      = " $wait wait"

    return "$prefix $total $running $ready $suspended $wait"
}

function Get-CPULines {
<#
    .SYNOPSIS
    Creates the CPU lines.
    .DESCRIPTION
    Creates the CPU line. User Processor Information counter instead of Processor counter to
    support processors with greater than 64 cores.
    .INPUTS
    None.
    .OUTPUTS
    System.String. Correctly formatted CPU line.
    .EXAMPLE
    Get-CPULines ----> %Cpu(s): 24.8 utl,  0.5 idl,  0.0 usr, 73.6 sys,  0.4 int
#>
    $prefix = "%Cpu(s):"

    $utl  = (Get-Counter "\Processor Information(*)\% Processor Time" ).CounterSamples[-1].CookedValue
    $idl  = (Get-Counter "\Processor Information(*)\% Idle Time"      ).CounterSamples[-1].CookedValue
    $usr  = (Get-Counter "\Processor Information(*)\% User Time"      ).CounterSamples[-1].CookedValue
    $sys  = (Get-Counter "\Processor Information(*)\% Privileged Time").CounterSamples[-1].CookedValue
    $int  = (Get-Counter "\Processor Information(*)\% Interrupt Time" ).CounterSamples[-1].CookedValue
    $int += (Get-Counter "\Processor Information(*)\% DPC Time"       ).CounterSamples[-1].CookedValue
    
    $utl = $utl.ToString("0.0")
    $idl = $idl.ToString("0.0")
    $usr = $usr.ToString("0.0")
    $sys = $sys.ToString("0.0")
    $int = $int.ToString("0.0")

    $utl = " $utl utl"
    $idl = " $idl idl"
    $usr = " $usr usr"
    $sys = " $sys sys"
    $int = " $int int"

    return "$prefix $utl, $idl, $usr, $sys, $int"
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
    $prefix = "MiB Mem:"

    # Get values in Byes
    $total = (Get-Counter -Counter "\Numa Node Memory(*)\Total MBytes"    ).CounterSamples[-1].CookedValue
    $free  = (Get-Counter -Counter "\Numa Node Memory(*)\Available MBytes").CounterSamples[-1].CookedValue

    ### SOURCE: https://thewindowsupdate.com/2019/03/16/finally-a-windows-task-manager-performance-tab-blog/ ###
    $cached  = (Get-Counter -Counter "\Memory\Cache Bytes"        ).CounterSamples.CookedValue
    $cached += (Get-Counter -Counter "\Memory\Modified Page List Bytes").CounterSamples.CookedValue
    $cached += (Get-Counter -Counter "\Memory\Standby Cache Normal Priority Bytes").CounterSamples.CookedValue
    $cached += (Get-Counter -Counter "\Memory\Standby Cache Reserve Bytes").CounterSamples.CookedValue
    
    $pagedPool    = (Get-Counter -Counter "\Memory\Pool Paged Bytes"   ).CounterSamples.CookedValue
    $nonPagedPool = (Get-Counter -Counter "\Memory\Pool Nonpaged Bytes").CounterSamples.CookedValue
    $commited     = (Get-Counter -Counter "\Memory\Committed Bytes"    ).CounterSamples.CookedValue
    $commitLimit  = (Get-Counter -Counter "\Memory\Commit Limit"       ).CounterSamples.CookedValue

    $inUse        = $total - $free # calculate inUse

    $cached       = Format-MemoryData -Number $cached       -BytesToMB
    $pagedPool    = Format-MemoryData -Number $pagedPool    -BytesToMB
    $nonPagedPool = Format-MemoryData -Number $nonPagedPool -BytesToMB
    $commited     = Format-MemoryData -Number $commited     -BytesToMB
    $commitLimit  = Format-MemoryData -Number $commitLimit  -BytesToMB
    $total        = Format-MemoryData -Number $total
    $free         = Format-MemoryData -Number $free
    $inUse        = Format-MemoryData -Number $inUse

    $free = "  " + $free # adjust spacing for free

    # Convert to strings and add title
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


function Get-ProcessHeaderLine {
<#
    .SYNOPSIS
    Creates the process header lines.
    .DESCRIPTION
    Creates the process header line.
    .INPUTS
    None.
    .OUTPUTS
    System.String. Correctly formatted process header line.
    .EXAMPLE
    Get-ProcessHeaderLine
#>
    $header = "   Id Name                 WS    PM    NPM %CPU %MEM CPU(sec)"

    return $header
}

function Get-ProcessLines {
<#
    .SYNOPSIS
    Creates the process lines.
    .DESCRIPTION
    Creates the process lines. Headings are as follows:

    PID:     Process ID.
    WS
    PM
    NPM
    %MEM:    The share of physical memory used.
    CPU(sec) Time in seconds used CPU

    ##########################################################################################################################################
    %CPU:    The share of CPU time used by the process since the last update. - (Get-Counter '\Process(*)\% Processor Time').CounterSamples
    ##########################################################################################################################################

    COMMAND: The command name or command line (name + options).
    .INPUTS
    None.
    .OUTPUTS
    System.String. Correctly formatted process lines.
    .EXAMPLE
    Get-ProcessLines
#>
    $mbMaker = 1024 * 1024
    $gbMaker = 1024 * 1024 * 1024

    $heading = "   Id Name                 WS    PM    NPM %CPU %MEM CPU(sec)"

    $processes = Get-Process | Select-Object -first 5 Id, 
                                                       Name, 
                                                       @{Name = "WS" ; Expression = { ($_.WS  / $mbMaker).ToString("0.0") }}, 
                                                       @{Name = "PM" ; Expression = { ($_.PM  / $mbMaker).ToString("0.0") }},
                                                       @{Name = "NPM"; Expression = { ($_.NPM / $mbMaker).ToString("0.0") }},
                                                       %CPU,
                                                       @{Name = "%MEM"; Expression = { ($_.WS / (64 * $gbMaker) * 100).ToString("0.00") }}, 
                                                       @{Name = "CPU(sec)"; Expression = { $_.CPU.ToString("0.0") }} | Format-Table

    # Convert to String                                                       
    $procString = $processes | Out-String
    # Split into lines
    $procStrings = $procString.Split("`n")
    # Loop through annd remove first 3 lines we don't need - this includes a blank line @ index 0
    $counter = 0
    foreach ($string in $procStrings) {
        if ($counter -gt 2) { $outStrings += "`n" + $string } 
        $counter++
    }

    return $outStrings
}

#################
##### Logic #####
#################
# Get line, display it, get next line, clear screen, display line, get next line, clear screen......
# This provides a faster refresh rate than:   while (1) { Render-Line1; Start-Sleep 1; Clear-Host }
$summaryLine  = Get-SummaryLine
$taskLine     = Get-TasksLine
$cpuLine      = Get-CPULines
$memoryLines  = Get-MemoryLines
$procHeadLine = Get-ProcessHeaderLine
$procLines    = Get-ProcessLines
Clear-Host
while (1) {
    $summaryLine 
    $taskLine
    $cpuLine
    $memoryLines
    Write-Host
    Write-Host $procHeadLine -ForegroundColor Black -BackgroundColor White
    $procLines
    
    $summaryLine  = Get-SummaryLine
    $taskLine     = Get-TasksLine
    $cpuLine      = Get-CPULines
    $memoryLines  = Get-MemoryLines
    $procHeadLine = Get-ProcessHeaderLine
    $procLines    = Get-ProcessLines

    #Start-Sleep 1
    Clear-Host 
}





