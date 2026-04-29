using System.ComponentModel.DataAnnotations;

namespace PulseCity.Application.DTOs;

public sealed record MatchDto(
    Guid Id,
    string Status,
    int Compatibility,
    IReadOnlyList<string> CommonInterests,
    DateTimeOffset CreatedAt,
    DateTimeOffset? RespondedAt,
    Guid? ChatId,
    UserSummaryDto User1,
    UserSummaryDto User2,
    bool Initiator1AnonymousInChat,
    bool Responder2AnonymousInChat
);

public sealed class CreateMatchRequest
{
    [Required]
    [MaxLength(128)]
    public string OtherUserId { get; set; } = string.Empty;

    [Range(0, 100)]
    public int Compatibility { get; set; }

    public List<string> CommonInterests { get; set; } = [];

    /// <summary>Whether the initiator wants to appear anonymous in the match chat.</summary>
    public bool AnonymousInChat { get; set; }
}

public sealed class RespondToMatchRequest
{
    [Required]
    [MaxLength(16)]
    public string Status { get; set; } = "accepted";

    public Guid? ChatId { get; set; }

    /// <summary>Whether the accepter wants to appear anonymous in the match chat.</summary>
    public bool AnonymousInChat { get; set; }
}

/// <summary>
/// Query for the "likes me" inbox. Returns pending matches where the caller is
/// the recipient (UserId2), latest first.
/// </summary>
public sealed class LikesMeQuery
{
    [Range(1, 50)]
    public int Limit { get; set; } = 20;
}

public sealed record LikesMeEntryDto(
    Guid MatchId,
    UserSummaryDto Liker,
    int Compatibility,
    IReadOnlyList<string> CommonInterests,
    DateTimeOffset LikedAt,
    bool LikerAnonymousInChat
);

public sealed record LikesMeResponseDto(
    int TotalCount,
    bool HasMore,
    IReadOnlyList<LikesMeEntryDto> Items
);
