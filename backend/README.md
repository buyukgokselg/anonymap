# PulseCity Backend

This folder contains the SQL Server-first ASP.NET Core backend that powers the Flutter app.

## Stack

- ASP.NET Core Web API (`net9.0`)
- SQL Server
- SignalR for realtime updates
- JWT authentication
- SMTP-based password reset
- Local media storage outside the repo
- Google Places proxy and pulse scoring on the server

## Solution layout

- `src/PulseCity.Api`: HTTP API, Swagger, SignalR hubs
- `src/PulseCity.Application`: DTOs and service contracts
- `src/PulseCity.Domain`: entities
- `src/PulseCity.Infrastructure`: EF Core, SQL Server services, JWT auth, SMTP mail, storage, Google Places

## What the backend handles

- Email/password register and login
- Google login via backend token exchange
- JWT session issuance
- SMTP password reset requests and code validation
- Authenticated media upload
- Private data export generation with signed download URLs
- User search, follow, friend request, block, report
- Feed posts, comments, likes, saves
- Stories and highlights
- Story seen/view tracking
- Google Places nearby/detail requests and pulse scoring
- SignalR realtime updates for feed, chats, profile, stories, relationships, presence

## Local setup

1. Copy the local config example if you want your own override file:

```powershell
Copy-Item `
  C:\project\anonymap\anonymap\backend\src\PulseCity.Api\appsettings.Local.example.json `
  C:\project\anonymap\anonymap\backend\src\PulseCity.Api\appsettings.Local.json
```

2. Fill these values in `appsettings.Local.json`:

- `ConnectionStrings:SqlServer`
- `PulseCity:Jwt:SigningKey`
- `PulseCity:GooglePlaces:ApiKey`
- `PulseCity:Smtp:*`

3. Run the API:

```powershell
dotnet run --project C:\project\anonymap\anonymap\backend\src\PulseCity.Api
```

Swagger:

- `http://localhost:5275/swagger`
- `https://localhost:7122/swagger`

## Storage locations

By default, runtime files live outside the repository under:

- `%LOCALAPPDATA%\PulseCity\storage\public`
- `%LOCALAPPDATA%\PulseCity\storage\private\exports`
- `%LOCALAPPDATA%\PulseCity\storage\private\mail`

Legacy repo-local uploads under `src/PulseCity.Api/Uploads` are still served as a compatibility fallback until you clean them up.

## Key endpoints

- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/google`
- `POST /api/auth/password/forgot`
- `POST /api/auth/password/reset`
- `GET /api/auth/me`
- `DELETE /api/auth/me`
- `POST /api/uploads/media`
- `POST /api/stories/{storyId}/view`

## Flutter integration

The Flutter app reads the backend URL from runtime config:

- Android local: `android/local.properties`
- iOS local: `ios/Flutter/Secrets.xcconfig`
- or `--dart-define=BACKEND_BASE_URL=...`

Current local defaults:

- Android emulator: `http://10.0.2.2:5275`
- iOS simulator: `http://localhost:5275`

## Production notes

- `PulseCity:Jwt:SigningKey` is required; the API no longer falls back to a known development key.
- Update the SMTP placeholders with real provider credentials before using password reset in production.
- If you move uploads to cloud storage later, replace `LocalFileStorageService` and keep the API surface unchanged.
