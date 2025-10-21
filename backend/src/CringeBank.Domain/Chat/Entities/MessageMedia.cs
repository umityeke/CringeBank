namespace CringeBank.Domain.Chat.Entities;

public sealed class MessageMedia
{
    public long Id { get; private set; }

    public long MessageId { get; private set; }

    public string Url { get; private set; } = string.Empty;

    public string? Mime { get; private set; }

    public int? Width { get; private set; }

    public int? Height { get; private set; }

    public Message Message { get; private set; } = null!;
}
