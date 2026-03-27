import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'model/BatchAbnormalModel.dart';
import 'model/FerthModel.dart';
import 'model/machine.dart';

enum BushType {
  subBush,
  mainBush,
}

class ApiService {
  // final String baseUrl = "http://localhost:9998/guide";
  final String baseUrl = "http://192.168.122.15:9004/guide";

  /// Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    startFetchingIOT();
  }

  /// ==========================
  /// MACHINE STREAM
  /// ==========================
  final StreamController<List<Machine>> _machineController =
      StreamController<List<Machine>>.broadcast();

  Stream<List<Machine>> get machineStream => _machineController.stream;

  List<Machine>? _lastMachines;

  /// ==========================
  /// IOT STREAMS
  /// ==========================
  final StreamController<List<FerthModel>> _subBushIotController =
      StreamController<List<FerthModel>>.broadcast();

  final StreamController<List<FerthModel>> _mainBushIotController =
      StreamController<List<FerthModel>>.broadcast();

  Stream<List<FerthModel>> get subBushIotStream => _subBushIotController.stream;
  Stream<List<FerthModel>> get mainBushIotStream =>
      _mainBushIotController.stream;

  List<FerthModel>? _lastSubBushData;
  List<FerthModel>? _lastMainBushData;

  Timer? _timer;

  /// ==========================
  /// MACHINE API
  /// ==========================
  Future<void> fetchMachines() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/machines'));

      if (response.statusCode != 200) {
        throw Exception("API Error ${response.statusCode}");
      }

      final List<dynamic> jsonList = jsonDecode(response.body);
      final List<Machine> machines =
          jsonList.map((e) => Machine.fromJson(e)).toList();

      if (_isMachineChanged(machines)) {
        _lastMachines = machines;
        _machineController.add(machines);
      }
    } catch (e) {
      print("Machine API error: $e");
      _machineController.add([]);
    }
  }

  bool _isMachineChanged(List<Machine> newData) {
    if (_lastMachines == null) return true;
    return jsonEncode(_lastMachines) != jsonEncode(newData);
  }

  Future<List<Machine>> getMachines() async {
    if (_lastMachines != null) return _lastMachines!;

    final completer = Completer<List<Machine>>();
    late StreamSubscription sub;

    sub = machineStream.listen((data) {
      if (!completer.isCompleted) {
        completer.complete(data);
      }
      sub.cancel();
    });

    await fetchMachines();
    return completer.future;
  }

  /// ==========================
  /// ADD BATCH
  /// ==========================
  Future<void> addBatch(BatchAbnormalModel batch) async {
    final url = Uri.parse('$baseUrl/lot_abnormal/add');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(batch.toJson()),
      );

      if (response.statusCode == 200) {
        print("Batch added success");
      } else {
        print("Batch add failed: ${response.body}");
      }
    } catch (e) {
      print("Batch API error: $e");
    }
  }

  /// ==========================
  /// START AUTO FETCH IOT
  /// ==========================
  void startFetchingIOT() {
    _fetchAllBushData();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) async {
      await _fetchAllBushData();
    });
  }

  Future<void> _fetchAllBushData() async {
    await Future.wait([
      fetchHeatMolybden(BushType.subBush),
      fetchHeatMolybden(BushType.mainBush),
    ]);
  }

  /// ==========================
  /// FETCH IOT BY TYPE
  /// ==========================
  Future<void> fetchHeatMolybden(BushType type) async {
    final endpoint = _getEndpoint(type);
    final controller = _getController(type);
    final lastData = _getLastData(type);

    try {
      final url = Uri.parse("$baseUrl/$endpoint");
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception("API error ${response.statusCode}");
      }

      final List<dynamic> jsonList = jsonDecode(response.body);

      final List<FerthModel> data = jsonList
          .map((e) => _mapAndFilterFerth(e))
          .where((ferth) => ferth.lots.isNotEmpty)
          .toList();

      if (data.isEmpty) {
        controller.add([]);
        _setLastData(type, []);
        return;
      }

      if (lastData == null || _isIotChanged(lastData, data)) {
        controller.add(data);
        _setLastData(type, data);
      }
    } catch (e) {
      print("IOT API error [$endpoint]: $e");
      controller.add([]);
    }
  }

  String _getEndpoint(BushType type) {
    switch (type) {
      case BushType.subBush:
        return "findDailyHeatMolybdenSubBushIOT";
      case BushType.mainBush:
        return "findDailyHeatMolybdenMainBushIOT";
    }
  }

  StreamController<List<FerthModel>> _getController(BushType type) {
    switch (type) {
      case BushType.subBush:
        return _subBushIotController;
      case BushType.mainBush:
        return _mainBushIotController;
    }
  }

  List<FerthModel>? _getLastData(BushType type) {
    switch (type) {
      case BushType.subBush:
        return _lastSubBushData;
      case BushType.mainBush:
        return _lastMainBushData;
    }
  }

  void _setLastData(BushType type, List<FerthModel> data) {
    switch (type) {
      case BushType.subBush:
        _lastSubBushData = data;
        break;
      case BushType.mainBush:
        _lastMainBushData = data;
        break;
    }
  }

  FerthModel _mapAndFilterFerth(dynamic e) {
    final FerthModel ferth = FerthModel.fromJson(e);

    for (var lot in ferth.lots) {
      lot.items.removeWhere((item) =>
          item.itemCheck == "HRC_1" ||
          item.itemCheck == "HRC_2" ||
          item.itemCheck == "Temp_Point" ||
          item.itemCheck == "Temp_Point_1" ||
          item.itemCheck == "Temp_Point_2" ||
          item.itemCheck == "Temp_Point_3" ||
          item.itemCheck == "Temp_Point_4");
    }

    ferth.lots.removeWhere((lot) => lot.items.isEmpty);
    return ferth;
  }

  bool _isIotChanged(List<FerthModel> oldData, List<FerthModel> newData) {
    return jsonEncode(oldData) != jsonEncode(newData);
  }

  /// ==========================
  /// GET CURRENT DATA
  /// ==========================
  Future<List<FerthModel>> getSubBushData() async {
    if (_lastSubBushData != null) return _lastSubBushData!;
    await fetchHeatMolybden(BushType.subBush);
    return _lastSubBushData ?? [];
  }

  Future<List<FerthModel>> getMainBushData() async {
    if (_lastMainBushData != null) return _lastMainBushData!;
    await fetchHeatMolybden(BushType.mainBush);
    return _lastMainBushData ?? [];
  }

  /// ==========================
  /// MANUAL REFRESH
  /// ==========================
  Future<void> refreshAll() async {
    await _fetchAllBushData();
    await fetchMachines();
  }

  /// ==========================
  /// CLEAN MEMORY
  /// ==========================
  void dispose() {
    _timer?.cancel();
    _machineController.close();
    _subBushIotController.close();
    _mainBushIotController.close();
  }
}
