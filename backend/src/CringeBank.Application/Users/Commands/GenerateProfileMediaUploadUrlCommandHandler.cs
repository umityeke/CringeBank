using System;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Commands;

namespace CringeBank.Application.Users.Commands;

public sealed class GenerateProfileMediaUploadUrlCommandHandler : ICommandHandler<GenerateProfileMediaUploadUrlCommand, GenerateProfileMediaUploadUrlResult>
{
    private readonly IProfileMediaStorageService _storageService;

    public GenerateProfileMediaUploadUrlCommandHandler(IProfileMediaStorageService storageService)
    {
        _storageService = storageService ?? throw new ArgumentNullException(nameof(storageService));
    }

    public async Task<GenerateProfileMediaUploadUrlResult> HandleAsync(GenerateProfileMediaUploadUrlCommand command, CancellationToken cancellationToken)
    {
        if (command is null)
        {
            throw new ArgumentNullException(nameof(command));
        }

        try
        {
            var token = await _storageService.CreateUploadTokenAsync(command.PublicId, command.MediaType, command.ContentType, cancellationToken);
            return GenerateProfileMediaUploadUrlResult.SuccessResult(token);
        }
        catch (InvalidOperationException ex)
        {
            return GenerateProfileMediaUploadUrlResult.Failure(ex.Message);
        }
    }
}
