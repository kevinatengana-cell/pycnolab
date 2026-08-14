import '../models/resultat_gamme.dart';

class HistoryService {
  HistoryService._internal();
  static final HistoryService instance = HistoryService._internal();

  final List<ResultatGamme> _history = [];

  List<ResultatGamme> get history => List.unmodifiable(_history);

  void add(ResultatGamme result) {
    _history.add(result);
  }

  void clear() {
    _history.clear();
  }

  static List<ResultatGamme> get mockLots => [
    ResultatGamme(
      materiauNom: "Lin Standard",
      normeCode: "ISO 527-4",
      horodatage: DateTime.now().subtract(const Duration(hours: 2)),
      resultatsEchantillons: [
        ResultatEchantillon(identifiant: "ECH-01", contrainteRuptureMpa: 310, deformationRupturePourcent: 2.2, moduleYoungMpa: 17500),
        ResultatEchantillon(identifiant: "ECH-02", contrainteRuptureMpa: 331, deformationRupturePourcent: 2.6, moduleYoungMpa: 19500),
      ],
      resistanceMoyenneMpa: 320.5,
      ecartTypeMpa: 14.8,
      moduleYoungMoyenMpa: 18500.0,
      statut: "conforme",
      deformationMoyennePourcent: 2.4,
      ecartTypeDeformationPourcent: 0.28,
      ecartTypeModuleYoungMpa: 1414.2,
    ),
    ResultatGamme(
      materiauNom: "Chanvre Premium",
      normeCode: "ISO 527-4",
      horodatage: DateTime.now().subtract(const Duration(hours: 1)),
      resultatsEchantillons: [
        ResultatEchantillon(identifiant: "ECH-01", contrainteRuptureMpa: 275, deformationRupturePourcent: 2.9, moduleYoungMpa: 14800),
        ResultatEchantillon(identifiant: "ECH-02", contrainteRuptureMpa: 285.4, deformationRupturePourcent: 3.3, moduleYoungMpa: 16000),
      ],
      resistanceMoyenneMpa: 280.2,
      ecartTypeMpa: 7.35,
      moduleYoungMoyenMpa: 15400.0,
      statut: "conforme",
      deformationMoyennePourcent: 3.1,
      ecartTypeDeformationPourcent: 0.28,
      ecartTypeModuleYoungMpa: 848.5,
    ),
    ResultatGamme(
      materiauNom: "Ortie Sauvage",
      normeCode: "ISO 527-4",
      horodatage: DateTime.now(),
      resultatsEchantillons: [
        ResultatEchantillon(identifiant: "ECH-01", contrainteRuptureMpa: 385.6, deformationRupturePourcent: 1.6, moduleYoungMpa: 20800),
        ResultatEchantillon(identifiant: "ECH-02", contrainteRuptureMpa: 436.0, deformationRupturePourcent: 2.0, moduleYoungMpa: 23400),
      ],
      resistanceMoyenneMpa: 410.8,
      ecartTypeMpa: 35.6,
      moduleYoungMoyenMpa: 22100.0,
      statut: "non_conforme",
      deformationMoyennePourcent: 1.8,
      ecartTypeDeformationPourcent: 0.28,
      ecartTypeModuleYoungMpa: 1838.4,
    ),
  ];
}
