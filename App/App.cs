using System;
using System.Diagnostics;
using System.Runtime.CompilerServices;

public static class Tests
{
    static void Main()
    {
        var ff = new ClassBFactoryFactory();
        var sw = Stopwatch.StartNew();

        for (int iter = 0; iter < 10; iter++)
        {
            sw.Restart();
            for (int i = 0; i < 10000000; i++)
            {
                Test(ff);
                Test(ff);
                Test(ff);
                Test(ff);
            }
            sw.Stop();
            Console.WriteLine(sw.ElapsedMilliseconds);
        }
    }

    [MethodImpl(MethodImplOptions.NoInlining)]
    static long Test(ClassAFactoryFactory ff)
    {
        if (ff != null)
        {
            var f = ff.GetClassAFactory();
            if (f != null)
            {
                ClassA classA = f.GetA();
                if (classA != null)
                {
                    // GetValue() call here is correctly devirtualized to idiv
                    // in FullPGO mode.
                    return classA.GetValue();
                }
            }
        }
        return 0;
    }
}