using System;
using System.Collections.Generic;
using CringeBank.Domain.Abstractions;

namespace CringeBank.Domain.ValueObjects;

public sealed class Money : ValueObject
{
    private Money()
    {
        Amount = 0m;
        Currency = CurrencyCode.Create("CG");
    }

    private Money(decimal amount, CurrencyCode currency)
    {
        Amount = amount;
        Currency = currency;
    }

    public decimal Amount { get; private set; }

    public CurrencyCode Currency { get; private set; } = CurrencyCode.Create("CG");

    public static Money Create(decimal amount, CurrencyCode currency)
    {
        ArgumentNullException.ThrowIfNull(currency);

        if (amount < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Tutar negatif olamaz.");
        }

        if (decimal.Round(amount, 2, MidpointRounding.AwayFromZero) != amount)
        {
            throw new ArgumentException("Tutar iki ondalık basamağa yuvarlanmalıdır.", nameof(amount));
        }

        return new Money(amount, currency);
    }

    public Money Add(decimal amount)
    {
        if (amount < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Ekleme miktarı negatif olamaz.");
        }

        var normalized = decimal.Round(amount, 2, MidpointRounding.AwayFromZero);
        return new Money(Amount + normalized, Currency);
    }

    public Money Subtract(decimal amount)
    {
        if (amount < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Çıkarma miktarı negatif olamaz.");
        }

        var normalized = decimal.Round(amount, 2, MidpointRounding.AwayFromZero);
        if (normalized > Amount)
        {
            throw new InvalidOperationException("Tutar negatif sonuç veremez.");
        }

        return new Money(Amount - normalized, Currency);
    }

    protected override IEnumerable<object?> GetEqualityComponents()
    {
        yield return Amount;
        yield return Currency;
    }

    public override string ToString() => $"{Amount:F2} {Currency.Value}";
}
