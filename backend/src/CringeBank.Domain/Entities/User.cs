using System;
using CringeBank.Domain.Abstractions;
using CringeBank.Domain.Enums;

namespace CringeBank.Domain.Entities;

public sealed class User : Entity, IAggregateRoot
{
    private User()
    {
    }

    public User(
        Guid id,
        string firebaseUid,
        string email,
        bool emailVerified,
        int claimsVersion,
        UserStatus status)
        : base(id)
    {
        FirebaseUid = firebaseUid;
        Email = email;
        EmailVerified = emailVerified;
        ClaimsVersion = claimsVersion;
        Status = status;
    }

    public string FirebaseUid { get; private set; } = string.Empty;

    public string Email { get; private set; } = string.Empty;

    public string? PhoneNumber { get; private set; }

    public string DisplayName { get; private set; } = string.Empty;

    public string? ProfileImageUrl { get; private set; }

    public bool EmailVerified { get; private set; }

    public int ClaimsVersion { get; private set; }

    public bool IsDisabled { get; private set; }

    public UserStatus Status { get; private set; } = UserStatus.Unknown;

    public DateTimeOffset? DisabledAtUtc { get; private set; }

    public DateTimeOffset? DeletedAtUtc { get; private set; }

    public DateTimeOffset? LastLoginAtUtc { get; private set; }

    public string? LastSeenAppVersion { get; private set; }

    public DateTimeOffset? LastSyncedAtUtc { get; private set; }

    public void UpdateCoreProfile(
        string email,
        string? phoneNumber,
        string? displayName,
        string? profileImageUrl,
        bool emailVerified,
        int claimsVersion,
        DateTimeOffset? lastLoginAtUtc,
        string? lastSeenAppVersion)
    {
        Email = email;
        PhoneNumber = phoneNumber;
        DisplayName = displayName ?? string.Empty;
        ProfileImageUrl = profileImageUrl;
        EmailVerified = emailVerified;
        ClaimsVersion = claimsVersion;
        LastLoginAtUtc = lastLoginAtUtc;
        LastSeenAppVersion = lastSeenAppVersion;
        Touch();
    }

    public void MarkSynced(DateTimeOffset syncedAtUtc)
    {
        LastSyncedAtUtc = syncedAtUtc;
        Touch(syncedAtUtc);
    }

    public void SetStatus(UserStatus status)
    {
        Status = status;
        Touch();
    }

    public void SetDisabled(bool isDisabled, DateTimeOffset? timestamp)
    {
        IsDisabled = isDisabled;
        DisabledAtUtc = isDisabled ? timestamp ?? DateTimeOffset.UtcNow : null;
        Touch();
    }

    public void SetDeleted(DateTimeOffset? timestamp)
    {
        DeletedAtUtc = timestamp ?? DateTimeOffset.UtcNow;
        if (DeletedAtUtc != null)
        {
            Status = UserStatus.Deleted;
        }

        Touch();
    }
}
