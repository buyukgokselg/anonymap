using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PulseCity.Api.Extensions;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class NotificationsController(INotificationsService notificationsService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<NotificationListResponseDto>> List(
        [FromQuery] NotificationListQuery query,
        CancellationToken cancellationToken
    ) => Ok(await notificationsService.ListAsync(User.GetRequiredUserId(), query, cancellationToken));

    [HttpGet("unread-count")]
    public async Task<ActionResult<UnreadCountDto>> UnreadCount(
        CancellationToken cancellationToken
    ) => Ok(await notificationsService.GetUnreadCountAsync(User.GetRequiredUserId(), cancellationToken));

    [HttpPost("{notificationId:guid}/read")]
    public async Task<IActionResult> MarkRead(
        Guid notificationId,
        CancellationToken cancellationToken
    )
    {
        var ok = await notificationsService.MarkReadAsync(notificationId, User.GetRequiredUserId(), cancellationToken);
        return ok ? Ok(new { updated = true }) : NotFound();
    }

    [HttpPost("read-all")]
    public async Task<ActionResult<object>> MarkAllRead(CancellationToken cancellationToken)
    {
        var affected = await notificationsService.MarkAllReadAsync(User.GetRequiredUserId(), cancellationToken);
        return Ok(new { affected });
    }

    [HttpDelete("{notificationId:guid}")]
    public async Task<IActionResult> Delete(
        Guid notificationId,
        CancellationToken cancellationToken
    )
    {
        var ok = await notificationsService.DeleteAsync(notificationId, User.GetRequiredUserId(), cancellationToken);
        return ok ? NoContent() : NotFound();
    }
}
