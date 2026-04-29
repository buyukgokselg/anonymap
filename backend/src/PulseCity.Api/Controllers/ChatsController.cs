using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PulseCity.Api.Extensions;
using PulseCity.Application.DTOs;
using PulseCity.Application.Interfaces;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class ChatsController(IChatsService chatsService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ChatThreadDto>>> GetChats(
        [FromQuery] int skip = 0,
        [FromQuery] int take = 25,
        [FromQuery] bool includeArchived = false,
        CancellationToken cancellationToken = default
    ) => Ok(
        await chatsService.GetChatsAsync(
            User.GetRequiredUserId(),
            skip,
            take,
            includeArchived,
            cancellationToken
        )
    );

    [HttpGet("{chatId:guid}")]
    public async Task<ActionResult<ChatThreadDto>> GetChat(
        Guid chatId,
        CancellationToken cancellationToken
    )
    {
        var chat = await chatsService.GetChatAsync(chatId, User.GetRequiredUserId(), cancellationToken);
        return chat is null ? NotFound() : Ok(chat);
    }

    [HttpPost("direct")]
    public async Task<ActionResult<ChatThreadDto>> CreateOrGetDirect(
        [FromBody] CreateDirectChatRequest request,
        CancellationToken cancellationToken
    ) => Ok(await chatsService.CreateOrGetDirectChatAsync(User.GetRequiredUserId(), request, cancellationToken));

    [HttpGet("{chatId:guid}/messages")]
    public async Task<ActionResult<IReadOnlyList<ChatMessageDto>>> GetMessages(
        Guid chatId,
        [FromQuery] int skip = 0,
        [FromQuery] int take = 50,
        CancellationToken cancellationToken = default
    ) => Ok(await chatsService.GetMessagesAsync(chatId, User.GetRequiredUserId(), skip, take, cancellationToken));

    [HttpPost("{chatId:guid}/messages")]
    public async Task<ActionResult<ChatMessageDto>> SendMessage(
        Guid chatId,
        [FromBody] SendChatMessageRequest request,
        CancellationToken cancellationToken
    ) => Ok(await chatsService.SendMessageAsync(chatId, User.GetRequiredUserId(), request, cancellationToken));

    [HttpPost("{chatId:guid}/messages/{messageId:guid}/status")]
    public async Task<IActionResult> UpdateMessageStatus(
        Guid chatId,
        Guid messageId,
        [FromBody] UpdateChatMessageStatusRequest request,
        CancellationToken cancellationToken
    )
    {
        var updated = await chatsService.UpdateMessageStatusAsync(
            chatId,
            messageId,
            User.GetRequiredUserId(),
            request,
            cancellationToken
        );
        return updated ? Ok(new { updated = true }) : NotFound();
    }

    [HttpPost("{chatId:guid}/messages/{messageId:guid}/reaction")]
    public async Task<IActionResult> UpdateReaction(
        Guid chatId,
        Guid messageId,
        [FromBody] UpdateChatReactionRequest request,
        CancellationToken cancellationToken
    )
    {
        var updated = await chatsService.UpdateReactionAsync(
            chatId,
            messageId,
            User.GetRequiredUserId(),
            request,
            cancellationToken
        );
        return updated ? Ok(new { updated = true }) : NotFound();
    }

    [HttpDelete("{chatId:guid}/messages/{messageId:guid}")]
    public async Task<IActionResult> DeleteMessage(
        Guid chatId,
        Guid messageId,
        [FromQuery] string scope = "everyone",
        CancellationToken cancellationToken = default
    )
    {
        var deleted = await chatsService.DeleteMessageAsync(
            chatId,
            messageId,
            User.GetRequiredUserId(),
            scope,
            cancellationToken
        );
        return deleted ? Ok(new { deleted = true, scope }) : NotFound();
    }

    [HttpPost("{chatId:guid}/typing")]
    public async Task<IActionResult> SetTyping(
        Guid chatId,
        [FromBody] SetTypingRequest request,
        CancellationToken cancellationToken
    )
    {
        var updated = await chatsService.SetTypingAsync(chatId, User.GetRequiredUserId(), request, cancellationToken);
        return updated ? Ok(new { updated = true }) : NotFound();
    }

    [HttpPost("{chatId:guid}/read")]
    public async Task<IActionResult> MarkAsRead(Guid chatId, CancellationToken cancellationToken)
    {
        var updated = await chatsService.MarkAsReadAsync(chatId, User.GetRequiredUserId(), cancellationToken);
        return updated ? Ok(new { updated = true }) : NotFound();
    }

    [HttpPost("{chatId:guid}/convert-to-friend")]
    public async Task<IActionResult> ConvertToFriendChat(Guid chatId, CancellationToken cancellationToken)
    {
        var updated = await chatsService.ConvertToFriendChatAsync(chatId, User.GetRequiredUserId(), cancellationToken);
        return updated ? Ok(new { updated = true }) : NotFound();
    }

    [HttpPost("{chatId:guid}/request-permanence")]
    public async Task<IActionResult> RequestPermanence(Guid chatId, CancellationToken cancellationToken)
    {
        var result = await chatsService.RequestChatPermanenceAsync(chatId, User.GetRequiredUserId(), cancellationToken);
        return result == "not_found" ? NotFound() : Ok(new { status = result });
    }

    [HttpDelete("{chatId:guid}")]
    public async Task<IActionResult> Delete(Guid chatId, CancellationToken cancellationToken)
    {
        var deleted = await chatsService.DeleteChatAsync(chatId, User.GetRequiredUserId(), cancellationToken);
        return deleted ? Ok(new { deleted = true }) : NotFound();
    }

    [HttpPost("{chatId:guid}/archive")]
    public async Task<IActionResult> Archive(Guid chatId, CancellationToken cancellationToken)
    {
        var updated = await chatsService.SetArchivedAsync(
            chatId,
            User.GetRequiredUserId(),
            true,
            cancellationToken
        );
        return updated ? Ok(new { archived = true }) : NotFound();
    }

    [HttpPost("{chatId:guid}/unarchive")]
    public async Task<IActionResult> Unarchive(Guid chatId, CancellationToken cancellationToken)
    {
        var updated = await chatsService.SetArchivedAsync(
            chatId,
            User.GetRequiredUserId(),
            false,
            cancellationToken
        );
        return updated ? Ok(new { archived = false }) : NotFound();
    }
}
