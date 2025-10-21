using System;
using System.Collections.Generic;
using System.Globalization;
using CringeBank.Domain.Abstractions;

namespace CringeBank.Domain.ValueObjects;

public sealed class CurrencyCode : ValueObject
{
    public static CurrencyCode Empty { get; } = new CurrencyCode(string.Empty);

    private CurrencyCode()
    {
        Value = string.Empty;
    }

    private CurrencyCode(string value)
    {
        Value = value;
    }

    public string Value { get; private set; } = string.Empty;

    public static CurrencyCode Create(string? input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            throw new ArgumentException("Para birimi kodu boş olamaz.", nameof(input));
        }

        var upper = input.Trim().ToUpperInvariant();
        if (upper.Length != 3)
        {
            throw new ArgumentException("Para birimi kodu 3 karakter olmalıdır.", nameof(input));
        }

        if (!IsValidIso4217(upper))
        {
            throw new ArgumentException("Geçerli bir ISO 4217 para birimi kodu girin.", nameof(input));
        }

        return new CurrencyCode(upper);
    }

    protected override IEnumerable<object?> GetEqualityComponents()
    {
        yield return Value;
    }

    public override string ToString() => Value;

    private static bool IsValidIso4217(string code)
    {
        foreach (var culture in CultureInfo.GetCultures(CultureTypes.SpecificCultures))
        {
            var region = new RegionInfo(culture.LCID);
            if (string.Equals(region.ISOCurrencySymbol, code, StringComparison.Ordinal))
            {
                return true;
            }
        }

        return string.Equals(code, "CG", StringComparison.Ordinal);
    }
}
