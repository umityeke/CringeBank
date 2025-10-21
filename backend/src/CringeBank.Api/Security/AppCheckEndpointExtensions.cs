using System;
using Microsoft.AspNetCore.Builder;

namespace CringeBank.Api.Security;

public static class AppCheckEndpointExtensions
{
    public static RouteHandlerBuilder RequireAppCheck(this RouteHandlerBuilder builder)
    {
        _ = builder ?? throw new ArgumentNullException(nameof(builder));

        builder.WithMetadata(AppCheckRequiredMetadata.Instance);
        builder.AddEndpointFilter<AppCheckEndpointFilter>();
        return builder;
    }

    public static RouteGroupBuilder RequireAppCheck(this RouteGroupBuilder builder)
    {
        _ = builder ?? throw new ArgumentNullException(nameof(builder));

        builder.WithMetadata(AppCheckRequiredMetadata.Instance);
        builder.AddEndpointFilter<AppCheckEndpointFilter>();
        return builder;
    }

    internal sealed class AppCheckRequiredMetadata
    {
        internal static AppCheckRequiredMetadata Instance { get; } = new();

        private AppCheckRequiredMetadata()
        {
        }
    }
}
