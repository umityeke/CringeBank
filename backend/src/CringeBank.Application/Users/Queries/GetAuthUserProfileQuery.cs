using System;
using CringeBank.Application.Abstractions.Queries;

namespace CringeBank.Application.Users.Queries;

public sealed record GetAuthUserProfileQuery(Guid PublicId) : IQuery<UserProfileResult?>;
