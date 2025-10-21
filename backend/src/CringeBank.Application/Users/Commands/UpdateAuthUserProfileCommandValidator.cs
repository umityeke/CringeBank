using System;
using CringeBank.Domain.ValueObjects;
using FluentValidation;

namespace CringeBank.Application.Users.Commands;

public sealed class UpdateAuthUserProfileCommandValidator : AbstractValidator<UpdateAuthUserProfileCommand>
{
    private const int MaxImageUrlLength = 512;
    private const int MaxLocationLength = 128;

    public UpdateAuthUserProfileCommandValidator()
    {
        RuleFor(x => x.PublicId)
            .NotEqual(Guid.Empty)
            .WithMessage("Geçerli bir kullanıcı kimliği zorunludur.");

        RuleFor(x => x.DisplayName)
            .Must(BeValidDisplayName)
            .WithMessage("Görünen ad 2-128 karakter arasında olmalı ve çok satırlı olmamalıdır.");

        RuleFor(x => x.Bio)
            .Must(BeValidBio)
            .WithMessage("Profil bio alanı 512 karakteri aşamaz.");

        RuleFor(x => x.Website)
            .Must(BeValidWebsite)
            .WithMessage("Web sitesi adresi http veya https ile başlayan geçerli bir URL olmalıdır.");

        RuleFor(x => x.AvatarUrl)
            .Must(url => string.IsNullOrWhiteSpace(url) || url.Trim().Length <= MaxImageUrlLength)
            .WithMessage("Avatar URL'i 512 karakteri aşamaz.");

        RuleFor(x => x.BannerUrl)
            .Must(url => string.IsNullOrWhiteSpace(url) || url.Trim().Length <= MaxImageUrlLength)
            .WithMessage("Banner URL'i 512 karakteri aşamaz.");

        RuleFor(x => x.Location)
            .Must(value => string.IsNullOrWhiteSpace(value) || value.Trim().Length <= MaxLocationLength)
            .WithMessage("Konum bilgisi 128 karakteri aşamaz.");
    }

    private static bool BeValidDisplayName(string? value)
    {
        try
        {
            _ = DisplayName.Create(value);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static bool BeValidBio(string? value)
    {
        try
        {
            _ = ProfileBio.Create(value);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static bool BeValidWebsite(string? value)
    {
        try
        {
            _ = WebsiteUrl.Create(value);
            return true;
        }
        catch
        {
            return false;
        }
    }
}
