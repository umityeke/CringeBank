using CringeBank.Application.Users;
using CringeBank.Domain.Entities;
using Mapster;

namespace CringeBank.Application.Mapping;

public static class MappingConfiguration
{
    public static TypeAdapterConfig CreateDefault()
    {
        var config = new TypeAdapterConfig();

        config.NewConfig<User, UserSynchronizationResult>()
            .Map(dest => dest.UserId, src => src.Id)
            .Map(dest => dest.DisplayName, src => string.IsNullOrWhiteSpace(src.DisplayName) ? null : src.DisplayName)
            .Map(dest => dest.ProfileImageUrl, src => string.IsNullOrWhiteSpace(src.ProfileImageUrl) ? null : src.ProfileImageUrl)
            .Map(dest => dest.PhoneNumber, src => string.IsNullOrWhiteSpace(src.PhoneNumber) ? null : src.PhoneNumber);

        return config;
    }
}
