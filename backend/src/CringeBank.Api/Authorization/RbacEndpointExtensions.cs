using System;
using Microsoft.AspNetCore.Builder;

namespace CringeBank.Api.Authorization;

public static class RbacEndpointExtensions
{
    public static RouteHandlerBuilder RequirePolicy(this RouteHandlerBuilder builder, string resource, string action)
    {
        _ = builder ?? throw new ArgumentNullException(nameof(builder));

        builder.WithMetadata(new RbacPolicyAttribute(resource, action));
        builder.AddEndpointFilter<PolicyEndpointFilter>();
        return builder;
    }
}
