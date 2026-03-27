import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:molybdeniot/model/BatchAbnormalModel.dart';
import 'package:molybdeniot/model/ItemModel.dart';
import 'package:molybdeniot/Dashboard_IOT/time_format.dart';

import '../../model/FerthModel.dart';
import '../../model/LotModel.dart';
import '../../model/abnormal_count.dart';
import '../../model/abnormal_status.dart';
import '../AnimatedIcon.dart';
import '../blinking_cell.dart';
import '../center_text.dart';
import '../centered_title_text.dart';
import '../custom_tooltip.dart';
import '../error_items_provider.dart';
import '../status_container_cell.dart';

class MolybdenMainBushTable extends StatefulWidget {
  final List<FerthModel> ferthList;

  const MolybdenMainBushTable({
    super.key,
    required this.ferthList,
  });

  @override
  State<MolybdenMainBushTable> createState() => _MolybdenMainBushTableState();
}

class _MolybdenMainBushTableState extends State<MolybdenMainBushTable> {
  bool _showWaitingItems = false;
  bool _isLoading = false;
  final ScrollController _verticalScrollController = ScrollController();

  static final DateTime kDefaultStart = DateTime(2024, 3, 20, 0, 0);
  static const int kToleranceMinutes = 1;

  static const List<String> kProcessSteps = [
    "Wash_3",
    "Molybden_1",
    "Vacuum",
    "Dry_1",
    "Cool_Fan_1",
    "Molybden_2",
    "Dry_2",
    "Cool_Fan_2",
    "1H_Oil_Hot",
    "3H_Oil_Cool",
  ];

  static const Map<String, String> kStepTitles = {
    "Wash_3": "Wash_3",
    "Molybden_1": "Molipden 1",
    "Vacuum": "Vacuum",
    "Dry_1": "Dry_1",
    "Cool_Fan_1": "Cool_Fan_1",
    "Molybden_2": "Molipden 2",
    "Dry_2": "Dry_2",
    "Cool_Fan_2": "Cool_Fan_2",
    "1H_Oil_Hot": "1h Hot Oil",
    "3H_Oil_Cool": "3h Cool Oil",
  };

  static const Map<String, int> estimatedTimes = {
    "Wash_3": 60,
    "Molybden_1": 60,
    "Vacuum": 30,
    "Dry_1": 60,
    "Cool_Fan_1": 30,
    "Molybden_2": 60,
    "Dry_2": 60,
    "Cool_Fan_2": 30,
    "1H_Oil_Hot": 60,
    "3H_Oil_Cool": 180,
  };

  List<String> getCheckTypesByFerth(String ferth) {
    return List<String>.from(kProcessSteps);
  }

  DateTime toSecond(DateTime t) {
    return DateTime(
      t.year,
      t.month,
      t.day,
      t.hour,
      t.minute,
      t.second,
    );
  }

  AbnormalStatus getItemAbnormalStatus(
    ItemModel item,
    DateTime previousFinishTime,
  ) {
    final checkType = item.itemCheck;
    final estimatedTime = estimatedTimes[checkType] ?? 0;

    final startTime = item.startTime;
    final finishTime = item.finishTime;

    bool isError = false;
    bool isOverdue = false;

    if (startTime != null) {
      final startSec = toSecond(startTime);
      final prevSec = toSecond(previousFinishTime);

      if (startSec.isBefore(prevSec)) {
        isError = true;
      }
    }

    if (startTime != null && finishTime == null && estimatedTime > 0) {
      final expectedFinish = startTime.add(Duration(minutes: estimatedTime));
      if (DateTime.now().isAfter(expectedFinish)) {
        isOverdue = true;
      }
    }

    return AbnormalStatus(isError: isError, isOverdue: isOverdue);
  }

  AbnormalCount countAbnormalItems(List<ItemModel> items) {
    DateTime previousFinishTime = kDefaultStart;
    int errorCount = 0;
    int overdueCount = 0;

    for (final step in kProcessSteps) {
      final item = _findItem(items, step);
      final status = getItemAbnormalStatus(item, previousFinishTime);

      if (status.isError) errorCount++;
      if (status.isOverdue) overdueCount++;

      final computed = _computeTimes(item, fallbackStart: previousFinishTime);
      previousFinishTime = computed.finish;
    }

    return AbnormalCount(errorCount: errorCount, overdueCount: overdueCount);
  }

  int getCurrentStepIndex(LotModel lot) {
    for (int i = 0; i < kProcessSteps.length; i++) {
      final item = _findItem(lot.items, kProcessSteps[i]);

      if (item.startTime != null && item.finishTime == null) {
        return i;
      }

      if (item.startTime == null) {
        return i;
      }
    }

    return kProcessSteps.length;
  }

  List<LotModel> sortLotsByErrorsAndSizeAndTime(List<FerthModel> ferthList) {
    final allLots = <LotModel>[];

    for (final ferth in ferthList) {
      allLots.addAll(ferth.lots);
    }

    allLots.sort((a, b) {
      final abnormalA = countAbnormalItems(a.items);
      final abnormalB = countAbnormalItems(b.items);

      if (abnormalA.overdueCount != abnormalB.overdueCount) {
        return abnormalB.overdueCount.compareTo(abnormalA.overdueCount);
      }

      if (abnormalA.errorCount != abnormalB.errorCount) {
        return abnormalB.errorCount.compareTo(abnormalA.errorCount);
      }

      if (a.items.length != b.items.length) {
        return b.items.length.compareTo(a.items.length);
      }

      final stepA = getCurrentStepIndex(a);
      final stepB = getCurrentStepIndex(b);

      if (stepA != stepB) {
        return stepB.compareTo(stepA);
      }

      final startTimesA =
          a.items.where((e) => e.startTime != null).map((e) => e.startTime!);
      final startTimesB =
          b.items.where((e) => e.startTime != null).map((e) => e.startTime!);

      if (startTimesA.isEmpty && startTimesB.isEmpty) return 0;
      if (startTimesA.isEmpty) return 1;
      if (startTimesB.isEmpty) return -1;

      final earliestA = startTimesA.reduce((x, y) => x.isBefore(y) ? x : y);
      final earliestB = startTimesB.reduce((x, y) => x.isBefore(y) ? x : y);

      return earliestA.compareTo(earliestB);
    });

    return allLots;
  }

  @override
  Widget build(BuildContext context) {
    final seenLots = <String>{};
    final rows = <TableRow>[];
    int idCounter = 1;

    final sortedLots = sortLotsByErrorsAndSizeAndTime(widget.ferthList);

    for (final lot in sortedLots) {
      if (!seenLots.add(lot.lot)) continue;

      final ferth = lot.info.isNotEmpty ? lot.info.first.ferth : "";
      final rowCells = <Widget>[
        CenteredText("$idCounter", Colors.grey),
        _buildRfidCell(lot),
        ..._createRowCellsForItem(
          items: lot.items,
          rowId: "main-$idCounter",
          lot: lot,
          ferth: ferth,
        ),
      ];

      final totalColumns = 2 + kProcessSteps.length;
      while (rowCells.length < totalColumns) {
        rowCells.add(const SizedBox.shrink());
      }

      rows.add(TableRow(children: rowCells));
      idCounter++;
    }

    return Stack(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  child: Table(
                    border: TableBorder.all(color: Colors.black45, width: 1),
                    columnWidths: _columnWidths,
                    children: rows,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showWaitingItems) _buildWaitingOverlay(context),
      ],
    );
  }

  Map<int, TableColumnWidth> get _columnWidths => const {
        0: FixedColumnWidth(70), // ID
        1: FixedColumnWidth(90), // RFID
        2: FixedColumnWidth(125), // Wash_3
        3: FixedColumnWidth(125), // Molipden 1
        4: FixedColumnWidth(110), // Vacuum
        5: FixedColumnWidth(110), // Dry_1
        6: FixedColumnWidth(125), // Cool_Fan_1
        7: FixedColumnWidth(125), // Molipden 2
        8: FixedColumnWidth(110), // Dry_2
        9: FixedColumnWidth(125), // Cool_Fan_2
        10: FixedColumnWidth(125), // 1h Hot Oil
        11: FixedColumnWidth(135), // 3h Cool Oil
      };

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.blue,
      child: Table(
        border: TableBorder.all(color: Colors.black45, width: 1),
        columnWidths: _columnWidths,
        children: [
          TableRow(
            children: [
              const CenteredTitleText('ID'),
              const CenteredTitleText('RFID'),
              ...kProcessSteps
                  .map((step) => CenteredTitleText(kStepTitles[step] ?? step))
                  .toList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingHeaderButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CenteredTitleText('Waiting'),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            shape: const CircleBorder(),
            side: const BorderSide(color: Colors.white, width: 2),
            backgroundColor: Colors.deepPurple,
            padding: const EdgeInsets.all(8),
          ),
          onPressed: () {},
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.black)
              : const Icon(Icons.hourglass_bottom, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildWaitingOverlay(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => setState(() => _showWaitingItems = false),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: 1.0,
          child: Container(
            height: MediaQuery.of(context).size.height / 1.6,
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Waiting Items List",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          hoverColor: Colors.blueAccent,
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () =>
                              setState(() => _showWaitingItems = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRfidCell(LotModel lot) {
    final details = (() {
      final list = lot.info
          .where((e) => e.poreqnosWithQty.isNotEmpty)
          .map((e) => e.poreqnosWithQty.replaceAll(' ; ', '\n'))
          .toList();

      if (list.isEmpty) return 'No PO info';
      return list.join('\n');
    })();

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: CustomTooltip(
        icNotePart: 'PO Details',
        details: details,
        child: SelectableText(
          '[${lot.rfID_key.toString().padLeft(2, '0')}]',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.blue,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  List<Widget> _createRowCellsForItem({
    required List<ItemModel> items,
    required String rowId,
    required LotModel lot,
    required String ferth,
  }) {
    DateTime previousFinishTime = kDefaultStart;

    final rowCells = <Widget>[];
    final currentOverdueItems = <Map<String, String>>{};
    final errorItemsProvider =
        Provider.of<ErrorItemsProvider>(context, listen: false);

    final allowedTypes = getCheckTypesByFerth(ferth);

    for (final checkType in kProcessSteps) {
      if (!allowedTypes.contains(checkType)) {
        rowCells.add(
          Container(
            height: 40,
            color: Colors.grey.withOpacity(.4),
          ),
        );
        continue;
      }

      final item = _findItem(items, checkType);

      final computed = _computeTimes(item, fallbackStart: previousFinishTime);
      final adjusted = _adjustStartIfNeeded(item, computed, previousFinishTime);

      final startTime = item.startTime;
      final finishTime = item.finishTime;
      final computedStartTime = adjusted.start;
      final computedFinishTime = adjusted.finish;

      const bool isWarning = false;

      final errorInfo = _computeErrors(
        checkType: checkType,
        item: item,
        computedStartTime: computedStartTime,
        computedFinishTime: computedFinishTime,
        previousFinishTime: previousFinishTime,
      );

      final isError = errorInfo.isError;
      final isErrorNG = errorInfo.isErrorNG;
      final errorComment = errorInfo.errorComment;

      if (isError && !errorItemsProvider.isAlreadyAbnormal(lot.lot)) {
        errorItemsProvider.markAbnormal(lot.lot);

        final batchAbnormalModel = BatchAbnormalModel(
          batchId: lot.lot,
          dateadd: DateTime.now(),
          process: checkType,
          comment: errorComment,
        );

        // ApiService().addBatch(batchAbnormalModel);
        debugPrint("Abnormal detected: ${batchAbnormalModel.batchId}");
      }

      final progressState = _computeProgress(
        item: item,
        computedStartTime: computedStartTime,
        computedFinishTime: computedFinishTime,
      );

      if (progressState.isOverdue) {
        currentOverdueItems.add({
          "checkType": checkType,
          "rowId": rowId,
          "lot": lot.lot,
          "machine": item.machine ?? "Unknown",
        });
      }

      final progressColors = _progressColors(
        isInProgress: progressState.isInProgress,
        computedFinishTime: computedFinishTime,
        isOverdue: progressState.isOverdue,
      );

      rowCells.add(
        BlinkingCell(
          isOverdue: progressState.isOverdue,
          isWarning: isWarning,
          child: Tooltip(
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(10),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            message: _tooltipMessage(
              checkType: checkType,
              item: item,
              isError: isError,
              isErrorNG: isErrorNG,
              isWarning: isWarning,
              isOverdue: progressState.isOverdue,
              computedStartTime: computedStartTime,
              computedFinishTime: computedFinishTime,
            ),
            child: StatusContainer(
              isOverdue: progressState.isOverdue,
              isInProgress: progressState.isInProgress,
              isError: isError,
              isWarning: isWarning,
              progress: progressState.progress,
              progressColors: progressColors,
              computedFinishTime: computedFinishTime,
              startTime: startTime,
              finishTime: finishTime,
              child: buildStatusRow(
                isOverdue: progressState.isOverdue,
                isWarning: isWarning,
                isInProgress: progressState.isInProgress,
                isError: isError,
                items: items,
                checkType: checkType,
                computedStartTime: computedStartTime,
              ),
            ),
          ),
        ),
      );

      _postFrameSyncErrors(
        errorItemsProvider: errorItemsProvider,
        currentOverdueItems: currentOverdueItems,
        checkType: checkType,
        rowId: rowId,
        lot: lot,
        finishTime: finishTime,
        computedFinishTime: computedFinishTime,
      );

      previousFinishTime = computedFinishTime;
    }

    return rowCells;
  }

  ItemModel _findItem(List<ItemModel> items, String checkType) {
    return items.firstWhere(
      (e) => e.itemCheck == checkType,
      orElse: () => ItemModel.basic(itemCheck: checkType),
    );
  }

  _Times _computeTimes(ItemModel item, {required DateTime fallbackStart}) {
    final estimated = estimatedTimes[item.itemCheck] ?? 0;
    final start = item.startTime ?? fallbackStart;
    final finish = item.finishTime ?? start.add(Duration(minutes: estimated));
    return _Times(start: start, finish: finish, estimatedMinutes: estimated);
  }

  _Times _adjustStartIfNeeded(
    ItemModel item,
    _Times t,
    DateTime previousFinishTime,
  ) {
    if (previousFinishTime.isBefore(DateTime.now()) && item.startTime == null) {
      final now = DateTime.now();
      return _Times(
        start: now,
        finish: now.add(Duration(minutes: t.estimatedMinutes)),
        estimatedMinutes: t.estimatedMinutes,
      );
    }
    return t;
  }

  _ErrorInfo _computeErrors({
    required String checkType,
    required ItemModel item,
    required DateTime computedStartTime,
    required DateTime computedFinishTime,
    required DateTime previousFinishTime,
  }) {
    bool isError = false;
    bool isErrorNG = false;
    String errorComment = "";

    final threshold =
        previousFinishTime.subtract(const Duration(minutes: kToleranceMinutes));

    if (computedStartTime.isBefore(threshold)) {
      isError = true;
      errorComment = "Start time is earlier than allowed";
    }

    return _ErrorInfo(
      isError: isError,
      isErrorNG: isErrorNG,
      errorComment: errorComment,
    );
  }

  _Progress _computeProgress({
    required ItemModel item,
    required DateTime computedStartTime,
    required DateTime computedFinishTime,
  }) {
    double progress = 1.0;
    bool isInProgress = false;
    bool isOverdue = false;

    if (item.startTime != null && item.finishTime == null) {
      final total = computedFinishTime.difference(computedStartTime);
      final elapsed = DateTime.now().difference(computedStartTime);

      final totalMinutes = total.inMinutes == 0 ? 1 : total.inMinutes;
      progress = (elapsed.inMinutes / totalMinutes).clamp(0.0, 1.0);

      isInProgress = true;
      if (DateTime.now().isAfter(computedFinishTime)) {
        isOverdue = true;
      }
    }

    return _Progress(
      progress: progress,
      isInProgress: isInProgress,
      isOverdue: isOverdue,
    );
  }

  List<Color> _progressColors({
    required bool isInProgress,
    required DateTime computedFinishTime,
    required bool isOverdue,
  }) {
    Color startColor = Colors.blue.withOpacity(0.8);
    Color endColor = isInProgress ? Colors.blue.withOpacity(0.2) : startColor;

    if (isOverdue) {
      final overdueMinutes =
          DateTime.now().difference(computedFinishTime).inMinutes;
      final opacity =
          (0.1 + (overdueMinutes / 30) * (0.8 - 0.4)).clamp(0.4, 0.8);
      startColor = Colors.orange.withOpacity(opacity);
      endColor = Colors.yellow.withOpacity((opacity + 0.1).clamp(0.0, 1.0));
    }

    return [
      startColor,
      HSVColor.fromColor(startColor).withValue(0.9).toColor(),
      endColor,
    ];
  }

  String _tooltipMessage({
    required String checkType,
    required ItemModel item,
    required bool isError,
    required bool isErrorNG,
    required bool isWarning,
    required bool isOverdue,
    required DateTime computedStartTime,
    required DateTime computedFinishTime,
  }) {
    final startTime = item.startTime;
    final finishTime = item.finishTime;

    if (isError) {
      return "⚠️ Schedule Error"
          "\nStart time: ${formatFullDate(startTime)} is too early!"
          "\nMachine: ${item.machine}";
    }

    if (isOverdue) {
      return "⚠️ Overdue!"
          "\nExpected finish: ${formatFullDate(computedFinishTime)}"
          "\nMachine: ${item.machine}";
    }

    if (startTime != null && finishTime == null) {
      return "Start: ${formatFullDate(startTime)}"
          "\nExpected finish: ${formatFullDate(computedFinishTime)}"
          "\nMachine: ${item.machine}";
    }

    if (startTime != null && finishTime != null) {
      return "Start: ${formatFullDate(startTime)}"
          "\nFinish: ${formatFullDate(finishTime)}"
          "\nMachine: ${item.machine}";
    }

    return "Expected start: ${formatFullDate(computedStartTime)}"
        "\nExpected finish: ${formatFullDate(computedFinishTime)}";
  }

  void _postFrameSyncErrors({
    required ErrorItemsProvider errorItemsProvider,
    required Set<Map<String, String>> currentOverdueItems,
    required String checkType,
    required String rowId,
    required LotModel lot,
    required DateTime? finishTime,
    required DateTime computedFinishTime,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      currentOverdueItems.removeWhere((m) =>
          m['checkType'] == checkType &&
          m['lot'] == lot.lot &&
          DateTime.now().isBefore(computedFinishTime));

      final stillOverdue = currentOverdueItems.any(
        (m) => m['rowId'] == rowId && m['checkType'] == checkType,
      );

      if (!stillOverdue &&
          errorItemsProvider.errorItemsByRowId.containsKey(rowId)) {
        errorItemsProvider.removeError(rowId);
      }

      for (final m in currentOverdueItems) {
        final lotId = m['lot'];
        final ct = m['checkType'];
        final machine = m['machine'];
        final uniqueRowId = m['rowId'];

        if (lotId == null ||
            ct == null ||
            machine == null ||
            uniqueRowId == null) {
          continue;
        }

        final isNew =
            !errorItemsProvider.errorItemsByRowId.containsKey(uniqueRowId);

        if (isNew) {
          errorItemsProvider.updateErrorItems(
            uniqueRowId,
            machine,
            ct,
            lotId,
            ["Overdue"],
          );
        }
      }
    });
  }

  Widget buildStatusRow({
    required bool isOverdue,
    required bool isWarning,
    required bool isInProgress,
    required bool isError,
    required List<ItemModel> items,
    required String checkType,
    required DateTime computedStartTime,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isOverdue || isWarning)
          const AnimatedIconWidget(
            icon: Icons.warning_amber,
            color: Colors.red,
            size: 12,
            animationType: AnimationType.pulse,
            duration: Duration(milliseconds: 800),
          ),
        if (isInProgress)
          const AnimatedIconWidget(
            icon: Icons.schedule,
            color: Colors.orange,
            size: 13,
            animationType: AnimationType.rotate,
            duration: Duration(seconds: 3),
          ),
        _createDataCell(items, checkType, computedStartTime),
      ],
    );
  }

  Widget _createDataCell(
    List<ItemModel> items,
    String checkType,
    DateTime previousFinishTime,
  ) {
    final item = _findItem(items, checkType);
    final estimated = estimatedTimes[checkType] ?? 0;

    final isEstimatedStartTime = item.startTime == null;
    final startTime = item.startTime ?? previousFinishTime;

    final isEstimatedFinishTime = item.finishTime == null;
    final finishTime =
        item.finishTime ?? startTime.add(Duration(minutes: estimated));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: TimeTooltip(
        startTime: startTime,
        finishTime: finishTime,
        isEstimatedStartTime: isEstimatedStartTime,
        isEstimatedFinishTime: isEstimatedFinishTime,
      ),
    );
  }

  String formatFullDateBasic(DateTime? dateTime) {
    if (dateTime == null) return "N/A";
    return "${dateTime.day.toString().padLeft(2, '0')}/"
        "${dateTime.month.toString().padLeft(2, '0')}/"
        "${dateTime.year} "
        "${dateTime.hour.toString().padLeft(2, '0')}:"
        "${dateTime.minute.toString().padLeft(2, '0')}";
  }

  String formatFullDate(DateTime? dateTime) {
    if (dateTime == null) return "N/A";
    return DateFormat("dd/MMM/yy HH:mm:ss").format(dateTime);
  }

  String formatTime(DateTime? time) {
    if (time == null) return '--:--';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _Times {
  final DateTime start;
  final DateTime finish;
  final int estimatedMinutes;

  const _Times({
    required this.start,
    required this.finish,
    required this.estimatedMinutes,
  });
}

class _ErrorInfo {
  final bool isError;
  final bool isErrorNG;
  final String errorComment;

  const _ErrorInfo({
    required this.isError,
    required this.isErrorNG,
    required this.errorComment,
  });
}

class _Progress {
  final double progress;
  final bool isInProgress;
  final bool isOverdue;

  const _Progress({
    required this.progress,
    required this.isInProgress,
    required this.isOverdue,
  });
}

extension FirstWhereOrNullExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
