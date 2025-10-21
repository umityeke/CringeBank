using System;
using CringeBank.Domain.ValueObjects;

namespace CringeBank.Domain.Entities;

public sealed partial class Order
{
    private static readonly CurrencyCode DefaultCurrency = CurrencyCode.Create("CG");

    public Money Price => Money.Create(PriceGold, DefaultCurrency);

    public Money Commission => Money.Create(CommissionGold, DefaultCurrency);

    public Money Total => Money.Create(TotalGold, DefaultCurrency);

    public void UpdateFinancials(Money price, Money commission)
    {
        ArgumentNullException.ThrowIfNull(price);
        ArgumentNullException.ThrowIfNull(commission);

        if (price.Currency != commission.Currency)
        {
            throw new ArgumentException("Fiyat ve komisyon aynı para biriminde olmalıdır.");
        }

        PriceGold = price.Amount;
        CommissionGold = commission.Amount;
        TotalGold = price.Amount + commission.Amount;
        Touch();
    }
}
