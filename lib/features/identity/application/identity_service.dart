import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_sync/src/rust/api/identity.dart';
import 'package:local_sync/features/master_key/application/master_key_service.dart';
import 'package:uuid/uuid.dart';

class IdentityService {
  final MasterKeyService _masterKeyService;
  final SharedPreferences _prefs;

  static const _deviceNameKey = 'device_display_name';
  static const _deviceSaltKey = 'localsync_device_salt';
  NetworkIdentity? _rustIdentity;

  IdentityService(this._masterKeyService, this._prefs);

  Future<NetworkIdentity?> initIdentity() async {
    final mnemonic = await _masterKeyService.getMnemonic();
    if (mnemonic == null) return null;

    try {
      String? salt = _prefs.getString(_deviceSaltKey);
      if (salt == null) {
        salt = const Uuid().v4();
        await _prefs.setString(_deviceSaltKey, salt);
      }

      _rustIdentity = await NetworkIdentity.fromMnemonic(
        phrase: mnemonic,
        salt: salt,
      );
      return _rustIdentity;
    } catch (e) {
      print('Error initializing Rust Identity: $e');
      return null;
    }
  }

  NetworkIdentity get identity {
    if (_rustIdentity == null) {
      throw Exception("Identity not initialized. Login with Master Key first.");
    }
    return _rustIdentity!;
  }

  Future<String> getDeviceAlias() async {
    // 1. Check prefs
    final stored = _prefs.getString(_deviceNameKey);
    if (stored != null) return stored;

    // 2. Generate default
    String name = "LocalSync Device";
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        name = info.model;
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        name = info.name;
      } else if (Platform.isMacOS) {
        final info = await deviceInfo.macOsInfo;
        name = info.computerName;
      } else if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        name = info.computerName;
      } else if (Platform.isLinux) {
        final info = await deviceInfo.linuxInfo;
        name = info.prettyName;
      }
    } catch (_) {}

    // 3. Save default
    await _prefs.setString(_deviceNameKey, name);
    return name;
  }
}
