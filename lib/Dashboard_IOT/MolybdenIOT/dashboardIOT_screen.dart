import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:molybdeniot/Dashboard_IOT/rule_IOT_table.dart';
import 'package:molybdeniot/Dashboard_IOT/status_legend_popup.dart';
import 'package:shimmer/shimmer.dart';

import '../../api_service.dart';
import '../../model/FerthModel.dart';
import '../ImageMachine.dart';
import '../SimpleClockIcon.dart';
import '../shimmer_title.dart';
import 'molybden_main_bush_table.dart';
import 'molybden_sub_bush_1h_table.dart';
import 'molybden_sub_bush_table.dart';

class DashboardIOTScreen extends StatefulWidget {
  const DashboardIOTScreen({super.key});

  @override
  State<DashboardIOTScreen> createState() => _DashboardIOTScreenState();
}

class _DashboardIOTScreenState extends State<DashboardIOTScreen> {
  late Future<List<FerthModel>> futureData;
  late Future<List<FerthModel>> futureData1;

  Timer? _timer;
  bool _showDetails = false;
  late DateTime _currentTime;

  DateTime? _lastUpdateTime;

  StreamSubscription<List<FerthModel>>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });

    _streamSubscription = ApiService().subBushIotStream.listen((data) {
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
    _streamSubscription?.cancel();
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
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF4F4F4),
                    Color(0xFF2C515E),
                    Color(0xFF1197D1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: LayoutBuilder(
              builder: (context, constraints) {
                double width = constraints.maxWidth;

                if (width < 800) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const ShimmerTitle(
                                  text: 'Dashboard Molybden', fontSize: 22),
                              const SizedBox(width: 8),
                              IconButton(
                                icon:
                                    const Icon(Icons.info, color: Colors.black),
                                onPressed: _showRulesPopup,
                              ),
                            ],
                          ),
                          Text(
                            DateFormat("dd/MMM HH:mm:ss").format(_currentTime),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              StatusLegendPopup.buildLegendItem(
                                  Colors.blue.withOpacity(0.8),
                                  "Completed",
                                  Colors.green,
                                  Colors.white),
                              const SizedBox(width: 16),
                              const Row(
                                children: [
                                  SimpleClockIcon(
                                    size: 20,
                                    color: Colors.orange,
                                    backgroundColor: Colors.transparent,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Now",
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white),
                                  )
                                ],
                              ),
                              const SizedBox(width: 16),
                              StatusLegendPopup.buildLegendIconItem(
                                  "Overdue",
                                  Icons.warning_amber,
                                  Colors.red,
                                  Colors.white),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Final: ${formatTime(_lastUpdateTime)}",
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14),
                              ),
                              Text(
                                "Next: ${formatTime(_lastUpdateTime?.add(const Duration(minutes: 1)))}",
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          const Shimmer(
                            period: Duration(milliseconds: 5000),
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF001F3F),
                                Color(0xFF003D5C),
                                Color(0xFF0074D9),
                                Color(0xFF39CCCC),
                                Color(0xFF0074D9),
                                Color(0xFF003D5C),
                                Color(0xFF001F3F),
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
                            icon: const Icon(Icons.info, color: Colors.black),
                            onPressed: _showRulesPopup,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Row(
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
                                size: 22,
                                color: Colors.orange,
                                backgroundColor: Colors.transparent,
                              ),
                              SizedBox(width: 10),
                              Text(
                                "Now",
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white),
                              )
                            ],
                          ),
                          const SizedBox(width: 24),
                          StatusLegendPopup.buildLegendIconItem("Overdue",
                              Icons.warning_amber, Colors.red, Colors.white),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            DateFormat("dd/MMM/yy HH:mm:ss")
                                .format(_currentTime),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20),
                          ),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Final update: ${formatTime(_lastUpdateTime)}",
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 18),
                              ),
                              Text(
                                "Next update: ${formatTime(_lastUpdateTime?.add(const Duration(minutes: 1)))}",
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 18),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            )),
      ),
      body: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// ===== SUB BUSH =====
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ShimmerTitle(text: 'Sub Bush'),
                        Expanded(
                          child: buildTableFromStream(
                            ApiService().subBushIotStream,
                            (data) => MolybdenSubBushTable(ferthList: data),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  /// ===== Main Bush =====
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ShimmerTitle(text: 'Main Bush'),
                        Expanded(
                          child: buildTableFromStream(
                            ApiService().mainBushIotStream,
                            (data) => MolybdenMainBushTable(ferthList: data),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            /// 1h + ImageMachine cùng hàng
            Expanded(
              flex: 2,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Expanded(
                  //   flex: 5,
                  //   child: buildTableFromStream(
                  //     ApiService().mainBushIotStream,
                  //     (data) => MolybdenMainBushTable(ferthList: data),
                  //   ),
                  // ),
                  Expanded(
                    flex: 3,
                    child: buildTableFromStream(
                      ApiService().subBush1HIotStream,
                      (data) => MolybdenTable(ferthList: data),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF1197D1).withOpacity(0.7),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x331197D1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: ImageMachine(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRulesPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
              maxHeight: MediaQuery.of(context).size.height - 48,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F2027),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blueAccent.withOpacity(.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.7),
                    blurRadius: 25,
                    spreadRadius: 3,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: const BoxDecoration(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(14)),
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF1197D1),
                          Color(0xFF2C515E),
                          Color(0xFF001F3F),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.rule, color: Colors.white),
                        const SizedBox(width: 10),
                        const Text(
                          "Molybden Rules Check",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const FerthRuleTable(),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      "System rule validation for Molybden process",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildTableFromStream(
    Stream<List<FerthModel>> stream,
    Widget Function(List<FerthModel>) tableBuilder,
  ) {
    return Card(
      elevation: 10,
      color: Colors.white,
      shadowColor: const Color(0xFF1197D1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: const Color(0xFF1197D1).withOpacity(0.7),
          width: 1.5,
        ),
      ),
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
              child: const Shimmer(
                period: Duration(milliseconds: 3000),
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF3F0000),
                    Color(0xFF5C0000),
                    Color(0xFFD90000),
                    Color(0xFFFF4136),
                    Color(0xFFD90000),
                    Color(0xFF5C0000),
                    Color(0xFF3F0000),
                  ],
                  stops: [0.0, 0.15, 0.3, 0.5, 0.7, 0.85, 1.0],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                child: Text(
                  "🚫 No Data Available",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            );
          } else {
            return tableBuilder(snapshot.data!);
          }
        },
      ),
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
