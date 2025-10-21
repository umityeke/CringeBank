using System.Collections.Generic;

namespace CringeBank.Api.Admin;

public sealed record AdminUserPageResponse(
    IReadOnlyCollection<AdminUserResponse> Items,
    string? NextCursor,
    bool HasMore);
