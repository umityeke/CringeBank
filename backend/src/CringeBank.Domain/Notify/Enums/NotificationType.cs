namespace CringeBank.Domain.Notify.Enums;

public enum NotificationType : byte
{
    Unknown = 0,
    DirectMessage = 1,
    FollowRequest = 2,
    FollowAccepted = 3,
    PostLike = 4,
    PostComment = 5,
    System = 10,
    Security = 11
}
