using PulseCity.Application.DTOs;

namespace PulseCity.Application.Interfaces;

public interface IActivitiesService
{
    Task<ActivityDto> CreateAsync(
        string hostUserId,
        CreateActivityRequest request,
        CancellationToken cancellationToken = default
    );

    Task<ActivityDto?> GetAsync(
        Guid activityId,
        string viewerUserId,
        CancellationToken cancellationToken = default
    );

    Task<ActivityListResponseDto> SearchAsync(
        string viewerUserId,
        ActivityListQuery query,
        CancellationToken cancellationToken = default
    );

    /// <summary>Caller'ın host olduğu (organize ettiği) etkinlikler.</summary>
    Task<ActivityListResponseDto> ListHostingAsync(
        string userId,
        CancellationToken cancellationToken = default
    );

    /// <summary>Caller'ın kabul edilen / bekleyen katılım kayıtları üzerinden join'lü etkinlikleri.</summary>
    Task<ActivityListResponseDto> ListJoinedAsync(
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<ActivityDto?> UpdateAsync(
        Guid activityId,
        string hostUserId,
        UpdateActivityRequest request,
        CancellationToken cancellationToken = default
    );

    Task<bool> CancelAsync(
        Guid activityId,
        string hostUserId,
        CancelActivityRequest request,
        CancellationToken cancellationToken = default
    );

    Task<ActivityParticipationDto?> JoinAsync(
        Guid activityId,
        string userId,
        JoinActivityRequest request,
        CancellationToken cancellationToken = default
    );

    Task<bool> LeaveAsync(
        Guid activityId,
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<ActivityParticipationDto?> RespondJoinAsync(
        Guid activityId,
        Guid participationId,
        string hostUserId,
        RespondJoinRequest request,
        CancellationToken cancellationToken = default
    );

    /// <summary>Host için: katılım istek listesi (Requested + Approved).</summary>
    Task<ActivityParticipationListDto> ListParticipantsAsync(
        Guid activityId,
        string viewerUserId,
        CancellationToken cancellationToken = default
    );

    /// <summary>
    /// Host veya onaylı katılımcı için aktivite grup sohbetinin id'sini döner —
    /// yoksa oluşturur. Caller hostsa veya Approved katılımcıysa <see cref="ChatThreadDto"/>
    /// döner; aksi halde null.
    /// </summary>
    Task<ChatThreadDto?> GetOrCreateGroupChatAsync(
        Guid activityId,
        string userId,
        CancellationToken cancellationToken = default
    );

    /// <summary>Aktivite sonrası bir katılımcıya 1..5 yıldız verir.</summary>
    Task<ActivityRatingDto?> CreateRatingAsync(
        Guid activityId,
        string raterUserId,
        CreateActivityRatingRequest request,
        CancellationToken cancellationToken = default
    );

    /// <summary>Aktivite için verilen tüm puanlar + ortalama.</summary>
    Task<ActivityRatingListDto> ListActivityRatingsAsync(
        Guid activityId,
        string viewerUserId,
        CancellationToken cancellationToken = default
    );

    /// <summary>Bir kullanıcının aldığı puanlar (profil sayfası için).</summary>
    Task<ActivityRatingListDto> ListUserRatingsAsync(
        string userId,
        CancellationToken cancellationToken = default
    );

    /// <summary>Caller'ın katıldığı/host olduğu, geçmiş ama henüz puanlamadığı etkinlikler.</summary>
    Task<PendingRatingListDto> ListPendingRatingsAsync(
        string userId,
        CancellationToken cancellationToken = default
    );
}
