# StaticPGO_Example

This project demonstrates how to collect a static profile (PGO) for a simple console app in order to make it faster.

### Prerequisites ###
*  The **latest** daily build of .NET 6.0 from [here](https://github.com/dotnet/installer/blob/main/README.md#installers-and-binaries) (should be at least 7/25/2021)
*  `dotnet tool install --global dotnet-pgo` tool. See [dotnet-pgo.md](https://github.com/dotnet/runtime/blob/main/docs/design/features/dotnet-pgo.md)

### Usage
First, we need to build a special version of our app and have a test run:
```ps1
dotnet publish -c Release -r win-x64 /p:CollectMibc=true # or linux-x64, osx-arm64, etc..
```
The console app has a special msbuild [task](https://github.com/EgorBo/StaticPGO_Example/blob/c1ba286cc4e63734ab7c0b3f81349948d39427f2/App.csproj#L29-L53) to do that job.

Then re-build the app using static PGO we collected:
```ps1
dotnet publish -c Release -r win-x64 /p:PgoData=pgo.mibc
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
[0/9]: 19 ms.
[1/9]: 19 ms.
[2/9]: 19 ms.
[3/9]: 19 ms.
[4/9]: 19 ms.
[5/9]: 19 ms.
[6/9]: 18 ms.
[7/9]: 18 ms.
[8/9]: 18 ms.
[9/9]: 18 ms.
```
3) Run with dynamic PGO (steps from **Usage** aren't needed. Only just set the following env.variables in your console):
```ps1
DOTNET_ReadyToRun=0           # ignore AOT code
DOTNET_TieredPGO=1            # enable dynamic pgo
DOTNET_TC_QuickJitForLoops=1  # don't bypass tier0 for methods with loops
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

![image](https://user-images.githubusercontent.com/523221/126899669-f5a49151-5927-4d52-b252-de024b5399f6.png)
  
With the static one you only need to collect it in advance.


### What exactly PGO can optimize for us?
* Most virtual calls are devirtualized, e.g.
```csharp
void DisposeMe(IDisposable d)
{
    d.Dispose();
}
```
is optimized into:
```csharp
void DisposeMe(IDisposable d)
{
    if (d is MyType) // PGO tells us `d` is mostly `MyType` here
        ((MyType)d).Dispose(); // can be inlined now, e.g. to no-op if MyType.Dispose is empty
    else
        d.Dispose(); // a cold fallback, just in case
}
```
* Inliner relies on PGO data and can be very aggressive for hot paths, see [dotnet/runtime#52708](https://github.com/dotnet/runtime/pull/52708) and [dotnet/runtime#55478](https://github.com/dotnet/runtime/pull/55478)
* JIT tries to keep all hot blocks together and moves the cold ones closer to the end of methods, e.g.:
```csharp
void DoWork(int a)
{
    if (a > 0)
        DoWork1();
    else
        DoWork2();
}
```
is transformed into:
```csharp
void DoWork(int a)
{
    // PGO told the jit that the DoWork1 branch was never (or rarely) taken
    if (a <= 0)
        DoWork2();
    else
        DoWork1();
}
```
* We can prejit (AOT) only the code that was touched during the test run using `--partial` option passed to crossgen2 - it should noticeably reduce binary size of R2R'd images.
