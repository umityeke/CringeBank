using CringeBank.Domain.ValueObjects;
using FluentValidation;

namespace CringeBank.Application.Users.Commands;

public sealed class SynchronizeFirebaseUserCommandValidator : AbstractValidator<SynchronizeFirebaseUserCommand>
{
    public SynchronizeFirebaseUserCommandValidator()
    {
        RuleFor(x => x.Profile)
            .NotNull()
            .WithMessage("Profil bilgisi sağlanmalıdır.");

        When(x => x.Profile is not null, () =>
        {
            RuleFor(x => x.Profile.FirebaseUid)
                .NotEmpty()
                .MaximumLength(128)
                .WithMessage("Firebase UID geçerli değil.");

            RuleFor(x => x.Profile.Email)
                .Cascade(CascadeMode.Stop)
                .NotEmpty()
                .Must(BeValidEmail)
                .WithMessage("Geçerli bir e-posta adresi girin.");

            RuleFor(x => x.Profile.ClaimsVersion)
                .GreaterThanOrEqualTo(0);

            RuleFor(x => x.Profile.DisplayName)
                .MaximumLength(128);

            RuleFor(x => x.Profile.ProfileImageUrl)
                .MaximumLength(512);

            RuleFor(x => x.Profile.PhoneNumber)
                .MaximumLength(32);
        });
    }

    private static bool BeValidEmail(string email)
    {
        try
        {
            _ = EmailAddress.Create(email);
            return true;
        }
        catch
        {
            return false;
        }
    }
}
