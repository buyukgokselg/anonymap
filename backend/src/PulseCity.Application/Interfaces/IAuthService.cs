using PulseCity.Application.DTOs;

namespace PulseCity.Application.Interfaces;

public interface IAuthService
{
    Task<AuthResponseDto> RegisterAsync(
        RegisterRequest request,
        CancellationToken cancellationToken = default
    );

    Task<AuthResponseDto> LoginAsync(
        LoginRequest request,
        CancellationToken cancellationToken = default
    );

    Task<AuthResponseDto> LoginWithGoogleAsync(
        GoogleLoginRequest request,
        CancellationToken cancellationToken = default
    );

    Task<PasswordResetRequestAcceptedDto> RequestPasswordResetAsync(
        ForgotPasswordRequest request,
        string? requesterIp,
        string? userAgent,
        CancellationToken cancellationToken = default
    );

    Task ResetPasswordAsync(
        ResetPasswordRequest request,
        CancellationToken cancellationToken = default
    );

    Task DeleteAccountAsync(string userId, CancellationToken cancellationToken = default);
}
