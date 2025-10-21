using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Api.Security;

public interface IAppCheckTokenVerifier
{
    Task<AppCheckVerificationResult> VerifyAsync(string token, CancellationToken cancellationToken = default);
}
