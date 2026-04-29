namespace PulseCity.Infrastructure.Options;

public sealed class SmtpOptions
{
    public const string SectionName = "PulseCity:Smtp";

    public string Host { get; set; } = "smtp.example.com";
    public int Port { get; set; } = 587;
    public bool UseSsl { get; set; } = true;
    public string UserName { get; set; } = "smtp-user@example.com";
    public string Password { get; set; } = "TEMP_SMTP_PASSWORD";
    public string SenderEmail { get; set; } = "noreply@pulsecity.app";
    public string SenderName { get; set; } = "PulseCity";
    public string PasswordResetBaseUrl { get; set; } = "pulsecity://reset-password";
    public int PasswordResetCodeLength { get; set; } = 10;
    public int PasswordResetExpiresMinutes { get; set; } = 30;
}
