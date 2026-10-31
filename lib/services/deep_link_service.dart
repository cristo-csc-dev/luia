// lib/services/deep_link_service.dart
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class DeepLinkService {
  final StreamController<Uri> _linkStreamController =
      StreamController<Uri>.broadcast();
  final AppLinks _appLinks = AppLinks();
  Uri? _lastHandledUri;

  Stream<Uri> get linkStream => _linkStreamController.stream;

  Future<void> init() async {
    await _initLinks();
  }

  void dispose() {
    _linkStreamController.close();
  }

  Future<void> _initLinks() async {
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      debugPrint('DeepLinkService: initialUri=$initialUri');
      if (initialUri != null) {
        _linkStreamController.add(initialUri);
      }
    } on FormatException catch (e) {
      debugPrint('DeepLink initial URI error: $e');
    }

    _appLinks.uriLinkStream.listen(
      (Uri uri) {
        debugPrint('DeepLinkService: uriLinkStream event: $uri');
        _linkStreamController.add(uri);
      },
      onError: (Object err) {
        debugPrint('DeepLink stream error: $err');
      },
    );
  }

  void handleUri(Uri uri, BuildContext context) {
    debugPrint('DeepLinkService.handleUri: received uri=$uri');

    // Ignore repeated URIs to avoid navigating again when app resumes
    if (_lastHandledUri != null && _lastHandledUri.toString() == uri.toString()) {
      debugPrint('DeepLinkService: ignoring duplicate uri');
      return;
    }
    _lastHandledUri = uri;

    final location = _locationFromUri(uri);
    if (location.isEmpty) {
      debugPrint('DeepLinkService: resolved empty location for uri=$uri');
      return;
    }

    debugPrint('DeepLinkService: resolved location=$location');
    final router = GoRouter.of(context);
    router.go(location);
  }

  String _locationFromUri(Uri uri) {
    var path = uri.path;
    if (path == '/' || path.isEmpty) {
      path = '/home';
    }

    if (!path.startsWith('/home') && !path.startsWith('/login')) {
      path = '/home$path';
    }

    final query = Uri(queryParameters: uri.queryParameters).query;
    return query.isEmpty ? path : '$path?$query';
  }
}