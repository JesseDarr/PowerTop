#########################
### General Functions ###
#########################
function Get-CounterData {
<#
    .SYNOPSIS
    Returns hash table of all needed counter data.
    .DESCRIPTION
    Returns hash table of all needed counter data.  To be stored in a variable and accessed by keys passed
    into other functoins.
    .INPUTS
    None.
    .OUTPUTS
    Hash table of all needed counter data.
    .EXAMPLE
    Get-CounterData
#>
    # Query info
    $cpuQueries = @("\Processor Information(*)\% Processor Time" 
                    "\Processor Information(*)\% Idle Time"      
                    "\Processor Information(*)\% User Time"      
                    "\Processor Information(*)\% Privileged Time"
                    "\Processor Information(*)\% Interrupt Time" 
                    "\Processor Information(*)\% DPC Time")
    
    $memQueries = @("\Numa Node Memory(*)\Total MBytes"           
                    "\Numa Node Memory(*)\Available MBytes"         
                    "\Memory\Cache Bytes"                           
                    "\Memory\Modified Page List Bytes"              
                    "\Memory\Standby Cache Normal Priority Bytes"   
                    "\Memory\Standby Cache Reserve Bytes"           
                    "\Memory\Pool Paged Bytes"                      
                    "\Memory\Pool Nonpaged Bytes"                   
                    "\Memory\Committed Bytes"                       
                    "\Memory\Commit Limit")

    $procQueries = @("\Process(*)\ID Process"
                     "\Process(*)\% Processor Time")

    $queries = $cpuQueries + $memQueries + $procQueries
    $results = (Get-Counter $queries).CounterSamples # actual query
    
    # Pull out CPU values and assign to hash table
    $cpu = @{}
    $cpu.utl  = ($results | Where-Object { $_.Path -like "*processor information(_total)\% processor time"  }).CookedValue
    $cpu.idl  = ($results | Where-Object { $_.Path -like "*processor information(_total)\% idle time"       }).CookedValue
    $cpu.usr  = ($results | Where-Object { $_.Path -like "*processor information(_total)\% user time"       }).CookedValue        
    $cpu.sys  = ($results | Where-Object { $_.Path -like "*processor information(_total)\% privileged time" }).CookedValue        
    $cpu.int  = ($results | Where-Object { $_.Path -like "*processor information(_total)\% interrupt time"  }).CookedValue        
    $cpu.int += ($results | Where-Object { $_.Path -like "*processor information(_total)\% dpc time"        }).CookedValue        

    # Pull out MEM values and assign to a hash table
    $mem = @{}
    $mem.total        = ($results | Where-Object { $_.Path -like "*numa node memory(_total)\total mbytes"      }).CookedValue
    $mem.free         = ($results | Where-Object { $_.Path -like "*numa node memory(_total)\available mbytes"  }).CookedValue
    $mem.cached       = ($results | Where-Object { $_.Path -like "*memory\cache bytes "                        }).CookedValue
    $mem.cached      += ($results | Where-Object { $_.Path -like "*memory\modified page list bytes"            }).CookedValue
    $mem.cached      += ($results | Where-Object { $_.Path -like "*memory\standby cache normal priority bytes" }).CookedValue
    $mem.cached      += ($results | Where-Object { $_.Path -like "*memory\standby cache reserve bytes"         }).CookedValue
    $mem.pagedpool    = ($results | Where-Object { $_.Path -like "*memory\pool paged bytes"                    }).CookedValue
    $mem.nonpagedpool = ($results | Where-Object { $_.Path -like "*memory\pool nonpaged bytes"                 }).CookedValue
    $mem.commited     = ($results | Where-Object { $_.Path -like "*memory\committed bytes"                     }).CookedValue
    $mem.commitLimit  = ($results | Where-Object { $_.Path -like "*memory\commit limit"                        }).CookedValue

    # Pull proccess path values and assign to hash table
    $proc = @{}
    $proc.id      = $results | Where-Object { $_.Path -like "*process(*)\id process" }
    $proc.percent = $results | Where-Object { $_.Path -like "*process(*)\% processor time" }
    
    # Pupulate return varaible
    $counterData = @{}
    $counterData.cpu  = $cpu
    $counterData.mem  = $mem
    $counterData.proc = $proc

    return $counterData
}

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
        [Parameter(Mandatory)][System.Array]$Processes
    )

    # Each process with 1 or more running threads counts as a running process
    # Each process with 1 or more ready threads counts as a ready process
    # Each process with 1 or more suspended threads counts as a suspended process, all others count as a wait process
    $running   = 0
    $ready     = 0
    $suspended = 0
    $wait      = 0
    foreach ($process in $Processes) {
        $runningThreads   = $process.Threads | Where-Object { $_.ThreadState -eq "Running" }
        $readyThreads     = $process.Threads | Where-Object { $_.ThreadState -eq "Ready" }
        $waitThreads      = $process.Threads | Where-Object { $_.ThreadState -eq "Wait"}
        $suspendedThreads = $waitThreads     | Where-Object { $_.WaitReason  -eq "Suspended" }

        if ($runningThreads.Count   -gt 0) { $running   += 1 }
        if ($readyThreads.Count     -gt 0) { $ready     += 1 }
        if ($suspendedThreads.Count -gt 0) { $suspended += 1 }
        else                               { $wait      += 1 }
    }
    $wait = $wait - $running # cheap way to not count running threads without the overhead of additional Where-Object statements

    # Create and populate hashtable
    $counts = @{}
    $counts.running   = $running
    $counts.ready     = $ready
    $counts.suspended = $suspended
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
        [Parameter(Mandatory)][Double]$Number,
        [Parameter()][Switch]$BytesToMB
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
    $cores =  (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors

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

function Get-CPULine {
<#
    .SYNOPSIS
    Creates the CPU lines.
    .DESCRIPTION
    Creates the CPU line. User Processor Information counter instead of Processor counter to
    support processors with greater than 64 cores.
    .INPUTS
    Selected.System.Collections.Hashtable created by Get-CounterData
    .OUTPUTS
    System.String. Correctly formatted CPU line.
    .EXAMPLE
    Get-CPULine -CounterData $counterData ----> %Cpu(s): 24.8 utl,  0.5 idl,  0.0 usr, 73.6 sys,  0.4 int
#>
    param (
        [Parameter(Mandatory)][System.Collections.Hashtable]$CounterData
    )

    $prefix = "%Cpu(s):"

    $utl  = $CounterData.utl
    $idl  = $CounterData.idl
    $usr  = $CounterData.usr
    $sys  = $CounterData.sys
    $int  = $CounterData.int
    
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
    param (
        [Parameter(Mandatory)][System.Collections.Hashtable]$CounterData
    )

    $prefix = "MiB Mem:"

    $total        = $CounterData.total
    $free         = $CounterData.free
    $cached       = $CounterData.cached
    $pagedPool    = $CounterData.pagedpool
    $nonPagedPool = $CounterData.nonPagedPool
    $commited     = $CounterData.commited
    $commitLimit  = $CounterData.commitLimit
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

function Get-ProcessLines {
<#
    .SYNOPSIS
    Creates the process lines, and the header line.
    .DESCRIPTION
    Creates the process lines. Headings are as follows:

    PID:        Process ID
    WS          Working Set
    PM          Paged Memory
    NPM         Non Paged Memory
    %MEM:       The share of physical memory used
    CPU(sec)    Time in seconds used CPU
    CommandLine Command line with flags

    ##########################################################################################################################################
    %CPU:    The share of CPU time used by the process since the last update. - (Get-Counter '\Process(*)\% Processor Time').CounterSamples
    ##########################################################################################################################################

    COMMAND: The command name or command line (name + options).
    .INPUTS
    None.
    .OUTPUTS
    Hashtable containg header and lines output.
    .EXAMPLE
    Get-ProcessLines
#>
    param (
        [Parameter(Mandatory)][System.Collections.Hashtable]$CounterData
    )

    # Setup some variables
    $ids       = $CounterData.id
    $percents  = $CounterData.percent
    $cores     =  (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    $mbMaker   = 1024 * 1024
    $gbMaker   = 1024 * 1024 * 1024
    $processes = Get-Process 

    # Make new percents array with replaced Path values so we can join on path
    $newPercents = [System.Collections.ArrayList]::new()
    foreach ($percent in $percents) {
        $output = @{}
        $output.Path         = $percent.Path.Replace("% processor time", "id process")
        $output.InstanceName = $percent.InstanceName
        $output.Percent      = $percent.CookedValue
        $newPercents        += $output
    }

    # Join ids and newPercents
    $percentsTable = Join-Object -Left $ids -Right $newPercents -LeftJoinProperty Path -RightJoinProperty Path -RightProperties Percent

    ###########################################################################
    ########### 14-17 seconds to go through this loop, WHY?!!?! OPTOMIZE ######
    ###########################################################################
    $processInfo = [System.Collections.ArrayList]::new()
    foreach ($process in $processes) {
        # Get CPU %
        $cpu = ($percentsTable | Where-Object { $_.CookedValue -eq $process.id}).Percent
        if ($cpu.count -eq 1) { $cpu = $cpu / $cores}  
        else                  { $cpu = 0 } # so we don't count the idle process

        # Calculate CPU(sec)
        if ($process.CPU) { $cpuSec = $process.CPU }
        else              { $cpuSec = 0}

        # Creat output hash table and start adding values to it
        $output = @{}
        $output.Id          = $process.Id
        $output.Name        = $process.Name
        $output.WS          = [math]::Round(($process.WS  / $mbMaker), 1)  
        $output.PM          = [math]::Round(($process.PM  / $mbMaker), 1)  
        $output.NPM         = [math]::Round(($process.NPM / $mbMaker), 1)  
        $output.CPU         = [math]::Round($cpu, 1)
        $output.MEM         = [math]::Round(($process.WS / (64 * $gbMaker) * 100), 2)
        $output.CPUs        = [math]::Round($cpuSec, 1)
        $output.CommandLine = $process.CommandLine

        $processInfo += $output
    }
    ###########################################################################
    ########### 14-17 seconds to go through this loop, WHY?!!?! OPTOMIZE ######
    ###########################################################################

    # Format everything into a table
    $processTable = $processInfo | Sort-Object CPU -Descending | Select-Object Id, 
                                                 Name, 
                                                 WS, 
                                                 PM, 
                                                 NPM,
                                                 @{Name = "%CPU";     Expression = { $_.CPU  }}, 
                                                 @{Name = "%MEM";     Expression = { $_.MEM  }}, 
                                                 @{Name = "CPU(sec)"; Expression = { $_.CPUs }}, 
                                                 CommandLine -First 10 | Format-Table

    # Convert to String                                                       
    $processString = $processTable | Out-String
    # Split into lines
    $processStrings = $processString.Split("`n")
    
    # Loop through annd remove lines we don't need,    
    $counter = 0
    foreach ($string in $processStrings) {
        if ($counter -ge 3 -and $counter -le $processStrings.Length - 3 ) { $outStrings += $string + "`n" } 

        if ($counter -eq 1) { $header = $string } # get the header line
        $counter++
    }

    return @{ header = $header 
              lines  = $outStrings }
}

#################
##### Logic #####
#################
# Get line, display it, get next line, clear screen, display line, get next line, clear screen......
# This provides a faster refresh rate than:   while (1) { Render-Line1; Start-Sleep 1; Clear-Host }
$counterData = Get-CounterData                              
$summaryLine = Get-SummaryLine                              
$taskLine    = Get-TasksLine                                 
$cpuLine     = Get-CPULine      -CounterData $counterData.cpu 
$memoryLines = Get-MemoryLines  -CounterData $counterData.mem 
$procLines   = Get-ProcessLines -CounterData $counterData.proc

Clear-Host
while (1) {
    $summaryLine 
    $taskLine
    $cpuLine
    $memoryLines
    Write-Host
    Write-Host $procLines.header -ForegroundColor Black -BackgroundColor White 
    $procLines.lines
    
    $counterData = Get-CounterData
    $summaryLine = Get-SummaryLine
    $taskLine    = Get-TasksLine
    $cpuLine     = Get-CPULine      -CounterData $counterData.cpu 
    $memoryLines = Get-MemoryLines  -CounterData $counterData.mem 
    $procLines   = Get-ProcessLines -CounterData $counterData.proc

    Clear-Host 
}