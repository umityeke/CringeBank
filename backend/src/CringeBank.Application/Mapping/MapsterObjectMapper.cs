using System;
using CringeBank.Application.Abstractions.Mapping;
using Mapster;

namespace CringeBank.Application.Mapping;

public sealed class MapsterObjectMapper : IObjectMapper
{
    private readonly TypeAdapterConfig _config;

    public MapsterObjectMapper(TypeAdapterConfig config)
    {
        _config = config ?? throw new ArgumentNullException(nameof(config));
    }

    public TDestination Map<TDestination>(object source) where TDestination : notnull
    {
        ArgumentNullException.ThrowIfNull(source);
        var result = source.Adapt<TDestination>(_config);
        return result ?? throw new InvalidOperationException($"'Adapt' {typeof(TDestination).Name} türüne null döndürdü.");
    }

    public object Map(object source, Type destinationType)
    {
        ArgumentNullException.ThrowIfNull(source);
        ArgumentNullException.ThrowIfNull(destinationType);
        return source.Adapt(source.GetType(), destinationType, _config)
               ?? throw new InvalidOperationException($"'Adapt' {destinationType.Name} türüne null döndürdü.");
    }
}
