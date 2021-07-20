
$currdir = Get-Location
$nettracePath = "$PSScriptRoot\obj\net.nettrace"
$mibcPath = "$PSScriptRoot\my.mibc"

Remove-Item "bin" -Recurse -ErrorAction Ignore
Remove-Item "obj" -Recurse -ErrorAction Ignore
Remove-Item $nettracePath -Recurse -ErrorAction Ignore
Remove-Item $mibcPath -Recurse -ErrorAction Ignore

dotnet publish -c Release -r win-x64 App.csproj

$env:COMPlus_EnableEventPipe=1
$env:COMPlus_EventPipeConfig="Microsoft-Windows-DotNETRuntime:0x1F000080018:5"
$env:COMPlus_EventPipeOutputPath=$nettracePath
$env:COMPlus_ReadyToRun=0
$env:COMPlus_TieredPGO=1
$env:COMPlus_TieredCompilation=1
$env:COMPlus_TC_CallCounting=0
$env:COMPlus_TC_QuickJitForLoops=1
$env:COMPlus_JitCollect64BitCounts=1

Write-Host ""
Write-Host "Collecting traces..."

# collect traces...
bin\Release\net6.0\win-x64\publish\App.exe

Write-Host ""
Write-Host "Converting traces to MIBC..."

# reset the env vars to default values
$env:COMPlus_EnableEventPipe=0
$env:COMPlus_ReadyToRun=1
$env:COMPlus_TieredCompilation=1
$env:COMPlus_TC_CallCounting=1
$env:COMPlus_TC_QuickJitForLoops=0
$env:COMPlus_TieredPGO=0

# wait some time while the traces are being prepared
Start-Sleep -Seconds 5
# not sure why it's "used by another process" still so I make a copy:
Copy-Item $nettracePath -Destination "$nettracePath.nettrace"

dotnet-pgo create-mibc -t "$nettracePath.nettrace" -o $mibcPath
dotnet-pgo dump $mibcPath "$mibcPath.txt"

Remove-Item "bin" -Recurse
Remove-Item "obj" -Recurse

# not sure what --partial does, but PGO data is not embedded if it's not set when Composite mode is enabled

Write-Host ""
Write-Host "Running 'dotnet publish' using pgo data, see publish2.log for details..."

# -v:d > publish2.log

dotnet publish -c Release -r win-x64 /p:PublishTrimmed=true /p:TrimMode=link /p:PublishReadyToRun=true /p:PublishReadyToRunUseCrossgen2=true /p:PublishReadyToRunComposite=true "/p:PublishReadyToRunCrossgen2ExtraArgs=--embed-pgo-data%3b--mibc%3a$mibcPath" -v:n > publish2.log

Write-Host ""
Write-Host "Results with StaticPGO:"

# Final run
bin\Release\net6.0\win-x64\publish\App.exe
