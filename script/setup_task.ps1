# PowerShell script to automatically create the Windows Scheduled Task
# Run as Administrator in PowerShell

$TaskName = "AirQualityCollector"
$PythonPath = "C:\Users\vstru\AppData\Local\Programs\Python\Python313\python.exe"
$ScriptPath = "d:\AIR_QUALITY_TRACKER\script\collect.py"
$WorkDir = "d:\AIR_QUALITY_TRACKER"

$Action = New-ScheduledTaskAction -Execute $PythonPath -Argument $ScriptPath -WorkingDirectory $WorkDir
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)

try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Description "Hourly Air Quality & Weather Ingestion Task" -Force
    Write-Host "Scheduled Task '$TaskName' registered successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error registering task: $_" -ForegroundColor Red
}
