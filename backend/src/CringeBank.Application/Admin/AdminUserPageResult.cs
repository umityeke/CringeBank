using System.Collections.Generic;

namespace CringeBank.Application.Admin;

public sealed record AdminUserPageResult(
    IReadOnlyCollection<AdminUserListItem> Items,
    string? NextCursor,
    bool HasMore);
