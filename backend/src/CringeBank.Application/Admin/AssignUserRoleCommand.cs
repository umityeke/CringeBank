using System;
using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Admin;

public sealed record AssignUserRoleCommand(
    Guid ActorPublicId,
    Guid TargetPublicId,
    string RoleName) : ICommand<AssignUserRoleResult>;
