using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Domain.Entities;
using PulseCity.Domain.Enums;
using PulseCity.Infrastructure.Data;
using PulseCity.Infrastructure.Options;
using PulseCity.Infrastructure.Services;

namespace PulseCity.Backend.Tests;

public sealed class AuthAndStoriesTests
{
    [Fact]
    public async Task RequestPasswordReset_CreatesToken_AndAllowsPasswordUpdate()
    {
        await using var dbContext = CreateDbContext();
        var emailSender = new FakeEmailSender();
        var authService = CreateAuthService(dbContext, emailSender);

        var user = SeedUser(dbContext, "owner@pulsecity.test");
        await dbContext.SaveChangesAsync();

        var response = await authService.RequestPasswordResetAsync(
            new ForgotPasswordRequest { Email = user.Email },
            requesterIp: "127.0.0.1",
            userAgent: "xunit",
            CancellationToken.None
        );

        Assert.True(response.Sent);
        var token = await dbContext.PasswordResetTokens.SingleAsync();
        Assert.Equal(user.Id, token.UserId);
        Assert.Single(emailSender.Messages);

        var code = ParseResetCode(emailSender.Messages.Single().TextBody);
        await authService.ResetPasswordAsync(
            new ResetPasswordRequest
            {
                Email = user.Email,
                Code = code,
                NewPassword = "NewPass123!"
            },
            CancellationToken.None
        );

        var login = await authService.LoginAsync(
            new LoginRequest
            {
                Email = user.Email,
                Password = "NewPass123!"
            },
            CancellationToken.None
        );

        Assert.Equal(user.Id, login.User.Id);
        Assert.NotNull(await dbContext.PasswordResetTokens.SingleAsync());
        Assert.NotNull((await dbContext.PasswordResetTokens.SingleAsync()).UsedAt);
    }

    [Fact]
    public async Task RecordStoryView_TracksSeenState_AndOwnerViewers()
    {
        await using var dbContext = CreateDbContext();
        var notifier = new NoopRealtimeNotifier();
        var service = new HighlightsService(dbContext, notifier, new NoopFileStorageService());

        var owner = SeedUser(dbContext, "owner@pulsecity.test", "owner");
        var viewer = SeedUser(dbContext, "viewer@pulsecity.test", "viewer");
        await dbContext.SaveChangesAsync();

        var story = await service.CreateStoryAsync(
            owner.Id,
            new CreateHighlightRequest
            {
                Title = "Story",
                CoverUrl = "/uploads/story.jpg",
                MediaUrls = ["/uploads/story.jpg"],
                Type = "image",
                DurationHours = 24
            },
            CancellationToken.None
        );

        await service.RecordStoryViewAsync(story.Id, viewer.Id, CancellationToken.None);

        var ownerStories = await service.GetActiveStoriesByUserAsync(
            owner.Id,
            owner.Id,
            CancellationToken.None
        );
        var viewerStories = await service.GetActiveStoriesByUserAsync(
            owner.Id,
            viewer.Id,
            CancellationToken.None
        );

        var ownerStory = Assert.Single(ownerStories);
        Assert.Equal(1, ownerStory.ViewCount);
        Assert.Single(ownerStory.Viewers);
        Assert.Equal(viewer.Id, ownerStory.Viewers[0].UserId);

        var viewerStory = Assert.Single(viewerStories);
        Assert.True(viewerStory.SeenByCurrentUser);
        Assert.Empty(viewerStory.Viewers);
    }

    [Fact]
    public async Task SearchUsersAsync_PrefersPrefixMatches_OverContainsMatches()
    {
        await using var dbContext = CreateDbContext();
        SeedUser(dbContext, "alex@pulsecity.test", "alex");
        SeedUser(dbContext, "calex@pulsecity.test", "calex");
        SeedUser(dbContext, "berlin@pulsecity.test", "berlinalex");
        await dbContext.SaveChangesAsync();

        var service = CreateUsersService(dbContext);
        var results = await service.SearchUsersAsync("alex", excludeUserId: null, CancellationToken.None);

        Assert.Equal(3, results.Count);
        Assert.Equal("alex", results[0].UserName);
        Assert.Contains(results.Skip(1), entry => entry.UserName == "calex");
        Assert.Contains(results.Skip(1), entry => entry.UserName == "berlinalex");
    }

    [Fact]
    public async Task Comments_CanBePaginated_Updated_AndDeleted()
    {
        await using var dbContext = CreateDbContext();
        var notifier = new SpyRealtimeNotifier();
        var service = new PostsService(dbContext, notifier, new NoopFileStorageService(), new NoopPushNotificationService());

        var owner = SeedUser(dbContext, "owner@pulsecity.test", "owner");
        var commenter = SeedUser(dbContext, "commenter@pulsecity.test", "commenter");
        var post = new Post
        {
            UserId = owner.Id,
            Text = "hello",
            Type = PulseCity.Domain.Enums.PostType.Post,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        };
        dbContext.Posts.Add(post);
        await dbContext.SaveChangesAsync();

        await service.AddCommentAsync(
            post.Id,
            commenter.Id,
            new AddPostCommentRequest { Text = "first" },
            CancellationToken.None
        );
        var second = await service.AddCommentAsync(
            post.Id,
            commenter.Id,
            new AddPostCommentRequest { Text = "second" },
            CancellationToken.None
        );

        var paged = await service.GetCommentsAsync(
            post.Id,
            commenter.Id,
            skip: 1,
            take: 1,
            CancellationToken.None
        );

        Assert.Single(paged);
        Assert.Equal("second", paged[0].Text);

        var updated = await service.UpdateCommentAsync(
            post.Id,
            second.Id,
            commenter.Id,
            new UpdatePostCommentRequest { Text = "updated" },
            CancellationToken.None
        );

        Assert.NotNull(updated);
        Assert.Equal("updated", updated!.Text);

        var deleted = await service.DeleteCommentAsync(
            post.Id,
            second.Id,
            commenter.Id,
            CancellationToken.None
        );

        Assert.True(deleted);
        Assert.Equal(4, notifier.FeedChangedCount);
        Assert.Equal(1, (await dbContext.Posts.SingleAsync()).CommentsCount);
    }

    [Fact]
    public async Task Chats_CanBeArchived_PerUser_WithoutBreakingDirectAccess()
    {
        await using var dbContext = CreateDbContext();
        var service = new ChatsService(dbContext, new NoopRealtimeNotifier(), new NoopPushNotificationService());

        var owner = SeedUser(dbContext, "owner@pulsecity.test", "owner");
        var peer = SeedUser(dbContext, "peer@pulsecity.test", "peer");
        await dbContext.SaveChangesAsync();

        var chat = await service.CreateOrGetDirectChatAsync(
            owner.Id,
            new CreateDirectChatRequest
            {
                OtherUserId = peer.Id,
                IsTemporary = false,
            },
            CancellationToken.None
        );

        var archived = await service.SetArchivedAsync(chat.Id, owner.Id, true, CancellationToken.None);
        Assert.True(archived);

        var visibleChats = await service.GetChatsAsync(owner.Id, cancellationToken: CancellationToken.None);
        Assert.Empty(visibleChats);

        var archivedChats = await service.GetChatsAsync(
            owner.Id,
            includeArchived: true,
            cancellationToken: CancellationToken.None
        );
        var archivedChat = Assert.Single(archivedChats);
        Assert.True(archivedChat.CurrentUserIsArchived);

        var directAccess = await service.GetChatAsync(chat.Id, owner.Id, CancellationToken.None);
        Assert.NotNull(directAccess);
        Assert.True(directAccess!.CurrentUserIsArchived);
    }

    private static PulseCityDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<PulseCityDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        return new PulseCityDbContext(options);
    }

    private static AuthService CreateAuthService(
        PulseCityDbContext dbContext,
        FakeEmailSender emailSender
    )
    {
        var jwtOptions = Options.Create(new JwtOptions
        {
            Issuer = "PulseCity.Api",
            Audience = "PulseCity.Mobile",
            SigningKey = "ThisIsATemporaryButLongEnoughSigningKey123!"
        });
        var smtpOptions = Options.Create(new SmtpOptions
        {
            Host = "smtp.example.com",
            UserName = "tester",
            Password = "secret",
            SenderEmail = "noreply@pulsecity.test",
            SenderName = "PulseCity",
            PasswordResetBaseUrl = "pulsecity://reset-password"
        });

        return new AuthService(
            dbContext,
            new JwtTokenService(jwtOptions),
            emailSender,
            smtpOptions
        );
    }

    private static UsersService CreateUsersService(PulseCityDbContext dbContext)
    {
        var hostEnvironment = new FakeHostEnvironment();
        var storageOptions = Options.Create(new StorageOptions());
        var privacyOptions = Options.Create(new PrivacyOptions());
        var jwtOptions = Options.Create(new JwtOptions
        {
            Issuer = "PulseCity.Api",
            Audience = "PulseCity.Mobile",
            SigningKey = "ThisIsATemporaryButLongEnoughSigningKey123!"
        });

        return new UsersService(
            dbContext,
            hostEnvironment,
            storageOptions,
            privacyOptions,
            jwtOptions,
            new NoopRealtimeNotifier(),
            new NoopNotificationsService(),
            new NoopBadgesService()
        );
    }

    private static UserProfile SeedUser(
        PulseCityDbContext dbContext,
        string email,
        string? username = null
    )
    {
        var userId = Guid.NewGuid().ToString("N");
        var profile = new UserProfile
        {
            Id = userId,
            Email = email,
            UserName = username ?? email.Split('@')[0],
            NormalizedUserName = (username ?? email.Split('@')[0]).ToLowerInvariant(),
            DisplayName = username ?? email.Split('@')[0],
            NormalizedDisplayName = (username ?? email.Split('@')[0]).ToLowerInvariant(),
            Mode = "kesif",
            PrivacyLevel = "full",
            IsVisible = true,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        };

        var credential = new UserCredential
        {
            UserId = userId,
            Email = email,
            HasPassword = true,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
        };
        credential.PasswordHash = new PasswordHasher<UserCredential>()
            .HashPassword(credential, "OldPass123!");

        dbContext.Users.Add(profile);
        dbContext.UserCredentials.Add(credential);
        return profile;
    }

    private static string ParseResetCode(string textBody)
    {
        var match = Regex.Match(textBody, @"Code:\s*(\S+)", RegexOptions.IgnoreCase);
        Assert.True(match.Success);
        return match.Groups[1].Value.Trim();
    }

    private sealed class FakeEmailSender : IEmailSender
    {
        public List<(string Subject, string HtmlBody, string TextBody)> Messages { get; } = [];

        public Task SendAsync(
            string toEmail,
            string toName,
            string subject,
            string htmlBody,
            string textBody,
            CancellationToken cancellationToken = default
        )
        {
            Messages.Add((subject, htmlBody, textBody));
            return Task.CompletedTask;
        }
    }

    private sealed class NoopRealtimeNotifier : IRealtimeNotifier
    {
        public Task NotifyPresenceChangedAsync(string city, string userId, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyProfileChangedAsync(string userId, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyFriendRequestsChangedAsync(IReadOnlyCollection<string> userIds, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyRelationshipChangedAsync(IReadOnlyCollection<string> userIds, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyMatchesChangedAsync(IReadOnlyCollection<string> userIds, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyTypingChangedAsync(Guid chatId, IReadOnlyCollection<string> participantIds, string userId, bool isTyping, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyChatUpdatedAsync(Guid chatId, IReadOnlyCollection<string> participantIds, ChatMessageDto? message = null, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyFeedChangedAsync(Guid? postId, string? authorUserId, string? placeId, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyNotificationCreatedAsync(string recipientUserId, NotificationDto notification, int unreadCount, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyNotificationsChangedAsync(string recipientUserId, int unreadCount, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyActivityChangedAsync(Guid activityId, IReadOnlyCollection<string> userIds, string changeKind, CancellationToken cancellationToken = default) => Task.CompletedTask;
    }

    private sealed class SpyRealtimeNotifier : IRealtimeNotifier
    {
        public int FeedChangedCount { get; private set; }

        public Task NotifyPresenceChangedAsync(string city, string userId, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyProfileChangedAsync(string userId, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyFriendRequestsChangedAsync(IReadOnlyCollection<string> userIds, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyRelationshipChangedAsync(IReadOnlyCollection<string> userIds, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyMatchesChangedAsync(IReadOnlyCollection<string> userIds, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyTypingChangedAsync(Guid chatId, IReadOnlyCollection<string> participantIds, string userId, bool isTyping, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyChatUpdatedAsync(Guid chatId, IReadOnlyCollection<string> participantIds, ChatMessageDto? message = null, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyNotificationCreatedAsync(string recipientUserId, NotificationDto notification, int unreadCount, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyNotificationsChangedAsync(string recipientUserId, int unreadCount, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task NotifyActivityChangedAsync(Guid activityId, IReadOnlyCollection<string> userIds, string changeKind, CancellationToken cancellationToken = default) => Task.CompletedTask;

        public Task NotifyFeedChangedAsync(Guid? postId, string? authorUserId, string? placeId, CancellationToken cancellationToken = default)
        {
            FeedChangedCount++;
            return Task.CompletedTask;
        }
    }

    private sealed class FakeHostEnvironment : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "Development";
        public string ApplicationName { get; set; } = "PulseCity.Tests";
        public string ContentRootPath { get; set; } = Path.GetTempPath();
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }

    private sealed class NoopPushNotificationService : IPushNotificationService
    {
        public Task SendToUserAsync(string userId, string title, string body, Dictionary<string, string>? data = null, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task SendToUsersAsync(IEnumerable<string> userIds, string title, string body, Dictionary<string, string>? data = null, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task RegisterTokenAsync(string userId, string token, string platform, CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task UnregisterTokenAsync(string userId, string token, CancellationToken cancellationToken = default) => Task.CompletedTask;
    }

    private sealed class NoopFileStorageService : IFileStorageService
    {
        public Task<string> SaveAsync(Stream stream, string fileName, string? contentType, CancellationToken cancellationToken = default) => Task.FromResult($"/uploads/{fileName}");
        public Task DeleteAsync(string urlOrRelativePath, CancellationToken cancellationToken = default) => Task.CompletedTask;
    }

    private sealed class NoopNotificationsService : INotificationsService
    {
        public Task<NotificationDto> CreateAsync(
            string recipientUserId,
            NotificationType type,
            string title,
            string body,
            string? actorUserId = null,
            string? deepLink = null,
            string? relatedEntityType = null,
            string? relatedEntityId = null,
            Dictionary<string, string>? pushData = null,
            bool sendPush = true,
            CancellationToken cancellationToken = default
        ) => Task.FromResult(new NotificationDto(
            Guid.NewGuid(),
            type.ToString(),
            title,
            body,
            deepLink,
            relatedEntityType,
            relatedEntityId,
            null,
            false,
            null,
            DateTimeOffset.UtcNow
        ));

        public Task<NotificationListResponseDto> ListAsync(string userId, NotificationListQuery query, CancellationToken cancellationToken = default)
            => Task.FromResult(new NotificationListResponseDto(Array.Empty<NotificationDto>(), 0, false));

        public Task<UnreadCountDto> GetUnreadCountAsync(string userId, CancellationToken cancellationToken = default)
            => Task.FromResult(new UnreadCountDto(0));

        public Task<bool> MarkReadAsync(Guid notificationId, string userId, CancellationToken cancellationToken = default)
            => Task.FromResult(true);

        public Task<int> MarkAllReadAsync(string userId, CancellationToken cancellationToken = default)
            => Task.FromResult(0);

        public Task<bool> DeleteAsync(Guid notificationId, string userId, CancellationToken cancellationToken = default)
            => Task.FromResult(true);
    }

    private sealed class NoopBadgesService : IBadgesService
    {
        public BadgeCatalogResponseDto GetCatalog()
            => new(Array.Empty<BadgeDefinitionDto>());

        public Task<UserBadgesResponseDto> GetForUserAsync(string userId, CancellationToken cancellationToken = default)
            => Task.FromResult(new UserBadgesResponseDto(Array.Empty<UserBadgeDto>(), 0, 0));

        public Task<IReadOnlyList<string>> RecomputeAsync(string userId, CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<string>>(Array.Empty<string>());
    }
}
