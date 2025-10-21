using System;
using System.Threading;
using System.Threading.Tasks;

namespace CringeBank.Application.Users;

public interface IProfileMediaStorageService
{
    Task<ProfileMediaUploadToken> CreateUploadTokenAsync(
        Guid userPublicId,
        ProfileMediaType mediaType,
        string contentType,
        CancellationToken cancellationToken = default);
}
