using System;
using System.Data.Common;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Wallet;
using CringeBank.Infrastructure.Persistence;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace CringeBank.Infrastructure.Wallets;

public sealed class StoreEscrowGateway : IStoreEscrowGateway
{
    private readonly CringeBankDbContext _dbContext;

    public StoreEscrowGateway(CringeBankDbContext dbContext)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
    }

    public async Task<EscrowOperationResult> ReleaseAsync(Guid orderPublicId, string actorAuthUid, bool isSystemOverride, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(actorAuthUid);

        FormattableString sql = $@"EXEC dbo.sp_Store_ReleaseEscrow
    @OrderPublicId={orderPublicId.ToString("D")},
    @ActorAuthUid={actorAuthUid},
    @IsSystemOverride={isSystemOverride}";

        try
        {
            await _dbContext.Database.ExecuteSqlInterpolatedAsync(sql, cancellationToken).ConfigureAwait(false);
            return EscrowOperationResult.Ok();
        }
        catch (DbException ex)
        {
            var message = ExtractErrorMessage(ex);
            var code = MapFailureCode(message);
            return EscrowOperationResult.Fail(code, message);
        }
    }

    public async Task<EscrowOperationResult> RefundAsync(Guid orderPublicId, string actorAuthUid, bool isSystemOverride, string? refundReason, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(actorAuthUid);

        FormattableString sql = $@"EXEC dbo.sp_Store_RefundEscrow
    @OrderPublicId={orderPublicId.ToString("D")},
    @ActorAuthUid={actorAuthUid},
    @IsSystemOverride={isSystemOverride},
    @RefundReason={refundReason}";

        try
        {
            await _dbContext.Database.ExecuteSqlInterpolatedAsync(sql, cancellationToken).ConfigureAwait(false);
            return EscrowOperationResult.Ok();
        }
        catch (DbException ex)
        {
            var message = ExtractErrorMessage(ex);
            var code = MapFailureCode(message);
            return EscrowOperationResult.Fail(code, message);
        }
    }

    private static string ExtractErrorMessage(DbException exception)
    {
        if (exception is SqlException sqlException)
        {
            foreach (SqlError error in sqlException.Errors)
            {
                var text = ExtractFromMessage(error.Message);
                if (!string.IsNullOrWhiteSpace(text))
                {
                    return text;
                }
            }
        }

        return ExtractFromMessage(exception.Message);
    }

    private static string ExtractFromMessage(string? message)
    {
        if (string.IsNullOrWhiteSpace(message))
        {
            return "Escrow işlemi başarısız oldu.";
        }

        var trimmed = message.Trim();
        var index = trimmed.LastIndexOf(':');

        if (index >= 0 && index < trimmed.Length - 1)
        {
            return trimmed[(index + 1)..].Trim();
        }

        return trimmed;
    }

    private static string MapFailureCode(string? message)
    {
        if (string.IsNullOrWhiteSpace(message))
        {
            return "escrow_failed";
        }

        var normalized = message.ToLowerInvariant();

        if (normalized.Contains("order not found"))
        {
            return "order_not_found";
        }

        if (normalized.Contains("status is not pending") || normalized.Contains("pending orders"))
        {
            return "invalid_order_status";
        }

        if (normalized.Contains("payment status"))
        {
            return "invalid_payment_status";
        }

        if (normalized.Contains("only buyer or system override") || normalized.Contains("only buyer, seller, or override"))
        {
            return "not_authorized";
        }

        if (normalized.Contains("escrow record not found"))
        {
            return "escrow_not_found";
        }

        if (normalized.Contains("escrow is not in locked state"))
        {
            return "escrow_not_locked";
        }

        if (normalized.Contains("buyer wallet not found"))
        {
            return "buyer_wallet_missing";
        }

        if (normalized.Contains("pending balance insufficient"))
        {
            return "insufficient_pending";
        }

        if (normalized.Contains("actor information is required"))
        {
            return "actor_missing";
        }

        if (normalized.Contains("either @orderid or @orderpublicid"))
        {
            return "invalid_request";
        }

        return "escrow_failed";
    }
}
