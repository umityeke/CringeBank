using System;
using System.Collections.Generic;
using CringeBank.Domain.Abstractions;

namespace CringeBank.Domain.ValueObjects;

public sealed class PostContent : ValueObject
{
    public static PostContent Empty { get; } = new PostContent(string.Empty);

    private PostContent()
    {
        Value = string.Empty;
    }

    private PostContent(string value)
    {
        Value = value;
    }

    public string Value { get; private set; } = string.Empty;

    public static PostContent Create(string? input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return Empty;
        }

        var trimmed = input.Trim();
        if (trimmed.Length > 2000)
        {
            throw new ArgumentException("Gönderi metni 2000 karakteri aşamaz.", nameof(input));
        }

        return new PostContent(trimmed);
    }

    protected override IEnumerable<object?> GetEqualityComponents()
    {
        yield return Value;
    }

    public override string ToString() => Value;
}
