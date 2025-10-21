using System;
using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Application.Auth;

public interface ILoginAuditWriter
{
    Task RecordAsync(LoginAuditCommand command, CancellationToken cancellationToken = default);
}

public sealed record LoginAuditCommand(
    string Identifier,
    DateTime? EventAtUtc,
    string? Source,
    string? Channel,
    string? Result,
    string? DeviceIdHash,
    string? IpHash,
    string? UserAgent,
    string? Locale,
    string? TimeZone,
    bool IsTrustedDevice,
    bool RememberMe,
    bool RequiresDeviceVerification);