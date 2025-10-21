using System.Collections.Generic;

namespace CringeBank.Infrastructure.Authorization;

public sealed class RbacOptions
{
    public int RolesCacheSeconds { get; set; } = 30;

    public IList<PolicyDefinition> Policies { get; set; } = new List<PolicyDefinition>();

    public IList<string> TwoManApprovalActions { get; set; } = new List<string>();
}

public sealed class PolicyDefinition
{
    public string Resource { get; set; } = string.Empty;

    public string Action { get; set; } = string.Empty;

    public IList<string> Roles { get; set; } = new List<string>();

    public string? Description { get; set; }
}
