using System;
using CringeBank.Domain.Abstractions;

namespace CringeBank.Domain.Entities;

public sealed class ProductImage : Entity
{
    private ProductImage()
    {
    }

    public ProductImage(Guid id, Guid productId, string url, int sortOrder)
        : base(id)
    {
        ProductId = productId;
        Url = url;
        SortOrder = sortOrder;
    }

    public Guid ProductId { get; private set; }

    public string Url { get; private set; } = string.Empty;

    public int SortOrder { get; private set; }

    public Product? Product { get; private set; }
}
