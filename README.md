# StaticPGO_Example

This project demonstrates how to collect a static profile (PGO) for a simple console app.
And compares it with DynamicPGO and the default mode.

### Prerequisites ###
*  The **latest** daily build of .NET 6.0 from [here](https://github.com/dotnet/installer/blob/main/README.md#installers-and-binaries) (should be at least 7/25/2021)
*  `dotnet tool install --global dotnet-pgo` tool. See [dotnet-pgo.md](https://github.com/dotnet/runtime/blob/main/docs/design/features/dotnet-pgo.md)

### Usage
First, we need to build a special version of our app and have a test run:
```
dotnet publish -c Release -r win-x64 /p:CollectMibc=true
```
The console app has a special msbuild [task](https://github.com/EgorBo/StaticPGO_Example/blob/c1ba286cc4e63734ab7c0b3f81349948d39427f2/App.csproj#L29-L53) to do that job.

Then re-build the app using static PGO we collected:
```
dotnet publish -c Release -r win-x64 /p:CollectMibc=false
```

Now compare the performance results after PGO with simple `dotnet run -c Release`.

### Results
1) Normal run `dotnet run -c Release`:
```
Running...
[0/9]: 57 ms.
[1/9]: 56 ms.
[2/9]: 56 ms.
[3/9]: 54 ms.
[4/9]: 54 ms.
[5/9]: 54 ms.
[6/9]: 54 ms.
[7/9]: 54 ms.
[8/9]: 54 ms.
[9/9]: 54 ms.
```
2) Run with static pgo (steps from the **Usage** section above):
```
Running...
[0/9]: 21 ms.
[1/9]: 21 ms.
[2/9]: 21 ms.
[3/9]: 21 ms.
[4/9]: 21 ms.
[5/9]: 21 ms.
[6/9]: 21 ms.
[7/9]: 21 ms.
[8/9]: 21 ms.
[9/9]: 21 ms.
```
3) Run with dynamic PGO (steps from **Usage** aren't needed. Only just set the following env.variables in your console):
```
DOTNET_ReadyToRun=0
DOTNET_TieredPGO=1
DOTNET_TC_QuickJitForLoops=1
```
```
Running...
[0/9]: 164 ms.
[1/9]: 175 ms.
[2/9]: 19 ms.
[3/9]: 18 ms.
[4/9]: 18 ms.
[5/9]: 18 ms.
[6/9]: 18 ms.
[7/9]: 18 ms.
[8/9]: 18 ms.
[9/9]: 18 ms.
```

### Notes
DynamicPGO is easy to use, but you pay for it with a slower start, because we need to disable all the prejitted code
and re-compile everything in tier0 with instrumentations (edge counters and class probes). E.g. the following aspnet benchmark 
demonstrates the difference between Static and Dynamic PGOs:

![image](https://user-images.githubusercontent.com/523221/126896425-9229a6a9-9427-469c-805f-30ecd4c534ab.png)
With the static one you only need to collect it in advance.
