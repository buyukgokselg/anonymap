using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;
using PulseCity.Infrastructure.Options;

namespace PulseCity.Infrastructure.Data;

public sealed class PulseCityDbContextFactory : IDesignTimeDbContextFactory<PulseCityDbContext>
{
    public PulseCityDbContext CreateDbContext(string[] args)
    {
        var environment =
            Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
            ?? Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT")
            ?? "Development";

        var basePath = Directory.GetCurrentDirectory();
        var apiProjectPath = Path.GetFullPath(Path.Combine(basePath, "..", "PulseCity.Api"));
        if (File.Exists(Path.Combine(apiProjectPath, "appsettings.json")))
        {
            basePath = apiProjectPath;
        }

        var configuration = new ConfigurationBuilder()
            .SetBasePath(basePath)
            .AddJsonFile("appsettings.json", optional: true)
            .AddJsonFile($"appsettings.{environment}.json", optional: true)
            .AddJsonFile("appsettings.Local.json", optional: true)
            .AddEnvironmentVariables()
            .Build();

        var optionsBuilder = new DbContextOptionsBuilder<PulseCityDbContext>();
        var connectionString = configuration.GetConnectionString("SqlServer")
            ?? "Server=localhost;Database=PulseCity;Trusted_Connection=True;TrustServerCertificate=True";
        optionsBuilder.UseSqlServer(connectionString);

        return new PulseCityDbContext(optionsBuilder.Options);
    }
}
