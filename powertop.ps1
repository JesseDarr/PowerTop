Import-Module .\powertop.psm1

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