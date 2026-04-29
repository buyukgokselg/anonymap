using Microsoft.AspNetCore.Mvc;

namespace PulseCity.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class HealthController : ControllerBase
{
    [HttpGet]
    public IActionResult Get() =>
        Ok(
            new
            {
                ok = true,
                service = "PulseCity API",
                utcNow = DateTimeOffset.UtcNow,
            }
        );
}
