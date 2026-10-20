import 'dart:convert';

class LicenseModel {
  const LicenseModel({
    required this.key,
    required this.activationDate,
    required this.expirationDate,
    required this.totalSeconds,
    required this.isActive,
    required this.machineId,
  });

  final String key;
  final DateTime activationDate;
  final DateTime expirationDate;
  final int totalSeconds;
  final bool isActive;
  final String machineId;

  int get totalDays => totalSeconds ~/ Duration.secondsPerDay;

  Duration get remainingTime {
    final remaining = expirationDate.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isExpired => !DateTime.now().isBefore(expirationDate);

  double get elapsedPercentage {
    final total = expirationDate.difference(activationDate).inSeconds;
    if (total <= 0) return 1.0;
    final elapsed = DateTime.now().difference(activationDate).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'activationDate': activationDate.toIso8601String(),
        'expirationDate': expirationDate.toIso8601String(),
        'totalSeconds': totalSeconds,
        'isActive': isActive,
        'machineId': machineId,
      };

  factory LicenseModel.fromJson(Map<String, dynamic> json) {
    final seconds = json['totalSeconds'] is int
        ? json['totalSeconds'] as int
        : ((json['totalDays'] as num?)?.toInt() ?? 0) * Duration.secondsPerDay;

    return LicenseModel(
      key: json['key'] as String,
      activationDate: DateTime.parse(json['activationDate'] as String),
      expirationDate: DateTime.parse(json['expirationDate'] as String),
      totalSeconds: seconds,
      isActive: json['isActive'] as bool? ?? true,
      machineId: json['machineId'] as String? ?? '',
    );
  }

  String toRawJson() => jsonEncode(toJson());

  factory LicenseModel.fromRawJson(String value) =>
      LicenseModel.fromJson(jsonDecode(value) as Map<String, dynamic>);
}
