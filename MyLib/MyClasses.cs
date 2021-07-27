
// These types were moved to a separate lib to complicate R2R's life (only Composite mode can handle it now)

public interface IFoo
{
    int Value { get; }
}

public interface IFooFactory
{
    IFoo Foo { get; }
}


// Implementation:


public class FooImpl : IFoo
{
    public int Value => 42;
}

public class FooFactoryImpl : IFooFactory
{
    public IFoo Foo { get; } = new FooImpl();
}
