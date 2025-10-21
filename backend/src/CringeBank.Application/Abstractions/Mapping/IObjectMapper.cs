using System;

namespace CringeBank.Application.Abstractions.Mapping;

public interface IObjectMapper
{
    TDestination Map<TDestination>(object source) where TDestination : notnull;

    object Map(object source, Type destinationType);
}
