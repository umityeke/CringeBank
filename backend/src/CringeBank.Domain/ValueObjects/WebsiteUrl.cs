using System;
using System.Collections.Generic;
using CringeBank.Domain.Abstractions;

namespace CringeBank.Domain.ValueObjects;

public sealed class WebsiteUrl : ValueObject
{
    public static WebsiteUrl Empty { get; } = new WebsiteUrl(string.Empty);

    private WebsiteUrl()
    {
        Value = string.Empty;
    }

    private WebsiteUrl(string value)
    {
        Value = value;
    }

    public string Value { get; private set; } = string.Empty;

    public static WebsiteUrl Create(string? input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return Empty;
        }

        var trimmed = input.Trim();
        if (trimmed.Length > 256)
        {
            throw new ArgumentException("Web sitesi adresi 256 karakteri aşamaz.", nameof(input));
        }

        if (!Uri.TryCreate(trimmed, UriKind.Absolute, out var uri) || (uri.Scheme != Uri.UriSchemeHttps && uri.Scheme != Uri.UriSchemeHttp))
        {
            throw new ArgumentException("Web sitesi adresi http veya https ile başlamalıdır.", nameof(input));
        }

        return new WebsiteUrl(uri.ToString());
    }

    protected override IEnumerable<object?> GetEqualityComponents()
    {
        yield return Value;
    }

    public override string ToString() => Value;
}
