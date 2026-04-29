using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PulseCity.Api.Extensions;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/users/{userId}/stories")]
[Authorize]
public sealed class StoriesController(IHighlightsService highlightsService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<HighlightDto>>> GetByUser(
        string userId,
        CancellationToken cancellationToken
    ) => Ok(await highlightsService.GetActiveStoriesByUserAsync(
        userId,
        User.GetRequiredUserId(),
        cancellationToken
    ));

    [HttpPost]
    public async Task<ActionResult<HighlightDto>> Create(
        string userId,
        [FromBody] CreateHighlightRequest request,
        CancellationToken cancellationToken
    )
    {
        if (userId != User.GetRequiredUserId())
        {
            return Forbid();
        }

        return Ok(await highlightsService.CreateStoryAsync(userId, request, cancellationToken));
    }

    [HttpDelete("{storyId:guid}")]
    public async Task<IActionResult> Delete(
        string userId,
        Guid storyId,
        CancellationToken cancellationToken
    )
    {
        if (userId != User.GetRequiredUserId())
        {
            return Forbid();
        }

        var deleted = await highlightsService.DeleteStoryAsync(
            userId,
            storyId,
            cancellationToken
        );
        return deleted ? Ok(new { deleted = true }) : NotFound();
    }
}
