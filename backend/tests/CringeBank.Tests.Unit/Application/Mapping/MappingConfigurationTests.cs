using System;
using CringeBank.Application.Mapping;
using CringeBank.Application.Users;
using CringeBank.Domain.Entities;
using CringeBank.Domain.Enums;
using Xunit;

namespace CringeBank.Tests.Unit.Application.Mapping;

public class MappingConfigurationTests
{
    [Fact]
    public void User_To_UserSynchronizationResult_MapsExpectedValues()
    {
        var config = MappingConfiguration.CreateDefault();
    var mapper = new MapsterObjectMapper(config);

        var user = new User(
            Guid.NewGuid(),
            firebaseUid: "uid-123",
            email: "user@example.com",
            emailVerified: false,
            claimsVersion: 1,
            status: UserStatus.Active);

        user.UpdateCoreProfile(
            email: "user@example.com",
            phoneNumber: "  ",
            displayName: " ",
            profileImageUrl: "https://cdn.example.com/avatar.png",
            emailVerified: true,
            claimsVersion: 2,
            lastLoginAtUtc: DateTimeOffset.UtcNow,
            lastSeenAppVersion: "1.0.0");

        user.MarkSynced(DateTimeOffset.UtcNow);

        var result = mapper.Map<UserSynchronizationResult>(user);

        Assert.Equal(user.Id, result.UserId);
        Assert.Equal(user.FirebaseUid, result.FirebaseUid);
        Assert.Equal(user.Email, result.Email);
        Assert.True(result.EmailVerified);
        Assert.Equal(user.ClaimsVersion, result.ClaimsVersion);
        Assert.Equal(user.Status, result.Status);
        Assert.Null(result.DisplayName);
        Assert.Null(result.PhoneNumber);
        Assert.Equal("https://cdn.example.com/avatar.png", result.ProfileImageUrl);
        Assert.Equal(user.LastLoginAtUtc, result.LastLoginAtUtc);
        Assert.Equal(user.LastSyncedAtUtc, result.LastSyncedAtUtc);
        Assert.Equal(user.LastSeenAppVersion, result.LastSeenAppVersion);
    }
}
