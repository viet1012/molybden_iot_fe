import 'dart:async';

import 'package:flutter/material.dart';
import 'package:molybdeniot/Dashboard_IOT/rule_IOT_table.dart';
import 'package:molybdeniot/Dashboard_IOT/status_legend_popup.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../api_service.dart';
import '../model/FerthModel.dart';
import 'Animated_induction_text.dart';
import 'ImageMachine.dart';
import 'MolybdenIOT/molybden_table.dart';
import 'SimpleClockIcon.dart';
import 'error_items_provider.dart';
import 'ferth_main_mold_table.dart';
import 'ferth_mold_main_table.dart';

class DashboardIOTScreen extends StatefulWidget {
  const DashboardIOTScreen({super.key});

  @override
  State<DashboardIOTScreen> createState() => _DashboardIOTScreenState();
}

class _DashboardIOTScreenState extends State<DashboardIOTScreen> {
  late Future<List<FerthModel>> futureData;
  late Future<List<FerthModel>> futureData1;

  Timer? _timer; // 🕒 Lưu trữ Timer
  bool _showDetails = false;
  late DateTime _currentTime;

  DateTime? _lastUpdateTime; // Thời gian cập nhật cuối cùng

  StreamSubscription<List<FerthModel>>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
    // ApiService().startFetchingIOT();

    // Lắng nghe sự kiện từ stream
    _streamSubscription = ApiService().iotStream.listen((data) {
      if (mounted) {
        setState(() {
          _lastUpdateTime = DateTime.now();
        });
        print("🔄 UI Reloaded at: $_lastUpdateTime");
      }
    });
  }

  @override
  void dispose() {
    ApiService()
        .dispose(); // 🛑 Đảm bảo dừng StreamController để tránh rò rỉ bộ nhớ
    _timer?.cancel();
    super.dispose();
  }

  String formatTime(DateTime? time) {
    if (time == null) return "Chưa cập nhật";
    return "${time.hour.toString().padLeft(2, '0')}:"
        "${time.minute.toString().padLeft(2, '0')}:"
        "${time.second.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ErrorItemsProvider(),
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(.7),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: AppBar(
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF4F4F4), // Xanh đen
                    Color(0xFF2C515E), // Xanh navy xám
                    Color(0xFF1197D1), // Xanh xám cổ điển
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Shimmer(
                      period: Duration(milliseconds: 5000),
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF001F3F), // Xanh đậm
                          Color(0xFF003D5C), // Xanh trung bình
                          Color(0xFF0074D9), // Xanh sáng
                          Color(0xFF39CCCC), // Xanh cyan
                          Color(0xFF0074D9), // Xanh sáng
                          Color(0xFF003D5C), // Xanh trung bình
                          Color(0xFF001F3F), // Xanh đậm
                        ],
                        stops: [0.0, 0.15, 0.3, 0.5, 0.7, 0.85, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      child: Text(
                        'Dashboard Molybden',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      hoverColor: Colors.white,
                      icon: const Icon(Icons.info, color: Colors.black),
                      onPressed: () {
                        setState(() {
                          _showDetails = !_showDetails;
                        });
                      },
                    ),
                    IconButton(
                      hoverColor: Colors.white,
                      onPressed: () => StatusLegendPopup.show(context),
                      icon: const Icon(Icons.help_outline,
                          color: Colors.black), // Icon thông tin
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StatusLegendPopup.buildLegendItem(
                        Colors.blue.withOpacity(0.8),
                        "Completed",
                        Colors.green,
                        Colors.white),
                    const SizedBox(width: 24),
                    const Row(
                      children: [
                        SimpleClockIcon(
                          size: 22, // kích thước
                          color: Colors.orange, // màu kim
                          backgroundColor:
                              Colors.transparent, // màu nền (tùy chọn)
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Now",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        )
                      ],
                    ),
                    const SizedBox(width: 24),
                    StatusLegendPopup.buildLegendIconItem("Overdue",
                        Icons.warning_amber, Colors.red, Colors.white),
                  ],
                ),
                Text(
                  DateFormat("dd/MMM/yy HH:mm:ss").format(_currentTime),
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Final update: ${formatTime(_lastUpdateTime)}",
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 20),
                    ),
                    Text(
                      "Next update: ${formatTime(_lastUpdateTime?.add(const Duration(minutes: 1)))}",
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  buildRow(
                    stream: ApiService().iotStream,
                    tableBuilder: (data) => MolybdenTable(ferthList: data),
                  ),

                  // Row(
                  //   children: [
                  //     Expanded(
                  //       child: Column(
                  //         children: [
                  //           const Shimmer(
                  //             period: Duration(milliseconds: 9000),
                  //             gradient: LinearGradient(
                  //               colors: [
                  //                 Color(0xFF0074D9), // Black (bóng tối nền)
                  //                 Color(0xFFE0E0E0), // Light gray (ánh sáng)
                  //                 Color(0xFF1067C1), // Quay về tối
                  //               ],
                  //               stops: [0.1, 0.5, 1],
                  //               begin: Alignment.topLeft,
                  //               end: Alignment.bottomRight,
                  //             ),
                  //             child: Text(
                  //               'Induction',
                  //               style: TextStyle(
                  //                   fontWeight: FontWeight.bold,
                  //                   color: Colors.white,
                  //                   fontSize: 20),
                  //             ),
                  //           ),
                  //           buildRow(
                  //             name: "Induction",
                  //             titles: ["Main Post", "Mold Post"],
                  //             stream: ApiService().iotStream2,
                  //             tableBuilder: (data) =>
                  //                 FerthMainMoldTable(ferthList: data),
                  //           ),
                  //         ],
                  //       ),
                  //     ),
                  //     const SizedBox(width: 8),
                  //     SizedBox(
                  //       width: MediaQuery.of(context).size.width / 2.3,
                  //       child: const ImageMachine(),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),
            if (_showDetails)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showDetails = false;
                    });
                  },
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: SizedBox(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(.9),
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.blueAccent,
                                    Colors.deepPurpleAccent
                                  ], // Gradient màu
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ), // Màu nền
                                border: Border.all(
                                  color: Colors.blueAccent, // Màu viền
                                  width: 2.0, // Độ dày viền
                                ),
                                borderRadius:
                                    BorderRadius.circular(8), // Bo tròn góc
                              ),
                              padding: const EdgeInsets.all(8),
                              // Thêm padding bên trong
                              child: const Text(
                                "HeatGuide Rules Check",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Flexible(
                                //   child: MolipdenDataTableWidget(),
                                // ),
                                Flexible(child: RuleIotDataTableWidget()),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildTableFromStream(Stream<List<FerthModel>> stream,
      Widget Function(List<FerthModel>) tableBuilder) {
    return Card(
      elevation: 10,
      // Tạo hiệu ứng đổ bóng
      color: Colors.white,
      shadowColor: Colors.blue.shade900,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: Colors.blueAccent, width: 1), // Viền xanh
      ),
      // margin: const EdgeInsets.all(8),
      child:  SizedBox(
              height: MediaQuery.of(context).size.height / 3.5,
              child: StreamBuilder<List<FerthModel>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Container(
                      alignment: Alignment.center,
                      child: const Text(
                        "🚫 No Data Available",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    );
                  } else {
                    return tableBuilder(snapshot.data!);
                  }
                },
              ),
            )

    );
  }

  Widget borderedTitle({
    required String text,
    Color textColor = Colors.black,
    Color borderColor = Colors.grey,
    double borderWidth = 2.0,
    double borderRadius = 8.0,
    Color backgroundColor = Colors.white,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: padding,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget buildRow({
    required Stream<List<FerthModel>> stream,
    required Widget Function(List<FerthModel>) tableBuilder,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(child: buildTableFromStream(stream, tableBuilder)),
      ],
    );
  }
}
