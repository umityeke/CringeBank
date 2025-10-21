using System;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Chat.Enums;
using CringeBank.Domain.ValueObjects;

namespace CringeBank.Domain.Chat.Entities;

public sealed partial class Conversation
{
    public static Conversation Create(long createdByUserId, bool isGroup, ConversationTitle title)
    {
        ArgumentNullException.ThrowIfNull(title);

        var utcNow = DateTime.UtcNow;

        var conversation = new Conversation
        {
            PublicId = Guid.NewGuid(),
            CreatedByUserId = createdByUserId,
            IsGroup = isGroup,
            CreatedAt = utcNow,
            UpdatedAt = utcNow
        };

        conversation.SetTitle(title);
        return conversation;
    }

    public ConversationTitle TitleValueObject => ConversationTitle.Create(Title);

    public ConversationMember AddMember(AuthUser user, ConversationMemberRole role, DateTime? joinedAtUtc = null)
    {
        ArgumentNullException.ThrowIfNull(user);

        if (_members.Exists(member => member.UserId == user.Id))
        {
            throw new InvalidOperationException("Kullanıcı zaten sohbet üyesi.");
        }

        var member = ConversationMember.Create(this, user, role, joinedAtUtc);
        _members.Add(member);
        Touch(joinedAtUtc);
        return member;
    }

    public Message AddMessage(AuthUser sender, MessageBody body, DateTime? utcNow = null)
    {
        ArgumentNullException.ThrowIfNull(sender);
        ArgumentNullException.ThrowIfNull(body);

        var message = Message.Create(this, sender, body, utcNow);
        _messages.Add(message);
        Touch(utcNow);
        return message;
    }

    public void SetTitle(ConversationTitle title)
    {
        ArgumentNullException.ThrowIfNull(title);

        Title = title.Value;
        Touch();
    }

    public void Touch(DateTime? utcNow = null)
    {
        UpdatedAt = (utcNow ?? DateTime.UtcNow).ToUniversalTime();
    }
}
