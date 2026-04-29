namespace PulseCity.Application.Interfaces;

public interface IEmailSender
{
    Task SendAsync(
        string toEmail,
        string toName,
        string subject,
        string htmlBody,
        string textBody,
        CancellationToken cancellationToken = default
    );
}
