class CaptureEssai {
  const CaptureEssai({
    required this.id,
    required this.typeEssai,
    required this.origine,
    required this.dateCreation,
    required this.donneesMoteur,
    required this.geometrie,
    required this.configuration,
    this.nomFichier,
    this.cheminSource,
  });

  final int id;
  final String typeEssai;
  final String origine;
  final DateTime dateCreation;
  final String? nomFichier;
  final String? cheminSource;
  final Map<String, Object?> donneesMoteur;
  final Map<String, Object?> geometrie;
  final Map<String, Object?> configuration;
}
