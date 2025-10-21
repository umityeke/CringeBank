using System;
using System.Collections.Generic;
using CringeBank.Domain.Abstractions;

namespace CringeBank.Domain.ValueObjects;

public sealed class ProfileBio : ValueObject
{
    public static ProfileBio Empty { get; } = new ProfileBio(string.Empty);

    private ProfileBio()
    {
        Value = string.Empty;
    }

    private ProfileBio(string value)
    {
        Value = value;
    }

    public string Value { get; private set; } = string.Empty;

    public static ProfileBio Create(string? input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return Empty;
        }

        var trimmed = input.Trim();
        if (trimmed.Length > 512)
        {
            throw new ArgumentException("Profil bio alanı 512 karakteri aşamaz.", nameof(input));
        }

        return new ProfileBio(trimmed);
    }

    protected override IEnumerable<object?> GetEqualityComponents()
    {
        yield return Value;
    }

    public override string ToString() => Value;
}
