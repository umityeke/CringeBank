namespace CringeBank.Domain.Wallet.Enums;

public enum WalletTransactionType : byte
{
    Deposit = 0,
    Withdraw = 1,
    TransferOut = 2,
    TransferIn = 3,
    Purchase = 4,
    Refund = 5
}
