using System;
using System.Linq;
using CringeBank.Domain.Entities;
using CringeBank.Domain.Enums;
using CringeBank.Domain.Events.Users;
using Xunit;

namespace CringeBank.Tests.Unit.Domain;

public class UserAggregateTests
{
    [Fact]
    public void UpdateCoreProfile_WithEmailChange_RaisesDomainEvent()
    {
        var user = CreateUser();

        user.UpdateCoreProfile(
            "new@example.com",
            phoneNumber: "+905551112233",
            displayName: "Yeni Kullanıcı",
            profileImageUrl: null,
            emailVerified: true,
            claimsVersion: 2,
            lastLoginAtUtc: DateTimeOffset.UtcNow,
            lastSeenAppVersion: "1.1.0");

        var @event = Assert.Single(user.DomainEvents, e => e is UserCoreProfileUpdatedDomainEvent);
        var profileEvent = Assert.IsType<UserCoreProfileUpdatedDomainEvent>(@event);
        Assert.Equal("new@example.com", profileEvent.Email);
        Assert.Equal("Yeni Kullanıcı", profileEvent.DisplayName);
    }

    [Fact]
    public void SetStatus_WithDifferentStatus_RaisesDomainEvent()
    {
        var user = CreateUser();

        user.SetStatus(UserStatus.Disabled);

        var @event = Assert.Single(user.DomainEvents, e => e is UserStatusChangedDomainEvent);
        var statusEvent = Assert.IsType<UserStatusChangedDomainEvent>(@event);
        Assert.Equal(UserStatus.Active, statusEvent.PreviousStatus);
        Assert.Equal(UserStatus.Disabled, statusEvent.CurrentStatus);
    }

    [Fact]
    public void MarkSynced_RaisesSynchronizationEvent()
    {
        var user = CreateUser();

        var syncedAt = DateTimeOffset.UtcNow;
        user.MarkSynced(syncedAt);

        var @event = Assert.Single(user.DomainEvents, e => e is UserSynchronizationCompletedDomainEvent);
        var syncEvent = Assert.IsType<UserSynchronizationCompletedDomainEvent>(@event);
        Assert.Equal(syncedAt, syncEvent.LastSyncedAtUtc);
    }

    [Fact]
    public void ClearDomainEvents_EmptiesCollection()
    {
        var user = CreateUser();
        user.SetStatus(UserStatus.Disabled);
        Assert.NotEmpty(user.DomainEvents);

        user.ClearDomainEvents();

        Assert.Empty(user.DomainEvents);
    }

    private static User CreateUser()
    {
        return new User(
            Guid.NewGuid(),
            firebaseUid: "firebase-uid",
            email: "old@example.com",
            emailVerified: true,
            claimsVersion: 1,
            status: UserStatus.Active);
    }
}
