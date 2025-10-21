namespace CringeBank.Domain.Social.Entities;

public sealed class SocialPostTag
{
    public long PostId { get; private set; }

    public long TagId { get; private set; }

    public SocialPost Post { get; private set; } = null!;

    public SocialTag Tag { get; private set; } = null!;
}
