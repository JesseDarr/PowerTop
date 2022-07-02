###
### 1..99999999 | %{ $_ * $_ * $_ }
###

$numCores    = 16
$proc        = (get-process -Id 2060)
$prevCPUSecs = $proc.CPU
$prevTime    = Get-Date

while (1) {
    # Get proc again to refresh data
    $proc = (get-process -Id 2060)

    # Get Current
    $currentCPUSecs = $proc.CPU
    $currentTime    = Get-Date
    
    # Get Deltas
    $deltaCPUSecs = $currentCPUSecs - $prevCPUSecs
    $deltaTime    = ($currentTime - $prevTime).TotalSeconds
    
    # Output
    ($deltaCPUSecs / ($deltaTime * 16)) * 100

    # Set next prev variables
    $prevCPUSecs = $currentCPUSecs
    $prevTime    = $currentTime    
}