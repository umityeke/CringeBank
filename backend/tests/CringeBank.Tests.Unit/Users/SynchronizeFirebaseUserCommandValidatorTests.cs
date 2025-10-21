using System;
using CringeBank.Application.Users;
using CringeBank.Application.Users.Commands;
using CringeBank.Domain.Enums;
using FluentValidation.TestHelper;
using Xunit;

namespace CringeBank.Tests.Unit.Users;

public class SynchronizeFirebaseUserCommandValidatorTests
{
    private readonly SynchronizeFirebaseUserCommandValidator _validator = new();

    [Fact]
    public void GivenNullProfile_ShouldHaveValidationError()
    {
        var command = new SynchronizeFirebaseUserCommand(null!);

        var result = _validator.TestValidate(command);

        result.ShouldHaveValidationErrorFor(x => x.Profile);
    }

    [Fact]
    public void GivenInvalidEmail_ShouldHaveValidationError()
    {
        var profile = CreateProfile() with { Email = "not-an-email" };
        var command = new SynchronizeFirebaseUserCommand(profile);

        var result = _validator.TestValidate(command);

        result.ShouldHaveValidationErrorFor(x => x.Profile!.Email);
    }

    [Fact]
    public void GivenTooLongFirebaseUid_ShouldHaveValidationError()
    {
        var profile = CreateProfile() with { FirebaseUid = new string('a', 129) };
        var command = new SynchronizeFirebaseUserCommand(profile);

        var result = _validator.TestValidate(command);

        result.ShouldHaveValidationErrorFor(x => x.Profile!.FirebaseUid);
    }

    [Fact]
    public void GivenNegativeClaimsVersion_ShouldHaveValidationError()
    {
        var profile = CreateProfile() with { ClaimsVersion = -1 };
        var command = new SynchronizeFirebaseUserCommand(profile);

        var result = _validator.TestValidate(command);

        result.ShouldHaveValidationErrorFor(x => x.Profile!.ClaimsVersion);
    }

    [Fact]
    public void GivenValidProfile_ShouldNotHaveValidationErrors()
    {
        var command = new SynchronizeFirebaseUserCommand(CreateProfile());

        var result = _validator.TestValidate(command);

        result.ShouldNotHaveAnyValidationErrors();
    }

    private static FirebaseUserProfile CreateProfile()
    {
        return new FirebaseUserProfile(
            FirebaseUid: "uid-123",
            Email: "user@example.com",
            EmailVerified: true,
            ClaimsVersion: 1,
            DisplayName: "Test User",
            ProfileImageUrl: "https://cdn.example.com/avatar.png",
            PhoneNumber: "+905551112233",
            LastLoginAtUtc: DateTimeOffset.UtcNow,
            LastSeenAppVersion: "1.0.0",
            IsDisabled: false,
            DisabledAtUtc: null,
            DeletedAtUtc: null,
            Status: UserStatus.Active);
    }
}
