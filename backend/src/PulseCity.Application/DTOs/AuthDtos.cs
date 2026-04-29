using System.ComponentModel.DataAnnotations;

namespace PulseCity.Application.DTOs;

public sealed class RegisterRequest
{
    [Required]
    [MaxLength(64)]
    public string FirstName { get; set; } = string.Empty;

    /// <summary>
    /// Opsiyoneldir; uygulama içinde gösterilmez. Anonimlik vaadi gereği yeni
    /// kayıt akışından çıkarıldı, geriye dönük uyumluluk için tip korundu.
    /// </summary>
    [MaxLength(64)]
    public string? LastName { get; set; }

    [Required]
    [EmailAddress]
    [MaxLength(256)]
    public string Email { get; set; } = string.Empty;

    [Required]
    [MinLength(8)]
    [MaxLength(128)]
    public string Password { get; set; } = string.Empty;

    [Required]
    [MaxLength(120)]
    public string City { get; set; } = string.Empty;

    [Required]
    [MaxLength(32)]
    [RegularExpression("^(female|male|nonbinary)$", ErrorMessage = "Gender must be one of: female, male, nonbinary.")]
    public string Gender { get; set; } = string.Empty;

    [Required]
    public DateTime BirthDate { get; set; }

    /// <summary>
    /// Cinsiyet eşleşme tercihi (kim ile eşleşmek istediğin).
    /// </summary>
    [Required]
    [MaxLength(16)]
    [RegularExpression("^(auto|women|men|everyone)$", ErrorMessage = "MatchPreference must be one of: auto, women, men, everyone.")]
    public string MatchPreference { get; set; } = "auto";

    /// <summary>
    /// Kullanıcının kayıt sırasında seçtiği tanışma niyeti.
    /// </summary>
    [Required]
    [MaxLength(16)]
    [RegularExpression("^(flirt|friends|fun|chill)$", ErrorMessage = "Mode must be one of: flirt, friends, fun, chill.")]
    public string Mode { get; set; } = "chill";
}

public sealed class LoginRequest
{
    [Required]
    [EmailAddress]
    [MaxLength(256)]
    public string Email { get; set; } = string.Empty;

    [Required]
    [MaxLength(128)]
    public string Password { get; set; } = string.Empty;
}

public sealed class GoogleLoginRequest
{
    [Required]
    public string IdToken { get; set; } = string.Empty;
}

public sealed record AuthUserDto(
    string Id,
    string Email,
    string UserName,
    string DisplayName,
    string ProfilePhotoUrl,
    string Mode,
    string PrivacyLevel,
    string PreferredLanguage,
    bool IsVisible,
    bool IsOnboarded
);

public sealed record AuthResponseDto(
    string AccessToken,
    DateTimeOffset ExpiresAt,
    bool IsNewUser,
    AuthUserDto User
);

public sealed class ForgotPasswordRequest
{
    [Required]
    [EmailAddress]
    [MaxLength(256)]
    public string Email { get; set; } = string.Empty;
}

public sealed class ResetPasswordRequest
{
    [Required]
    [EmailAddress]
    [MaxLength(256)]
    public string Email { get; set; } = string.Empty;

    [Required]
    [MinLength(6)]
    [MaxLength(32)]
    public string Code { get; set; } = string.Empty;

    [Required]
    [MinLength(8)]
    [MaxLength(128)]
    public string NewPassword { get; set; } = string.Empty;
}

public sealed record PasswordResetRequestAcceptedDto(
    bool Sent,
    string Message
);
