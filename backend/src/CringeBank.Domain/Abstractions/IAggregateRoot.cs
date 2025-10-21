using System.Collections.Generic;
using CringeBank.Domain.Events;

namespace CringeBank.Domain.Abstractions;

public interface IAggregateRoot
{
	IReadOnlyCollection<IDomainEvent> DomainEvents { get; }

	void ClearDomainEvents();
}
