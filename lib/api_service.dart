import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'model/BatchAbnormalModel.dart';
import 'model/FerthModel.dart';
import 'model/LotModel.dart';
import 'model/machine.dart';

class ApiService {
  final String baseUrl = "http://localhost:9998/heatguide";

  /// Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    startFetchingIOT();
  }

  /// STREAM MACHINE
  final StreamController<List<Machine>> _machineController =
  StreamController.broadcast();

  Stream<List<Machine>> get machineStream => _machineController.stream;

  List<Machine>? _lastMachines;

  /// STREAM IOT
  final StreamController<List<FerthModel>> _iotController =
  StreamController.broadcast();

  final StreamController<List<FerthModel>> _iotController1 =
  StreamController.broadcast();

  final StreamController<List<FerthModel>> _iotController2 =
  StreamController.broadcast();

  Stream<List<FerthModel>> get iotStream => _iotController.stream;
  Stream<List<FerthModel>> get iotStream1 => _iotController1.stream;
  Stream<List<FerthModel>> get iotStream2 => _iotController2.stream;

  List<FerthModel>? _lastIotData;
  List<FerthModel>? _lastIotData2;

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

      List<dynamic> jsonList = jsonDecode(response.body);

      List<Machine> machines =
      jsonList.map((e) => Machine.fromJson(e)).toList();

      if (_isMachineChanged(machines)) {
        _lastMachines = machines;
        _machineController.add(machines);
      }
    } catch (e) {
      print("Machine API error $e");
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
      completer.complete(data);
      sub.cancel();
    });

    fetchMachines();

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
        print("Batch add failed ${response.body}");
      }
    } catch (e) {
      print("Batch API error $e");
    }
  }

  /// ==========================
  /// START AUTO FETCH IOT
  /// ==========================

  void startFetchingIOT() {
    fetchHeatGuide("findDailyHeatGuideMoldAndMainIOT");
    fetchHeatGuide("findDailyHeatGuideMainAndMoldIOT");

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      fetchHeatGuide("findDailyHeatGuideMoldAndMainIOT");
      fetchHeatGuide("findDailyHeatGuideMainAndMoldIOT");
    });
  }

  /// ==========================
  /// FETCH IOT
  /// ==========================

  Future<void> fetchHeatGuide(String endpoint) async {
    try {
      final url = Uri.parse("$baseUrl/$endpoint");

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception("API error ${response.statusCode}");
      }

      List<dynamic> jsonList = jsonDecode(response.body);

      List<FerthModel> data = jsonList.map((e) {
        FerthModel ferth = FerthModel.fromJson(e);

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
      }).where((e) => e.lots.isNotEmpty).toList();

      if (endpoint.contains("MainAndMold")) {
        _updateStream(_iotController2, data, _lastIotData2);
      } else {
        _updateStream(_iotController, data, _lastIotData);
      }
    } catch (e) {
      print("IOT API error $endpoint $e");
    }
  }

  /// ==========================
  /// UPDATE STREAM
  /// ==========================

  void _updateStream(
      StreamController<List<FerthModel>> controller,
      List<FerthModel> newData,
      List<FerthModel>? lastData) {
    if (newData.isEmpty) {
      controller.add([]);
      return;
    }

    if (lastData == null || _isIotChanged(lastData, newData)) {
      controller.add(newData);
    }
  }

  bool _isIotChanged(List<FerthModel> oldData, List<FerthModel> newData) {
    return jsonEncode(oldData) != jsonEncode(newData);
  }

  /// ==========================
  /// CLEAN MEMORY
  /// ==========================

  void dispose() {
    _timer?.cancel();

    _machineController.close();
    _iotController.close();
    _iotController1.close();
    _iotController2.close();
  }
}