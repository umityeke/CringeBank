using System;

namespace CringeBank.Domain.Abstractions;

public abstract class Entity
{
  public Guid Id { get; protected set; }

  public DateTimeOffset CreatedAtUtc { get; protected set; }

  public DateTimeOffset UpdatedAtUtc { get; protected set; }

  protected Entity()
  {
    CreatedAtUtc = DateTimeOffset.UtcNow;
    UpdatedAtUtc = DateTimeOffset.UtcNow;
  }

  protected Entity(Guid id)
    : this()
  {
    Id = id;
  }

  public void Touch(DateTimeOffset? timestamp = null)
  {
    UpdatedAtUtc = timestamp ?? DateTimeOffset.UtcNow;
  }
}
