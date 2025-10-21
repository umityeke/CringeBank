using System;
using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Admin;

public sealed record RemoveUserRoleCommand(
    Guid ActorPublicId,
    Guid TargetPublicId,
    string RoleName) : ICommand<RemoveUserRoleResult>;
