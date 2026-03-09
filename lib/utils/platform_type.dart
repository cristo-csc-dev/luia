import 'dart:io'; // Para Platform
import 'package:flutter/foundation.dart'; // Para kIsWeb

enum PlatformType { web, mobile, desktop, unknown }

class PlatformHelper {
  static PlatformType get currentPlatformType {
    // 1. Primero verificamos si es Web
    if (kIsWeb) {
      return PlatformType.web;
    }

    // 2. Si no es Web, es seguro usar dart:io para chequear el OS
    if (Platform.isAndroid || Platform.isIOS || Platform.isFuchsia) {
      return PlatformType.mobile;
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return PlatformType.desktop;
    }

    return PlatformType.unknown;
  }
  
  // Opcional: Un getter para obtener el nombre como String
  static String get platformName {
    if (kIsWeb) return "Web";
    if (Platform.isAndroid) return "Android";
    if (Platform.isIOS) return "iOS";
    if (Platform.isWindows) return "Windows";
    if (Platform.isMacOS) return "macOS";
    if (Platform.isLinux) return "Linux";
    return "Desconocido";
  }
}