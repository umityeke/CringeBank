using System;

namespace CringeBank.Domain.Auth.Entities;

public sealed class AuthFollow
{
    public long Id { get; private set; }

    public long FollowerUserId { get; private set; }

    public long FolloweeUserId { get; private set; }

    public DateTime CreatedAt { get; private set; }

    public AuthUser Follower { get; private set; } = null!;

    public AuthUser Followee { get; private set; } = null!;
}
