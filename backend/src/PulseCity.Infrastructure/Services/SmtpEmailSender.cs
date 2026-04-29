using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Options;
using PulseCity.Application.Interfaces;
using PulseCity.Infrastructure.Options;

namespace PulseCity.Infrastructure.Services;

public sealed class SmtpEmailSender(
    IOptions<SmtpOptions> smtpOptions
) : IEmailSender
{
    public async Task SendAsync(
        string toEmail,
        string toName,
        string subject,
        string htmlBody,
        string textBody,
        CancellationToken cancellationToken = default
    )
    {
        var options = smtpOptions.Value;
        if (string.IsNullOrWhiteSpace(options.Host))
        {
            throw new InvalidOperationException("SMTP host is not configured.");
        }

        using var message = new MailMessage
        {
            From = new MailAddress(options.SenderEmail, options.SenderName),
            Subject = subject,
            Body = htmlBody,
            IsBodyHtml = true,
        };
        message.To.Add(new MailAddress(toEmail, string.IsNullOrWhiteSpace(toName) ? toEmail : toName));
        message.AlternateViews.Add(
            AlternateView.CreateAlternateViewFromString(textBody, null, "text/plain")
        );

        using var client = new SmtpClient(options.Host, options.Port)
        {
            EnableSsl = options.UseSsl,
            DeliveryMethod = SmtpDeliveryMethod.Network,
            UseDefaultCredentials = false,
            Credentials = new NetworkCredential(options.UserName, options.Password),
        };

        cancellationToken.ThrowIfCancellationRequested();
        await client.SendMailAsync(message, cancellationToken);
    }
}
