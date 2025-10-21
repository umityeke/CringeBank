using System;
using CringeBank.Application.Abstractions.Commands;
using CringeBank.Domain.Auth.Enums;

namespace CringeBank.Application.Admin;

public sealed record UpdateUserStatusCommand(
    Guid ActorPublicId,
    Guid TargetPublicId,
    AuthUserStatus Status) : ICommand<UpdateUserStatusResult>;
