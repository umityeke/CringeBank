using System;
using System.Linq;
using CringeBank.Application.Admin;
using CringeBank.Domain.Auth.Enums;

namespace CringeBank.Api.Admin;

public static class AdminResponseMapper
{
    public static AdminUserResponse Map(AdminUserListItem item)
    {
        ArgumentNullException.ThrowIfNull(item);

        return new AdminUserResponse(
            item.PublicId,
            item.Email,
            item.Username,
            item.Status.ToString(),
            item.CreatedAt,
            item.UpdatedAt,
            item.LastLoginAt,
            item.DisplayName,
            item.Roles.ToArray());
    }

    public static AdminUserPageResponse Map(AdminUserPageResult result)
    {
        ArgumentNullException.ThrowIfNull(result);

        var items = result.Items
            .Select(Map)
            .ToArray();

        return new AdminUserPageResponse(items, result.NextCursor, result.HasMore);
    }
}
