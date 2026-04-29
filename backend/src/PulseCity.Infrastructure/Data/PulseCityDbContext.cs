using System.Text.Json;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using PulseCity.Domain.Entities;

namespace PulseCity.Infrastructure.Data;

public sealed class PulseCityDbContext(DbContextOptions<PulseCityDbContext> options)
    : DbContext(options)
{
    public DbSet<UserProfile> Users => Set<UserProfile>();
    public DbSet<UserCredential> UserCredentials => Set<UserCredential>();
    public DbSet<PasswordResetToken> PasswordResetTokens => Set<PasswordResetToken>();
    public DbSet<ChatThread> Chats => Set<ChatThread>();
    public DbSet<ChatParticipant> ChatParticipants => Set<ChatParticipant>();
    public DbSet<ChatMessage> ChatMessages => Set<ChatMessage>();
    public DbSet<ChatMessageHiddenState> ChatMessageHiddenStates => Set<ChatMessageHiddenState>();
    public DbSet<FollowRelation> Follows => Set<FollowRelation>();
    public DbSet<FriendRequest> FriendRequests => Set<FriendRequest>();
    public DbSet<Friendship> Friendships => Set<Friendship>();
    public DbSet<Highlight> Highlights => Set<Highlight>();
    public DbSet<StoryView> StoryViews => Set<StoryView>();
    public DbSet<BlockedUser> BlockedUsers => Set<BlockedUser>();
    public DbSet<UserReport> UserReports => Set<UserReport>();
    public DbSet<UserMatch> Matches => Set<UserMatch>();
    public DbSet<DiscoverPass> DiscoverPasses => Set<DiscoverPass>();
    public DbSet<UserPresence> Presences => Set<UserPresence>();
    public DbSet<Post> Posts => Set<Post>();
    public DbSet<PostLike> PostLikes => Set<PostLike>();
    public DbSet<PostComment> PostComments => Set<PostComment>();
    public DbSet<SavedPost> SavedPosts => Set<SavedPost>();
    public DbSet<SavedPlace> SavedPlaces => Set<SavedPlace>();
    public DbSet<PlaceSnapshot> PlaceSnapshots => Set<PlaceSnapshot>();
    public DbSet<UserDataExport> UserDataExports => Set<UserDataExport>();
    public DbSet<DeviceToken> DeviceTokens => Set<DeviceToken>();
    public DbSet<SignalCrossing> SignalCrossings => Set<SignalCrossing>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<Activity> Activities => Set<Activity>();
    public DbSet<ActivityParticipation> ActivityParticipations => Set<ActivityParticipation>();
    public DbSet<ActivityRating> ActivityRatings => Set<ActivityRating>();
    public DbSet<UserBadge> UserBadges => Set<UserBadge>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var stringListConverter = new ValueConverter<List<string>, string>(
            value => JsonSerializer.Serialize(value, JsonSerializerOptions.Web),
            value =>
                string.IsNullOrWhiteSpace(value)
                    ? new List<string>()
                    : JsonSerializer.Deserialize<List<string>>(value, JsonSerializerOptions.Web) ?? new List<string>()
        );
        var stringListComparer = new ValueComparer<List<string>>(
            (left, right) =>
                object.ReferenceEquals(left, right)
                || (left != null
                    && right != null
                    && Enumerable.SequenceEqual(left, right)),
            value =>
                value == null
                    ? 0
                    : value.Aggregate(
                        0,
                        (current, item) => HashCode.Combine(current, item == null ? 0 : item.GetHashCode())
                    ),
            value => value == null ? new List<string>() : value.ToList()
        );

        var stringDictConverter = new ValueConverter<Dictionary<string, string>, string>(
            value => JsonSerializer.Serialize(value, JsonSerializerOptions.Web),
            value =>
                string.IsNullOrWhiteSpace(value)
                    ? new Dictionary<string, string>()
                    : JsonSerializer.Deserialize<Dictionary<string, string>>(value, JsonSerializerOptions.Web) ?? new Dictionary<string, string>()
        );
        var stringDictComparer = new ValueComparer<Dictionary<string, string>>(
            (left, right) =>
                object.ReferenceEquals(left, right)
                || (left != null
                    && right != null
                    && left.Count == right.Count
                    && !left.Except(right).Any()),
            value =>
                value == null
                    ? 0
                    : value.Aggregate(
                        0,
                        (current, pair) => HashCode.Combine(current, pair.Key.GetHashCode(), (pair.Value ?? string.Empty).GetHashCode())
                    ),
            value => value == null ? new Dictionary<string, string>() : new Dictionary<string, string>(value)
        );
        var boolDictConverter = new ValueConverter<Dictionary<string, bool>, string>(
            value => JsonSerializer.Serialize(value, JsonSerializerOptions.Web),
            value =>
                string.IsNullOrWhiteSpace(value)
                    ? new Dictionary<string, bool>()
                    : JsonSerializer.Deserialize<Dictionary<string, bool>>(value, JsonSerializerOptions.Web) ?? new Dictionary<string, bool>()
        );
        var boolDictComparer = new ValueComparer<Dictionary<string, bool>>(
            (left, right) =>
                object.ReferenceEquals(left, right)
                || (left != null
                    && right != null
                    && left.Count == right.Count
                    && !left.Except(right).Any()),
            value =>
                value == null
                    ? 0
                    : value.Aggregate(
                        0,
                        (current, pair) => HashCode.Combine(current, pair.Key.GetHashCode(), pair.Value.GetHashCode())
                    ),
            value => value == null ? new Dictionary<string, bool>() : new Dictionary<string, bool>(value)
        );

        modelBuilder.Entity<UserProfile>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Id).HasMaxLength(128);
            entity.Property(x => x.Email).HasMaxLength(256);
            entity.Property(x => x.FirstName).HasMaxLength(64);
            entity.Property(x => x.LastName).HasMaxLength(64);
            entity.Property(x => x.UserName).HasMaxLength(64);
            entity.Property(x => x.NormalizedUserName).HasMaxLength(64);
            entity.Property(x => x.DisplayName).HasMaxLength(64);
            entity.Property(x => x.NormalizedDisplayName).HasMaxLength(64);
            entity.Property(x => x.Bio).HasMaxLength(160);
            entity.Property(x => x.City).HasMaxLength(120);
            entity.Property(x => x.NormalizedCity).HasMaxLength(120);
            entity.Property(x => x.Website).HasMaxLength(256);
            entity.Property(x => x.Gender).HasMaxLength(32);
            entity.Property(x => x.BirthDate).HasColumnType("date");
            entity.Property(x => x.Purpose).HasMaxLength(64);
            entity.Property(x => x.MatchPreference).HasMaxLength(16);
            entity.Property(x => x.Mode).HasMaxLength(32);
            entity.Property(x => x.PrivacyLevel).HasMaxLength(32);
            entity.Property(x => x.PreferredLanguage).HasMaxLength(8);
            entity.Property(x => x.LocationGranularity).HasMaxLength(24);
            entity.Property(x => x.ProfilePhotoUrl).HasMaxLength(512);
            entity.Property(x => x.PhotoUrls)
                .HasConversion(stringListConverter)
                .Metadata.SetValueComparer(stringListComparer);
            entity.Property(x => x.Interests)
                .HasConversion(stringListConverter)
                .Metadata.SetValueComparer(stringListComparer);

            // Dating-context fields
            entity.Property(x => x.Orientation).HasMaxLength(24);
            entity.Property(x => x.RelationshipIntent).HasMaxLength(24);
            entity.Property(x => x.DrinkingStatus).HasMaxLength(24);
            entity.Property(x => x.SmokingStatus).HasMaxLength(24);
            entity.Property(x => x.LookingForModes)
                .HasConversion(stringListConverter)
                .Metadata.SetValueComparer(stringListComparer);
            entity.Property(x => x.Dealbreakers)
                .HasConversion(stringListConverter)
                .Metadata.SetValueComparer(stringListComparer);
            entity.Property(x => x.DatingPrompts)
                .HasConversion(stringDictConverter)
                .Metadata.SetValueComparer(stringDictComparer);
            entity.Property(x => x.EnabledFeatures)
                .HasConversion(boolDictConverter)
                .Metadata.SetValueComparer(boolDictComparer);

            entity.HasIndex(x => x.NormalizedUserName);
            entity.HasIndex(x => x.NormalizedDisplayName);
            entity.HasIndex(x => x.NormalizedCity);
            entity.HasIndex(x => x.Mode);
            entity.HasIndex(x => x.RelationshipIntent);
            // Pinned post: SET NULL on cascade (post silindiğinde sabitleme düşer).
            entity.HasOne<Post>()
                .WithMany()
                .HasForeignKey(x => x.PinnedPostId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<UserCredential>(entity =>
        {
            entity.HasKey(x => x.UserId);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.Property(x => x.Email).HasMaxLength(256);
            entity.Property(x => x.PasswordHash).HasMaxLength(512);
            entity.Property(x => x.GoogleSubject).HasMaxLength(256);
            entity.HasIndex(x => x.Email).IsUnique();
            entity.HasIndex(x => x.GoogleSubject)
                .IsUnique()
                .HasFilter("[GoogleSubject] IS NOT NULL");
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<PasswordResetToken>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.Property(x => x.TokenHash).HasMaxLength(512);
            entity.Property(x => x.RequestedIp).HasMaxLength(128);
            entity.Property(x => x.UserAgent).HasMaxLength(512);
            entity.HasIndex(x => new { x.UserId, x.CreatedAt });
            entity.HasIndex(x => x.ExpiresAt);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<ChatThread>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.ToTable("Chats");
            entity.Property(x => x.CreatedByUserId).HasMaxLength(128);
            entity.Property(x => x.LastMessage).HasMaxLength(2000);
            entity.Property(x => x.LastSenderId).HasMaxLength(128);
            entity.Property(x => x.DirectMessageKey).HasMaxLength(300);
            entity.Property(x => x.Kind).HasMaxLength(16).HasDefaultValue("direct");
            entity.Property(x => x.Title).HasMaxLength(200).HasDefaultValue(string.Empty);
            entity.HasIndex(x => x.LastMessageTime);
            entity.HasIndex(x => x.ExpiresAt);
            entity.HasIndex(x => x.ActivityId);
            entity.HasIndex(x => x.DirectMessageKey)
                .IsUnique()
                .HasFilter("[DirectMessageKey] IS NOT NULL");
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.CreatedByUserId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.LastSenderId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<ChatParticipant>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.HasIndex(x => new { x.ChatId, x.UserId }).IsUnique();
            entity.HasIndex(x => new { x.UserId, x.JoinedAt });
            entity.HasIndex(x => new { x.UserId, x.IsArchived, x.JoinedAt });
            entity.HasIndex(x => new { x.UserId, x.DeletedAt });
            entity.HasOne<ChatThread>()
                .WithMany()
                .HasForeignKey(x => x.ChatId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<ChatMessage>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.SenderId).HasMaxLength(128);
            entity.Property(x => x.DeletedByUserId).HasMaxLength(128);
            entity.Property(x => x.Text).HasMaxLength(4000);
            entity.Property(x => x.PhotoUrl).HasMaxLength(512);
            entity.Property(x => x.VideoUrl).HasMaxLength(512);
            entity.Property(x => x.Reaction).HasMaxLength(64);
            entity.Property(x => x.SharedPostAuthor).HasMaxLength(128);
            entity.Property(x => x.SharedPostLocation).HasMaxLength(160);
            entity.Property(x => x.SharedPostVibe).HasMaxLength(64);
            entity.Property(x => x.SharedPostMediaUrl).HasMaxLength(512);
            entity.HasIndex(x => new { x.ChatId, x.CreatedAt });
            entity.HasIndex(x => new { x.ChatId, x.DeletedAt });
            entity.HasOne<ChatThread>()
                .WithMany()
                .HasForeignKey(x => x.ChatId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.SenderId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<Post>()
                .WithMany()
                .HasForeignKey(x => x.SharedPostId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<ChatMessageHiddenState>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.HasIndex(x => new { x.MessageId, x.UserId }).IsUnique();
            entity.HasIndex(x => new { x.UserId, x.HiddenAt });
            entity.HasOne<ChatMessage>()
                .WithMany()
                .HasForeignKey(x => x.MessageId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<FollowRelation>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.FollowerUserId).HasMaxLength(128);
            entity.Property(x => x.FollowingUserId).HasMaxLength(128);
            entity.HasIndex(x => new { x.FollowerUserId, x.FollowingUserId }).IsUnique();
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.FollowerUserId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.FollowingUserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<FriendRequest>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.FromUserId).HasMaxLength(128);
            entity.Property(x => x.ToUserId).HasMaxLength(128);
            entity.HasIndex(x => new { x.ToUserId, x.Status, x.CreatedAt });
            entity.HasIndex(x => new { x.FromUserId, x.ToUserId, x.Status });
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.FromUserId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.ToUserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<Friendship>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserAId).HasMaxLength(128);
            entity.Property(x => x.UserBId).HasMaxLength(128);
            entity.HasIndex(x => new { x.UserAId, x.UserBId }).IsUnique();
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserAId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserBId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<Highlight>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.Property(x => x.Title).HasMaxLength(80);
            entity.Property(x => x.CoverUrl).HasMaxLength(512);
            entity.Property(x => x.MediaUrls)
                .HasConversion(stringListConverter)
                .Metadata.SetValueComparer(stringListComparer);
            entity.Property(x => x.Type).HasMaxLength(24);
            entity.Property(x => x.TextColorHex).HasMaxLength(16);
            entity.Property(x => x.ModeTag).HasMaxLength(32);
            entity.Property(x => x.LocationLabel).HasMaxLength(160);
            entity.Property(x => x.PlaceId).HasMaxLength(160);
            entity.Property(x => x.EntryKind).HasMaxLength(24);
            entity.HasIndex(x => new { x.UserId, x.EntryKind, x.CreatedAt });
            entity.HasIndex(x => x.ExpiresAt);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<StoryView>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.ViewerUserId).HasMaxLength(128);
            entity.HasIndex(x => new { x.StoryId, x.ViewerUserId }).IsUnique();
            entity.HasIndex(x => new { x.StoryId, x.ViewedAt });
            entity.HasOne<Highlight>()
                .WithMany()
                .HasForeignKey(x => x.StoryId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.ViewerUserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<BlockedUser>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.Property(x => x.BlockedUserId).HasMaxLength(128);
            entity.HasIndex(x => new { x.UserId, x.BlockedUserId }).IsUnique();
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.BlockedUserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<UserReport>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.ReporterUserId).HasMaxLength(128);
            entity.Property(x => x.TargetUserId).HasMaxLength(128);
            entity.Property(x => x.Reason).HasMaxLength(120);
            entity.Property(x => x.Details).HasMaxLength(1000);
            entity.HasIndex(x => new { x.TargetUserId, x.CreatedAt });
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.ReporterUserId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.TargetUserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<UserMatch>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId1).HasMaxLength(128);
            entity.Property(x => x.UserId2).HasMaxLength(128);
            entity.Property(x => x.CommonInterests)
                .HasConversion(stringListConverter)
                .Metadata.SetValueComparer(stringListComparer);
            entity.HasIndex(x => new { x.UserId2, x.Status, x.CreatedAt });
            entity.HasIndex(x => new { x.UserId1, x.UserId2, x.CreatedAt });
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId1)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId2)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<ChatThread>()
                .WithMany()
                .HasForeignKey(x => x.ChatId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<UserPresence>(entity =>
        {
            entity.HasKey(x => x.UserId);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.Property(x => x.City).HasMaxLength(120);
            entity.Property(x => x.Mode).HasMaxLength(32);
            entity.HasIndex(x => new { x.IsSignalActive, x.UpdatedAt });
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<DiscoverPass>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.Property(x => x.TargetUserId).HasMaxLength(128);
            entity.HasIndex(x => new { x.UserId, x.TargetUserId }).IsUnique();
            entity.HasIndex(x => new { x.UserId, x.CreatedAt });
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.TargetUserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<Post>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.Property(x => x.Text).HasMaxLength(2000);
            entity.Property(x => x.LocationName).HasMaxLength(120);
            entity.Property(x => x.PlaceId).HasMaxLength(160);
            entity.Property(x => x.PhotoUrls)
                .HasConversion(stringListConverter)
                .Metadata.SetValueComparer(stringListComparer);
            entity.Property(x => x.VideoUrl).HasMaxLength(512);
            entity.Property(x => x.VibeTag).HasMaxLength(64);
            entity.HasIndex(x => x.CreatedAt);
            entity.HasIndex(x => x.PlaceId);
            entity.HasIndex(x => new { x.UserId, x.CreatedAt });
            entity.HasIndex(x => new { x.Latitude, x.Longitude });
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<PostLike>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.HasIndex(x => new { x.PostId, x.UserId }).IsUnique();
            entity.HasOne<Post>()
                .WithMany()
                .HasForeignKey(x => x.PostId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<PostComment>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.Property(x => x.Text).HasMaxLength(1000);
            entity.HasIndex(x => new { x.PostId, x.CreatedAt });
            entity.HasOne<Post>()
                .WithMany()
                .HasForeignKey(x => x.PostId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<SavedPost>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.HasIndex(x => new { x.PostId, x.UserId }).IsUnique();
            entity.HasOne<Post>()
                .WithMany()
                .HasForeignKey(x => x.PostId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<SavedPlace>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.Property(x => x.PlaceId).HasMaxLength(160);
            entity.Property(x => x.PlaceName).HasMaxLength(160);
            entity.Property(x => x.Vicinity).HasMaxLength(300);
            entity.HasIndex(x => new { x.UserId, x.PlaceId }).IsUnique();
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<PlaceSnapshot>(entity =>
        {
            entity.HasKey(x => x.PlaceId);
            entity.Property(x => x.PlaceId).HasMaxLength(160);
            entity.Property(x => x.Name).HasMaxLength(160);
            entity.Property(x => x.Vicinity).HasMaxLength(300);
            entity.HasIndex(x => x.UpdatedAt);
        });

        modelBuilder.Entity<UserDataExport>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.Property(x => x.FileName).HasMaxLength(260);
            entity.Property(x => x.RelativePath).HasMaxLength(512);
            entity.Property(x => x.Status).HasMaxLength(32);
            entity.HasIndex(x => new { x.UserId, x.CreatedAt });
            entity.HasIndex(x => x.ExpiresAt);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<DeviceToken>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.Property(x => x.Token).HasMaxLength(512);
            entity.Property(x => x.Platform).HasMaxLength(16);
            entity.HasIndex(x => x.Token).IsUnique();
            entity.HasIndex(x => new { x.UserId, x.UpdatedAt });
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<SignalCrossing>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserAId).HasMaxLength(128);
            entity.Property(x => x.UserBId).HasMaxLength(128);
            entity.Property(x => x.PlaceId).HasMaxLength(160);
            entity.Property(x => x.LocationLabel).HasMaxLength(160);
            entity.HasIndex(x => new { x.UserAId, x.UserBId, x.CrossedAt });
            entity.HasIndex(x => x.CrossedAt);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserAId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserBId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<Notification>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.RecipientUserId).HasMaxLength(128);
            entity.Property(x => x.ActorUserId).HasMaxLength(128);
            entity.Property(x => x.Title).HasMaxLength(160);
            entity.Property(x => x.Body).HasMaxLength(512);
            entity.Property(x => x.DeepLink).HasMaxLength(512);
            entity.Property(x => x.RelatedEntityType).HasMaxLength(64);
            entity.Property(x => x.RelatedEntityId).HasMaxLength(128);
            entity.HasIndex(x => new { x.RecipientUserId, x.IsRead, x.CreatedAt });
            entity.HasIndex(x => new { x.RecipientUserId, x.CreatedAt });
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.RecipientUserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<Activity>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.HostUserId).HasMaxLength(128);
            entity.Property(x => x.Title).HasMaxLength(160);
            entity.Property(x => x.Description).HasMaxLength(2000);
            entity.Property(x => x.Mode).HasMaxLength(32);
            entity.Property(x => x.CoverImageUrl).HasMaxLength(512);
            entity.Property(x => x.LocationName).HasMaxLength(200);
            entity.Property(x => x.LocationAddress).HasMaxLength(400);
            entity.Property(x => x.City).HasMaxLength(120);
            entity.Property(x => x.NormalizedCity).HasMaxLength(120);
            entity.Property(x => x.PlaceId).HasMaxLength(128);
            entity.Property(x => x.PreferredGender).HasMaxLength(24);
            entity.Property(x => x.CancellationReason).HasMaxLength(400);
            entity.Property(x => x.Interests)
                .HasConversion(stringListConverter)
                .Metadata.SetValueComparer(stringListComparer);

            entity.HasIndex(x => new { x.Status, x.StartsAt });
            entity.HasIndex(x => new { x.NormalizedCity, x.Status, x.StartsAt });
            entity.HasIndex(x => new { x.HostUserId, x.Status, x.StartsAt });
            entity.HasIndex(x => new { x.Category, x.Status, x.StartsAt });
            entity.HasIndex(x => new { x.Latitude, x.Longitude });

            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.HostUserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<ActivityParticipation>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.Property(x => x.JoinMessage).HasMaxLength(400);
            entity.Property(x => x.ResponseNote).HasMaxLength(400);

            entity.HasIndex(x => new { x.ActivityId, x.UserId }).IsUnique();
            entity.HasIndex(x => new { x.ActivityId, x.Status });
            entity.HasIndex(x => new { x.UserId, x.Status, x.RequestedAt });

            entity.HasOne<Activity>()
                .WithMany()
                .HasForeignKey(x => x.ActivityId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<ActivityRating>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.RaterUserId).HasMaxLength(128);
            entity.Property(x => x.RatedUserId).HasMaxLength(128);
            entity.Property(x => x.Comment).HasMaxLength(800);

            entity.HasIndex(x => new { x.ActivityId, x.RaterUserId, x.RatedUserId })
                .IsUnique();
            entity.HasIndex(x => x.RatedUserId);
            entity.HasIndex(x => x.ActivityId);

            entity.HasOne<Activity>()
                .WithMany()
                .HasForeignKey(x => x.ActivityId)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.RaterUserId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.RatedUserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<UserBadge>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.UserId).HasMaxLength(128);
            entity.Property(x => x.BadgeCode).HasMaxLength(32);

            entity.HasIndex(x => new { x.UserId, x.BadgeCode }).IsUnique();
            entity.HasIndex(x => x.UserId);

            entity.HasOne<UserProfile>()
                .WithMany()
                .HasForeignKey(x => x.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
