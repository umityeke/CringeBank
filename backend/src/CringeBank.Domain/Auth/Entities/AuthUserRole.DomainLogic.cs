using System;

namespace CringeBank.Domain.Auth.Entities;

public sealed partial class AuthUserRole
{
    private AuthUserRole()
    {
    }

    public static AuthUserRole Create(long userId, int roleId)
    {
        if (userId <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(userId));
        }

        if (roleId <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(roleId));
        }

        return new AuthUserRole
        {
            UserId = userId,
            RoleId = roleId
        };
    }
}
