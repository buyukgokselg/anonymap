namespace PulseCity.Application.Interfaces;

public interface IFileStorageService
{
    Task<string> SaveAsync(
        Stream stream,
        string fileName,
        string? contentType,
        CancellationToken cancellationToken = default
    );

    Task DeleteAsync(
        string urlOrRelativePath,
        CancellationToken cancellationToken = default
    );
}
