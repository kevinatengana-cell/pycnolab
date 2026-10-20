import 'package:flutter/foundation.dart';

import '../models/resultat_gamme.dart';

class HistoryService extends ChangeNotifier {
  HistoryService._internal();
  static final HistoryService instance = HistoryService._internal();

  final List<ResultatGamme> _history = [];

  List<ResultatGamme> get history => List.unmodifiable(_history);

  void add(ResultatGamme result) {
    _history.add(result);
    notifyListeners();
  }

  void clear() {
    _history.clear();
    notifyListeners();
  }

  void signalHistoryChanged() => notifyListeners();
}
