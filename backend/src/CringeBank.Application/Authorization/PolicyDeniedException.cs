using System;

namespace CringeBank.Application.Authorization;

public sealed class PolicyDeniedException : Exception
{
    public PolicyDeniedException(string resource, string action)
        : base($"Policy denied for {resource}.{action}.")
    {
        Resource = resource;
        Action = action;
    }

    public string Resource { get; }

    public string Action { get; }
}
