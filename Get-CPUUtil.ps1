###
### 1..99999999 | %{ $_ * $_ * $_ }
###

$cores       = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$proc        = (get-process -Id 2060)
$prevCPUSecs = $proc.CPU
$prevTime    = Get-Date

while (1) {
    # Get proc again to refresh dataf
    $proc = (get-process -Id 2060)

    # Get Current
    $currentCPUSecs = $proc.CPU
    $currentTime    = Get-Date
    
    # Get Deltas
    $deltaCPUSecs = $currentCPUSecs - $prevCPUSecs
    $deltaTime    = ($currentTime - $prevTime).TotalSeconds
    
    # Output
    ($deltaCPUSecs / ($deltaTime * $cores)) * 100

    # Set next prev variables
    $prevCPUSecs = $currentCPUSecs
    $prevTime    = $currentTime    

    start-sleep 1
}