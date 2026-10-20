class FormuleModel {
  const FormuleModel({
    this.id,
    this.essaiId,
    required this.ordreExecution,
    required this.cleVariable,
    required this.libelle,
    required this.unite,
    required this.expression,
  });

  final int? id;
  final int? essaiId;
  final int ordreExecution;
  final String cleVariable;
  final String libelle;
  final String unite;
  final String expression;

  Map<String, Object?> toMap({bool includeId = false}) {
    final map = <String, Object?>{
      'essai_id': essaiId,
      'ordre_execution': ordreExecution,
      'cle_variable': cleVariable,
      'libelle': libelle,
      'unite': unite,
      'expression': expression,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  factory FormuleModel.fromMap(Map<String, Object?> map) {
    return FormuleModel(
      id: (map['id'] as num?)?.toInt(),
      essaiId: (map['essai_id'] as num?)?.toInt(),
      ordreExecution: (map['ordre_execution'] as num?)?.toInt() ?? 0,
      cleVariable: map['cle_variable'] as String? ?? '',
      libelle: map['libelle'] as String? ?? '',
      unite: map['unite'] as String? ?? '',
      expression: map['expression'] as String? ?? '',
    );
  }

  FormuleModel copyWith({
    int? id,
    int? essaiId,
    int? ordreExecution,
    String? cleVariable,
    String? libelle,
    String? unite,
    String? expression,
  }) {
    return FormuleModel(
      id: id ?? this.id,
      essaiId: essaiId ?? this.essaiId,
      ordreExecution: ordreExecution ?? this.ordreExecution,
      cleVariable: cleVariable ?? this.cleVariable,
      libelle: libelle ?? this.libelle,
      unite: unite ?? this.unite,
      expression: expression ?? this.expression,
    );
  }
}
