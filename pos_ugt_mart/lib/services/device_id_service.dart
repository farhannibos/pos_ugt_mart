import 'dart:io' show Platform;
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// ID unik per instalasi aplikasi, dipakai saat mengajukan lisensi premium
/// (dicocokkan manual oleh admin di dev-panel). Dibuat sekali lalu disimpan
/// secara lokal sehingga nilainya tetap sama tiap kali dibuka.
class DeviceIdService {
  static const _key = 'device_license_id';
  static String? _cached;

  static Future<String> getDeviceId() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) {
      _cached = saved;
      return saved;
    }
    final id = '${_platformTag()}-${_randomHex(6)}';
    await prefs.setString(_key, id);
    _cached = id;
    return id;
  }

  /// Nama perangkat untuk ditampilkan ke user (mis. "Xiaomi Redmi Note 10"),
  /// murni informasional dan tidak dipakai sebagai bagian dari ID.
  static Future<String> getDeviceLabel() async {
    try {
      if (kIsWeb) return 'Web Browser';
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model}';
      }
      if (Platform.isIOS) {
        final i = await info.iosInfo;
        return '${i.name} (${i.model})';
      }
      return Platform.operatingSystem;
    } catch (_) {
      return '';
    }
  }

  static String _platformTag() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'device';
  }

  static String _randomHex(int bytes) {
    final rnd = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      buffer.write(rnd.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
