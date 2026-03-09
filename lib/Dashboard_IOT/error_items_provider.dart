import 'package:flutter/material.dart';

class ErrorItemsProvider with ChangeNotifier {
  // Sử dụng rowId làm key, lưu trữ lỗi cho từng rowId.
  Map<String, Map<String, dynamic>> _errorItemsByRowId = {};

  Map<String, Map<String, dynamic>> get errorItemsByRowId => _errorItemsByRowId;

  final Set<String> abnormalLots = {}; // ✅ lưu các lot đã gửi lỗi

  void updateErrorItems(String rowId, String machineId, String checkType,
      String lot, List<String> errors) {
    // Thêm hoặc cập nhật lỗi cho rowId
    if (!_errorItemsByRowId.containsKey(rowId)) {
      _errorItemsByRowId[rowId] = {
        'machineId': machineId,
        'checkType': checkType,
        'lot': lot,
        'errors': errors
      };
    } else {
      _errorItemsByRowId[rowId]!['errors'] = errors;
    }
    notifyListeners();
  }

  // Xóa lỗi của một rowId
  void removeError(String rowId) {
    if (errorItemsByRowId.containsKey(rowId)) {
      // print(
      //     "🛑 Xóa khỏi Provider: $rowId - Trước khi xóa: ${errorItemsByRowId.keys}");
      errorItemsByRowId.remove(rowId);
      notifyListeners();
      //print("✅ Sau khi xóa: ${errorItemsByRowId.keys}");
    }
  }

  void clearErrors() {
    errorItemsByRowId.clear();
    notifyListeners();
  }

  // ✅ Đánh dấu lot đã gửi lỗi
  void markAbnormal(String lotId) {
    abnormalLots.add(lotId);
  }

  // ✅ Kiểm tra đã gửi lỗi chưa
  bool isAlreadyAbnormal(String lotId) {
    return abnormalLots.contains(lotId);
  }
}
