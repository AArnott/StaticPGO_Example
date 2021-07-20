using System;

public class ClassA
{
    public virtual long GetValue() => 0;
}

public class ClassB : ClassA
{
    long a = 42;
    long b = 42;

    public override long GetValue()
    {
        return a / b;
    }
}

public class ClassAFactory
{
    public virtual ClassA GetA() => null;
}

public class ClassBFactory : ClassAFactory
{
    private static readonly ClassB ClassB = new();

    public override ClassA GetA() => ClassB;
}

public class ClassBFactoryFactory : ClassAFactoryFactory
{
    private static readonly ClassBFactory ClassBFactory = new();

    public override ClassAFactory GetClassAFactory() => ClassBFactory;
}

public class ClassAFactoryFactory
{
    public virtual ClassAFactory GetClassAFactory() => null;
}