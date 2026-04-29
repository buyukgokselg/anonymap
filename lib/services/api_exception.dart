enum ApiErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  validation,
  rateLimited,
  server,
  unknown,
}

class ApiException implements Exception {
  final String message;
  final ApiErrorKind kind;
  final int? statusCode;

  const ApiException(
    this.message, {
    this.kind = ApiErrorKind.unknown,
    this.statusCode,
  });

  factory ApiException.fromStatus(
    int statusCode, {
    String? message,
  }) {
    final normalized = (message == null || message.trim().isEmpty)
        ? _defaultMessageForStatus(statusCode)
        : message.trim();

    return ApiException(
      normalized,
      kind: switch (statusCode) {
        400 || 409 || 422 => ApiErrorKind.validation,
        401 => ApiErrorKind.unauthorized,
        403 => ApiErrorKind.forbidden,
        429 => ApiErrorKind.rateLimited,
        >= 500 => ApiErrorKind.server,
        _ => ApiErrorKind.unknown,
      },
      statusCode: statusCode,
    );
  }

  static String _defaultMessageForStatus(int statusCode) {
    return switch (statusCode) {
      400 => 'The request could not be processed.',
      401 => 'Your session has expired. Please sign in again.',
      403 => 'You do not have permission to do this.',
      404 => 'The requested resource was not found.',
      409 => 'This action conflicts with the current state.',
      422 => 'Some submitted information is invalid.',
      429 => 'Too many requests. Please try again shortly.',
      >= 500 => 'The server could not complete the request.',
      _ => 'The request failed.',
    };
  }

  @override
  String toString() => message;
}
