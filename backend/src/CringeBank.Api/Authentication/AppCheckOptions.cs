namespace CringeBank.Api.Authentication;

public sealed class AppCheckOptions
{
    public bool Enabled { get; set; }

    public string? ProjectNumber { get; set; }

    public string? AppId { get; set; }

    public int CacheTtlSeconds { get; set; } = 300;
}
