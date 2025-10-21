using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using CringeBank.Domain.Abstractions;

namespace CringeBank.Domain.ValueObjects;

public sealed partial class Username : ValueObject
{
    public static Username Empty { get; } = new Username(string.Empty, string.Empty);

    private Username()
    {
        Value = string.Empty;
        Normalized = string.Empty;
    }

    private Username(string value, string normalized)
    {
        Value = value;
        Normalized = normalized;
    }

    public string Value { get; private set; } = string.Empty;

    public string Normalized { get; private set; } = string.Empty;

    public static Username Create(string input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            throw new ArgumentException("Kullanıcı adı boş olamaz.", nameof(input));
        }

        var trimmed = input.Trim();
        if (trimmed.Length is < 3 or > 64)
        {
            throw new ArgumentException("Kullanıcı adı 3 ile 64 karakter arasında olmalıdır.", nameof(input));
        }

        var lowercase = trimmed.ToLowerInvariant();
        if (!UsernameRegex().IsMatch(lowercase))
        {
            throw new ArgumentException("Kullanıcı adı sadece küçük harf, rakam, nokta ve alt çizgi içerebilir ve harfle veya rakamla başlamalı/bitmelidir.", nameof(input));
        }

        if (lowercase.Contains("..", StringComparison.Ordinal) || lowercase.Contains("__", StringComparison.Ordinal) || lowercase.Contains("._", StringComparison.Ordinal) || lowercase.Contains("_.", StringComparison.Ordinal))
        {
            throw new ArgumentException("Kullanıcı adında ardışık nokta veya alt çizgi kullanılamaz.", nameof(input));
        }

    return new Username(trimmed, lowercase);
    }

    public static Username FromPersistence(string value, string normalized)
    {
        if (string.IsNullOrWhiteSpace(value) || string.IsNullOrWhiteSpace(normalized))
        {
            throw new ArgumentException("Veritabanı kullanıcı adı değerleri işlenemiyor.");
        }

        return new Username(value, normalized);
    }

    protected override IEnumerable<object?> GetEqualityComponents()
    {
        yield return Normalized;
    }

    public override string ToString() => Value;

    [GeneratedRegex("^[a-z0-9](?:[a-z0-9._]{1,62}[a-z0-9])?$", RegexOptions.CultureInvariant)]
    private static partial Regex UsernameRegex();
}
