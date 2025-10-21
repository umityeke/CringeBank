using System;
using System.Collections.Generic;
using System.Globalization;
using System.Net.Mail;
using System.Text.RegularExpressions;
using CringeBank.Domain.Abstractions;

namespace CringeBank.Domain.ValueObjects;

public sealed partial class EmailAddress : ValueObject
{
    public static EmailAddress Empty { get; } = new EmailAddress(string.Empty, string.Empty);

    private EmailAddress()
    {
        Value = string.Empty;
        Normalized = string.Empty;
    }

    private EmailAddress(string value, string normalized)
    {
        Value = value;
        Normalized = normalized;
    }

    public string Value { get; private set; } = string.Empty;

    public string Normalized { get; private set; } = string.Empty;

    public static EmailAddress Create(string input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            throw new ArgumentException("E-posta adresi boş olamaz.", nameof(input));
        }

        var trimmed = input.Trim();

        if (trimmed.Length > 256)
        {
            throw new ArgumentException("E-posta adresi 256 karakterden kısa olmalıdır.", nameof(input));
        }

        if (!EmailRegex().IsMatch(trimmed))
        {
            throw new ArgumentException("E-posta adresi geçerli biçimde değil.", nameof(input));
        }

        try
        {
            _ = new MailAddress(trimmed);
        }
        catch (FormatException ex)
        {
            throw new ArgumentException("E-posta adresi geçerli biçimde değil.", nameof(input), ex);
        }

        var normalized = trimmed.ToUpperInvariant();
        return new EmailAddress(trimmed, normalized);
    }

    public static EmailAddress FromPersistence(string value, string normalized)
    {
        if (string.IsNullOrWhiteSpace(value) || string.IsNullOrWhiteSpace(normalized))
        {
            throw new ArgumentException("Veritabanı e-posta değerleri işlenemiyor.");
        }

        return new EmailAddress(value, normalized);
    }

    protected override IEnumerable<object?> GetEqualityComponents()
    {
        yield return Normalized;
    }

    public override string ToString() => Value;

    [GeneratedRegex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex EmailRegex();
}
