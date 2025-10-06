using System;
using System.Collections.Generic;
using CringeBank.Domain.Abstractions;
using CringeBank.Domain.Enums;

namespace CringeBank.Domain.Entities;

public sealed class Product : Entity, IAggregateRoot
{
    private readonly List<ProductImage> _images = new();

    private Product()
    {
    }

    public Product(
        Guid id,
        string title,
        string description,
        decimal priceGold,
        string category,
        ProductCondition condition,
        SellerType sellerType,
        Guid? sellerId,
        Guid? vendorId)
        : base(id)
    {
        Title = title;
        Description = description;
        PriceGold = priceGold;
        Category = category;
        Condition = condition;
        SellerType = sellerType;
        SellerId = sellerId;
        VendorId = vendorId;
        Status = ProductStatus.Active;
    }

    public string Title { get; private set; } = string.Empty;

    public string Description { get; private set; } = string.Empty;

    public decimal PriceGold { get; private set; }

    public string Category { get; private set; } = string.Empty;

    public ProductCondition Condition { get; private set; }

    public ProductStatus Status { get; private set; } = ProductStatus.Unknown;

    public SellerType SellerType { get; private set; } = SellerType.Unknown;

    public Guid? SellerId { get; private set; }

    public Guid? VendorId { get; private set; }

    public IReadOnlyCollection<ProductImage> Images => _images.AsReadOnly();

    public void UpdateDetails(string title, string description, decimal priceGold, string category, ProductCondition condition)
    {
        Title = title;
        Description = description;
        PriceGold = priceGold;
        Category = category;
        Condition = condition;
        Touch();
    }

    public void ChangeStatus(ProductStatus status)
    {
        Status = status;
        Touch();
    }

    public void AddImage(Guid imageId, string url, int sortOrder)
    {
        _images.Add(new ProductImage(imageId, Id, url, sortOrder));
        Touch();
    }

    public void RemoveImage(Guid imageId)
    {
        var image = _images.Find(x => x.Id == imageId);
        if (image != null)
        {
            _images.Remove(image);
            Touch();
        }
    }
}
