using System;
using System.Collections.Generic;
using CringeBank.Domain.Abstractions;

namespace CringeBank.Domain.ValueObjects;

public sealed class ConversationTitle : ValueObject
{
    public static ConversationTitle Empty { get; } = new ConversationTitle(string.Empty);

    private ConversationTitle()
    {
        Value = string.Empty;
    }

    private ConversationTitle(string value)
    {
        Value = value;
    }

    public string Value { get; private set; } = string.Empty;

    public static ConversationTitle Create(string? input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return Empty;
        }

        var trimmed = input.Trim();
        if (trimmed.Length > 128)
        {
            throw new ArgumentException("Sohbet başlığı 128 karakteri aşamaz.", nameof(input));
        }

        return new ConversationTitle(trimmed);
    }

    protected override IEnumerable<object?> GetEqualityComponents()
    {
        yield return Value;
    }

    public override string ToString() => Value;
}
