using Google.Apis.Auth;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;
using PulseCity.Domain.Entities;
using PulseCity.Infrastructure.Data;
using PulseCity.Infrastructure.Internal;
using PulseCity.Infrastructure.Options;
using System.Security.Cryptography;
using System.Text;

namespace PulseCity.Infrastructure.Services;

public sealed class AuthService(
    PulseCityDbContext dbContext,
    JwtTokenService jwtTokenService,
    IEmailSender emailSender,
    IOptions<SmtpOptions> smtpOptions
) : IAuthService
{
    private readonly PasswordHasher<UserCredential> _passwordHasher = new();
    private readonly PasswordHasher<PasswordResetToken> _passwordResetHasher = new();

    public async Task<AuthResponseDto> RegisterAsync(
        RegisterRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var firstName = request.FirstName.Trim();
        // LastName opsiyonel — anonimlik vaadi gereği yeni kayıt akışı göndermez,
        // ama eski istemcilerle uyumluluk için kabul edilir.
        var lastName = request.LastName?.Trim() ?? string.Empty;
        var city = request.City.Trim();
        var gender = NormalizeGender(request.Gender);
        var matchPreference = NormalizeMatchPreference(
            request.MatchPreference,
            gender
        );
        var mode = NormalizeMode(request.Mode);
        var birthDate = request.BirthDate.Date;
        var age = CalculateAge(birthDate);

        if (string.IsNullOrWhiteSpace(firstName))
        {
            throw new InvalidOperationException("First name is required.");
        }
        if (string.IsNullOrWhiteSpace(city))
        {
            throw new InvalidOperationException("City is required.");
        }
        if (string.IsNullOrWhiteSpace(gender))
        {
            throw new InvalidOperationException("Gender is required.");
        }
        if (age < 18)
        {
            throw new InvalidOperationException("You must be at least 18 years old.");
        }

        if (
            await dbContext.UserCredentials.AsNoTracking().AnyAsync(
                entry => entry.Email == email,
                cancellationToken
            )
        )
        {
            throw new InvalidOperationException("This email is already in use.");
        }

        var userId = Guid.NewGuid().ToString("N");
        var username = TextNormalizer.BuildUserName(email, userId);
        var displayName = string.IsNullOrWhiteSpace(lastName)
            ? firstName
            : $"{firstName} {lastName}".Trim();
        var profile = new UserProfile
        {
            Id = userId,
            Email = email,
            FirstName = firstName,
            LastName = lastName,
            UserName = username,
            NormalizedUserName = TextNormalizer.Normalize(username),
            DisplayName = string.IsNullOrWhiteSpace(displayName) ? username : displayName,
            NormalizedDisplayName = TextNormalizer.Normalize(
                string.IsNullOrWhiteSpace(displayName) ? username : displayName
            ),
            City = city,
            NormalizedCity = TextNormalizer.Normalize(city),
            Gender = gender,
            BirthDate = birthDate,
            Age = age,
            MatchPreference = matchPreference,
            Mode = mode,
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
        credential.PasswordHash = _passwordHasher.HashPassword(
            credential,
            request.Password
        );

        dbContext.Users.Add(profile);
        dbContext.UserCredentials.Add(credential);
        await dbContext.SaveChangesAsync(cancellationToken);

        return BuildAuthResponse(profile, isNewUser: true);
    }

    public async Task<AuthResponseDto> LoginAsync(
        LoginRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var credential = await dbContext.UserCredentials.FirstOrDefaultAsync(
            entry => entry.Email == email,
            cancellationToken
        ) ?? throw new InvalidOperationException("Invalid email or password.");

        if (!credential.HasPassword)
        {
            throw new InvalidOperationException(
                "This account uses Google sign-in. Please continue with Google."
            );
        }

        if (credential.LockoutEnd.HasValue && credential.LockoutEnd > DateTimeOffset.UtcNow)
        {
            throw new InvalidOperationException("Account is temporarily locked. Please try again later.");
        }

        var verification = _passwordHasher.VerifyHashedPassword(
            credential,
            credential.PasswordHash,
            request.Password
        );

        if (verification == PasswordVerificationResult.Failed)
        {
            credential.FailedLoginAttempts++;
            if (credential.FailedLoginAttempts >= 5)
            {
                credential.LockoutEnd = DateTimeOffset.UtcNow.AddMinutes(15);
            }
            await dbContext.SaveChangesAsync(cancellationToken);
            throw new InvalidOperationException("Invalid email or password.");
        }

        credential.FailedLoginAttempts = 0;
        credential.LockoutEnd = null;

        var user = await dbContext.Users.FirstAsync(
            entry => entry.Id == credential.UserId,
            cancellationToken
        );
        user.LastSeenAt = DateTimeOffset.UtcNow;
        user.IsOnline = true;
        user.UpdatedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        return BuildAuthResponse(user, isNewUser: false);
    }

    public async Task<AuthResponseDto> LoginWithGoogleAsync(
        GoogleLoginRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var payload = await GoogleJsonWebSignature.ValidateAsync(
            request.IdToken,
            new GoogleJsonWebSignature.ValidationSettings
            {
                Audience = new[]
                {
                    "51483368324-31hlp0as81o4lnbbduiu4u6r3s9i8hht.apps.googleusercontent.com",
                    "51483368324-epv27k6iisv4l355gd6bj1o4sabsdatu.apps.googleusercontent.com",
                },
            }
        );
        var email = payload.Email.Trim().ToLowerInvariant();
        var googleSubject = payload.Subject;

        var credential = await dbContext.UserCredentials.FirstOrDefaultAsync(
            entry => entry.GoogleSubject == googleSubject || entry.Email == email,
            cancellationToken
        );

        var isNewUser = false;
        UserProfile user;

        if (credential is null)
        {
            isNewUser = true;
            var userId = Guid.NewGuid().ToString("N");
            var username = TextNormalizer.BuildUserName(email, userId);

            user = new UserProfile
            {
                Id = userId,
                Email = email,
                UserName = username,
                NormalizedUserName = TextNormalizer.Normalize(username),
                DisplayName = payload.Name ?? username,
                NormalizedDisplayName = TextNormalizer.Normalize(payload.Name ?? username),
                ProfilePhotoUrl = payload.Picture ?? string.Empty,
                Mode = "kesif",
                PrivacyLevel = "full",
                IsVisible = true,
                CreatedAt = DateTimeOffset.UtcNow,
                UpdatedAt = DateTimeOffset.UtcNow,
            };

            credential = new UserCredential
            {
                UserId = userId,
                Email = email,
                GoogleSubject = googleSubject,
                HasPassword = false,
                CreatedAt = DateTimeOffset.UtcNow,
                UpdatedAt = DateTimeOffset.UtcNow,
            };

            dbContext.Users.Add(user);
            dbContext.UserCredentials.Add(credential);
        }
        else
        {
            user = await dbContext.Users.FirstAsync(
                entry => entry.Id == credential.UserId,
                cancellationToken
            );

            credential.GoogleSubject = googleSubject;
            credential.Email = email;
            credential.UpdatedAt = DateTimeOffset.UtcNow;

            user.Email = email;
            user.DisplayName = string.IsNullOrWhiteSpace(payload.Name)
                ? user.DisplayName
                : payload.Name!;
            user.NormalizedDisplayName = TextNormalizer.Normalize(user.DisplayName);
            if (!string.IsNullOrWhiteSpace(payload.Picture))
            {
                user.ProfilePhotoUrl = payload.Picture;
            }
            user.LastSeenAt = DateTimeOffset.UtcNow;
            user.IsOnline = true;
            user.UpdatedAt = DateTimeOffset.UtcNow;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return BuildAuthResponse(user, isNewUser);
    }

    public async Task<PasswordResetRequestAcceptedDto> RequestPasswordResetAsync(
        ForgotPasswordRequest request,
        string? requesterIp,
        string? userAgent,
        CancellationToken cancellationToken = default
    )
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var message = new PasswordResetRequestAcceptedDto(
            Sent: true,
            Message: "If that account exists, a reset code has been sent."
        );

        var credential = await dbContext.UserCredentials.FirstOrDefaultAsync(
            entry => entry.Email == email,
            cancellationToken
        );
        if (credential is null || !credential.HasPassword)
        {
            return message;
        }

        var user = await dbContext.Users.FirstOrDefaultAsync(
            entry => entry.Id == credential.UserId,
            cancellationToken
        );
        if (user is null)
        {
            return message;
        }

        var smtp = smtpOptions.Value;
        var codeLength = Math.Clamp(smtp.PasswordResetCodeLength, 10, 16);
        var resetCode = GenerateResetCode(codeLength);
        var token = new PasswordResetToken
        {
            UserId = user.Id,
            RequestedIp = requesterIp?.Trim() ?? string.Empty,
            UserAgent = userAgent?.Trim() ?? string.Empty,
            ExpiresAt = DateTimeOffset.UtcNow.AddMinutes(
                Math.Clamp(smtp.PasswordResetExpiresMinutes, 10, 120)
            ),
            CreatedAt = DateTimeOffset.UtcNow,
        };
        token.TokenHash = _passwordResetHasher.HashPassword(token, resetCode);

        var existingTokens = await dbContext.PasswordResetTokens
            .Where(entry => entry.UserId == user.Id && entry.UsedAt == null)
            .ToListAsync(cancellationToken);
        dbContext.PasswordResetTokens.RemoveRange(existingTokens);
        dbContext.PasswordResetTokens.Add(token);
        await dbContext.SaveChangesAsync(cancellationToken);

        var resetLink = BuildPasswordResetLink(email, resetCode);
        var displayName = string.IsNullOrWhiteSpace(user.DisplayName) ? user.UserName : user.DisplayName;
        await emailSender.SendAsync(
            email,
            displayName,
            "PulseCity password reset",
            BuildPasswordResetHtml(displayName, resetCode, resetLink, smtp.PasswordResetExpiresMinutes),
            BuildPasswordResetText(resetCode, resetLink, smtp.PasswordResetExpiresMinutes),
            cancellationToken
        );

        return message;
    }

    public async Task ResetPasswordAsync(
        ResetPasswordRequest request,
        CancellationToken cancellationToken = default
    )
    {
        var email = request.Email.Trim().ToLowerInvariant();
        var credential = await dbContext.UserCredentials.FirstOrDefaultAsync(
            entry => entry.Email == email,
            cancellationToken
        ) ?? throw new InvalidOperationException("Password reset code is invalid or expired.");

        if (!credential.HasPassword)
        {
            throw new InvalidOperationException(
                "This account uses Google sign-in. Please continue with Google."
            );
        }

        var token = await dbContext.PasswordResetTokens
            .Where(entry =>
                entry.UserId == credential.UserId
                && entry.UsedAt == null
                && entry.ExpiresAt > DateTimeOffset.UtcNow)
            .OrderByDescending(entry => entry.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw new InvalidOperationException("Password reset code is invalid or expired.");

        if (token.Attempts >= 5)
        {
            throw new InvalidOperationException("Too many attempts for this reset code. Please request a new one.");
        }

        token.Attempts++;
        await dbContext.SaveChangesAsync(cancellationToken);

        var verification = _passwordResetHasher.VerifyHashedPassword(
            token,
            token.TokenHash,
            request.Code.Trim()
        );
        if (verification == PasswordVerificationResult.Failed)
        {
            throw new InvalidOperationException("Password reset code is invalid or expired.");
        }

        credential.PasswordHash = _passwordHasher.HashPassword(credential, request.NewPassword);
        credential.HasPassword = true;
        credential.UpdatedAt = DateTimeOffset.UtcNow;
        token.UsedAt = DateTimeOffset.UtcNow;

        var staleTokens = await dbContext.PasswordResetTokens
            .Where(entry => entry.UserId == credential.UserId && entry.Id != token.Id)
            .ToListAsync(cancellationToken);
        dbContext.PasswordResetTokens.RemoveRange(staleTokens);

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    public async Task DeleteAccountAsync(
        string userId,
        CancellationToken cancellationToken = default
    )
    {
        var user = await dbContext.Users.FirstOrDefaultAsync(
            entry => entry.Id == userId,
            cancellationToken
        );
        if (user is null)
        {
            return;
        }

        var credentials = await dbContext.UserCredentials.FirstOrDefaultAsync(
            entry => entry.UserId == userId,
            cancellationToken
        );

        if (credentials is not null)
        {
            dbContext.UserCredentials.Remove(credentials);
        }

        var follows = await dbContext.Follows.Where(entry =>
            entry.FollowerUserId == userId || entry.FollowingUserId == userId).ToListAsync(cancellationToken);
        var requests = await dbContext.FriendRequests.Where(entry =>
            entry.FromUserId == userId || entry.ToUserId == userId).ToListAsync(cancellationToken);
        var friendships = await dbContext.Friendships.Where(entry =>
            entry.UserAId == userId || entry.UserBId == userId).ToListAsync(cancellationToken);
        var blocked = await dbContext.BlockedUsers.Where(entry =>
            entry.UserId == userId || entry.BlockedUserId == userId).ToListAsync(cancellationToken);
        var reports = await dbContext.UserReports.Where(entry =>
            entry.ReporterUserId == userId || entry.TargetUserId == userId).ToListAsync(cancellationToken);
        var highlights = await dbContext.Highlights.Where(entry => entry.UserId == userId).ToListAsync(cancellationToken);
        var highlightIds = highlights.Select(entry => entry.Id).ToList();
        var storyViews = await dbContext.StoryViews.Where(entry =>
            entry.ViewerUserId == userId || highlightIds.Contains(entry.StoryId)).ToListAsync(cancellationToken);
        var matches = await dbContext.Matches.Where(entry =>
            entry.UserId1 == userId || entry.UserId2 == userId).ToListAsync(cancellationToken);
        var presence = await dbContext.Presences.FirstOrDefaultAsync(entry => entry.UserId == userId, cancellationToken);
        var posts = await dbContext.Posts.Where(entry => entry.UserId == userId).ToListAsync(cancellationToken);
        var postIds = posts.Select(entry => entry.Id).ToList();
        var likes = await dbContext.PostLikes.Where(entry =>
            entry.UserId == userId || postIds.Contains(entry.PostId)).ToListAsync(cancellationToken);
        var comments = await dbContext.PostComments.Where(entry =>
            entry.UserId == userId || postIds.Contains(entry.PostId)).ToListAsync(cancellationToken);
        var savedPosts = await dbContext.SavedPosts.Where(entry => entry.UserId == userId || postIds.Contains(entry.PostId)).ToListAsync(cancellationToken);
        var savedPlaces = await dbContext.SavedPlaces.Where(entry => entry.UserId == userId).ToListAsync(cancellationToken);
        var chatIds = await dbContext.ChatParticipants
            .Where(entry => entry.UserId == userId)
            .Select(entry => entry.ChatId)
            .Distinct()
            .ToListAsync(cancellationToken);
        var chats = await dbContext.Chats.Where(entry => chatIds.Contains(entry.Id)).ToListAsync(cancellationToken);
        var hiddenStates = await dbContext.ChatMessageHiddenStates.Where(entry =>
            entry.UserId == userId).ToListAsync(cancellationToken);

        dbContext.Follows.RemoveRange(follows);
        dbContext.FriendRequests.RemoveRange(requests);
        dbContext.Friendships.RemoveRange(friendships);
        dbContext.BlockedUsers.RemoveRange(blocked);
        dbContext.UserReports.RemoveRange(reports);
        dbContext.StoryViews.RemoveRange(storyViews);
        dbContext.Highlights.RemoveRange(highlights);
        dbContext.Matches.RemoveRange(matches);
        if (presence != null) dbContext.Presences.Remove(presence);
        dbContext.Chats.RemoveRange(chats);
        dbContext.ChatMessageHiddenStates.RemoveRange(hiddenStates);
        dbContext.PostLikes.RemoveRange(likes);
        dbContext.PostComments.RemoveRange(comments);
        dbContext.SavedPosts.RemoveRange(savedPosts);
        dbContext.SavedPlaces.RemoveRange(savedPlaces);
        dbContext.Posts.RemoveRange(posts);
        dbContext.Users.Remove(user);

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private AuthResponseDto BuildAuthResponse(UserProfile user, bool isNewUser)
    {
        var (accessToken, expiresAt) = jwtTokenService.CreateToken(user);
        var isOnboarded = user.Interests.Count > 0 && !string.IsNullOrWhiteSpace(user.Mode);

        return new AuthResponseDto(
            accessToken,
            expiresAt,
            isNewUser,
            new AuthUserDto(
                user.Id,
                user.Email,
                user.UserName,
                user.DisplayName,
                user.ProfilePhotoUrl,
                user.Mode,
                user.PrivacyLevel,
                user.PreferredLanguage,
                user.IsVisible,
                isOnboarded
            )
        );
    }

    private static string GenerateResetCode(int length)
    {
        const string alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        var buffer = new byte[length];
        RandomNumberGenerator.Fill(buffer);
        var builder = new StringBuilder(length);
        foreach (var value in buffer)
        {
            builder.Append(alphabet[value % alphabet.Length]);
        }
        return builder.ToString();
    }

    private string BuildPasswordResetLink(string email, string code)
    {
        var baseUrl = smtpOptions.Value.PasswordResetBaseUrl.Trim();
        if (string.IsNullOrWhiteSpace(baseUrl))
        {
            return string.Empty;
        }

        if (!Uri.TryCreate(baseUrl, UriKind.Absolute, out var uri))
        {
            return baseUrl;
        }

        var separator = string.IsNullOrWhiteSpace(uri.Query) ? "?" : "&";
        return $"{baseUrl}{separator}email={Uri.EscapeDataString(email)}&code={Uri.EscapeDataString(code)}";
    }

    private static string BuildPasswordResetHtml(
        string displayName,
        string code,
        string resetLink,
        int expiresInMinutes
    )
    {
        var action = string.IsNullOrWhiteSpace(resetLink)
            ? string.Empty
            : $"""
               <p style="margin:24px 0;">
                 <a href="{resetLink}" style="background:#f34f6f;color:#ffffff;text-decoration:none;padding:12px 18px;border-radius:12px;display:inline-block;font-weight:700;">Reset password</a>
               </p>
               """;

        return $"""
            <div style="font-family:Arial,Helvetica,sans-serif;background:#090523;color:#ffffff;padding:32px;">
              <div style="max-width:520px;margin:0 auto;background:#17152d;border-radius:24px;padding:32px;border:1px solid rgba(255,255,255,0.08);">
                <p style="margin:0 0 8px 0;color:#f34f6f;font-weight:700;">PulseCity</p>
                <h1 style="margin:0 0 12px 0;font-size:26px;">Password reset</h1>
                <p style="margin:0 0 18px 0;color:#d2d4df;">Hi {System.Net.WebUtility.HtmlEncode(displayName)}, use the code below to reset your password.</p>
                <div style="font-size:28px;letter-spacing:6px;font-weight:800;padding:18px 20px;border-radius:18px;background:#0f0c21;text-align:center;">{System.Net.WebUtility.HtmlEncode(code)}</div>
                <p style="margin:18px 0 0 0;color:#a6a9bb;">This code expires in {expiresInMinutes} minutes.</p>
                {action}
              </div>
            </div>
            """;
    }

    private static string BuildPasswordResetText(
        string code,
        string resetLink,
        int expiresInMinutes
    )
    {
        var linkBlock = string.IsNullOrWhiteSpace(resetLink)
            ? string.Empty
            : $"{Environment.NewLine}Reset link: {resetLink}{Environment.NewLine}";
        return $"PulseCity password reset{Environment.NewLine}{Environment.NewLine}Code: {code}{Environment.NewLine}This code expires in {expiresInMinutes} minutes.{linkBlock}";
    }

    private static string NormalizeGender(string? value) =>
        SharedHelpers.NormalizeGender(value);

    private static string NormalizeMatchPreference(string? value, string gender) =>
        SharedHelpers.NormalizeMatchPreference(value, gender);

    private static string NormalizeMode(string? value) =>
        SharedHelpers.NormalizeMode(value);

    private static int CalculateAge(DateTime birthDate)
    {
        var today = DateTime.UtcNow.Date;
        var age = today.Year - birthDate.Year;
        if (birthDate.Date > today.AddYears(-age))
        {
            age--;
        }
        return Math.Max(0, age);
    }
}
