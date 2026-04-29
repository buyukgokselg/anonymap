using PulseCity.Application.DTOs;

namespace PulseCity.Application.Interfaces;

public interface IChatsService
{
    Task<ChatThreadDto> CreateOrGetDirectChatAsync(
        string userId,
        CreateDirectChatRequest request,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<ChatThreadDto>> GetChatsAsync(
        string userId,
        int skip = 0,
        int take = 25,
        bool includeArchived = false,
        CancellationToken cancellationToken = default
    );

    Task<ChatThreadDto?> GetChatAsync(
        Guid chatId,
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<IReadOnlyList<ChatMessageDto>> GetMessagesAsync(
        Guid chatId,
        string userId,
        int skip = 0,
        int take = 50,
        CancellationToken cancellationToken = default
    );

    Task<ChatMessageDto> SendMessageAsync(
        Guid chatId,
        string userId,
        SendChatMessageRequest request,
        CancellationToken cancellationToken = default
    );

    Task<bool> UpdateMessageStatusAsync(
        Guid chatId,
        Guid messageId,
        string userId,
        UpdateChatMessageStatusRequest request,
        CancellationToken cancellationToken = default
    );

    Task<bool> UpdateReactionAsync(
        Guid chatId,
        Guid messageId,
        string userId,
        UpdateChatReactionRequest request,
        CancellationToken cancellationToken = default
    );

    Task<bool> DeleteMessageAsync(
        Guid chatId,
        Guid messageId,
        string userId,
        string scope,
        CancellationToken cancellationToken = default
    );

    Task<bool> SetTypingAsync(
        Guid chatId,
        string userId,
        SetTypingRequest request,
        CancellationToken cancellationToken = default
    );

    Task<bool> MarkAsReadAsync(
        Guid chatId,
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<bool> ConvertToFriendChatAsync(
        Guid chatId,
        string userId,
        CancellationToken cancellationToken = default
    );

    /// <summary>
    /// Sends a "make permanent" request inside a temporary chat.
    /// Returns the new pending state: "pending" | "accepted" | "already_permanent".
    /// When both participants request, the chat becomes permanent.
    /// </summary>
    Task<string> RequestChatPermanenceAsync(
        Guid chatId,
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<bool> DeleteChatAsync(
        Guid chatId,
        string userId,
        CancellationToken cancellationToken = default
    );

    Task<bool> SetArchivedAsync(
        Guid chatId,
        string userId,
        bool isArchived,
        CancellationToken cancellationToken = default
    );
}
