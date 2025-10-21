using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Auth;
using CringeBank.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CringeBank.Infrastructure.Auth;

public sealed class SqlLoginAuditWriter : ILoginAuditWriter
{
    private readonly CringeBankDbContext _dbContext;

    public SqlLoginAuditWriter(CringeBankDbContext dbContext)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
    }

    public Task RecordAsync(LoginAuditCommand command, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(command);

        FormattableString sql = $@"EXEC auth.sp_RecordLoginEvent
    @Identifier={command.Identifier},
    @EventAt={command.EventAtUtc},
    @Source={command.Source},
    @Channel={command.Channel},
    @Result={command.Result},
    @DeviceIdHash={command.DeviceIdHash},
    @IpHash={command.IpHash},
    @UserAgent={command.UserAgent},
    @Locale={command.Locale},
    @TimeZone={command.TimeZone},
    @IsTrustedDevice={command.IsTrustedDevice},
    @RememberMe={command.RememberMe},
    @RequiresDeviceVerification={command.RequiresDeviceVerification}";

        return _dbContext.Database.ExecuteSqlInterpolatedAsync(sql, cancellationToken);
    }
}