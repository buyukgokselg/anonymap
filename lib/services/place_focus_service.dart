import 'dart:async';

import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class PlaceFocusRequest {
  const PlaceFocusRequest({
    required this.placeId,
    required this.placeName,
    this.latitude,
    this.longitude,
  });

  final String placeId;
  final String placeName;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;
}

class PlaceFocusService {
  PlaceFocusService._();

  static final PlaceFocusService instance = PlaceFocusService._();

  final StreamController<PlaceFocusRequest> _controller =
      StreamController<PlaceFocusRequest>.broadcast();
  PlaceFocusRequest? _pendingRequest;

  Stream<PlaceFocusRequest> get requests => _controller.stream;

  PlaceFocusRequest? takePendingRequest() {
    final pending = _pendingRequest;
    _pendingRequest = null;
    return pending;
  }

  Future<void> focusPlace({
    required String placeName,
    String placeId = '',
    double? latitude,
    double? longitude,
  }) async {
    final trimmedName = placeName.trim();
    final trimmedPlaceId = placeId.trim();
    if (trimmedName.isEmpty && trimmedPlaceId.isEmpty) {
      return;
    }

    final request = PlaceFocusRequest(
      placeId: trimmedPlaceId,
      placeName: trimmedName,
      latitude: latitude,
      longitude: longitude,
    );
    _pendingRequest = request;

    final navigator = rootNavigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }

    await Future<void>.delayed(const Duration(milliseconds: 180));
    _controller.add(request);
  }
}
