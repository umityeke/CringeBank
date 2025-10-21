using System;
using CringeBank.Domain.ValueObjects;

namespace CringeBank.Domain.Wallet.Entities;

public sealed partial class WalletAccount
{
    public static WalletAccount Create(long userId, CurrencyCode currency)
    {
        ArgumentNullException.ThrowIfNull(currency);

        var utcNow = DateTime.UtcNow;

        return new WalletAccount
        {
            UserId = userId,
            Currency = currency.Value,
            Balance = 0m,
            UpdatedAt = utcNow
        };
    }

    public CurrencyCode CurrencyCodeValueObject => CurrencyCode.Create(Currency);

    public void Credit(decimal amount)
    {
        ValidateAmount(amount);
    var normalizedAmount = NormalizeAmount(amount);
    Balance += normalizedAmount;
        Touch();
    }

    public void Debit(decimal amount)
    {
        ValidateAmount(amount);
        var normalizedAmount = NormalizeAmount(amount);
        if (Balance < normalizedAmount)
        {
            throw new InvalidOperationException("Yetersiz bakiye.");
        }

        Balance -= normalizedAmount;
        Touch();
    }

    public void Touch(DateTime? utcNow = null)
    {
        UpdatedAt = (utcNow ?? DateTime.UtcNow).ToUniversalTime();
    }

    private static void ValidateAmount(decimal amount)
    {
        if (amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Tutar sıfırdan büyük olmalıdır.");
        }

        if (decimal.Round(amount, 2, MidpointRounding.AwayFromZero) != amount)
        {
            throw new ArgumentException("Tutar iki ondalık basamakla sınırlandırılmalıdır.", nameof(amount));
        }
    }

    private static decimal NormalizeAmount(decimal amount) => decimal.Round(amount, 2, MidpointRounding.AwayFromZero);
}
