using System;
using System.Linq;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using CringeBank.Application.Abstractions.Events;
using CringeBank.Domain.Abstractions;
using CringeBank.Domain.Auth.Entities;
using CringeBank.Domain.Chat.Entities;
using CringeBank.Domain.Entities;
using CringeBank.Domain.Social.Entities;
using CringeBank.Domain.Outbox.Entities;
using CringeBank.Domain.Wallet.Entities;
using Microsoft.EntityFrameworkCore;

namespace CringeBank.Infrastructure.Persistence;

public sealed class CringeBankDbContext : DbContext
{
    public const string Schema = "cringebank";

    private readonly IDomainEventDispatcher? _domainEventDispatcher;

    public CringeBankDbContext(DbContextOptions<CringeBankDbContext> options, IDomainEventDispatcher? domainEventDispatcher = null)
        : base(options)
    {
        _domainEventDispatcher = domainEventDispatcher;
    }

    public DbSet<Product> Products => Set<Product>();

    public DbSet<ProductImage> ProductImages => Set<ProductImage>();

    public DbSet<Order> Orders => Set<Order>();

    public DbSet<Escrow> Escrows => Set<Escrow>();

    public DbSet<Wallet> Wallets => Set<Wallet>();

    public DbSet<User> Users => Set<User>();

    public DbSet<AuthUser> AuthUsers => Set<AuthUser>();

    public DbSet<AuthUserProfile> AuthUserProfiles => Set<AuthUserProfile>();

    public DbSet<AuthUserSecurity> AuthUserSecurities => Set<AuthUserSecurity>();

    public DbSet<AuthUserBlock> AuthUserBlocks => Set<AuthUserBlock>();

    public DbSet<AuthFollow> AuthFollows => Set<AuthFollow>();

    public DbSet<AuthDeviceToken> AuthDeviceTokens => Set<AuthDeviceToken>();

    public DbSet<AuthRole> AuthRoles => Set<AuthRole>();

    public DbSet<AuthUserRole> AuthUserRoles => Set<AuthUserRole>();

    public DbSet<AuthLoginEvent> AuthLoginEvents => Set<AuthLoginEvent>();

    public DbSet<SocialPost> SocialPosts => Set<SocialPost>();

    public DbSet<SocialPostMedia> SocialPostMediaItems => Set<SocialPostMedia>();

    public DbSet<SocialPostLike> SocialPostLikes => Set<SocialPostLike>();

    public DbSet<SocialPostComment> SocialPostComments => Set<SocialPostComment>();

    public DbSet<SocialCommentLike> SocialCommentLikes => Set<SocialCommentLike>();

    public DbSet<SocialPostSave> SocialPostSaves => Set<SocialPostSave>();

    public DbSet<SocialTag> SocialTags => Set<SocialTag>();

    public DbSet<SocialPostTag> SocialPostTags => Set<SocialPostTag>();

    public DbSet<OutboxEvent> OutboxEvents => Set<OutboxEvent>();

    public DbSet<Conversation> Conversations => Set<Conversation>();

    public DbSet<ConversationMember> ConversationMembers => Set<ConversationMember>();

    public DbSet<Message> Messages => Set<Message>();

    public DbSet<MessageMedia> MessageMedia => Set<MessageMedia>();

    public DbSet<MessageReceipt> MessageReceipts => Set<MessageReceipt>();

    public DbSet<WalletAccount> WalletAccounts => Set<WalletAccount>();

    public DbSet<WalletTransaction> WalletTransactions => Set<WalletTransaction>();

    public DbSet<WalletTransferAudit> WalletTransferAudits => Set<WalletTransferAudit>();

    public DbSet<WalletInAppPurchase> WalletInAppPurchases => Set<WalletInAppPurchase>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        ArgumentNullException.ThrowIfNull(modelBuilder);

        modelBuilder.HasDefaultSchema(Schema);
        modelBuilder.ApplyConfigurationsFromAssembly(Assembly.GetExecutingAssembly());
        base.OnModelCreating(modelBuilder);
    }

    public override int SaveChanges()
    {
        ApplyAuditing();
        var result = base.SaveChanges();
        DispatchDomainEventsAsync().GetAwaiter().GetResult();
        return result;
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        ApplyAuditing();
        return SaveChangesInternalAsync(cancellationToken);
    }

    private void ApplyAuditing()
    {
        var utcNow = DateTimeOffset.UtcNow;

        foreach (var entry in ChangeTracker.Entries<Entity>())
        {
            if (entry.State == EntityState.Added)
            {
                entry.Property(nameof(Entity.CreatedAtUtc)).CurrentValue = utcNow;
                entry.Property(nameof(Entity.UpdatedAtUtc)).CurrentValue = utcNow;
            }
            else if (entry.State == EntityState.Modified)
            {
                entry.Property(nameof(Entity.CreatedAtUtc)).IsModified = false;
                entry.Property(nameof(Entity.UpdatedAtUtc)).CurrentValue = utcNow;
            }
        }
    }

    private async Task<int> SaveChangesInternalAsync(CancellationToken cancellationToken)
    {
        var result = await base.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        await DispatchDomainEventsAsync(cancellationToken).ConfigureAwait(false);
        return result;
    }

    private async Task DispatchDomainEventsAsync(CancellationToken cancellationToken = default)
    {
        if (_domainEventDispatcher is null)
        {
            return;
        }

        var aggregates = ChangeTracker
            .Entries<IAggregateRoot>()
            .Where(entry => entry.Entity.DomainEvents.Count > 0)
            .Select(entry => entry.Entity)
            .ToList();

        foreach (var aggregate in aggregates)
        {
            var events = aggregate.DomainEvents.ToArray();
            aggregate.ClearDomainEvents();

            foreach (var domainEvent in events)
            {
                await _domainEventDispatcher.PublishAsync(domainEvent, cancellationToken).ConfigureAwait(false);
            }
        }
    }
}
