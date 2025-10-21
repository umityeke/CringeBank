using System;
using CringeBank.Domain.Abstractions;
using CringeBank.Domain.Events.Users;
using CringeBank.Domain.Enums;

namespace CringeBank.Domain.Entities;

public sealed class User : AggregateRoot
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
        var hasSignificantChange = !string.Equals(Email, email, StringComparison.OrdinalIgnoreCase)
            || !string.Equals(DisplayName, displayName ?? string.Empty, StringComparison.Ordinal)
            || EmailVerified != emailVerified
            || ClaimsVersion != claimsVersion
            || !Nullable.Equals(LastLoginAtUtc, lastLoginAtUtc);

        Email = email;
        PhoneNumber = phoneNumber;
        DisplayName = displayName ?? string.Empty;
        ProfileImageUrl = profileImageUrl;
        EmailVerified = emailVerified;
        ClaimsVersion = claimsVersion;
        LastLoginAtUtc = lastLoginAtUtc;
        LastSeenAppVersion = lastSeenAppVersion;
        Touch();

        if (hasSignificantChange)
        {
            RaiseDomainEvent(new UserCoreProfileUpdatedDomainEvent(Id, FirebaseUid, Email, DisplayName, EmailVerified, LastLoginAtUtc));
        }
    }

    public void MarkSynced(DateTimeOffset syncedAtUtc)
    {
        LastSyncedAtUtc = syncedAtUtc;
        Touch(syncedAtUtc);

        RaiseDomainEvent(new UserSynchronizationCompletedDomainEvent(Id, FirebaseUid, LastSyncedAtUtc));
    }

    public void SetStatus(UserStatus status)
    {
        if (Status == status)
        {
            return;
        }

        var previousStatus = Status;

        Status = status;
        Touch();

        RaiseDomainEvent(new UserStatusChangedDomainEvent(Id, FirebaseUid, previousStatus, Status));
    }

    public void SetDisabled(bool isDisabled, DateTimeOffset? timestamp)
    {
        if (IsDisabled == isDisabled && Nullable.Equals(DisabledAtUtc, timestamp))
        {
            return;
        }

        IsDisabled = isDisabled;
        DisabledAtUtc = isDisabled ? timestamp ?? DateTimeOffset.UtcNow : null;
        Touch();

        RaiseDomainEvent(new UserDisabledStatusChangedDomainEvent(Id, FirebaseUid, IsDisabled, DisabledAtUtc));
    }

    public void SetDeleted(DateTimeOffset? timestamp)
    {
        DeletedAtUtc = timestamp ?? DateTimeOffset.UtcNow;
        if (DeletedAtUtc != null)
        {
            if (Status != UserStatus.Deleted)
            {
                var previousStatus = Status;
                Status = UserStatus.Deleted;
                RaiseDomainEvent(new UserStatusChangedDomainEvent(Id, FirebaseUid, previousStatus, Status));
            }
        }

        Touch();

        RaiseDomainEvent(new UserDeletedDomainEvent(Id, FirebaseUid, DeletedAtUtc));
    }
}
