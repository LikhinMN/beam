import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class SettingsStore {
  static final SettingsStore instance = SettingsStore._init();
  SettingsStore._init();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Auto-initialize deviceName if missing
    if (_prefs.getString('device_name') == null) {
      await _prefs.setString('device_name', resolveDeviceName());
    }
  }

  String resolveDeviceName() {
    if (Platform.isLinux) {
      return Platform.localHostname;
    } else if (Platform.isAndroid) {
      return 'Android Device ${Random().nextInt(9999)}';
    }
    return 'Beam Device ${Random().nextInt(9999)}';
  }

  String get deviceName => _prefs.getString('device_name') ?? 'Beam Device';
  Future<void> setDeviceName(String name) async {
    await _prefs.setString('device_name', name);
  }

  String get deviceId {
    String? id = _prefs.getString('device_id');
    if (id == null) {
      id =
          DateTime.now().millisecondsSinceEpoch.toString() +
          Random().nextInt(10000).toString();
      _prefs.setString('device_id', id);
    }
    return id;
  }

  int get port => _prefs.getInt('device_port') ?? 9001;
  Future<void> setPort(int p) async {
    await _prefs.setInt('device_port', p);
  }

  String? get downloadDirectory => _prefs.getString('download_dir');
  Future<void> setDownloadDirectory(String? dir) async {
    if (dir == null) {
      await _prefs.remove('download_dir');
    } else {
      await _prefs.setString('download_dir', dir);
    }
  }

  bool get autoAcceptFromTrusted => _prefs.getBool('auto_accept') ?? true;
  Future<void> setAutoAcceptFromTrusted(bool val) async {
    await _prefs.setBool('auto_accept', val);
  }

  bool get showSpeedInNotification =>
      _prefs.getBool('show_speed_notif') ?? true;
  Future<void> setShowSpeedInNotification(bool val) async {
    await _prefs.setBool('show_speed_notif', val);
  }
}
