using System;
using CringeBank.Domain.Enums;
using CringeBank.Domain.Events;

namespace CringeBank.Domain.Events.Users;

public sealed record UserCoreProfileUpdatedDomainEvent(
    Guid UserId,
    string FirebaseUid,
    string Email,
    string DisplayName,
    bool EmailVerified,
    DateTimeOffset? LastLoginAtUtc) : DomainEvent;

public sealed record UserSynchronizationCompletedDomainEvent(
    Guid UserId,
    string FirebaseUid,
    DateTimeOffset? LastSyncedAtUtc) : DomainEvent;

public sealed record UserStatusChangedDomainEvent(
    Guid UserId,
    string FirebaseUid,
    UserStatus PreviousStatus,
    UserStatus CurrentStatus) : DomainEvent;

public sealed record UserDisabledStatusChangedDomainEvent(
    Guid UserId,
    string FirebaseUid,
    bool IsDisabled,
    DateTimeOffset? DisabledAtUtc) : DomainEvent;

public sealed record UserDeletedDomainEvent(
    Guid UserId,
    string FirebaseUid,
    DateTimeOffset? DeletedAtUtc) : DomainEvent;
