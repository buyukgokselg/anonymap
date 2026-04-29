using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PulseCity.Api.Extensions;
using PulseCity.Application.Interfaces;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/stories")]
[Authorize]
public sealed class StoryInteractionsController(
    IHighlightsService highlightsService
) : ControllerBase
{
    [HttpPost("{storyId:guid}/view")]
    public async Task<IActionResult> MarkViewed(
        Guid storyId,
        CancellationToken cancellationToken
    )
    {
        await highlightsService.RecordStoryViewAsync(
            storyId,
            User.GetRequiredUserId(),
            cancellationToken
        );
        return NoContent();
    }
}
