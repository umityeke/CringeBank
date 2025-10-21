namespace CringeBank.Domain.Notify.Enums;

public enum NotificationOutboxStatus : byte
{
    Pending = 0,
    Sent = 1,
    Failed = 2
}
