import 'package:flutter/services.dart';

class AppInfoService {
  static const channel = MethodChannel('com.lix.lunarix_notes/app_info');

  /// Read the installed package rather than duplicating the release version.
  Future<String?> getVersion() async {
    try {
      final info = await channel.invokeMapMethod<String, dynamic>('getVersion');
      final name = info?['name'] as String?;
      final build = info?['build'] as int?;
      if (name == null || name.isEmpty || build == null) return null;
      return '$name+$build';
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
