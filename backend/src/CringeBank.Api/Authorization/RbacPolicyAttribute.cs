using System;

namespace CringeBank.Api.Authorization;

[AttributeUsage(AttributeTargets.Method, AllowMultiple = true, Inherited = false)]
public sealed class RbacPolicyAttribute : Attribute
{
    public RbacPolicyAttribute(string resource, string action)
    {
        Resource = string.IsNullOrWhiteSpace(resource)
            ? throw new ArgumentException("Resource must be provided.", nameof(resource))
            : resource;

        Action = string.IsNullOrWhiteSpace(action)
            ? throw new ArgumentException("Action must be provided.", nameof(action))
            : action;
    }

    public string Resource { get; }

    public string Action { get; }
}
