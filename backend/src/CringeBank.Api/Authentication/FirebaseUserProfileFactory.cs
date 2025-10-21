using System;
using System.Collections.Generic;
using System.Globalization;
using System.Security.Claims;
using System.Text.Json;
using CringeBank.Application.Users;
using CringeBank.Domain.Enums;
using FirebaseAdmin.Auth;
using Microsoft.Extensions.Options;

namespace CringeBank.Api.Authentication;

public sealed class FirebaseUserProfileFactory
{
    private readonly FirebaseAuthenticationOptions _options;

    public FirebaseUserProfileFactory(IOptions<FirebaseAuthenticationOptions> options)
    {
        ArgumentNullException.ThrowIfNull(options);
        _options = options.Value;
    }

    public FirebaseUserProfile Create(ClaimsPrincipal principal)
    {
        ArgumentNullException.ThrowIfNull(principal);

        var firebaseUid = FindFirstValue(principal, "firebase_uid")
            ?? FindFirstValue(principal, "user_id")
            ?? throw new InvalidOperationException("Firebase UID claim bulunamadı.");

        var email = FindFirstValue(principal, ClaimTypes.Email)
            ?? FindFirstValue(principal, "email")
            ?? throw new InvalidOperationException("Email claim bulunamadı.");

        var emailVerified = GetBooleanClaim(principal, "email_verified", fallback: true);
        var claimsVersion = GetIntClaim(principal, "claims_version", _options.MinimumClaimsVersion);
        var displayName = FindFirstValue(principal, ClaimTypes.Name) ?? FindFirstValue(principal, "name");
        var profileImageUrl = FindFirstValue(principal, "picture");
        var phoneNumber = FindFirstValue(principal, "phone_number");
        var lastLoginAtUtc = GetTimestampClaim(principal, "auth_time");
        var lastSeenAppVersion = FindFirstValue(principal, "app_version");
        var isDisabled = GetBooleanClaim(principal, "disabled");
        var disabledAtUtc = GetTimestampClaim(principal, "disabled_at");
        var deletedAtUtc = GetTimestampClaim(principal, "deleted_at");
        var statusValue = FindFirstValue(principal, "user_status");
        var status = GetUserStatus(statusValue, isDisabled, deletedAtUtc);

        return CreateProfile(
            firebaseUid,
            email,
            emailVerified,
            claimsVersion,
            displayName,
            profileImageUrl,
            phoneNumber,
            lastLoginAtUtc,
            lastSeenAppVersion,
            isDisabled,
            disabledAtUtc,
            deletedAtUtc,
            status);
    }

    public FirebaseUserProfile Create(UserRecord record)
    {
        ArgumentNullException.ThrowIfNull(record);

        if (string.IsNullOrWhiteSpace(record.Uid))
        {
            throw new InvalidOperationException("Firebase UID bulunamadı.");
        }

        if (string.IsNullOrWhiteSpace(record.Email))
        {
            throw new InvalidOperationException($"Kullanıcı e-posta bilgisi eksik (UID: {record.Uid}).");
        }

        var claims = record.CustomClaims ?? new Dictionary<string, object>();
        var emailVerified = GetCustomBoolean(claims, "email_verified", record.EmailVerified);
        var claimsVersion = GetCustomInt(claims, "claims_version", _options.MinimumClaimsVersion);
        var displayName = string.IsNullOrWhiteSpace(record.DisplayName) ? null : record.DisplayName;
        var profileImageUrl = string.IsNullOrWhiteSpace(record.PhotoUrl) ? null : record.PhotoUrl;
        var phoneNumber = string.IsNullOrWhiteSpace(record.PhoneNumber) ? null : record.PhoneNumber;
        var lastLoginAtUtc = GetCustomTimestamp(claims, "auth_time");
        var lastSeenAppVersion = GetCustomString(claims, "app_version");
        var isDisabled = GetCustomBoolean(claims, "disabled", record.Disabled);
        var disabledAtUtc = GetCustomTimestamp(claims, "disabled_at");
        var deletedAtUtc = GetCustomTimestamp(claims, "deleted_at");
        var statusValue = GetCustomString(claims, "user_status");
        var status = GetUserStatus(statusValue, isDisabled, deletedAtUtc);

        return CreateProfile(
            record.Uid,
            record.Email,
            emailVerified,
            claimsVersion,
            displayName,
            profileImageUrl,
            phoneNumber,
            lastLoginAtUtc,
            lastSeenAppVersion,
            isDisabled,
            disabledAtUtc,
            deletedAtUtc,
            status);
    }

    private static string? FindFirstValue(ClaimsPrincipal principal, string claimType)
        => principal.FindFirst(claimType)?.Value;

    private static bool GetBooleanClaim(ClaimsPrincipal principal, string claimType, bool fallback = false)
    {
        var value = FindFirstValue(principal, claimType);
        if (string.IsNullOrWhiteSpace(value))
        {
            return fallback;
        }

        return bool.TryParse(value, out var parsed) ? parsed : fallback;
    }

    private static int GetIntClaim(ClaimsPrincipal principal, string claimType, int fallback)
    {
        var value = FindFirstValue(principal, claimType);
        if (string.IsNullOrWhiteSpace(value))
        {
            return fallback;
        }

        return int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed)
            ? parsed
            : fallback;
    }

    private static DateTimeOffset? GetTimestampClaim(ClaimsPrincipal principal, string claimType)
    {
        var value = FindFirstValue(principal, claimType);
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        return ParseTimestampString(value);
    }

    private static FirebaseUserProfile CreateProfile(
        string firebaseUid,
        string email,
        bool emailVerified,
        int claimsVersion,
        string? displayName,
        string? profileImageUrl,
        string? phoneNumber,
        DateTimeOffset? lastLoginAtUtc,
        string? lastSeenAppVersion,
        bool isDisabled,
        DateTimeOffset? disabledAtUtc,
        DateTimeOffset? deletedAtUtc,
        UserStatus status)
    {
        return new FirebaseUserProfile(
            firebaseUid,
            email,
            emailVerified,
            claimsVersion,
            displayName,
            profileImageUrl,
            phoneNumber,
            lastLoginAtUtc,
            lastSeenAppVersion,
            isDisabled,
            disabledAtUtc,
            deletedAtUtc,
            status);
    }

    private static UserStatus GetUserStatus(string? statusValue, bool isDisabled, DateTimeOffset? deletedAtUtc)
    {
        if (!string.IsNullOrWhiteSpace(statusValue))
        {
            if (Enum.TryParse<UserStatus>(statusValue, true, out var parsed))
            {
                return parsed;
            }

            if (int.TryParse(statusValue, NumberStyles.Integer, CultureInfo.InvariantCulture, out var numeric)
                && Enum.IsDefined(typeof(UserStatus), numeric))
            {
                return (UserStatus)numeric;
            }
        }

        if (deletedAtUtc.HasValue)
        {
            return UserStatus.Deleted;
        }

        if (isDisabled)
        {
            return UserStatus.Disabled;
        }

        return UserStatus.Active;
    }

    private static bool GetCustomBoolean(IReadOnlyDictionary<string, object> claims, string claimType, bool fallback = false)
    {
        if (!TryGetCustomClaim(claims, claimType, out var value))
        {
            return fallback;
        }

        return value switch
        {
            bool flag => flag,
            string s when bool.TryParse(s, out var parsed) => parsed,
            int i => i != 0,
            long l => l != 0,
            double d => Math.Abs(d) > double.Epsilon,
            JsonElement jsonElement => jsonElement.ValueKind switch
            {
                JsonValueKind.True => true,
                JsonValueKind.False => false,
                JsonValueKind.Number when jsonElement.TryGetInt64(out var number) => number != 0,
                JsonValueKind.String when bool.TryParse(jsonElement.GetString(), out var parsed) => parsed,
                _ => fallback
            },
            _ => fallback
        };
    }

    private static int GetCustomInt(IReadOnlyDictionary<string, object> claims, string claimType, int fallback)
    {
        if (!TryGetCustomClaim(claims, claimType, out var value))
        {
            return fallback;
        }

        return value switch
        {
            int i => i,
            long l => (int)l,
            double d => (int)d,
            string s when int.TryParse(s, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed) => parsed,
            JsonElement jsonElement => jsonElement.ValueKind switch
            {
                JsonValueKind.Number when jsonElement.TryGetInt32(out var intValue) => intValue,
                JsonValueKind.Number when jsonElement.TryGetInt64(out var longValue) => (int)longValue,
                JsonValueKind.String when int.TryParse(jsonElement.GetString(), NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed) => parsed,
                _ => fallback
            },
            _ => fallback
        };
    }

    private static string? GetCustomString(IReadOnlyDictionary<string, object> claims, string claimType)
    {
        if (!TryGetCustomClaim(claims, claimType, out var value))
        {
            return null;
        }

        return value switch
        {
            string s when !string.IsNullOrWhiteSpace(s) => s,
            JsonElement jsonElement when jsonElement.ValueKind == JsonValueKind.String => jsonElement.GetString(),
            _ => value?.ToString()
        };
    }

    private static DateTimeOffset? GetCustomTimestamp(IReadOnlyDictionary<string, object> claims, string claimType)
    {
        if (!TryGetCustomClaim(claims, claimType, out var value))
        {
            return null;
        }

        return value switch
        {
            DateTimeOffset dto => dto.ToUniversalTime(),
            DateTime dt => new DateTimeOffset(DateTime.SpecifyKind(dt, DateTimeKind.Utc)),
            long l => FromUnixTime(l),
            int i => FromUnixTime(i),
            double d => FromUnixTime((long)d),
            string s => ParseTimestampString(s),
            JsonElement jsonElement => jsonElement.ValueKind switch
            {
                JsonValueKind.Number when jsonElement.TryGetInt64(out var longValue) => FromUnixTime(longValue),
                JsonValueKind.String => ParseTimestampString(jsonElement.GetString()),
                _ => null
            },
            _ => null
        };
    }

    private static bool TryGetCustomClaim(IReadOnlyDictionary<string, object> claims, string claimType, out object? value)
    {
        value = null;

        if (claims is null)
        {
            return false;
        }

        if (!claims.TryGetValue(claimType, out var raw) || raw is null)
        {
            return false;
        }

        if (raw is string s && string.IsNullOrWhiteSpace(s))
        {
            return false;
        }

        value = raw;
        return true;
    }

    private static DateTimeOffset? ParseTimestampString(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        if (long.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var seconds))
        {
            return FromUnixTime(seconds);
        }

        if (DateTimeOffset.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var parsed))
        {
            return parsed.ToUniversalTime();
        }

        return null;
    }

    private static DateTimeOffset? FromUnixTime(long value)
    {
        try
        {
            if (Math.Abs(value) > 10_000_000_000L)
            {
                return DateTimeOffset.FromUnixTimeMilliseconds(value);
            }

            return DateTimeOffset.FromUnixTimeSeconds(value);
        }
        catch (ArgumentOutOfRangeException)
        {
            return null;
        }
    }

}
