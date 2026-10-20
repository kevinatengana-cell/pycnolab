import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/license_model.dart';

class LicenseService {
  LicenseService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String testCode24Hours = 'PYCNO-TEST-24H';
  static const String testCode30Minutes = 'PYCNO-TEST-30M';
  static const String testCode7Days = 'PYCNO-TEST-7D';
  static const String testCode14Days = 'PYCNO-TEST-14D';
  static const String _licenseKeyName = 'pycnolab_license_payload';
  static const String _consumedCodesKey = 'pycnolab_consumed_license_codes';
  static const String _lastKnownTimeKey = 'pycnolab_last_known_timestamp';

  static const Map<String, String> _reserveAssets = {
    '1M': 'assets/licenses/reserve_cles_1_Mois.txt',
    '3M': 'assets/licenses/reserve_cles_3_Mois.txt',
    '6M': 'assets/licenses/reserve_cles_6_Mois.txt',
    '1Y': 'assets/licenses/reserve_cles_1_An.txt',
  };

  final FlutterSecureStorage _storage;
  Set<String>? _reserveCache;

  Future<String> getMachineId() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('reg', [
          'query',
          r'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography',
          '/v',
          'MachineGuid',
        ]);
        final output = result.stdout.toString();
        final match =
            RegExp(r'MachineGuid\s+REG_SZ\s+([^\r\n]+)').firstMatch(output);
        if (match != null) return match.group(1)!.trim();
      }
    } catch (_) {
      // Le HWID n’est pas bloquant pour le mode hors ligne de test.
    }
    return 'PYCNOLAB_DESKTOP_HWID';
  }

  Future<Set<String>> _loadReserveCodes() async {
    if (_reserveCache != null) return _reserveCache!;

    final result = <String>{};
    for (final asset in _reserveAssets.values) {
      try {
        final content = await rootBundle.loadString(asset);
        result.addAll(
          const LineSplitter()
              .convert(content)
              .map(_normalizeCode)
              .where((code) => code.isNotEmpty),
        );
      } catch (_) {
        // Une réserve absente ou illisible est simplement ignorée.
      }
    }
    _reserveCache = result;
    return result;
  }

  static String _normalizeCode(String value) => value.trim().toUpperCase();

  Future<Duration?> _durationForCode(String code) async {
    if (code == testCode24Hours) {
      return const Duration(hours: 24);
    }
    if (code == testCode30Minutes) {
      return const Duration(minutes: 30);
    }
    if (code == testCode7Days) {
      return const Duration(days: 7);
    }
    if (code == testCode14Days) {
      return const Duration(days: 14);
    }

    final reserves = await _loadReserveCodes();
    if (!reserves.contains(code)) return null;

    if (code.startsWith('1M-')) return const Duration(days: 30);
    if (code.startsWith('3M-')) return const Duration(days: 90);
    if (code.startsWith('6M-')) return const Duration(days: 180);
    if (code.startsWith('1Y-')) return const Duration(days: 365);
    return null;
  }

  Future<List<String>> _consumedCodes() async {
    final raw = await _storage.read(key: _consumedCodesKey);
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().map(_normalizeCode).toList();
      }
    } catch (_) {
      // Un registre corrompu ne doit pas provoquer un crash de l’interface.
    }
    return <String>[];
  }

  Future<bool> _wasConsumed(String code) async {
    final consumed = await _consumedCodes();
    return consumed.contains(code);
  }

  Future<void> _markConsumed(String code) async {
    final consumed = await _consumedCodes();
    if (!consumed.contains(code)) consumed.add(code);
    await _storage.write(key: _consumedCodesKey, value: jsonEncode(consumed));
  }

  Future<bool> isLicenseValid() async {
    final license = await getSavedLicense();
    if (license == null || !license.isActive) return false;

    final now = DateTime.now();
    final lastKnownRaw = await _storage.read(key: _lastKnownTimeKey);
    if (lastKnownRaw != null) {
      try {
        final lastKnown = DateTime.parse(lastKnownRaw);
        if (now.isBefore(lastKnown.subtract(const Duration(minutes: 5)))) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }

    await _storage.write(key: _lastKnownTimeKey, value: now.toIso8601String());
    return !license.isExpired;
  }

  Future<LicenseModel?> getSavedLicense() async {
    try {
      final raw = await _storage.read(key: _licenseKeyName);
      if (raw == null || raw.isEmpty) return null;
      return LicenseModel.fromRawJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<bool> activateLicense(String rawCode) async {
    final code = _normalizeCode(rawCode);
    if (code.isEmpty || await _wasConsumed(code)) return false;

    final duration = await _durationForCode(code);
    if (duration == null) return false;

    final now = DateTime.now();
    final currentLicense = await getSavedLicense();
    final currentIsValid = currentLicense != null &&
        currentLicense.isActive &&
        !currentLicense.isExpired;
    final activationDate = currentIsValid ? currentLicense.activationDate : now;
    final expirationBase =
        currentIsValid && currentLicense.expirationDate.isAfter(now)
            ? currentLicense.expirationDate
            : now;
    final expirationDate = expirationBase.add(duration);
    final license = LicenseModel(
      key: code,
      activationDate: activationDate,
      expirationDate: expirationDate,
      totalSeconds: expirationDate.difference(activationDate).inSeconds,
      isActive: true,
      machineId: await getMachineId(),
    );

    await _markConsumed(code);
    await _storage.write(key: _licenseKeyName, value: license.toRawJson());
    await _storage.write(key: _lastKnownTimeKey, value: now.toIso8601String());
    return true;
  }

  Future<void> revokeLicense() async {
    await _storage.delete(key: _licenseKeyName);
    await _storage.delete(key: _lastKnownTimeKey);
  }
}
