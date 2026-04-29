using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using PulseCity.Domain.Entities;
using PulseCity.Infrastructure.Options;

namespace PulseCity.Infrastructure.Services;

public sealed class JwtTokenService(IOptions<JwtOptions> options)
{
    public (string AccessToken, DateTimeOffset ExpiresAt) CreateToken(UserProfile user)
    {
        var jwtOptions = options.Value;
        var expiresAt = DateTimeOffset.UtcNow.AddMinutes(
            Math.Max(15, jwtOptions.AccessTokenMinutes)
        );
        var signingKey = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(jwtOptions.SigningKey)
        );
        var credentials = new SigningCredentials(
            signingKey,
            SecurityAlgorithms.HmacSha256
        );

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id),
            new(JwtRegisteredClaimNames.Email, user.Email),
            new(JwtRegisteredClaimNames.Name, user.DisplayName),
            new("username", user.UserName),
            new("picture", user.ProfilePhotoUrl ?? string.Empty),
        };

        var token = new JwtSecurityToken(
            issuer: jwtOptions.Issuer,
            audience: jwtOptions.Audience,
            claims: claims,
            notBefore: DateTime.UtcNow,
            expires: expiresAt.UtcDateTime,
            signingCredentials: credentials
        );

        return (new JwtSecurityTokenHandler().WriteToken(token), expiresAt);
    }
}
