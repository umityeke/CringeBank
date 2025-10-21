namespace CringeBank.Domain.Outbox.Enums;

public enum OutboxEventStatus : byte
{
    Pending = 0,
    Sent = 1,
    Failed = 2
}
