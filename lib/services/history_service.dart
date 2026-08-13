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
}
