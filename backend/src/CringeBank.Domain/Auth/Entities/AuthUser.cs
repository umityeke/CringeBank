using System;
using System.Collections.Generic;
using CringeBank.Domain.Auth.Enums;
using CringeBank.Domain.Social.Entities;
using CringeBank.Domain.ValueObjects;

namespace CringeBank.Domain.Auth.Entities;

public sealed partial class AuthUser
{
    private readonly List<AuthUserBlock> _blocksInitiated = new();
    private readonly List<AuthUserBlock> _blocksReceived = new();
    private readonly List<AuthFollow> _followers = new();
    private readonly List<AuthFollow> _following = new();
    private readonly List<AuthDeviceToken> _deviceTokens = new();
    private readonly List<AuthUserRole> _userRoles = new();
    private readonly List<AuthLoginEvent> _loginEvents = new();
    private readonly List<SocialPost> _posts = new();
    private readonly List<SocialPostLike> _postLikes = new();
    private readonly List<SocialPostComment> _postComments = new();
    private readonly List<SocialCommentLike> _commentLikes = new();
    private readonly List<SocialPostSave> _postSaves = new();

    public long Id { get; private set; }

    public Guid PublicId { get; private set; }

    public string Email { get; private set; } = string.Empty;

    public string EmailNormalized { get; private set; } = string.Empty;

    public string Username { get; private set; } = string.Empty;

    public string UsernameNormalized { get; private set; } = string.Empty;

    public byte[]? PasswordHash { get; private set; }

    public byte[]? PasswordSalt { get; private set; }

    public string AuthProvider { get; private set; } = "sql";

    public string? Phone { get; private set; }

    public AuthUserStatus Status { get; private set; } = AuthUserStatus.Active;

    public DateTime? LastLoginAt { get; private set; }

    public DateTime CreatedAt { get; private set; }

    public DateTime UpdatedAt { get; private set; }

    public AuthUserProfile? Profile { get; private set; }

    public AuthUserSecurity? Security { get; private set; }

    public IReadOnlyCollection<AuthUserBlock> BlocksInitiated => _blocksInitiated;

    public IReadOnlyCollection<AuthUserBlock> BlocksReceived => _blocksReceived;

    public IReadOnlyCollection<AuthFollow> Followers => _followers;

    public IReadOnlyCollection<AuthFollow> Following => _following;

    public IReadOnlyCollection<AuthDeviceToken> DeviceTokens => _deviceTokens;

    public IReadOnlyCollection<AuthUserRole> UserRoles => _userRoles;

    public IReadOnlyCollection<AuthLoginEvent> LoginEvents => _loginEvents;

    public IReadOnlyCollection<SocialPost> Posts => _posts;

    public IReadOnlyCollection<SocialPostLike> PostLikes => _postLikes;

    public IReadOnlyCollection<SocialPostComment> PostComments => _postComments;

    public IReadOnlyCollection<SocialCommentLike> CommentLikes => _commentLikes;

    public IReadOnlyCollection<SocialPostSave> PostSaves => _postSaves;

    public EmailAddress EmailValueObject => EmailAddress.FromPersistence(Email, EmailNormalized);

    public Username UsernameValueObject => CringeBank.Domain.ValueObjects.Username.FromPersistence(Username, UsernameNormalized);
}
