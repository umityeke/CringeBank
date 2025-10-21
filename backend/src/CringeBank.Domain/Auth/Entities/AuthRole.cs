using System;
using System.Collections.Generic;

namespace CringeBank.Domain.Auth.Entities;

public sealed class AuthRole
{
    private readonly List<AuthUserRole> _userRoles = new();

    private AuthRole()
    {
    }

    public AuthRole(string name, string? description)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);

        Name = name;
        Description = description;
    }

    public int Id { get; private set; }

    public string Name { get; private set; } = string.Empty;

    public string? Description { get; private set; }

    public IReadOnlyCollection<AuthUserRole> UserRoles => _userRoles;
}
