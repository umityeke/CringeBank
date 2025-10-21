using System;
using System.Collections.Generic;
using CringeBank.Domain.Abstractions;

namespace CringeBank.Domain.ValueObjects;

public sealed class DisplayName : ValueObject
{
    public static DisplayName Empty { get; } = new DisplayName(string.Empty);

    private DisplayName()
    {
        Value = string.Empty;
    }

    private DisplayName(string value)
    {
        Value = value;
    }

    public string Value { get; private set; } = string.Empty;

    public static DisplayName Create(string? input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return Empty;
        }

        var trimmed = input.Trim();
        if (trimmed.Length is < 2 or > 128)
        {
            throw new ArgumentException("Görünen ad 2 ile 128 karakter arasında olmalıdır.", nameof(input));
        }

        if (trimmed.AsSpan().IndexOfAny('\n', '\r') >= 0)
        {
            throw new ArgumentException("Görünen ad çok satırlı olamaz.", nameof(input));
        }

        return new DisplayName(trimmed);
    }

    protected override IEnumerable<object?> GetEqualityComponents()
    {
        yield return Value;
    }

    public override string ToString() => Value;
}
