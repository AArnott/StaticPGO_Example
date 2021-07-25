using System;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Threading;

public static class Tests
{
    static void Main()
    {
        Console.WriteLine("Running...");
        var sw = Stopwatch.StartNew();
        var factory = new FooFactoryImpl();

        for (int iteration = 0; iteration < 10; iteration++)
        {
            sw.Restart();

            // it's too fast, add a few more iterations :)
            for (int i = 0; i < 10000000; i++)
                Test(factory);

            sw.Stop();
            Console.WriteLine($"[{iteration}/9]: {sw.ElapsedMilliseconds} ms.");
            Thread.Sleep(20);
        }
    }

    [MethodImpl(MethodImplOptions.NoInlining)]
    static int Test(IFooFactory factory)
    {
        // Should be devirtualized to (with PGO data):
        // 
        // if ((factory is FooFactoryImpl t1) && (t1.Foo is FooImpl))
        //     return 42;
        // else
        //     <fallback>
        //
        IFoo? foo = factory?.Foo;
        return foo?.Value ?? 0;
    }
}