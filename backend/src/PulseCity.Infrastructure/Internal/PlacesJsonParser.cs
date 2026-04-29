using System.Text.Json;

namespace PulseCity.Infrastructure.Internal;

internal static class PlacesJsonParser
{
    public static RawPlace? MapNearbyResult(JsonElement result)
    {
        var placeId = ReadString(result, "place_id");
        if (string.IsNullOrWhiteSpace(placeId))
        {
            return null;
        }

        return new RawPlace
        {
            PlaceId = placeId,
            Name = ReadString(result, "name"),
            Vicinity = ReadString(result, "vicinity"),
            Latitude = ReadNestedDouble(result, "geometry", "location", "lat"),
            Longitude = ReadNestedDouble(result, "geometry", "location", "lng"),
            Rating = ReadDouble(result, "rating"),
            UserRatingsTotal = ReadInt(result, "user_ratings_total"),
            OpenNow = ReadNestedBool(result, "opening_hours", "open_now"),
            PriceLevel = ReadInt(result, "price_level"),
            Types = ReadStringArray(result, "types"),
            PhotoReferences = ReadPhotoReferences(result),
        };
    }

    public static RawPlace? MapDetailResult(JsonElement result)
    {
        var placeId = ReadString(result, "place_id");
        if (string.IsNullOrWhiteSpace(placeId))
        {
            return null;
        }

        return new RawPlace
        {
            PlaceId = placeId,
            Name = ReadString(result, "name"),
            Vicinity = ReadString(result, "formatted_address"),
            Address = ReadString(result, "formatted_address"),
            Phone = ReadString(result, "formatted_phone_number"),
            Website = ReadString(result, "website"),
            Latitude = ReadNestedDouble(result, "geometry", "location", "lat"),
            Longitude = ReadNestedDouble(result, "geometry", "location", "lng"),
            Rating = ReadDouble(result, "rating"),
            UserRatingsTotal = ReadInt(result, "user_ratings_total"),
            OpenNow = ReadNestedBool(result, "opening_hours", "open_now"),
            PriceLevel = ReadInt(result, "price_level"),
            Types = ReadStringArray(result, "types"),
            PhotoReferences = ReadPhotoReferences(result),
            WeekdayText = ReadNestedStringArray(result, "opening_hours", "weekday_text"),
            Reviews = ReadReviews(result),
        };
    }

    private static string ReadString(JsonElement element, string propertyName) =>
        element.TryGetProperty(propertyName, out var property) && property.ValueKind == JsonValueKind.String
            ? property.GetString() ?? string.Empty
            : string.Empty;

    private static double ReadDouble(JsonElement element, string propertyName) =>
        element.TryGetProperty(propertyName, out var property) && property.TryGetDouble(out var value) ? value : 0;

    private static int ReadInt(JsonElement element, string propertyName) =>
        element.TryGetProperty(propertyName, out var property) && property.TryGetInt32(out var value) ? value : 0;

    private static double ReadNestedDouble(JsonElement element, params string[] properties)
    {
        var current = element;
        foreach (var property in properties[..^1])
        {
            if (!current.TryGetProperty(property, out current))
            {
                return 0;
            }
        }

        return current.TryGetProperty(properties[^1], out var leaf) && leaf.TryGetDouble(out var value) ? value : 0;
    }

    private static bool ReadNestedBool(JsonElement element, params string[] properties)
    {
        var current = element;
        foreach (var property in properties[..^1])
        {
            if (!current.TryGetProperty(property, out current))
            {
                return false;
            }
        }

        return current.TryGetProperty(properties[^1], out var leaf) && leaf.ValueKind == JsonValueKind.True;
    }

    private static List<string> ReadStringArray(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var property) || property.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        return property.EnumerateArray()
            .Where(item => item.ValueKind == JsonValueKind.String)
            .Select(item => item.GetString() ?? string.Empty)
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .ToList();
    }

    private static List<string> ReadNestedStringArray(JsonElement element, params string[] properties)
    {
        var current = element;
        foreach (var property in properties[..^1])
        {
            if (!current.TryGetProperty(property, out current))
            {
                return [];
            }
        }

        if (!current.TryGetProperty(properties[^1], out var leaf) || leaf.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        return leaf.EnumerateArray()
            .Where(item => item.ValueKind == JsonValueKind.String)
            .Select(item => item.GetString() ?? string.Empty)
            .ToList();
    }

    private static List<string> ReadPhotoReferences(JsonElement element)
    {
        if (!element.TryGetProperty("photos", out var photos) || photos.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        return photos.EnumerateArray()
            .Select(photo => ReadString(photo, "photo_reference"))
            .Where(item => !string.IsNullOrWhiteSpace(item))
            .ToList();
    }

    private static List<RawReview> ReadReviews(JsonElement element)
    {
        if (!element.TryGetProperty("reviews", out var reviews) || reviews.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        return reviews.EnumerateArray()
            .Select(review => new RawReview(
                ReadString(review, "author_name"),
                ReadInt(review, "rating"),
                ReadString(review, "text"),
                ReadString(review, "relative_time_description")
            ))
            .ToList();
    }
}
