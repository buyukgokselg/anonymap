import 'package:flutter/widgets.dart';

class NetworkMediaHeaders {
  const NetworkMediaHeaders._();

  static Map<String, String>? forUrl(String? url) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    final host = uri?.host.toLowerCase() ?? value.toLowerCase();
    if (host.contains('.ngrok-free.app') ||
        host.contains('.ngrok-free.dev') ||
        host.contains('.ngrok.app')) {
      return const {'ngrok-skip-browser-warning': 'true'};
    }

    return null;
  }

  static ImageProvider<Object> imageProvider(String url) {
    return NetworkImage(url, headers: forUrl(url));
  }
}
