class CritereModel {
  const CritereModel({
    this.id,
    this.essaiId,
    required this.cleVariable,
    this.seuilMin,
    this.seuilMax,
  });

  final int? id;
  final int? essaiId;
  final String cleVariable;
  final double? seuilMin;
  final double? seuilMax;

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'essai_id': essaiId,
      'cle_variable': cleVariable,
      'seuil_min': seuilMin,
      'seuil_max': seuilMax,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  factory CritereModel.fromMap(Map<String, Object?> map) {
    return CritereModel(
      id: (map['id'] as num?)?.toInt(),
      essaiId: (map['essai_id'] as num?)?.toInt(),
      cleVariable: map['cle_variable'] as String? ?? '',
      seuilMin: (map['seuil_min'] as num?)?.toDouble(),
      seuilMax: (map['seuil_max'] as num?)?.toDouble(),
    );
  }

  CritereModel copyWith({
    int? id,
    int? essaiId,
    String? cleVariable,
    double? seuilMin,
    double? seuilMax,
    bool clearSeuilMin = false,
    bool clearSeuilMax = false,
  }) {
    return CritereModel(
      id: id ?? this.id,
      essaiId: essaiId ?? this.essaiId,
      cleVariable: cleVariable ?? this.cleVariable,
      seuilMin: clearSeuilMin ? null : (seuilMin ?? this.seuilMin),
      seuilMax: clearSeuilMax ? null : (seuilMax ?? this.seuilMax),
    );
  }
}
