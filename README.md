
This project demonstrates how to collect a static profile (PGO aka Profile-Guided Optimization) for a simple console app in order to make it faster. The profile describes a typical behavior of an app: which methods are executed, which parts of those methods are hot or cold, actual types of objects hidden under abstractions, etc. It can be collected dynamically via tiered compilation or statically where we build a special version of an app, run it, simulate typical workloads, save the resulting profile to a file and then re-use it in production. Both approaches have pros and cons, and since the static one is a bit more difficult to set up - I'm going to focus on it.

**NOTE:** The workflow to collect static profiles is not final yet and can be improved/simplied in the future versions of daily builds.

## What exactly PGO can optimize for us?
* Inliner relies on PGO data and can be very aggressive for hot paths, see [dotnet/runtime#52708](https://github.com/dotnet/runtime/pull/52708) and [dotnet/runtime#55478](https://github.com/dotnet/runtime/pull/55478). Namely, this [code](https://github.com/dotnet/runtime/blob/c93bb62e33934c3b8b6b1d293612d44360483bd8/src/coreclr/jit/inlinepolicy.cpp#L1675-L1697).
* Most virtual calls can be devirtualized using PGO data, e.g.:
```csharp
void DisposeMe(IDisposable d)
{
    d.Dispose();
}
```
&nbsp;&nbsp;&nbsp;&nbsp;is optimized into:
```csharp
void DisposeMe(IDisposable d)
{
    if (d is MyType)           // E.g. Profile states that Dispose here is mostly called on MyType.
        ((MyType)d).Dispose(); // It can be inlined now (e.g. to no-op if MyType::Dispose() is empty)
    else
        d.Dispose();           // a cold fallback, just in case
}
```
![image](https://user-images.githubusercontent.com/523221/126960839-6bc3b110-014a-4680-abd8-44c9e7e01765.png)
&nbsp;&nbsp;&nbsp;&nbsp;*^ codegen diff for a case where MyType::Dispose is empty*

  

* JIT re-orders blocks to keep hot ones closer to each other and pushes cold ones to the end of the method.
```csharp
void DoWork(int a)
{
    if (a > 0)
        DoWork1();
    else
        DoWork2();
}
```
&nbsp;&nbsp;&nbsp;&nbsp;is transformed into:
```csharp
void DoWork(int a)
{
    // E.g. Profile states that DoWork1 branch was never (or rarely) taken
    if (a <= 0)
        DoWork2();
    else
        DoWork1();
}
```
* Some optimizations such as Loop Clonning, Inline Casts, etc. aren't applied in cold blocks
* Guided AOT: We can prejit only the code that was executed during the test run. It should noticeably reduce binary size of R2R'd images as the cold methods won't be prejitted at all. For that, you need to pass `--partial` flag to crossgen2 along with the actual MIBC data.


## Prerequisites ###
*  The **latest** daily build of .NET 6.0 from [here](https://github.com/dotnet/installer/blob/main/README.md#installers-and-binaries) (should be at least 7/25/2021)
*  `dotnet tool install --global dotnet-pgo --version "6.0.0-rc.1.21375.2"` tool. See [dotnet-pgo.md](https://github.com/dotnet/runtime/blob/main/docs/design/features/dotnet-pgo.md)

## How to run the sample
First, we need to build a special version of our sample and run it in order to collect a profile:
```ps1
dotnet publish -c Release -r win-x64 /p:CollectMibc=true # or linux-x64, osx-arm64, etc..
```
The console app has a special msbuild [task](https://github.com/EgorBo/StaticPGO_Example/blob/c1ba286cc4e63734ab7c0b3f81349948d39427f2/App.csproj#L29-L53) to do that job. Basically, it runs a fully instrumented build, collect traces, convert them to a special format (*.mibc) that we can use to optimize our app.
Now we can re-publish the app using the PGO data we collected:

```ps1
dotnet publish -c Release -r win-x64 /p:PgoData=pgo.mibc
```
Let's compare performance for StaticPGO, DynamicPGO and Default modes:

## Performance results
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
2) Run with static pgo (steps from the **[How to run the sample](https://github.com/EgorBo/StaticPGO_Example#how-to-run-the-sample)** section above):
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
3) Run with dynamic PGO (steps from **[How to run the sample](https://github.com/EgorBo/StaticPGO_Example#how-to-run-the-sample)** aren't needed. Only just set the following env.variables in your console):
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

## Notes
DynamicPGO is easy to use, but you pay for it with a slower start, because we need to disable all the prejitted code
and re-compile everything in tier0 with instrumentation - edge counters and class probes. E.g. the following aspnet benchmark 
demonstrates the difference between Static and Dynamic PGOs:

![image](https://user-images.githubusercontent.com/523221/126899669-f5a49151-5927-4d52-b252-de024b5399f6.png)
  
With the static one you only need to collect it in advance.
