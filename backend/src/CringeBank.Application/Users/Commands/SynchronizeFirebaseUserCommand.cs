using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Users.Commands;

public sealed record SynchronizeFirebaseUserCommand(FirebaseUserProfile Profile) : ICommand<UserSynchronizationResult>;
