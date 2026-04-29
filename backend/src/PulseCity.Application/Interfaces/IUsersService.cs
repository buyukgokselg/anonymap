using PulseCity.Application.Auth;
using PulseCity.Application.DTOs;

namespace PulseCity.Application.Interfaces;

public interface IUsersService
{
    Task<UserProfileDto> GetOrCreateCurrentUserAsync(
        AuthenticatedUser authenticatedUser,
        CancellationToken cancellationToken = default
    );

    Task<UserProfileDto> UpdateCurrentUserAsync(
        string userId,
        UpdateUserProfileRequest request,
        CancellationToken cancellationToken = default
    );

    Task<PublicUserProfileDto?> GetUserByIdAsync(
        string userId,
        string? requesterUserId,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<UserSummaryDto>> GetFollowersAsync(
        string userId,
        string? requesterUserId,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<UserSummaryDto>> GetFollowingAsync(
        string userId,
        string? requesterUserId,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<UserSummaryDto>> GetFriendsAsync(
        string userId,
        string? requesterUserId,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<UserSummaryDto>> SearchUsersAsync(
        string query,
        string? excludeUserId,
        CancellationToken cancellationToken = default
    );

    Task<UserDataExportDto> CreateDataExportAsync(
        string userId,
        string publicBaseUrl,
        CancellationToken cancellationToken = default
    );

    Task<UserDataExportDownloadResult?> GetDataExportDownloadAsync(
        string userId,
        Guid exportId,
        string token,
        CancellationToken cancellationToken = default
    );

    /// <summary>
    /// Kullanıcının profilinde sabitlediği post'u günceller. <paramref name="postId"/>
    /// null ise sabitleme kaldırılır. Post başkasına aitse NotFound döner.
    /// </summary>
    Task<UserProfileDto> UpdatePinnedMomentAsync(
        string userId,
        Guid? postId,
        CancellationToken cancellationToken = default
    );

    /// <summary>
    /// Kullanıcının post'larından türetilmiş detaylı mekan ziyaret listesi.
    /// PlaceId bazlı gruplanır, son ziyaret tarihine göre sıralanır.
    /// </summary>
    Task<IReadOnlyList<UserPlaceVisitDto>> GetPlacesVisitedAsync(
        string userId,
        string? requesterUserId,
        CancellationToken cancellationToken = default
    );

    /// <summary>
    /// İzleyici ile hedef kullanıcı arasındaki sinyal kesişimlerinin özeti.
    /// Aynı kullanıcı için çağırılırsa boş dönmelidir.
    /// </summary>
    Task<SignalCrossingSummaryDto> GetSignalCrossingsAsync(
        string targetUserId,
        string requesterUserId,
        CancellationToken cancellationToken = default
    );

    /// <summary>
    /// Dating swipe-stack için aday kullanıcı listesi.
    /// Kimya skoruna göre sıralanır; engellenenler, kendi profili ve
    /// dealbreakers ile uyuşmayanlar elenir.
    /// </summary>
    Task<DiscoverPeopleResponseDto> GetDiscoverPeopleAsync(
        string requesterUserId,
        DiscoverPeopleQuery query,
        CancellationToken cancellationToken = default
    );

    /// <summary>
    /// Records a left-swipe (pass) on another user so the discover stack
    /// does not serve that candidate again. Idempotent.
    /// </summary>
    Task RecordDiscoverPassAsync(
        string userId,
        RecordDiscoverPassRequest request,
        CancellationToken cancellationToken = default
    );

    /// <summary>
    /// Removes a previously recorded pass so the user can be surfaced again
    /// (swipe rewind). Returns true if a row was deleted.
    /// </summary>
    Task<bool> UndoDiscoverPassAsync(
        string userId,
        string targetUserId,
        CancellationToken cancellationToken = default
    );

    /// <summary>
    /// Yeni foto doğrulama başvurusu kaydeder. Geliştirme ortamında otomatik
    /// onaylar, üretimde "pending" durumunda bekler. VerificationApproved
    /// notification'ı çağrılana iletilir.
    /// </summary>
    Task<PhotoVerificationStatusDto> SubmitPhotoVerificationAsync(
        string userId,
        SubmitPhotoVerificationRequest request,
        CancellationToken cancellationToken = default
    );

    /// <summary>
    /// Foto doğrulama durumunu döner — UI rozet/kart için kullanır.
    /// </summary>
    Task<PhotoVerificationStatusDto> GetPhotoVerificationStatusAsync(
        string userId,
        CancellationToken cancellationToken = default
    );
}
