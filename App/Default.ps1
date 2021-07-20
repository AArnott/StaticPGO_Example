Remove-Item "bin" -Recurse -ErrorAction Ignore
Remove-Item "obj" -Recurse -ErrorAction Ignore

# reset the env vars
$env:COMPlus_EnableEventPipe=0
$env:COMPlus_ReadyToRun=1
$env:COMPlus_TieredPGO=0
$env:COMPlus_TieredCompilation=1
$env:COMPlus_TC_CallCounting=1
$env:COMPlus_TC_QuickJitForLoops=0

dotnet run -c Release
