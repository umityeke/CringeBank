using System;
using System.Reflection;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Application.Abstractions.Events;
using CringeBank.Application.Abstractions.Mapping;
using CringeBank.Application.Abstractions.Pipeline;
using CringeBank.Application.Abstractions.Queries;
using CringeBank.Application.Mapping;
using CringeBank.Application.Pipeline;
using CringeBank.Application.Events;
using FluentValidation;
using Microsoft.Extensions.DependencyInjection;
using Scrutor;
using Mapster;

namespace CringeBank.Application;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddApplicationCore(this IServiceCollection services)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddScoped<IDispatcher, Dispatcher>();
    services.AddScoped<IDomainEventDispatcher, DomainEventDispatcher>();
        services.AddScoped(typeof(ICommandPipelineBehavior<,>), typeof(ValidationCommandPipelineBehavior<,>));
        services.AddScoped(typeof(IQueryPipelineBehavior<,>), typeof(ValidationQueryPipelineBehavior<,>));
        RegisterMappings(services);
        services.AddValidatorsFromAssembly(typeof(ServiceCollectionExtensions).Assembly);
        services.RegisterApplicationHandlers(typeof(ServiceCollectionExtensions).Assembly);
        return services;
    }

    private static void RegisterMappings(IServiceCollection services)
    {
    var mappingConfig = MappingConfiguration.CreateDefault();
    mappingConfig.Compile();

        services.AddSingleton(mappingConfig);
        services.AddScoped<IObjectMapper, MapsterObjectMapper>();
    }

    private static void RegisterApplicationHandlers(this IServiceCollection services, Assembly assembly)
    {
        services.Scan(scan => scan
            .FromAssemblies(assembly)
            .AddClasses(classes => classes.AssignableTo(typeof(ICommandHandler<,>)))
                .AsImplementedInterfaces()
                .WithScopedLifetime()
            .AddClasses(classes => classes.AssignableTo(typeof(IQueryHandler<,>)))
                .AsImplementedInterfaces()
                .WithScopedLifetime()
            .AddClasses(classes => classes.AssignableTo(typeof(IDomainEventHandler<>)))
                .AsImplementedInterfaces()
                .WithScopedLifetime());
    }
}
