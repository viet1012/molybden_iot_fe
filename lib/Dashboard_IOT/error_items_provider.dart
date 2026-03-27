import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ErrorItemsProvider with ChangeNotifier {
  final Map<String, Map<String, dynamic>> _errorItemsByRowId = {};
  final Set<String> abnormalLots = {};

  Map<String, Map<String, dynamic>> get errorItemsByRowId => _errorItemsByRowId;

  void updateErrorItems(
    String uniqueRowId,
    String machineId,
    String checkType,
    String lot,
    List<String> errors,
  ) {
    _errorItemsByRowId[uniqueRowId] = {
      'rowId': uniqueRowId,
      'machineId': machineId,
      'checkType': checkType,
      'lot': lot,
      'errors': errors,
    };

    debugPrint(
      '[Provider][ADD/UPDATE] key=$uniqueRowId | machine=$machineId | step=$checkType | lot=$lot | total=${_errorItemsByRowId.length}',
    );

    notifyListeners();
  }

  void removeError(String uniqueRowId) {
    final removed = _errorItemsByRowId.remove(uniqueRowId);
    if (removed != null) {
      debugPrint(
        '[Provider][REMOVE] key=$uniqueRowId | total=${_errorItemsByRowId.length}',
      );
      notifyListeners();
    }
  }

  void clearErrors() {
    _errorItemsByRowId.clear();
    abnormalLots.clear();
    debugPrint('[Provider][CLEAR ALL]');
    notifyListeners();
  }

  void markAbnormal(String lotId) {
    abnormalLots.add(lotId);
    debugPrint('[Provider][MARK ABNORMAL] lot=$lotId');
  }

  bool isAlreadyAbnormal(String lotId) {
    return abnormalLots.contains(lotId);
  }
}
