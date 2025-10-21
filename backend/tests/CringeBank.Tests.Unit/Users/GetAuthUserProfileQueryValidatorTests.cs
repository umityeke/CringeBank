using System;
using CringeBank.Application.Users.Queries;
using FluentValidation.TestHelper;
using Xunit;

namespace CringeBank.Tests.Unit.Users;

public class GetAuthUserProfileQueryValidatorTests
{
    private readonly GetAuthUserProfileQueryValidator _validator = new();

    [Fact]
    public void GivenEmptyPublicId_ShouldHaveValidationError()
    {
        var query = new GetAuthUserProfileQuery(Guid.Empty);

        var result = _validator.TestValidate(query);

        result.ShouldHaveValidationErrorFor(x => x.PublicId);
    }

    [Fact]
    public void GivenValidPublicId_ShouldNotHaveValidationErrors()
    {
        var query = new GetAuthUserProfileQuery(Guid.NewGuid());

        var result = _validator.TestValidate(query);

        result.ShouldNotHaveAnyValidationErrors();
    }
}
