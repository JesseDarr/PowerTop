function Get-PrevProcs {
    param (
        [Parameter(Mandatory)][System.Diagnostics.Process[]]$Processes
    )

    $prevProcs = [System.Collections.ArrayList]::new()
    foreach ($proc in $Processes) { 
        $null = $prevProcs.Add(($proc | Select-Object ID, CPU, Name))
    }
    return $prevProcs
}

$cores       = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$prevTime    = Get-Date
$procs       = Get-Process
$prevProcs   = Get-PrevProcs -Processes $procs

start-sleep 1

# Get Current
$currentTime = Get-Date
$procs       = Get-Process

foreach ($proc in $procs) {
    if (!$proc.CPU) { $currentCPUSecs = 0 }
    else            { $currentCPUSecs = $proc.CPU }
    $prevCPUSecs    = ($prevProcs | Where-Object { $_.Id -eq $proc.Id}).CPU

    # Get Deltas
    $deltaCPUSecs = $currentCPUSecs - $prevCPUSecs
    $deltaTime    = ($currentTime - $prevTime).TotalSeconds

    # Output
    $out = ($deltaCPUSecs / ($deltaTime * $cores)) * 100
    Write-Host $proc.Name $out
}

# Set next prev variables
$prevProcs = Get-PrevProcs -Processes $procs
$prevTime  = $currentTime   
