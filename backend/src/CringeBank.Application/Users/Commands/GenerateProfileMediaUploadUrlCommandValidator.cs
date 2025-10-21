using System;
using FluentValidation;

namespace CringeBank.Application.Users.Commands;

public sealed class GenerateProfileMediaUploadUrlCommandValidator : AbstractValidator<GenerateProfileMediaUploadUrlCommand>
{
    public GenerateProfileMediaUploadUrlCommandValidator()
    {
        RuleFor(x => x.PublicId)
            .NotEqual(Guid.Empty)
            .WithMessage("Geçerli bir kullanıcı kimliği zorunludur.");

        RuleFor(x => x.ContentType)
            .NotEmpty()
            .MaximumLength(128)
            .WithMessage("İçerik tipi boş olamaz ve 128 karakteri aşamaz.")
            .Must(BeSupportedContentType)
            .WithMessage("Sadece görsel içerik türlerine izin verilir (image/*).");

        RuleFor(x => x.MediaType)
            .IsInEnum();
    }

    private static bool BeSupportedContentType(string contentType)
    {
        return !string.IsNullOrWhiteSpace(contentType)
            && contentType.Trim().StartsWith("image/", StringComparison.OrdinalIgnoreCase);
    }
}
