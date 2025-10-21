using System;
using CringeBank.Domain.Outbox.Enums;

namespace CringeBank.Domain.Outbox.Entities;

public sealed class OutboxEvent
{
    public long Id { get; private set; }

    public string Topic { get; private set; } = string.Empty;

    public string Payload { get; private set; } = string.Empty;

    public OutboxEventStatus Status { get; private set; } = OutboxEventStatus.Pending;

    public int Retries { get; private set; }

    public DateTime CreatedAtUtc { get; private set; }

    public DateTime? ProcessedAtUtc { get; private set; }

    private OutboxEvent()
    {
    }

    public OutboxEvent(string topic, string payload)
    {
        Topic = string.IsNullOrWhiteSpace(topic)
            ? throw new ArgumentException("Topic cannot be null or whitespace.", nameof(topic))
            : topic;
        Payload = payload ?? throw new ArgumentNullException(nameof(payload));
        Status = OutboxEventStatus.Pending;
        CreatedAtUtc = DateTime.UtcNow;
    }

    public void MarkSent(DateTime processedAtUtc)
    {
        Status = OutboxEventStatus.Sent;
        ProcessedAtUtc = processedAtUtc;
    }

    public void MarkFailed(DateTime attemptedAtUtc)
    {
        Status = OutboxEventStatus.Failed;
        ProcessedAtUtc = attemptedAtUtc;
        Retries++;
    }

    public void ResetToPending()
    {
        Status = OutboxEventStatus.Pending;
        ProcessedAtUtc = null;
    }
}
