using Microsoft.EntityFrameworkCore;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Domain.Entities;
using PulseCity.Domain.Enums;
using PulseCity.Infrastructure.Data;
using PulseCity.Infrastructure.Internal;

namespace PulseCity.Infrastructure.Services;

public sealed class ChatsService(
    PulseCityDbContext dbContext,
    IRealtimeNotifier realtimeNotifier,
    IPushNotificationService pushNotificationService
) : IChatsService
{
    public async Task<ChatThreadDto> CreateOrGetDirectChatAsync(
        string userId,
        CreateDirectChatRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var otherUserId = request.OtherUserId.Trim();
        if (string.IsNullOrWhiteSpace(otherUserId) || otherUserId == userId)
        {
            throw new InvalidOperationException("Invalid chat target.");
        }

        await EnsureUsersExistAsync(userId, otherUserId, cancellationToken);
        await EnsureUsersNotBlockedAsync(userId, otherUserId, cancellationToken);

        var directKey = BuildDirectKey(userId, otherUserId);
        var existing = await dbContext.Chats.AsNoTracking()
            .FirstOrDefaultAsync(entry => entry.DirectMessageKey == directKey, cancellationToken);

        if (existing is not null)
        {
            return await BuildChatDtoAsync(existing, userId, cancellationToken);
        }

        var now = DateTimeOffset.UtcNow;
        var chat = new ChatThread
        {
            CreatedByUserId = userId,
            LastMessageTime = now,
            CreatedAt = now,
            IsTemporary = request.IsTemporary,
            IsFriendChat = !request.IsTemporary,
            ExpiresAt = request.IsTemporary ? now.AddHours(24) : null,
            DirectMessageKey = directKey,
        };

        dbContext.Chats.Add(chat);
        dbContext.ChatParticipants.AddRange(
            new ChatParticipant
            {
                ChatId = chat.Id,
                UserId = userId,
                JoinedAt = now,
                LastReadAt = now,
            },
            new ChatParticipant
            {
                ChatId = chat.Id,
                UserId = otherUserId,
                JoinedAt = now,
                LastReadAt = now,
            }
        );

        await dbContext.SaveChangesAsync(cancellationToken);
        await realtimeNotifier.NotifyChatUpdatedAsync(
            chat.Id,
            [userId, otherUserId],
            cancellationToken: cancellationToken
        );
        return await BuildChatDtoAsync(chat, userId, cancellationToken);
    }

    public async Task<IReadOnlyList<ChatThreadDto>> GetChatsAsync(
        string userId,
        int skip = 0,
        int take = 25,
        bool includeArchived = false,
        CancellationToken cancellationToken = default
    )
    {
        var safeSkip = Math.Max(0, skip);
        var safeTake = Math.Clamp(take, 1, 100);
        var currentUserParticipations = await dbContext.ChatParticipants.AsNoTracking()
            .Where(entry => entry.UserId == userId && entry.DeletedAt == null && (includeArchived || !entry.IsArchived))
            .OrderByDescending(entry => entry.JoinedAt)
            .ToListAsync(cancellationToken);

        var chatIds = currentUserParticipations
            .Select(entry => entry.ChatId)
            .ToList();

        if (chatIds.Count == 0)
        {
            return [];
        }

        var blockedUserIds = await GetBlockedUserIdsAsync(userId, cancellationToken);
        var participants = await dbContext.ChatParticipants.AsNoTracking()
            .Where(entry => chatIds.Contains(entry.ChatId))
            .OrderBy(entry => entry.JoinedAt)
            .ToListAsync(cancellationToken);

        var accessibleChatIds = participants
            .GroupBy(entry => entry.ChatId)
            .Where(group =>
                !group.Any(entry => entry.UserId != userId && blockedUserIds.Contains(entry.UserId)))
            .Select(group => group.Key)
            .ToList();

        if (accessibleChatIds.Count == 0)
        {
            return [];
        }

        var chats = await dbContext.Chats.AsNoTracking()
            .Where(entry => accessibleChatIds.Contains(entry.Id))
            .OrderByDescending(entry => entry.LastMessageTime)
            .Skip(safeSkip)
            .Take(safeTake)
            .ToListAsync(cancellationToken);

        var participantLookup = participants
            .Where(entry => accessibleChatIds.Contains(entry.ChatId))
            .GroupBy(entry => entry.ChatId)
            .ToDictionary(group => group.Key, group => (IReadOnlyList<ChatParticipant>)group.ToList());

        var participantUserIds = participants
            .Where(entry => accessibleChatIds.Contains(entry.ChatId))
            .Select(entry => entry.UserId)
            .Distinct()
            .ToList();

        var users = await dbContext.Users.AsNoTracking()
            .Where(entry => participantUserIds.Contains(entry.Id))
            .ToDictionaryAsync(entry => entry.Id, cancellationToken);
        var archiveLookup = currentUserParticipations.ToDictionary(
            entry => entry.ChatId,
            entry => entry.IsArchived
        );

        return chats
            .Select(chat => BuildChatDto(
                chat,
                participantLookup[chat.Id],
                users,
                archiveLookup.GetValueOrDefault(chat.Id)
            ))
            .ToList();
    }

    public async Task<ChatThreadDto?> GetChatAsync(
        Guid chatId,
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var isParticipant = await IsParticipantAsync(chatId, userId, cancellationToken);
        if (!isParticipant)
        {
            return null;
        }

        var blockedUserIds = await GetBlockedUserIdsAsync(userId, cancellationToken);
        var participants = await dbContext.ChatParticipants.AsNoTracking()
            .Where(entry => entry.ChatId == chatId)
            .OrderBy(entry => entry.JoinedAt)
            .ToListAsync(cancellationToken);
        if (participants.Any(entry => entry.UserId != userId && blockedUserIds.Contains(entry.UserId)))
        {
            return null;
        }

        var chat = await dbContext.Chats.AsNoTracking()
            .FirstOrDefaultAsync(entry => entry.Id == chatId, cancellationToken);

        if (chat is null)
        {
            return null;
        }

        var userIds = participants.Select(entry => entry.UserId).Distinct().ToList();
        var users = await dbContext.Users.AsNoTracking()
            .Where(entry => userIds.Contains(entry.Id))
            .ToDictionaryAsync(entry => entry.Id, cancellationToken);
        var currentUserArchived = participants
            .FirstOrDefault(entry => entry.UserId == userId)
            ?.IsArchived ?? false;

        return BuildChatDto(chat, participants, users, currentUserArchived);
    }

    public async Task<IReadOnlyList<ChatMessageDto>> GetMessagesAsync(
        Guid chatId,
        string userId,
        int skip = 0,
        int take = 50,
        CancellationToken cancellationToken = default
    )
    {
        var safeSkip = Math.Max(0, skip);
        var safeTake = Math.Clamp(take, 1, 200);
        var isParticipant = await IsParticipantAsync(chatId, userId, cancellationToken);
        if (!isParticipant)
        {
            return [];
        }

        var blockedUserIds = await GetBlockedUserIdsAsync(userId, cancellationToken);
        var currentParticipant = await dbContext.ChatParticipants.AsNoTracking()
            .FirstOrDefaultAsync(
                entry => entry.ChatId == chatId && entry.UserId == userId,
                cancellationToken
            );
        if (currentParticipant is null)
        {
            return [];
        }
        var participantIds = await dbContext.ChatParticipants.AsNoTracking()
            .Where(entry => entry.ChatId == chatId)
            .Select(entry => entry.UserId)
            .ToListAsync(cancellationToken);
        if (participantIds.Any(entry => entry != userId && blockedUserIds.Contains(entry)))
        {
            return [];
        }

        var messages = await dbContext.ChatMessages.AsNoTracking()
            .Where(entry => entry.ChatId == chatId)
            .Where(entry => !currentParticipant.DeletedAt.HasValue || entry.CreatedAt > currentParticipant.DeletedAt.Value)
            .OrderByDescending(entry => entry.CreatedAt)
            .Skip(safeSkip)
            .Take(safeTake)
            .ToListAsync(cancellationToken);

        if (messages.Count == 0)
        {
            return [];
        }

        var hiddenMessageIds = await dbContext.ChatMessageHiddenStates.AsNoTracking()
            .Where(entry => entry.UserId == userId)
            .Where(entry => messages.Select(message => message.Id).Contains(entry.MessageId))
            .Select(entry => entry.MessageId)
            .ToHashSetAsync(cancellationToken);

        messages = messages
            .Where(entry => !hiddenMessageIds.Contains(entry.Id))
            .ToList();

        if (messages.Count == 0)
        {
            return [];
        }

        messages.Reverse();
        return await BuildMessageDtosAsync(messages, cancellationToken);
    }

    public async Task<ChatMessageDto> SendMessageAsync(
        Guid chatId,
        string userId,
        SendChatMessageRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var chat = await dbContext.Chats.FirstOrDefaultAsync(entry => entry.Id == chatId, cancellationToken)
            ?? throw new KeyNotFoundException("Chat was not found.");

        var participants = await dbContext.ChatParticipants
            .Where(entry => entry.ChatId == chatId)
            .ToListAsync(cancellationToken);

        if (!participants.Any(entry => entry.UserId == userId))
        {
            throw new InvalidOperationException("You are not a participant in this chat.");
        }
        if (await HasBlockedParticipantAsync(userId, participants, cancellationToken))
        {
            throw new InvalidOperationException("This conversation is blocked.");
        }

        var type = ParseMessageType(request.Type);
        var trimmedText = request.Text.Trim();
        var hasPayload =
            !string.IsNullOrWhiteSpace(trimmedText)
            || !string.IsNullOrWhiteSpace(request.PhotoUrl)
            || !string.IsNullOrWhiteSpace(request.VideoUrl)
            || request.Latitude.HasValue
            || request.Longitude.HasValue
            || request.SharedPostId.HasValue;

        if (!hasPayload)
        {
            throw new InvalidOperationException("A message must contain text or media.");
        }

        var now = DateTimeOffset.UtcNow;
        var message = new ChatMessage
        {
            ChatId = chatId,
            SenderId = userId,
            Text = trimmedText,
            Type = type,
            Status = ChatMessageStatus.Sent,
            CreatedAt = now,
            PhotoUrl = string.IsNullOrWhiteSpace(request.PhotoUrl) ? null : request.PhotoUrl.Trim(),
            VideoUrl = string.IsNullOrWhiteSpace(request.VideoUrl) ? null : request.VideoUrl.Trim(),
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            PhotoApproved = request.PhotoApproved,
            Reaction = string.IsNullOrWhiteSpace(request.Reaction) ? null : request.Reaction.Trim(),
            DisappearSeconds = request.DisappearSeconds,
            SharedPostId = request.SharedPostId,
            SharedPostAuthor = string.IsNullOrWhiteSpace(request.SharedPostAuthor) ? null : request.SharedPostAuthor.Trim(),
            SharedPostLocation = string.IsNullOrWhiteSpace(request.SharedPostLocation) ? null : request.SharedPostLocation.Trim(),
            SharedPostVibe = string.IsNullOrWhiteSpace(request.SharedPostVibe) ? null : request.SharedPostVibe.Trim(),
            SharedPostMediaUrl = string.IsNullOrWhiteSpace(request.SharedPostMediaUrl) ? null : request.SharedPostMediaUrl.Trim(),
        };

        dbContext.ChatMessages.Add(message);

        chat.LastMessage = BuildPreviewText(type, trimmedText);
        chat.LastSenderId = userId;
        chat.LastMessageTime = now;

        foreach (var participant in participants)
        {
            if (participant.UserId == userId)
            {
                participant.UnreadCount = 0;
                participant.IsTyping = false;
                participant.IsArchived = false;
                participant.ArchivedAt = null;
                participant.DeletedAt = null;
                participant.LastReadAt = now;
                continue;
            }

            participant.UnreadCount += 1;
            participant.IsArchived = false;
            participant.ArchivedAt = null;
            participant.DeletedAt = null;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        var dto = (await BuildMessageDtosAsync([message], cancellationToken)).Single();
        await realtimeNotifier.NotifyChatUpdatedAsync(
            chatId,
            participants.Select(entry => entry.UserId).Distinct().ToList(),
            dto,
            cancellationToken
        );
        // Push notification to other participants
        var sender = await dbContext.Users.AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
        var senderName = sender?.DisplayName ?? "Birisi";
        var preview = chat.LastMessage ?? "Yeni mesaj";
        var otherParticipantIds = participants
            .Where(p => p.UserId != userId)
            .Select(p => p.UserId)
            .ToList();
        _ = pushNotificationService.SendToUsersAsync(
            otherParticipantIds,
            senderName,
            preview,
            new Dictionary<string, string>
            {
                ["type"] = "new_message",
                ["chatId"] = chatId.ToString(),
                ["senderId"] = userId,
            },
            cancellationToken
        );
        return dto;
    }

    public async Task<bool> UpdateMessageStatusAsync(
        Guid chatId,
        Guid messageId,
        string userId,
        UpdateChatMessageStatusRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var isParticipant = await IsParticipantAsync(chatId, userId, cancellationToken);
        if (!isParticipant)
        {
            return false;
        }
        if (await IsChatBlockedForUserAsync(chatId, userId, cancellationToken))
        {
            return false;
        }

        var message = await dbContext.ChatMessages
            .FirstOrDefaultAsync(entry => entry.Id == messageId && entry.ChatId == chatId, cancellationToken);
        if (message is null)
        {
            return false;
        }

        message.Status = ParseMessageStatus(request.Status);
        await dbContext.SaveChangesAsync(cancellationToken);
        await NotifyChatParticipantsAsync(chatId, cancellationToken);
        return true;
    }

    public async Task<bool> UpdateReactionAsync(
        Guid chatId,
        Guid messageId,
        string userId,
        UpdateChatReactionRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var isParticipant = await IsParticipantAsync(chatId, userId, cancellationToken);
        if (!isParticipant)
        {
            return false;
        }
        if (await IsChatBlockedForUserAsync(chatId, userId, cancellationToken))
        {
            return false;
        }

        var message = await dbContext.ChatMessages
            .FirstOrDefaultAsync(entry => entry.Id == messageId && entry.ChatId == chatId, cancellationToken);
        if (message is null)
        {
            return false;
        }

        message.Reaction = string.IsNullOrWhiteSpace(request.Reaction) ? null : request.Reaction.Trim();
        await dbContext.SaveChangesAsync(cancellationToken);
        await NotifyChatParticipantsAsync(chatId, cancellationToken);
        return true;
    }

    public async Task<bool> DeleteMessageAsync(
        Guid chatId,
        Guid messageId,
        string userId,
        string scope,
        CancellationToken cancellationToken = default
    )
    {
        var isParticipant = await IsParticipantAsync(chatId, userId, cancellationToken);
        if (!isParticipant || await IsChatBlockedForUserAsync(chatId, userId, cancellationToken))
        {
            return false;
        }

        var normalizedScope = string.Equals(scope, "everyone", StringComparison.OrdinalIgnoreCase)
            ? "everyone"
            : string.Equals(scope, "me", StringComparison.OrdinalIgnoreCase)
                ? "me"
                : string.Empty;
        if (string.IsNullOrWhiteSpace(normalizedScope))
        {
            return false;
        }

        var message = await dbContext.ChatMessages
            .FirstOrDefaultAsync(entry => entry.Id == messageId && entry.ChatId == chatId, cancellationToken);
        if (message is null)
        {
            return false;
        }

        if (normalizedScope == "me")
        {
            var participant = await dbContext.ChatParticipants
                .FirstOrDefaultAsync(
                    entry => entry.ChatId == chatId && entry.UserId == userId,
                    cancellationToken
                );
            if (participant is null)
            {
                return false;
            }

            var existingHiddenState = await dbContext.ChatMessageHiddenStates
                .FirstOrDefaultAsync(
                    entry => entry.MessageId == messageId && entry.UserId == userId,
                    cancellationToken
                );
            if (existingHiddenState is null)
            {
                dbContext.ChatMessageHiddenStates.Add(
                    new ChatMessageHiddenState
                    {
                        MessageId = messageId,
                        UserId = userId,
                        HiddenAt = DateTimeOffset.UtcNow,
                    }
                );
            }

            await dbContext.SaveChangesAsync(cancellationToken);
            await NotifyChatParticipantsAsync(chatId, cancellationToken);
            return true;
        }

        if (!string.Equals(message.SenderId, userId, StringComparison.Ordinal) || message.DeletedAt.HasValue)
        {
            return false;
        }

        message.DeletedAt = DateTimeOffset.UtcNow;
        message.DeletedByUserId = userId;
        message.UpdatedAt = message.DeletedAt;
        message.Text = string.Empty;
        message.PhotoUrl = null;
        message.VideoUrl = null;
        message.Latitude = null;
        message.Longitude = null;
        message.PhotoApproved = null;
        message.Reaction = null;
        message.SharedPostAuthor = null;
        message.SharedPostLocation = null;
        message.SharedPostVibe = null;
        message.SharedPostMediaUrl = null;
        message.SharedPostId = null;
        message.DisappearSeconds = null;
        message.Type = ChatMessageType.Text;

        var chat = await dbContext.Chats.FirstOrDefaultAsync(entry => entry.Id == chatId, cancellationToken);
        if (chat is not null && chat.LastMessageTime == message.CreatedAt && string.Equals(chat.LastSenderId, userId, StringComparison.Ordinal))
        {
            chat.LastMessage = "Message unsent";
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await NotifyChatParticipantsAsync(chatId, cancellationToken);
        return true;
    }

    public async Task<bool> SetTypingAsync(
        Guid chatId,
        string userId,
        SetTypingRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var participant = await dbContext.ChatParticipants
            .FirstOrDefaultAsync(entry => entry.ChatId == chatId && entry.UserId == userId, cancellationToken);
        if (participant is null)
        {
            return false;
        }
        if (await IsChatBlockedForUserAsync(chatId, userId, cancellationToken))
        {
            return false;
        }

        participant.IsTyping = request.IsTyping;
        await dbContext.SaveChangesAsync(cancellationToken);
        var participantIds = await GetChatParticipantIdsAsync(chatId, cancellationToken);
        await realtimeNotifier.NotifyTypingChangedAsync(
            chatId,
            participantIds,
            userId,
            request.IsTyping,
            cancellationToken
        );
        return true;
    }

    public async Task<bool> MarkAsReadAsync(
        Guid chatId,
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var participant = await dbContext.ChatParticipants
            .FirstOrDefaultAsync(entry => entry.ChatId == chatId && entry.UserId == userId, cancellationToken);
        if (participant is null)
        {
            return false;
        }
        if (await IsChatBlockedForUserAsync(chatId, userId, cancellationToken))
        {
            return false;
        }

        var now = DateTimeOffset.UtcNow;
        participant.UnreadCount = 0;
        participant.LastReadAt = now;
        participant.IsTyping = false;

        var unreadMessages = await dbContext.ChatMessages
            .Where(entry =>
                entry.ChatId == chatId
                && entry.SenderId != userId
                && entry.Status != ChatMessageStatus.Read)
            .ToListAsync(cancellationToken);

        foreach (var message in unreadMessages)
        {
            message.Status = ChatMessageStatus.Read;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await NotifyChatParticipantsAsync(chatId, cancellationToken);
        await realtimeNotifier.NotifyTypingChangedAsync(
            chatId,
            await GetChatParticipantIdsAsync(chatId, cancellationToken),
            userId,
            false,
            cancellationToken
        );
        return true;
    }

    public async Task<bool> ConvertToFriendChatAsync(
        Guid chatId,
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var chat = await dbContext.Chats.FirstOrDefaultAsync(entry => entry.Id == chatId, cancellationToken);
        if (chat is null || !await IsParticipantAsync(chatId, userId, cancellationToken))
        {
            return false;
        }
        if (await IsChatBlockedForUserAsync(chatId, userId, cancellationToken))
        {
            return false;
        }

        chat.IsTemporary = false;
        chat.IsFriendChat = true;
        chat.ExpiresAt = null;
        await dbContext.SaveChangesAsync(cancellationToken);
        await NotifyChatParticipantsAsync(chatId, cancellationToken);
        return true;
    }

    public async Task<string> RequestChatPermanenceAsync(
        Guid chatId,
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var chat = await dbContext.Chats.FirstOrDefaultAsync(entry => entry.Id == chatId, cancellationToken);
        if (chat is null || !await IsParticipantAsync(chatId, userId, cancellationToken))
        {
            return "not_found";
        }
        if (!chat.IsTemporary)
        {
            return "already_permanent";
        }

        var participantIds = await GetChatParticipantIdsAsync(chatId, cancellationToken);
        var otherUserId = participantIds.FirstOrDefault(id => id != userId);

        // If the other participant already requested permanence → both agree, make it permanent
        if (chat.PendingFriendRequestFromUserId == otherUserId && otherUserId is not null)
        {
            chat.IsTemporary = false;
            chat.IsFriendChat = true;
            chat.ExpiresAt = null;
            chat.PendingFriendRequestFromUserId = null;
            await dbContext.SaveChangesAsync(cancellationToken);
            await NotifyChatParticipantsAsync(chatId, cancellationToken);
            return "accepted";
        }

        // Record this user's request
        chat.PendingFriendRequestFromUserId = userId;
        await dbContext.SaveChangesAsync(cancellationToken);
        // Notify the other participant so they see the pending banner
        await NotifyChatParticipantsAsync(chatId, cancellationToken);
        if (otherUserId is not null)
        {
            var requester = await dbContext.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
            var requesterName = requester?.DisplayName ?? "Birisi";
            _ = pushNotificationService.SendToUserAsync(
                otherUserId,
                requesterName,
                "seni arkadaş olarak eklemek istiyor! 🤝",
                new Dictionary<string, string> { ["type"] = "chat_permanence_request", ["chatId"] = chatId.ToString() },
                cancellationToken
            );
        }
        return "pending";
    }

    public async Task<bool> DeleteChatAsync(
        Guid chatId,
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var participant = await dbContext.ChatParticipants
            .FirstOrDefaultAsync(
                entry => entry.ChatId == chatId && entry.UserId == userId,
                cancellationToken
            );
        if (participant is null)
        {
            return false;
        }
        if (await IsChatBlockedForUserAsync(chatId, userId, cancellationToken))
        {
            return false;
        }

        participant.IsArchived = true;
        participant.ArchivedAt = DateTimeOffset.UtcNow;
        participant.DeletedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        await realtimeNotifier.NotifyChatUpdatedAsync(
            chatId,
            await GetChatParticipantIdsAsync(chatId, cancellationToken),
            cancellationToken: cancellationToken
        );
        return true;
    }

    public async Task<bool> SetArchivedAsync(
        Guid chatId,
        string userId,
        bool isArchived,
        CancellationToken cancellationToken = default
    )
    {
        var participant = await dbContext.ChatParticipants
            .FirstOrDefaultAsync(
                entry => entry.ChatId == chatId && entry.UserId == userId,
                cancellationToken
            );
        if (participant is null)
        {
            return false;
        }
        if (await IsChatBlockedForUserAsync(chatId, userId, cancellationToken))
        {
            return false;
        }

        participant.IsArchived = isArchived;
        participant.ArchivedAt = isArchived ? DateTimeOffset.UtcNow : null;
        await dbContext.SaveChangesAsync(cancellationToken);
        await realtimeNotifier.NotifyChatUpdatedAsync(
            chatId,
            await GetChatParticipantIdsAsync(chatId, cancellationToken),
            cancellationToken: cancellationToken
        );
        return true;
    }

    private async Task NotifyChatParticipantsAsync(Guid chatId, CancellationToken cancellationToken)
    {
        await realtimeNotifier.NotifyChatUpdatedAsync(
            chatId,
            await GetChatParticipantIdsAsync(chatId, cancellationToken),
            cancellationToken: cancellationToken
        );
    }

    private async Task<IReadOnlyCollection<string>> GetChatParticipantIdsAsync(
        Guid chatId,
        CancellationToken cancellationToken
    ) => await dbContext.ChatParticipants.AsNoTracking()
        .Where(entry => entry.ChatId == chatId)
        .Select(entry => entry.UserId)
        .Distinct()
        .ToListAsync(cancellationToken);

    private ChatThreadDto BuildChatDto(
        ChatThread chat,
        IReadOnlyList<ChatParticipant> participants,
        IReadOnlyDictionary<string, UserProfile> users,
        bool currentUserIsArchived
    )
    {
        var dtoParticipants = participants
            .Where(entry => users.ContainsKey(entry.UserId))
            .Select(entry =>
            {
                var user = users[entry.UserId];
                return new ChatParticipantDto(
                    user.Id,
                    user.UserName,
                    user.DisplayName,
                    user.ProfilePhotoUrl,
                    user.Mode,
                    user.PrivacyLevel,
                    user.IsVisible,
                    user.IsOnline,
                    entry.UnreadCount,
                    entry.IsTyping,
                    entry.JoinedAt,
                    entry.LastReadAt
                );
            })
            .ToList();

        return new ChatThreadDto(
            chat.Id,
            chat.CreatedByUserId,
            chat.DirectMessageKey,
            currentUserIsArchived,
            chat.LastSenderId,
            chat.LastMessage,
            chat.LastMessageTime,
            chat.CreatedAt,
            chat.ExpiresAt,
            chat.IsTemporary,
            chat.IsFriendChat,
            dtoParticipants,
            chat.PendingFriendRequestFromUserId,
            string.IsNullOrWhiteSpace(chat.Kind) ? "direct" : chat.Kind,
            chat.ActivityId,
            chat.Title ?? string.Empty
        );
    }

    private async Task<ChatThreadDto> BuildChatDtoAsync(
        ChatThread chat,
        string currentUserId,
        CancellationToken cancellationToken
    )
    {
        var participants = await dbContext.ChatParticipants.AsNoTracking()
            .Where(entry => entry.ChatId == chat.Id)
            .OrderBy(entry => entry.JoinedAt)
            .ToListAsync(cancellationToken);

        var userIds = participants.Select(entry => entry.UserId).Distinct().ToList();
        var users = await dbContext.Users.AsNoTracking()
            .Where(entry => userIds.Contains(entry.Id))
            .ToDictionaryAsync(entry => entry.Id, cancellationToken);
        var currentUserArchived = participants
            .FirstOrDefault(entry => entry.UserId == currentUserId)
            ?.IsArchived ?? false;

        return BuildChatDto(chat, participants, users, currentUserArchived);
    }

    private Task<HashSet<string>> GetBlockedUserIdsAsync(
        string userId,
        CancellationToken cancellationToken
    ) => BlockedUsersHelper.GetBlockedUserIdsAsync(dbContext, userId, cancellationToken);

    private async Task<bool> HasBlockedParticipantAsync(
        string userId,
        IReadOnlyList<ChatParticipant> participants,
        CancellationToken cancellationToken
    )
    {
        var blockedUserIds = await GetBlockedUserIdsAsync(userId, cancellationToken);
        return participants.Any(entry => entry.UserId != userId && blockedUserIds.Contains(entry.UserId));
    }

    private async Task<bool> IsChatBlockedForUserAsync(
        Guid chatId,
        string userId,
        CancellationToken cancellationToken
    )
    {
        var participants = await dbContext.ChatParticipants.AsNoTracking()
            .Where(entry => entry.ChatId == chatId)
            .ToListAsync(cancellationToken);

        return participants.Count == 0 || await HasBlockedParticipantAsync(userId, participants, cancellationToken);
    }

    private async Task<IReadOnlyList<ChatMessageDto>> BuildMessageDtosAsync(
        IReadOnlyList<ChatMessage> messages,
        CancellationToken cancellationToken
    )
    {
        if (messages.Count == 0)
        {
            return [];
        }

        var senderIds = messages.Select(entry => entry.SenderId).Distinct().ToList();
        var senders = await dbContext.Users.AsNoTracking()
            .Where(entry => senderIds.Contains(entry.Id))
            .ToDictionaryAsync(entry => entry.Id, cancellationToken);

        return messages
            .Where(entry => senders.ContainsKey(entry.SenderId))
            .Select(entry =>
            {
                var sender = senders[entry.SenderId];
                var deletedForEveryone = entry.DeletedAt.HasValue;
                return new ChatMessageDto(
                    entry.Id,
                    entry.ChatId,
                    entry.SenderId,
                    sender.DisplayName,
                    sender.ProfilePhotoUrl,
                    deletedForEveryone ? "This message was unsent." : entry.Text,
                    entry.Type.ToString().ToLowerInvariant(),
                    entry.Status.ToString().ToLowerInvariant(),
                    entry.CreatedAt,
                    entry.UpdatedAt,
                    entry.DeletedAt,
                    deletedForEveryone,
                    deletedForEveryone ? null : entry.PhotoUrl,
                    deletedForEveryone ? null : entry.VideoUrl,
                    deletedForEveryone ? null : entry.Latitude,
                    deletedForEveryone ? null : entry.Longitude,
                    deletedForEveryone ? null : entry.PhotoApproved,
                    deletedForEveryone ? null : entry.Reaction,
                    deletedForEveryone ? null : entry.DisappearSeconds,
                    deletedForEveryone ? null : entry.SharedPostId,
                    deletedForEveryone ? null : entry.SharedPostAuthor,
                    deletedForEveryone ? null : entry.SharedPostLocation,
                    deletedForEveryone ? null : entry.SharedPostVibe,
                    deletedForEveryone ? null : entry.SharedPostMediaUrl
                );
            })
            .ToList();
    }

    private async Task EnsureUsersExistAsync(
        string userId,
        string otherUserId,
        CancellationToken cancellationToken
    )
    {
        var knownUsers = await dbContext.Users.AsNoTracking()
            .Where(entry => entry.Id == userId || entry.Id == otherUserId)
            .Select(entry => entry.Id)
            .ToListAsync(cancellationToken);

        if (!knownUsers.Contains(userId) || !knownUsers.Contains(otherUserId))
        {
            throw new KeyNotFoundException("One or more users were not found.");
        }
    }

    private async Task EnsureUsersNotBlockedAsync(
        string userId,
        string otherUserId,
        CancellationToken cancellationToken
    )
    {
        var isBlocked = await dbContext.BlockedUsers.AsNoTracking().AnyAsync(
            entry =>
                (entry.UserId == userId && entry.BlockedUserId == otherUserId)
                || (entry.UserId == otherUserId && entry.BlockedUserId == userId),
            cancellationToken
        );

        if (isBlocked)
        {
            throw new InvalidOperationException("This conversation is blocked.");
        }
    }

    private Task<bool> IsParticipantAsync(
        Guid chatId,
        string userId,
        CancellationToken cancellationToken
    ) => dbContext.ChatParticipants.AsNoTracking().AnyAsync(
        entry => entry.ChatId == chatId && entry.UserId == userId,
        cancellationToken
    );

    private static string BuildDirectKey(string firstUserId, string secondUserId)
    {
        var ordered = new[] { firstUserId, secondUserId }.OrderBy(entry => entry, StringComparer.Ordinal).ToArray();
        return string.Join(":", ordered);
    }

    private static string BuildPreviewText(ChatMessageType type, string text) =>
        !string.IsNullOrWhiteSpace(text)
            ? text
            : type switch
            {
                ChatMessageType.Photo => "Fotoğraf gönderildi",
                ChatMessageType.Video => "Video gönderildi",
                ChatMessageType.Location => "Konum paylaşıldı",
                ChatMessageType.PostShare => "Gönderi paylaşıldı",
                ChatMessageType.Disappearing => "Kaybolan mesaj gönderildi",
                ChatMessageType.PhotoRequest => "Fotoğraf isteği gönderildi",
                ChatMessageType.System => "Sistem mesajı",
                _ => "Mesaj gönderildi",
            };

    private static ChatMessageType ParseMessageType(string? value) =>
        value?.Trim().ToLowerInvariant() switch
        {
            "photo" => ChatMessageType.Photo,
            "video" => ChatMessageType.Video,
            "location" => ChatMessageType.Location,
            "postshare" => ChatMessageType.PostShare,
            "post_share" => ChatMessageType.PostShare,
            "disappearing" => ChatMessageType.Disappearing,
            "photorequest" => ChatMessageType.PhotoRequest,
            "photo_request" => ChatMessageType.PhotoRequest,
            "system" => ChatMessageType.System,
            _ => ChatMessageType.Text,
        };

    private static ChatMessageStatus ParseMessageStatus(string? value) =>
        value?.Trim().ToLowerInvariant() switch
        {
            "delivered" => ChatMessageStatus.Delivered,
            "read" => ChatMessageStatus.Read,
            _ => ChatMessageStatus.Sent,
        };
}
