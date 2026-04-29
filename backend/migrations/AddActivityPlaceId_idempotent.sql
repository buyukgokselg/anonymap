IF OBJECT_ID(N'[__EFMigrationsHistory]') IS NULL
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE TABLE [BlockedUsers] (
        [Id] uniqueidentifier NOT NULL,
        [UserId] nvarchar(128) NOT NULL,
        [BlockedUserId] nvarchar(128) NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_BlockedUsers] PRIMARY KEY ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE TABLE [Follows] (
        [Id] uniqueidentifier NOT NULL,
        [FollowerUserId] nvarchar(128) NOT NULL,
        [FollowingUserId] nvarchar(128) NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_Follows] PRIMARY KEY ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE TABLE [FriendRequests] (
        [Id] uniqueidentifier NOT NULL,
        [FromUserId] nvarchar(128) NOT NULL,
        [ToUserId] nvarchar(128) NOT NULL,
        [Status] int NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        [RespondedAt] datetimeoffset NULL,
        CONSTRAINT [PK_FriendRequests] PRIMARY KEY ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE TABLE [Friendships] (
        [Id] uniqueidentifier NOT NULL,
        [UserAId] nvarchar(128) NOT NULL,
        [UserBId] nvarchar(128) NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_Friendships] PRIMARY KEY ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE TABLE [PlaceSnapshots] (
        [PlaceId] nvarchar(160) NOT NULL,
        [Name] nvarchar(160) NOT NULL,
        [Vicinity] nvarchar(300) NOT NULL,
        [Latitude] float NOT NULL,
        [Longitude] float NOT NULL,
        [Rating] float NOT NULL,
        [UserRatingsTotal] int NOT NULL,
        [PriceLevel] int NOT NULL,
        [IsOpenNow] bit NOT NULL,
        [GooglePulseScore] int NOT NULL,
        [DensityScore] int NOT NULL,
        [TrendScore] int NOT NULL,
        [UpdatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_PlaceSnapshots] PRIMARY KEY ([PlaceId])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE TABLE [PostComments] (
        [Id] uniqueidentifier NOT NULL,
        [PostId] uniqueidentifier NOT NULL,
        [UserId] nvarchar(128) NOT NULL,
        [Text] nvarchar(1000) NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_PostComments] PRIMARY KEY ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE TABLE [PostLikes] (
        [Id] uniqueidentifier NOT NULL,
        [PostId] uniqueidentifier NOT NULL,
        [UserId] nvarchar(128) NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_PostLikes] PRIMARY KEY ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE TABLE [Posts] (
        [Id] uniqueidentifier NOT NULL,
        [UserId] nvarchar(128) NOT NULL,
        [Text] nvarchar(2000) NOT NULL,
        [LocationName] nvarchar(120) NOT NULL,
        [PlaceId] nvarchar(160) NOT NULL,
        [Latitude] float NULL,
        [Longitude] float NULL,
        [PhotoUrls] nvarchar(max) NOT NULL,
        [VideoUrl] nvarchar(512) NULL,
        [Rating] float NOT NULL,
        [VibeTag] nvarchar(64) NOT NULL,
        [CommentsCount] int NOT NULL,
        [Type] int NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        [UpdatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_Posts] PRIMARY KEY ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE TABLE [Presences] (
        [UserId] nvarchar(128) NOT NULL,
        [Latitude] float NOT NULL,
        [Longitude] float NOT NULL,
        [City] nvarchar(120) NOT NULL,
        [Mode] nvarchar(32) NOT NULL,
        [ShareProfile] bit NOT NULL,
        [IsSignalActive] bit NOT NULL,
        [UpdatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_Presences] PRIMARY KEY ([UserId])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE TABLE [SavedPlaces] (
        [Id] uniqueidentifier NOT NULL,
        [UserId] nvarchar(128) NOT NULL,
        [PlaceId] nvarchar(160) NOT NULL,
        [PlaceName] nvarchar(160) NOT NULL,
        [Vicinity] nvarchar(300) NOT NULL,
        [Latitude] float NULL,
        [Longitude] float NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_SavedPlaces] PRIMARY KEY ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE TABLE [SavedPosts] (
        [Id] uniqueidentifier NOT NULL,
        [UserId] nvarchar(128) NOT NULL,
        [PostId] uniqueidentifier NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_SavedPosts] PRIMARY KEY ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE TABLE [UserCredentials] (
        [UserId] nvarchar(128) NOT NULL,
        [Email] nvarchar(256) NOT NULL,
        [PasswordHash] nvarchar(512) NOT NULL,
        [GoogleSubject] nvarchar(256) NOT NULL,
        [HasPassword] bit NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        [UpdatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_UserCredentials] PRIMARY KEY ([UserId])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE TABLE [UserReports] (
        [Id] uniqueidentifier NOT NULL,
        [ReporterUserId] nvarchar(128) NOT NULL,
        [TargetUserId] nvarchar(128) NOT NULL,
        [Reason] nvarchar(120) NOT NULL,
        [Details] nvarchar(1000) NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_UserReports] PRIMARY KEY ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE TABLE [Users] (
        [Id] nvarchar(128) NOT NULL,
        [Email] nvarchar(256) NOT NULL,
        [UserName] nvarchar(64) NOT NULL,
        [NormalizedUserName] nvarchar(64) NOT NULL,
        [DisplayName] nvarchar(64) NOT NULL,
        [NormalizedDisplayName] nvarchar(64) NOT NULL,
        [Bio] nvarchar(160) NOT NULL,
        [City] nvarchar(120) NOT NULL,
        [NormalizedCity] nvarchar(120) NOT NULL,
        [Website] nvarchar(256) NOT NULL,
        [Gender] nvarchar(32) NOT NULL,
        [Age] int NOT NULL,
        [Purpose] nvarchar(64) NOT NULL,
        [Mode] nvarchar(32) NOT NULL,
        [PrivacyLevel] nvarchar(32) NOT NULL,
        [IsVisible] bit NOT NULL,
        [IsOnline] bit NOT NULL,
        [ProfilePhotoUrl] nvarchar(512) NOT NULL,
        [PhotoUrls] nvarchar(max) NOT NULL,
        [Interests] nvarchar(max) NOT NULL,
        [Latitude] float NULL,
        [Longitude] float NULL,
        [LastSeenAt] datetimeoffset NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        [UpdatedAt] datetimeoffset NOT NULL,
        [FollowersCount] int NOT NULL,
        [FollowingCount] int NOT NULL,
        [FriendsCount] int NOT NULL,
        [PulseScore] int NOT NULL,
        [PlacesVisited] int NOT NULL,
        [VibeTagsCreated] int NOT NULL,
        CONSTRAINT [PK_Users] PRIMARY KEY ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE UNIQUE INDEX [IX_BlockedUsers_UserId_BlockedUserId] ON [BlockedUsers] ([UserId], [BlockedUserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE UNIQUE INDEX [IX_Follows_FollowerUserId_FollowingUserId] ON [Follows] ([FollowerUserId], [FollowingUserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE INDEX [IX_FriendRequests_FromUserId_ToUserId_Status] ON [FriendRequests] ([FromUserId], [ToUserId], [Status]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE INDEX [IX_FriendRequests_ToUserId_Status_CreatedAt] ON [FriendRequests] ([ToUserId], [Status], [CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE UNIQUE INDEX [IX_Friendships_UserAId_UserBId] ON [Friendships] ([UserAId], [UserBId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE INDEX [IX_PlaceSnapshots_UpdatedAt] ON [PlaceSnapshots] ([UpdatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE INDEX [IX_PostComments_PostId_CreatedAt] ON [PostComments] ([PostId], [CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE UNIQUE INDEX [IX_PostLikes_PostId_UserId] ON [PostLikes] ([PostId], [UserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE INDEX [IX_Posts_CreatedAt] ON [Posts] ([CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE INDEX [IX_Posts_PlaceId] ON [Posts] ([PlaceId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE INDEX [IX_Presences_IsSignalActive_UpdatedAt] ON [Presences] ([IsSignalActive], [UpdatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE UNIQUE INDEX [IX_SavedPlaces_UserId_PlaceId] ON [SavedPlaces] ([UserId], [PlaceId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE UNIQUE INDEX [IX_SavedPosts_PostId_UserId] ON [SavedPosts] ([PostId], [UserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE UNIQUE INDEX [IX_UserCredentials_Email] ON [UserCredentials] ([Email]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE UNIQUE INDEX [IX_UserCredentials_GoogleSubject] ON [UserCredentials] ([GoogleSubject]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE INDEX [IX_Users_NormalizedCity] ON [Users] ([NormalizedCity]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE INDEX [IX_Users_NormalizedDisplayName] ON [Users] ([NormalizedDisplayName]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    CREATE INDEX [IX_Users_NormalizedUserName] ON [Users] ([NormalizedUserName]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407163809_InitialSqlServer'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260407163809_InitialSqlServer', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    DROP INDEX [IX_UserCredentials_GoogleSubject] ON [UserCredentials];
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    DECLARE @var sysname;
    SELECT @var = [d].[name]
    FROM [sys].[default_constraints] [d]
    INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
    WHERE ([d].[parent_object_id] = OBJECT_ID(N'[UserCredentials]') AND [c].[name] = N'GoogleSubject');
    IF @var IS NOT NULL EXEC(N'ALTER TABLE [UserCredentials] DROP CONSTRAINT [' + @var + '];');
    ALTER TABLE [UserCredentials] ALTER COLUMN [GoogleSubject] nvarchar(256) NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE TABLE [Chats] (
        [Id] uniqueidentifier NOT NULL,
        [CreatedByUserId] nvarchar(128) NOT NULL,
        [LastMessage] nvarchar(2000) NOT NULL,
        [LastSenderId] nvarchar(128) NULL,
        [LastMessageTime] datetimeoffset NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        [ExpiresAt] datetimeoffset NULL,
        [IsTemporary] bit NOT NULL,
        [IsFriendChat] bit NOT NULL,
        [DirectMessageKey] nvarchar(300) NULL,
        CONSTRAINT [PK_Chats] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_Chats_Users_CreatedByUserId] FOREIGN KEY ([CreatedByUserId]) REFERENCES [Users] ([Id]),
        CONSTRAINT [FK_Chats_Users_LastSenderId] FOREIGN KEY ([LastSenderId]) REFERENCES [Users] ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE TABLE [Highlights] (
        [Id] uniqueidentifier NOT NULL,
        [UserId] nvarchar(128) NOT NULL,
        [Title] nvarchar(80) NOT NULL,
        [CoverUrl] nvarchar(512) NOT NULL,
        [Type] nvarchar(24) NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_Highlights] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_Highlights_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE TABLE [ChatMessages] (
        [Id] uniqueidentifier NOT NULL,
        [ChatId] uniqueidentifier NOT NULL,
        [SenderId] nvarchar(128) NOT NULL,
        [Text] nvarchar(4000) NOT NULL,
        [Type] int NOT NULL,
        [Status] int NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        [PhotoUrl] nvarchar(512) NULL,
        [VideoUrl] nvarchar(512) NULL,
        [Latitude] float NULL,
        [Longitude] float NULL,
        [PhotoApproved] bit NULL,
        [Reaction] nvarchar(64) NULL,
        [DisappearSeconds] int NULL,
        [SharedPostId] uniqueidentifier NULL,
        [SharedPostAuthor] nvarchar(128) NULL,
        [SharedPostLocation] nvarchar(160) NULL,
        [SharedPostVibe] nvarchar(64) NULL,
        [SharedPostMediaUrl] nvarchar(512) NULL,
        CONSTRAINT [PK_ChatMessages] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ChatMessages_Chats_ChatId] FOREIGN KEY ([ChatId]) REFERENCES [Chats] ([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_ChatMessages_Posts_SharedPostId] FOREIGN KEY ([SharedPostId]) REFERENCES [Posts] ([Id]) ON DELETE SET NULL,
        CONSTRAINT [FK_ChatMessages_Users_SenderId] FOREIGN KEY ([SenderId]) REFERENCES [Users] ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE TABLE [ChatParticipants] (
        [Id] uniqueidentifier NOT NULL,
        [ChatId] uniqueidentifier NOT NULL,
        [UserId] nvarchar(128) NOT NULL,
        [JoinedAt] datetimeoffset NOT NULL,
        [LastReadAt] datetimeoffset NULL,
        [UnreadCount] int NOT NULL,
        [IsTyping] bit NOT NULL,
        CONSTRAINT [PK_ChatParticipants] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ChatParticipants_Chats_ChatId] FOREIGN KEY ([ChatId]) REFERENCES [Chats] ([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_ChatParticipants_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE TABLE [Matches] (
        [Id] uniqueidentifier NOT NULL,
        [UserId1] nvarchar(128) NOT NULL,
        [UserId2] nvarchar(128) NOT NULL,
        [Compatibility] int NOT NULL,
        [CommonInterests] nvarchar(max) NOT NULL,
        [Status] int NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        [RespondedAt] datetimeoffset NULL,
        [ChatId] uniqueidentifier NULL,
        CONSTRAINT [PK_Matches] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_Matches_Chats_ChatId] FOREIGN KEY ([ChatId]) REFERENCES [Chats] ([Id]) ON DELETE SET NULL,
        CONSTRAINT [FK_Matches_Users_UserId1] FOREIGN KEY ([UserId1]) REFERENCES [Users] ([Id]),
        CONSTRAINT [FK_Matches_Users_UserId2] FOREIGN KEY ([UserId2]) REFERENCES [Users] ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_UserReports_ReporterUserId] ON [UserReports] ([ReporterUserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_UserReports_TargetUserId_CreatedAt] ON [UserReports] ([TargetUserId], [CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_UserCredentials_GoogleSubject] ON [UserCredentials] ([GoogleSubject]) WHERE [GoogleSubject] IS NOT NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_SavedPosts_UserId] ON [SavedPosts] ([UserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_Posts_UserId] ON [Posts] ([UserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_PostLikes_UserId] ON [PostLikes] ([UserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_PostComments_UserId] ON [PostComments] ([UserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_Friendships_UserBId] ON [Friendships] ([UserBId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_Follows_FollowingUserId] ON [Follows] ([FollowingUserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_BlockedUsers_BlockedUserId] ON [BlockedUsers] ([BlockedUserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_ChatMessages_ChatId_CreatedAt] ON [ChatMessages] ([ChatId], [CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_ChatMessages_SenderId] ON [ChatMessages] ([SenderId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_ChatMessages_SharedPostId] ON [ChatMessages] ([SharedPostId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE UNIQUE INDEX [IX_ChatParticipants_ChatId_UserId] ON [ChatParticipants] ([ChatId], [UserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_ChatParticipants_UserId_JoinedAt] ON [ChatParticipants] ([UserId], [JoinedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_Chats_CreatedByUserId] ON [Chats] ([CreatedByUserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_Chats_DirectMessageKey] ON [Chats] ([DirectMessageKey]) WHERE [DirectMessageKey] IS NOT NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_Chats_LastMessageTime] ON [Chats] ([LastMessageTime]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_Chats_LastSenderId] ON [Chats] ([LastSenderId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_Highlights_UserId_CreatedAt] ON [Highlights] ([UserId], [CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_Matches_ChatId] ON [Matches] ([ChatId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_Matches_UserId1_UserId2_CreatedAt] ON [Matches] ([UserId1], [UserId2], [CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    CREATE INDEX [IX_Matches_UserId2_Status_CreatedAt] ON [Matches] ([UserId2], [Status], [CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [BlockedUsers] ADD CONSTRAINT [FK_BlockedUsers_Users_BlockedUserId] FOREIGN KEY ([BlockedUserId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [BlockedUsers] ADD CONSTRAINT [FK_BlockedUsers_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [Follows] ADD CONSTRAINT [FK_Follows_Users_FollowerUserId] FOREIGN KEY ([FollowerUserId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [Follows] ADD CONSTRAINT [FK_Follows_Users_FollowingUserId] FOREIGN KEY ([FollowingUserId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [FriendRequests] ADD CONSTRAINT [FK_FriendRequests_Users_FromUserId] FOREIGN KEY ([FromUserId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [FriendRequests] ADD CONSTRAINT [FK_FriendRequests_Users_ToUserId] FOREIGN KEY ([ToUserId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [Friendships] ADD CONSTRAINT [FK_Friendships_Users_UserAId] FOREIGN KEY ([UserAId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [Friendships] ADD CONSTRAINT [FK_Friendships_Users_UserBId] FOREIGN KEY ([UserBId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [PostComments] ADD CONSTRAINT [FK_PostComments_Posts_PostId] FOREIGN KEY ([PostId]) REFERENCES [Posts] ([Id]) ON DELETE CASCADE;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [PostComments] ADD CONSTRAINT [FK_PostComments_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [PostLikes] ADD CONSTRAINT [FK_PostLikes_Posts_PostId] FOREIGN KEY ([PostId]) REFERENCES [Posts] ([Id]) ON DELETE CASCADE;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [PostLikes] ADD CONSTRAINT [FK_PostLikes_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [Posts] ADD CONSTRAINT [FK_Posts_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [Presences] ADD CONSTRAINT [FK_Presences_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [SavedPlaces] ADD CONSTRAINT [FK_SavedPlaces_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [SavedPosts] ADD CONSTRAINT [FK_SavedPosts_Posts_PostId] FOREIGN KEY ([PostId]) REFERENCES [Posts] ([Id]) ON DELETE CASCADE;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [SavedPosts] ADD CONSTRAINT [FK_SavedPosts_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [UserCredentials] ADD CONSTRAINT [FK_UserCredentials_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [UserReports] ADD CONSTRAINT [FK_UserReports_Users_ReporterUserId] FOREIGN KEY ([ReporterUserId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    ALTER TABLE [UserReports] ADD CONSTRAINT [FK_UserReports_Users_TargetUserId] FOREIGN KEY ([TargetUserId]) REFERENCES [Users] ([Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407170550_RelationalExpansionForMessaging'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260407170550_RelationalExpansionForMessaging', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407184500_ProgrammableSqlObjects'
)
BEGIN
    CREATE OR ALTER VIEW dbo.vw_PostFeedSummary
    AS
    SELECT
        p.Id,
        p.UserId,
        u.DisplayName AS UserDisplayName,
        u.ProfilePhotoUrl AS UserProfilePhotoUrl,
        p.Text,
        p.LocationName AS Location,
        p.PlaceId,
        p.Latitude,
        p.Longitude,
        p.PhotoUrls,
        p.VideoUrl,
        p.Rating,
        p.VibeTag,
        CASE WHEN p.Type = 1 THEN N'short' ELSE N'post' END AS Type,
        ISNULL(lk.LikesCount, 0) AS LikesCount,
        p.CommentsCount,
        p.CreatedAt
    FROM Posts AS p
    INNER JOIN Users AS u ON u.Id = p.UserId
    LEFT JOIN
    (
        SELECT PostId, COUNT(*) AS LikesCount
        FROM PostLikes
        GROUP BY PostId
    ) AS lk ON lk.PostId = p.Id;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407184500_ProgrammableSqlObjects'
)
BEGIN
    CREATE OR ALTER PROCEDURE dbo.usp_GetSavedPostsByUser
        @UserId nvarchar(128)
    AS
    BEGIN
        SET NOCOUNT ON;

        SELECT v.*
        FROM SavedPosts AS sp
        INNER JOIN dbo.vw_PostFeedSummary AS v ON v.Id = sp.PostId
        WHERE sp.UserId = @UserId
        ORDER BY sp.CreatedAt DESC;
    END
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407184500_ProgrammableSqlObjects'
)
BEGIN
    CREATE OR ALTER PROCEDURE dbo.usp_UpsertUserPresence
        @UserId nvarchar(128),
        @Latitude float,
        @Longitude float,
        @City nvarchar(120),
        @Mode nvarchar(32),
        @ShareProfile bit,
        @IsSignalActive bit,
        @IsOnline bit
    AS
    BEGIN
        SET NOCOUNT ON;

        DECLARE @Now datetimeoffset = SYSUTCDATETIME();
        DECLARE @NormalizedCity nvarchar(120) = LOWER(LTRIM(RTRIM(ISNULL(@City, N''))));
        DECLARE @CleanMode nvarchar(32) = NULLIF(LTRIM(RTRIM(ISNULL(@Mode, N''))), N'');

        UPDATE Users
        SET
            Latitude = @Latitude,
            Longitude = @Longitude,
            City = CASE WHEN NULLIF(LTRIM(RTRIM(ISNULL(@City, N''))), N'') IS NULL THEN City ELSE LTRIM(RTRIM(@City)) END,
            NormalizedCity = CASE WHEN NULLIF(@NormalizedCity, N'') IS NULL THEN NormalizedCity ELSE @NormalizedCity END,
            Mode = COALESCE(@CleanMode, Mode),
            IsOnline = @IsOnline,
            LastSeenAt = @Now,
            UpdatedAt = @Now
        WHERE Id = @UserId;

        IF EXISTS (SELECT 1 FROM Presences WHERE UserId = @UserId)
        BEGIN
            UPDATE Presences
            SET
                Latitude = @Latitude,
                Longitude = @Longitude,
                City = LTRIM(RTRIM(ISNULL(@City, N''))),
                Mode = COALESCE(@CleanMode, Mode),
                ShareProfile = @ShareProfile,
                IsSignalActive = CASE WHEN @IsOnline = 1 THEN @IsSignalActive ELSE 0 END,
                UpdatedAt = @Now
            WHERE UserId = @UserId;
        END
        ELSE
        BEGIN
            INSERT INTO Presences
            (
                UserId,
                Latitude,
                Longitude,
                City,
                Mode,
                ShareProfile,
                IsSignalActive,
                UpdatedAt
            )
            VALUES
            (
                @UserId,
                @Latitude,
                @Longitude,
                LTRIM(RTRIM(ISNULL(@City, N''))),
                COALESCE(@CleanMode, N'kesif'),
                @ShareProfile,
                CASE WHEN @IsOnline = 1 THEN @IsSignalActive ELSE 0 END,
                @Now
            );
        END
    END
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407184500_ProgrammableSqlObjects'
)
BEGIN
    CREATE OR ALTER FUNCTION dbo.fn_GetNearbyVisibleUsers
    (
        @CurrentUserId nvarchar(128),
        @Latitude float,
        @Longitude float,
        @RadiusKm float
    )
    RETURNS TABLE
    AS
    RETURN
    WITH CandidateUsers AS
    (
        SELECT
            u.Id,
            u.Email,
            u.UserName,
            u.DisplayName,
            u.Bio,
            COALESCE(NULLIF(p.City, N''), u.City, N'') AS City,
            u.Website,
            u.Gender,
            u.Age,
            u.Purpose,
            COALESCE(NULLIF(p.Mode, N''), u.Mode, N'kesif') AS Mode,
            u.PrivacyLevel,
            u.IsVisible,
            u.IsOnline,
            u.ProfilePhotoUrl,
            u.PhotoUrls,
            u.Interests,
            COALESCE(p.Latitude, u.Latitude) AS Latitude,
            COALESCE(p.Longitude, u.Longitude) AS Longitude,
            u.LastSeenAt,
            u.FollowersCount,
            u.FollowingCount,
            u.FriendsCount,
            u.PulseScore,
            u.PlacesVisited,
            u.VibeTagsCreated,
            ISNULL(p.ShareProfile, CAST(1 AS bit)) AS ShareProfile,
            ISNULL(p.IsSignalActive, CAST(0 AS bit)) AS IsSignalActive
        FROM Users AS u
        LEFT JOIN Presences AS p ON p.UserId = u.Id
        WHERE
            u.Id <> @CurrentUserId
            AND u.IsVisible = 1
            AND u.IsOnline = 1
            AND ISNULL(p.IsSignalActive, 0) = 1
            AND COALESCE(p.Latitude, u.Latitude) IS NOT NULL
            AND COALESCE(p.Longitude, u.Longitude) IS NOT NULL
    )
    SELECT
        cu.Id,
        cu.Email,
        cu.UserName,
        cu.DisplayName,
        cu.Bio,
        cu.City,
        cu.Website,
        cu.Gender,
        cu.Age,
        cu.Purpose,
        cu.Mode,
        cu.PrivacyLevel,
        cu.IsVisible,
        cu.IsOnline,
        cu.ProfilePhotoUrl,
        cu.PhotoUrls,
        cu.Interests,
        cu.Latitude,
        cu.Longitude,
        cu.LastSeenAt,
        cu.FollowersCount,
        cu.FollowingCount,
        cu.FriendsCount,
        cu.PulseScore,
        cu.PlacesVisited,
        cu.VibeTagsCreated,
        CAST(
            geography::Point(@Latitude, @Longitude, 4326).STDistance(
                geography::Point(cu.Latitude, cu.Longitude, 4326)
            ) AS float
        ) AS DistanceMeters,
        cu.ShareProfile,
        cu.IsSignalActive
    FROM CandidateUsers AS cu
    WHERE
        CAST(
            geography::Point(@Latitude, @Longitude, 4326).STDistance(
                geography::Point(cu.Latitude, cu.Longitude, 4326)
            ) AS float
        ) <= (@RadiusKm * 1000.0);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407184500_ProgrammableSqlObjects'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260407184500_ProgrammableSqlObjects', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407185945_PrivacyRealtimeLocalization'
)
BEGIN
    ALTER TABLE [Users] ADD [AllowAnalytics] bit NOT NULL DEFAULT CAST(1 AS bit);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407185945_PrivacyRealtimeLocalization'
)
BEGIN
    ALTER TABLE [Users] ADD [EnableDifferentialPrivacy] bit NOT NULL DEFAULT CAST(1 AS bit);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407185945_PrivacyRealtimeLocalization'
)
BEGIN
    ALTER TABLE [Users] ADD [KAnonymityLevel] int NOT NULL DEFAULT 3;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407185945_PrivacyRealtimeLocalization'
)
BEGIN
    ALTER TABLE [Users] ADD [LocationGranularity] nvarchar(24) NOT NULL DEFAULT N'nearby';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407185945_PrivacyRealtimeLocalization'
)
BEGIN
    ALTER TABLE [Users] ADD [PreferredLanguage] nvarchar(8) NOT NULL DEFAULT N'tr';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407185945_PrivacyRealtimeLocalization'
)
BEGIN
    CREATE TABLE [UserDataExports] (
        [Id] uniqueidentifier NOT NULL,
        [UserId] nvarchar(128) NOT NULL,
        [FileName] nvarchar(260) NOT NULL,
        [RelativePath] nvarchar(512) NOT NULL,
        [Status] nvarchar(32) NOT NULL,
        [FileSizeBytes] bigint NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        [ExpiresAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_UserDataExports] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_UserDataExports_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407185945_PrivacyRealtimeLocalization'
)
BEGIN
    CREATE INDEX [IX_UserDataExports_ExpiresAt] ON [UserDataExports] ([ExpiresAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407185945_PrivacyRealtimeLocalization'
)
BEGIN
    CREATE INDEX [IX_UserDataExports_UserId_CreatedAt] ON [UserDataExports] ([UserId], [CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407185945_PrivacyRealtimeLocalization'
)
BEGIN
    CREATE OR ALTER VIEW dbo.vw_UserPresencePrivacyProjection
    AS
    SELECT
        u.Id,
        u.Email,
        u.UserName,
        u.DisplayName,
        u.Bio,
        COALESCE(NULLIF(p.City, N''), u.City, N'') AS City,
        u.Website,
        u.Gender,
        u.Age,
        u.Purpose,
        COALESCE(NULLIF(p.Mode, N''), u.Mode, N'kesif') AS Mode,
        u.PrivacyLevel,
        u.PreferredLanguage,
        u.LocationGranularity,
        u.EnableDifferentialPrivacy,
        u.KAnonymityLevel,
        u.AllowAnalytics,
        u.IsVisible,
        u.IsOnline,
        u.ProfilePhotoUrl,
        u.PhotoUrls,
        u.Interests,
        COALESCE(p.Latitude, u.Latitude) AS Latitude,
        COALESCE(p.Longitude, u.Longitude) AS Longitude,
        u.LastSeenAt,
        u.FollowersCount,
        u.FollowingCount,
        u.FriendsCount,
        u.PulseScore,
        u.PlacesVisited,
        u.VibeTagsCreated,
        ISNULL(p.ShareProfile, CAST(1 AS bit)) AS ShareProfile,
        ISNULL(p.IsSignalActive, CAST(0 AS bit)) AS IsSignalActive
    FROM Users AS u
    LEFT JOIN Presences AS p ON p.UserId = u.Id;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407185945_PrivacyRealtimeLocalization'
)
BEGIN
    CREATE OR ALTER FUNCTION dbo.fn_GetNearbyVisibleUsers
    (
        @CurrentUserId nvarchar(128),
        @Latitude float,
        @Longitude float,
        @RadiusKm float
    )
    RETURNS TABLE
    AS
    RETURN
    SELECT
        projection.Id,
        projection.Email,
        projection.UserName,
        projection.DisplayName,
        projection.Bio,
        projection.City,
        projection.Website,
        projection.Gender,
        projection.Age,
        projection.Purpose,
        projection.Mode,
        projection.PrivacyLevel,
        projection.PreferredLanguage,
        projection.LocationGranularity,
        projection.EnableDifferentialPrivacy,
        projection.KAnonymityLevel,
        projection.AllowAnalytics,
        projection.IsVisible,
        projection.IsOnline,
        projection.ProfilePhotoUrl,
        projection.PhotoUrls,
        projection.Interests,
        projection.Latitude,
        projection.Longitude,
        projection.LastSeenAt,
        projection.FollowersCount,
        projection.FollowingCount,
        projection.FriendsCount,
        projection.PulseScore,
        projection.PlacesVisited,
        projection.VibeTagsCreated,
        CAST(
            geography::Point(@Latitude, @Longitude, 4326).STDistance(
                geography::Point(projection.Latitude, projection.Longitude, 4326)
            ) AS float
        ) AS DistanceMeters,
        projection.ShareProfile,
        projection.IsSignalActive
    FROM dbo.vw_UserPresencePrivacyProjection AS projection
    WHERE
        projection.Id <> @CurrentUserId
        AND projection.IsVisible = 1
        AND projection.IsOnline = 1
        AND projection.IsSignalActive = 1
        AND projection.Latitude IS NOT NULL
        AND projection.Longitude IS NOT NULL
        AND CAST(
            geography::Point(@Latitude, @Longitude, 4326).STDistance(
                geography::Point(projection.Latitude, projection.Longitude, 4326)
            ) AS float
        ) <= (@RadiusKm * 1000.0);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407185945_PrivacyRealtimeLocalization'
)
BEGIN
    CREATE OR ALTER PROCEDURE dbo.usp_DeleteUserDataExport
        @ExportId uniqueidentifier
    AS
    BEGIN
        SET NOCOUNT ON;

        DELETE FROM UserDataExports
        WHERE Id = @ExportId;
    END
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260407185945_PrivacyRealtimeLocalization'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260407185945_PrivacyRealtimeLocalization', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260408224833_StoryHighlightMetadata'
)
BEGIN
    ALTER TABLE [Highlights] ADD [LocationLabel] nvarchar(160) NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260408224833_StoryHighlightMetadata'
)
BEGIN
    ALTER TABLE [Highlights] ADD [MediaUrls] nvarchar(max) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260408224833_StoryHighlightMetadata'
)
BEGIN
    ALTER TABLE [Highlights] ADD [ModeTag] nvarchar(32) NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260408224833_StoryHighlightMetadata'
)
BEGIN
    ALTER TABLE [Highlights] ADD [PlaceId] nvarchar(160) NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260408224833_StoryHighlightMetadata'
)
BEGIN
    ALTER TABLE [Highlights] ADD [TextColorHex] nvarchar(16) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260408224833_StoryHighlightMetadata'
)
BEGIN
    ALTER TABLE [Highlights] ADD [TextOffsetX] float NOT NULL DEFAULT 0.0E0;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260408224833_StoryHighlightMetadata'
)
BEGIN
    ALTER TABLE [Highlights] ADD [TextOffsetY] float NOT NULL DEFAULT 0.0E0;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260408224833_StoryHighlightMetadata'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260408224833_StoryHighlightMetadata', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260408231034_StoryHighlightOverlayFlags'
)
BEGIN
    ALTER TABLE [Highlights] ADD [ShowLocationOverlay] bit NOT NULL DEFAULT CAST(0 AS bit);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260408231034_StoryHighlightOverlayFlags'
)
BEGIN
    ALTER TABLE [Highlights] ADD [ShowModeOverlay] bit NOT NULL DEFAULT CAST(0 AS bit);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260408231034_StoryHighlightOverlayFlags'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260408231034_StoryHighlightOverlayFlags', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409094943_StoryEntryKindsAndModelSync'
)
BEGIN
    DROP INDEX [IX_Highlights_UserId_CreatedAt] ON [Highlights];
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409094943_StoryEntryKindsAndModelSync'
)
BEGIN
    ALTER TABLE [Highlights] ADD [EntryKind] nvarchar(24) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409094943_StoryEntryKindsAndModelSync'
)
BEGIN
    ALTER TABLE [Highlights] ADD [ExpiresAt] datetimeoffset NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409094943_StoryEntryKindsAndModelSync'
)
BEGIN
    CREATE INDEX [IX_Highlights_ExpiresAt] ON [Highlights] ([ExpiresAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409094943_StoryEntryKindsAndModelSync'
)
BEGIN
    CREATE INDEX [IX_Highlights_UserId_EntryKind_CreatedAt] ON [Highlights] ([UserId], [EntryKind], [CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409094943_StoryEntryKindsAndModelSync'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260409094943_StoryEntryKindsAndModelSync', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409111852_PasswordResetAndStoryViews'
)
BEGIN
    CREATE TABLE [PasswordResetTokens] (
        [Id] uniqueidentifier NOT NULL,
        [UserId] nvarchar(128) NOT NULL,
        [TokenHash] nvarchar(512) NOT NULL,
        [ExpiresAt] datetimeoffset NOT NULL,
        [UsedAt] datetimeoffset NULL,
        [RequestedIp] nvarchar(128) NOT NULL,
        [UserAgent] nvarchar(512) NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_PasswordResetTokens] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_PasswordResetTokens_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409111852_PasswordResetAndStoryViews'
)
BEGIN
    CREATE TABLE [StoryViews] (
        [Id] uniqueidentifier NOT NULL,
        [StoryId] uniqueidentifier NOT NULL,
        [ViewerUserId] nvarchar(128) NOT NULL,
        [ViewedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_StoryViews] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_StoryViews_Highlights_StoryId] FOREIGN KEY ([StoryId]) REFERENCES [Highlights] ([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_StoryViews_Users_ViewerUserId] FOREIGN KEY ([ViewerUserId]) REFERENCES [Users] ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409111852_PasswordResetAndStoryViews'
)
BEGIN
    CREATE INDEX [IX_PasswordResetTokens_ExpiresAt] ON [PasswordResetTokens] ([ExpiresAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409111852_PasswordResetAndStoryViews'
)
BEGIN
    CREATE INDEX [IX_PasswordResetTokens_UserId_CreatedAt] ON [PasswordResetTokens] ([UserId], [CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409111852_PasswordResetAndStoryViews'
)
BEGIN
    CREATE INDEX [IX_StoryViews_StoryId_ViewedAt] ON [StoryViews] ([StoryId], [ViewedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409111852_PasswordResetAndStoryViews'
)
BEGIN
    CREATE UNIQUE INDEX [IX_StoryViews_StoryId_ViewerUserId] ON [StoryViews] ([StoryId], [ViewerUserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409111852_PasswordResetAndStoryViews'
)
BEGIN
    CREATE INDEX [IX_StoryViews_ViewerUserId] ON [StoryViews] ([ViewerUserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409111852_PasswordResetAndStoryViews'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260409111852_PasswordResetAndStoryViews', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409185720_PresenceProfileAndNearbySync'
)
BEGIN
    ALTER TABLE [Users] ADD [BirthDate] date NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409185720_PresenceProfileAndNearbySync'
)
BEGIN
    ALTER TABLE [Users] ADD [FirstName] nvarchar(64) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409185720_PresenceProfileAndNearbySync'
)
BEGIN
    ALTER TABLE [Users] ADD [LastName] nvarchar(64) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409185720_PresenceProfileAndNearbySync'
)
BEGIN
    ALTER TABLE [Users] ADD [MatchPreference] nvarchar(16) NOT NULL DEFAULT N'auto';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409185720_PresenceProfileAndNearbySync'
)
BEGIN
    UPDATE Users
    SET
        FirstName = CASE
            WHEN LTRIM(RTRIM(ISNULL(FirstName, N''))) <> N'' THEN LTRIM(RTRIM(FirstName))
            WHEN CHARINDEX(N' ', LTRIM(RTRIM(ISNULL(DisplayName, N'')))) > 0 THEN LEFT(LTRIM(RTRIM(DisplayName)), CHARINDEX(N' ', LTRIM(RTRIM(DisplayName))) - 1)
            WHEN LTRIM(RTRIM(ISNULL(DisplayName, N''))) <> N'' THEN LTRIM(RTRIM(DisplayName))
            ELSE UserName
        END,
        LastName = CASE
            WHEN LTRIM(RTRIM(ISNULL(LastName, N''))) <> N'' THEN LTRIM(RTRIM(LastName))
            WHEN CHARINDEX(N' ', LTRIM(RTRIM(ISNULL(DisplayName, N'')))) > 0 THEN LTRIM(SUBSTRING(LTRIM(RTRIM(DisplayName)), CHARINDEX(N' ', LTRIM(RTRIM(DisplayName))) + 1, 200))
            ELSE N''
        END,
        MatchPreference = CASE
            WHEN LTRIM(RTRIM(ISNULL(MatchPreference, N''))) <> N'' AND LOWER(LTRIM(RTRIM(MatchPreference))) <> N'auto' THEN LOWER(LTRIM(RTRIM(MatchPreference)))
            WHEN LOWER(LTRIM(RTRIM(ISNULL(Gender, N'')))) IN (N'male', N'man', N'erkek') THEN N'women'
            WHEN LOWER(LTRIM(RTRIM(ISNULL(Gender, N'')))) IN (N'female', N'woman', N'kadin', N'kadın') THEN N'men'
            ELSE N'everyone'
        END;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409185720_PresenceProfileAndNearbySync'
)
BEGIN
    CREATE OR ALTER VIEW dbo.vw_UserPresencePrivacyProjection
    AS
    SELECT
        u.Id,
        u.UserName,
        u.DisplayName,
        u.Bio,
        COALESCE(NULLIF(p.City, N''), u.City, N'') AS City,
        u.Gender,
        COALESCE(NULLIF(p.Mode, N''), u.Mode, N'kesif') AS Mode,
        u.MatchPreference,
        u.PrivacyLevel,
        u.LocationGranularity,
        u.EnableDifferentialPrivacy,
        u.KAnonymityLevel,
        u.IsVisible,
        u.IsOnline,
        u.ProfilePhotoUrl,
        u.Interests,
        COALESCE(p.Latitude, u.Latitude) AS Latitude,
        COALESCE(p.Longitude, u.Longitude) AS Longitude,
        u.LastSeenAt,
        u.FollowersCount,
        u.FollowingCount,
        u.FriendsCount,
        u.PulseScore,
        u.PlacesVisited,
        u.VibeTagsCreated,
        ISNULL(p.ShareProfile, CAST(1 AS bit)) AS ShareProfile,
        ISNULL(p.IsSignalActive, CAST(0 AS bit)) AS IsSignalActive
    FROM Users AS u
    LEFT JOIN Presences AS p ON p.UserId = u.Id;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409185720_PresenceProfileAndNearbySync'
)
BEGIN
    CREATE OR ALTER FUNCTION dbo.fn_GetNearbyVisibleUsers
    (
        @CurrentUserId nvarchar(128),
        @Latitude float,
        @Longitude float,
        @RadiusKm float
    )
    RETURNS TABLE
    AS
    RETURN
    SELECT
        projection.Id,
        projection.UserName,
        projection.DisplayName,
        projection.Bio,
        projection.City,
        projection.Gender,
        projection.Mode,
        projection.MatchPreference,
        projection.PrivacyLevel,
        projection.LocationGranularity,
        projection.IsVisible,
        projection.IsOnline,
        projection.ProfilePhotoUrl,
        projection.Interests,
        projection.Latitude,
        projection.Longitude,
        projection.LastSeenAt,
        projection.FollowersCount,
        projection.FollowingCount,
        projection.FriendsCount,
        projection.PulseScore,
        projection.PlacesVisited,
        projection.VibeTagsCreated,
        CAST(
            geography::Point(@Latitude, @Longitude, 4326).STDistance(
                geography::Point(projection.Latitude, projection.Longitude, 4326)
            ) AS float
        ) AS DistanceMeters,
        projection.ShareProfile,
        projection.IsSignalActive,
        projection.EnableDifferentialPrivacy,
        projection.KAnonymityLevel
    FROM dbo.vw_UserPresencePrivacyProjection AS projection
    WHERE
        projection.Id <> @CurrentUserId
        AND projection.IsVisible = 1
        AND projection.IsOnline = 1
        AND projection.Latitude IS NOT NULL
        AND projection.Longitude IS NOT NULL
        AND CAST(
            geography::Point(@Latitude, @Longitude, 4326).STDistance(
                geography::Point(projection.Latitude, projection.Longitude, 4326)
            ) AS float
        ) <= (@RadiusKm * 1000.0);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409185720_PresenceProfileAndNearbySync'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260409185720_PresenceProfileAndNearbySync', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409220454_AccountLockoutAndResetAttempts'
)
BEGIN
    ALTER TABLE [UserCredentials] ADD [FailedLoginAttempts] int NOT NULL DEFAULT 0;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409220454_AccountLockoutAndResetAttempts'
)
BEGIN
    ALTER TABLE [UserCredentials] ADD [LockoutEnd] datetimeoffset NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409220454_AccountLockoutAndResetAttempts'
)
BEGIN
    ALTER TABLE [PasswordResetTokens] ADD [Attempts] int NOT NULL DEFAULT 0;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409220454_AccountLockoutAndResetAttempts'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260409220454_AccountLockoutAndResetAttempts', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409223543_AddChatAndPostIndexesAndCommentOps'
)
BEGIN
    DROP INDEX [IX_Posts_UserId] ON [Posts];
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409223543_AddChatAndPostIndexesAndCommentOps'
)
BEGIN
    CREATE INDEX [IX_Posts_Latitude_Longitude] ON [Posts] ([Latitude], [Longitude]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409223543_AddChatAndPostIndexesAndCommentOps'
)
BEGIN
    CREATE INDEX [IX_Posts_UserId_CreatedAt] ON [Posts] ([UserId], [CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409223543_AddChatAndPostIndexesAndCommentOps'
)
BEGIN
    CREATE INDEX [IX_Chats_ExpiresAt] ON [Chats] ([ExpiresAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409223543_AddChatAndPostIndexesAndCommentOps'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260409223543_AddChatAndPostIndexesAndCommentOps', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409225523_AddChatArchiveSupport'
)
BEGIN
    ALTER TABLE [ChatParticipants] ADD [ArchivedAt] datetimeoffset NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409225523_AddChatArchiveSupport'
)
BEGIN
    ALTER TABLE [ChatParticipants] ADD [IsArchived] bit NOT NULL DEFAULT CAST(0 AS bit);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409225523_AddChatArchiveSupport'
)
BEGIN
    CREATE INDEX [IX_ChatParticipants_UserId_IsArchived_JoinedAt] ON [ChatParticipants] ([UserId], [IsArchived], [JoinedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260409225523_AddChatArchiveSupport'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260409225523_AddChatArchiveSupport', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260411120000_ChatMessageVisibilityHardening'
)
BEGIN
    ALTER TABLE [ChatParticipants] ADD [DeletedAt] datetimeoffset NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260411120000_ChatMessageVisibilityHardening'
)
BEGIN
    ALTER TABLE [ChatMessages] ADD [DeletedAt] datetimeoffset NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260411120000_ChatMessageVisibilityHardening'
)
BEGIN
    ALTER TABLE [ChatMessages] ADD [DeletedByUserId] nvarchar(128) NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260411120000_ChatMessageVisibilityHardening'
)
BEGIN
    ALTER TABLE [ChatMessages] ADD [UpdatedAt] datetimeoffset NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260411120000_ChatMessageVisibilityHardening'
)
BEGIN
    CREATE TABLE [ChatMessageHiddenStates] (
        [Id] uniqueidentifier NOT NULL,
        [MessageId] uniqueidentifier NOT NULL,
        [UserId] nvarchar(128) NOT NULL,
        [HiddenAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_ChatMessageHiddenStates] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ChatMessageHiddenStates_ChatMessages_MessageId] FOREIGN KEY ([MessageId]) REFERENCES [ChatMessages] ([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_ChatMessageHiddenStates_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260411120000_ChatMessageVisibilityHardening'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_ChatMessageHiddenStates_MessageId_UserId] ON [ChatMessageHiddenStates] ([MessageId], [UserId]) WHERE [MessageId] IS NOT NULL AND [UserId] IS NOT NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260411120000_ChatMessageVisibilityHardening'
)
BEGIN
    CREATE INDEX [IX_ChatMessageHiddenStates_UserId_HiddenAt] ON [ChatMessageHiddenStates] ([UserId], [HiddenAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260411120000_ChatMessageVisibilityHardening'
)
BEGIN
    CREATE INDEX [IX_ChatMessages_ChatId_DeletedAt] ON [ChatMessages] ([ChatId], [DeletedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260411120000_ChatMessageVisibilityHardening'
)
BEGIN
    CREATE INDEX [IX_ChatParticipants_UserId_DeletedAt] ON [ChatParticipants] ([UserId], [DeletedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260411120000_ChatMessageVisibilityHardening'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260411120000_ChatMessageVisibilityHardening', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260412104442_AddDeviceTokens'
)
BEGIN
    CREATE TABLE [DeviceTokens] (
        [Id] uniqueidentifier NOT NULL,
        [UserId] nvarchar(128) NOT NULL,
        [Token] nvarchar(512) NOT NULL,
        [Platform] nvarchar(16) NOT NULL,
        [RegisteredAt] datetimeoffset NOT NULL,
        [UpdatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_DeviceTokens] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_DeviceTokens_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260412104442_AddDeviceTokens'
)
BEGIN
    CREATE UNIQUE INDEX [IX_DeviceTokens_Token] ON [DeviceTokens] ([Token]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260412104442_AddDeviceTokens'
)
BEGIN
    CREATE INDEX [IX_DeviceTokens_UserId_UpdatedAt] ON [DeviceTokens] ([UserId], [UpdatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260412104442_AddDeviceTokens'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260412104442_AddDeviceTokens', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260412212352_AddMatchAnonAndChatPermanence'
)
BEGIN
    ALTER TABLE [Matches] ADD [Initiator1AnonymousInChat] bit NOT NULL DEFAULT CAST(0 AS bit);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260412212352_AddMatchAnonAndChatPermanence'
)
BEGIN
    ALTER TABLE [Chats] ADD [PendingFriendRequestFromUserId] nvarchar(max) NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260412212352_AddMatchAnonAndChatPermanence'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260412212352_AddMatchAnonAndChatPermanence', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260418222335_AddResponder2AnonymousInChat'
)
BEGIN
    ALTER TABLE [Matches] ADD [Responder2AnonymousInChat] bit NOT NULL DEFAULT CAST(0 AS bit);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260418222335_AddResponder2AnonymousInChat'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260418222335_AddResponder2AnonymousInChat', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419132549_AddProfilePhase3Fields'
)
BEGIN
    ALTER TABLE [Users] ADD [PinnedAt] datetimeoffset NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419132549_AddProfilePhase3Fields'
)
BEGIN
    ALTER TABLE [Users] ADD [PinnedPostId] uniqueidentifier NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419132549_AddProfilePhase3Fields'
)
BEGIN
    CREATE TABLE [SignalCrossings] (
        [Id] uniqueidentifier NOT NULL,
        [UserAId] nvarchar(128) NOT NULL,
        [UserBId] nvarchar(128) NOT NULL,
        [CrossedAt] datetimeoffset NOT NULL,
        [PlaceId] nvarchar(160) NOT NULL,
        [LocationLabel] nvarchar(160) NOT NULL,
        [ApproxLatitude] float NULL,
        [ApproxLongitude] float NULL,
        CONSTRAINT [PK_SignalCrossings] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_SignalCrossings_Users_UserAId] FOREIGN KEY ([UserAId]) REFERENCES [Users] ([Id]),
        CONSTRAINT [FK_SignalCrossings_Users_UserBId] FOREIGN KEY ([UserBId]) REFERENCES [Users] ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419132549_AddProfilePhase3Fields'
)
BEGIN
    CREATE INDEX [IX_Users_PinnedPostId] ON [Users] ([PinnedPostId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419132549_AddProfilePhase3Fields'
)
BEGIN
    CREATE INDEX [IX_SignalCrossings_CrossedAt] ON [SignalCrossings] ([CrossedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419132549_AddProfilePhase3Fields'
)
BEGIN
    CREATE INDEX [IX_SignalCrossings_UserAId_UserBId_CrossedAt] ON [SignalCrossings] ([UserAId], [UserBId], [CrossedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419132549_AddProfilePhase3Fields'
)
BEGIN
    CREATE INDEX [IX_SignalCrossings_UserBId] ON [SignalCrossings] ([UserBId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419132549_AddProfilePhase3Fields'
)
BEGIN
    ALTER TABLE [Users] ADD CONSTRAINT [FK_Users_Posts_PinnedPostId] FOREIGN KEY ([PinnedPostId]) REFERENCES [Posts] ([Id]) ON DELETE SET NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419132549_AddProfilePhase3Fields'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260419132549_AddProfilePhase3Fields', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419190004_AddDatingFieldsAndFeatureFlags'
)
BEGIN
    ALTER TABLE [Users] ADD [DatingPrompts] nvarchar(max) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419190004_AddDatingFieldsAndFeatureFlags'
)
BEGIN
    ALTER TABLE [Users] ADD [Dealbreakers] nvarchar(max) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419190004_AddDatingFieldsAndFeatureFlags'
)
BEGIN
    ALTER TABLE [Users] ADD [DrinkingStatus] nvarchar(24) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419190004_AddDatingFieldsAndFeatureFlags'
)
BEGIN
    ALTER TABLE [Users] ADD [EnabledFeatures] nvarchar(max) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419190004_AddDatingFieldsAndFeatureFlags'
)
BEGIN
    ALTER TABLE [Users] ADD [HeightCm] int NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419190004_AddDatingFieldsAndFeatureFlags'
)
BEGIN
    ALTER TABLE [Users] ADD [IsPhotoVerified] bit NOT NULL DEFAULT CAST(0 AS bit);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419190004_AddDatingFieldsAndFeatureFlags'
)
BEGIN
    ALTER TABLE [Users] ADD [LookingForModes] nvarchar(max) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419190004_AddDatingFieldsAndFeatureFlags'
)
BEGIN
    ALTER TABLE [Users] ADD [Orientation] nvarchar(24) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419190004_AddDatingFieldsAndFeatureFlags'
)
BEGIN
    ALTER TABLE [Users] ADD [RelationshipIntent] nvarchar(24) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419190004_AddDatingFieldsAndFeatureFlags'
)
BEGIN
    ALTER TABLE [Users] ADD [SmokingStatus] nvarchar(24) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419190004_AddDatingFieldsAndFeatureFlags'
)
BEGIN
    CREATE INDEX [IX_Users_Mode] ON [Users] ([Mode]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419190004_AddDatingFieldsAndFeatureFlags'
)
BEGIN
    CREATE INDEX [IX_Users_RelationshipIntent] ON [Users] ([RelationshipIntent]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260419190004_AddDatingFieldsAndFeatureFlags'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260419190004_AddDatingFieldsAndFeatureFlags', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260420110751_AddDiscoverPass'
)
BEGIN
    CREATE TABLE [DiscoverPasses] (
        [Id] uniqueidentifier NOT NULL,
        [UserId] nvarchar(128) NOT NULL,
        [TargetUserId] nvarchar(128) NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_DiscoverPasses] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_DiscoverPasses_Users_TargetUserId] FOREIGN KEY ([TargetUserId]) REFERENCES [Users] ([Id]),
        CONSTRAINT [FK_DiscoverPasses_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260420110751_AddDiscoverPass'
)
BEGIN
    CREATE INDEX [IX_DiscoverPasses_TargetUserId] ON [DiscoverPasses] ([TargetUserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260420110751_AddDiscoverPass'
)
BEGIN
    CREATE INDEX [IX_DiscoverPasses_UserId_CreatedAt] ON [DiscoverPasses] ([UserId], [CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260420110751_AddDiscoverPass'
)
BEGIN
    CREATE UNIQUE INDEX [IX_DiscoverPasses_UserId_TargetUserId] ON [DiscoverPasses] ([UserId], [TargetUserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260420110751_AddDiscoverPass'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260420110751_AddDiscoverPass', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260426111649_AddNotifications'
)
BEGIN
    CREATE TABLE [Notifications] (
        [Id] uniqueidentifier NOT NULL,
        [RecipientUserId] nvarchar(128) NOT NULL,
        [ActorUserId] nvarchar(128) NULL,
        [Type] int NOT NULL,
        [Title] nvarchar(160) NOT NULL,
        [Body] nvarchar(512) NOT NULL,
        [DeepLink] nvarchar(512) NULL,
        [RelatedEntityType] nvarchar(64) NULL,
        [RelatedEntityId] nvarchar(128) NULL,
        [IsRead] bit NOT NULL,
        [ReadAt] datetimeoffset NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_Notifications] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_Notifications_Users_RecipientUserId] FOREIGN KEY ([RecipientUserId]) REFERENCES [Users] ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260426111649_AddNotifications'
)
BEGIN
    CREATE INDEX [IX_Notifications_RecipientUserId_CreatedAt] ON [Notifications] ([RecipientUserId], [CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260426111649_AddNotifications'
)
BEGIN
    CREATE INDEX [IX_Notifications_RecipientUserId_IsRead_CreatedAt] ON [Notifications] ([RecipientUserId], [IsRead], [CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260426111649_AddNotifications'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260426111649_AddNotifications', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260426161759_AddActivities'
)
BEGIN
    CREATE TABLE [Activities] (
        [Id] uniqueidentifier NOT NULL,
        [HostUserId] nvarchar(128) NOT NULL,
        [Title] nvarchar(160) NOT NULL,
        [Description] nvarchar(2000) NOT NULL,
        [Category] int NOT NULL,
        [Mode] nvarchar(32) NOT NULL,
        [CoverImageUrl] nvarchar(512) NULL,
        [LocationName] nvarchar(200) NOT NULL,
        [LocationAddress] nvarchar(400) NULL,
        [Latitude] float NOT NULL,
        [Longitude] float NOT NULL,
        [City] nvarchar(120) NOT NULL,
        [NormalizedCity] nvarchar(120) NOT NULL,
        [StartsAt] datetimeoffset NOT NULL,
        [EndsAt] datetimeoffset NULL,
        [ReminderMinutesBefore] int NOT NULL,
        [ReminderSent] bit NOT NULL,
        [MaxParticipants] int NULL,
        [CurrentParticipantCount] int NOT NULL,
        [Visibility] int NOT NULL,
        [JoinPolicy] int NOT NULL,
        [RequiresVerification] bit NOT NULL,
        [Interests] nvarchar(max) NOT NULL,
        [MinAge] int NULL,
        [MaxAge] int NULL,
        [PreferredGender] nvarchar(24) NOT NULL,
        [Status] int NOT NULL,
        [CancellationReason] nvarchar(400) NULL,
        [CancelledAt] datetimeoffset NULL,
        [CompletedAt] datetimeoffset NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        [UpdatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_Activities] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_Activities_Users_HostUserId] FOREIGN KEY ([HostUserId]) REFERENCES [Users] ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260426161759_AddActivities'
)
BEGIN
    CREATE TABLE [ActivityParticipations] (
        [Id] uniqueidentifier NOT NULL,
        [ActivityId] uniqueidentifier NOT NULL,
        [UserId] nvarchar(128) NOT NULL,
        [Status] int NOT NULL,
        [JoinMessage] nvarchar(400) NULL,
        [ResponseNote] nvarchar(400) NULL,
        [RequestedAt] datetimeoffset NOT NULL,
        [RespondedAt] datetimeoffset NULL,
        [CancelledAt] datetimeoffset NULL,
        CONSTRAINT [PK_ActivityParticipations] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ActivityParticipations_Activities_ActivityId] FOREIGN KEY ([ActivityId]) REFERENCES [Activities] ([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_ActivityParticipations_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260426161759_AddActivities'
)
BEGIN
    CREATE INDEX [IX_Activities_Category_Status_StartsAt] ON [Activities] ([Category], [Status], [StartsAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260426161759_AddActivities'
)
BEGIN
    CREATE INDEX [IX_Activities_HostUserId_Status_StartsAt] ON [Activities] ([HostUserId], [Status], [StartsAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260426161759_AddActivities'
)
BEGIN
    CREATE INDEX [IX_Activities_Latitude_Longitude] ON [Activities] ([Latitude], [Longitude]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260426161759_AddActivities'
)
BEGIN
    CREATE INDEX [IX_Activities_NormalizedCity_Status_StartsAt] ON [Activities] ([NormalizedCity], [Status], [StartsAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260426161759_AddActivities'
)
BEGIN
    CREATE INDEX [IX_Activities_Status_StartsAt] ON [Activities] ([Status], [StartsAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260426161759_AddActivities'
)
BEGIN
    CREATE INDEX [IX_ActivityParticipations_ActivityId_Status] ON [ActivityParticipations] ([ActivityId], [Status]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260426161759_AddActivities'
)
BEGIN
    CREATE UNIQUE INDEX [IX_ActivityParticipations_ActivityId_UserId] ON [ActivityParticipations] ([ActivityId], [UserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260426161759_AddActivities'
)
BEGIN
    CREATE INDEX [IX_ActivityParticipations_UserId_Status_RequestedAt] ON [ActivityParticipations] ([UserId], [Status], [RequestedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260426161759_AddActivities'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260426161759_AddActivities', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427112234_AddPhotoVerificationStatus'
)
BEGIN
    ALTER TABLE [Users] ADD [VerificationSelfieUrl] nvarchar(max) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427112234_AddPhotoVerificationStatus'
)
BEGIN
    ALTER TABLE [Users] ADD [VerificationStatus] nvarchar(max) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427112234_AddPhotoVerificationStatus'
)
BEGIN
    ALTER TABLE [Users] ADD [VerificationSubmittedAt] datetimeoffset NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427112234_AddPhotoVerificationStatus'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260427112234_AddPhotoVerificationStatus', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427112844_AddActivityRecurrence'
)
BEGIN
    ALTER TABLE [Activities] ADD [RecurrenceParentId] uniqueidentifier NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427112844_AddActivityRecurrence'
)
BEGIN
    ALTER TABLE [Activities] ADD [RecurrenceRule] nvarchar(max) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427112844_AddActivityRecurrence'
)
BEGIN
    ALTER TABLE [Activities] ADD [RecurrenceUntil] datetimeoffset NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427112844_AddActivityRecurrence'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260427112844_AddActivityRecurrence', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427163416_AddActivityGroupChat'
)
BEGIN
    ALTER TABLE [Chats] ADD [ActivityId] uniqueidentifier NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427163416_AddActivityGroupChat'
)
BEGIN
    ALTER TABLE [Chats] ADD [Kind] nvarchar(16) NOT NULL DEFAULT N'direct';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427163416_AddActivityGroupChat'
)
BEGIN
    ALTER TABLE [Chats] ADD [Title] nvarchar(200) NOT NULL DEFAULT N'';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427163416_AddActivityGroupChat'
)
BEGIN
    CREATE INDEX [IX_Chats_ActivityId] ON [Chats] ([ActivityId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427163416_AddActivityGroupChat'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260427163416_AddActivityGroupChat', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427164832_AddActivityRatings'
)
BEGIN
    ALTER TABLE [Users] ADD [ActivityRatingAverage] float NOT NULL DEFAULT 0.0E0;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427164832_AddActivityRatings'
)
BEGIN
    ALTER TABLE [Users] ADD [ActivityRatingCount] int NOT NULL DEFAULT 0;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427164832_AddActivityRatings'
)
BEGIN
    CREATE TABLE [ActivityRatings] (
        [Id] uniqueidentifier NOT NULL,
        [ActivityId] uniqueidentifier NOT NULL,
        [RaterUserId] nvarchar(128) NOT NULL,
        [RatedUserId] nvarchar(128) NOT NULL,
        [Score] int NOT NULL,
        [Comment] nvarchar(800) NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_ActivityRatings] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ActivityRatings_Activities_ActivityId] FOREIGN KEY ([ActivityId]) REFERENCES [Activities] ([Id]) ON DELETE CASCADE,
        CONSTRAINT [FK_ActivityRatings_Users_RatedUserId] FOREIGN KEY ([RatedUserId]) REFERENCES [Users] ([Id]),
        CONSTRAINT [FK_ActivityRatings_Users_RaterUserId] FOREIGN KEY ([RaterUserId]) REFERENCES [Users] ([Id])
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427164832_AddActivityRatings'
)
BEGIN
    CREATE INDEX [IX_ActivityRatings_ActivityId] ON [ActivityRatings] ([ActivityId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427164832_AddActivityRatings'
)
BEGIN
    CREATE UNIQUE INDEX [IX_ActivityRatings_ActivityId_RaterUserId_RatedUserId] ON [ActivityRatings] ([ActivityId], [RaterUserId], [RatedUserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427164832_AddActivityRatings'
)
BEGIN
    CREATE INDEX [IX_ActivityRatings_RatedUserId] ON [ActivityRatings] ([RatedUserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427164832_AddActivityRatings'
)
BEGIN
    CREATE INDEX [IX_ActivityRatings_RaterUserId] ON [ActivityRatings] ([RaterUserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427164832_AddActivityRatings'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260427164832_AddActivityRatings', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427231831_AddUserBadges'
)
BEGIN
    CREATE TABLE [UserBadges] (
        [Id] uniqueidentifier NOT NULL,
        [UserId] nvarchar(128) NOT NULL,
        [BadgeCode] nvarchar(32) NOT NULL,
        [Tier] int NOT NULL,
        [EarnedAt] datetimeoffset NOT NULL,
        [Progress] int NOT NULL,
        CONSTRAINT [PK_UserBadges] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_UserBadges_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427231831_AddUserBadges'
)
BEGIN
    CREATE INDEX [IX_UserBadges_UserId] ON [UserBadges] ([UserId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427231831_AddUserBadges'
)
BEGIN
    CREATE UNIQUE INDEX [IX_UserBadges_UserId_BadgeCode] ON [UserBadges] ([UserId], [BadgeCode]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260427231831_AddUserBadges'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260427231831_AddUserBadges', N'9.0.11');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260429000000_AddActivityPlaceId'
)
BEGIN
    ALTER TABLE [Activities] ADD [PlaceId] nvarchar(128) NULL;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260429000000_AddActivityPlaceId'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260429000000_AddActivityPlaceId', N'9.0.11');
END;

COMMIT;
GO

