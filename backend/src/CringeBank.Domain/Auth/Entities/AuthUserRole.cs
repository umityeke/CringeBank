namespace CringeBank.Domain.Auth.Entities;

public sealed partial class AuthUserRole
{
    public long UserId { get; private set; }

    public int RoleId { get; private set; }

    public AuthUser User { get; private set; } = null!;

    public AuthRole Role { get; private set; } = null!;
}
