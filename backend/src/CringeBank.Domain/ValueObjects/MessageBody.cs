using System;
using System.Collections.Generic;
using CringeBank.Domain.Abstractions;

namespace CringeBank.Domain.ValueObjects;

public sealed class MessageBody : ValueObject
{
    public static MessageBody Empty { get; } = new MessageBody(string.Empty);

    private MessageBody()
    {
        Value = string.Empty;
    }

    private MessageBody(string value)
    {
        Value = value;
    }

    public string Value { get; private set; } = string.Empty;

    public static MessageBody Create(string? input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            throw new ArgumentException("Mesaj metni boş olamaz.", nameof(input));
        }

        var trimmed = input.Trim();

        if (trimmed.Length == 0)
        {
            throw new ArgumentException("Mesaj metni boş olamaz.", nameof(input));
        }

        if (trimmed.Length > 2000)
        {
            throw new ArgumentException("Mesaj metni 2000 karakteri aşamaz.", nameof(input));
        }

        return new MessageBody(trimmed);
    }

    protected override IEnumerable<object?> GetEqualityComponents()
    {
        yield return Value;
    }

    public override string ToString() => Value;
}
