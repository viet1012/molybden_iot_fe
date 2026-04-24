import 'package:flutter/material.dart';
import 'package:molybdeniot/model/ItemModel.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:molybdeniot/Dashboard_IOT/time_format.dart';

import '../../model/FerthModel.dart';
import '../../model/LotModel.dart';
import '../../model/abnormal_count.dart';
import '../../model/abnormal_status.dart';
import '../AnimatedIcon.dart';
import '../blinking_cell.dart';
import '../centered_title_text.dart';
import '../custom_tooltip.dart';
import '../error_items_provider.dart';
import '../status_container_cell.dart';

class MolybdenTable extends StatefulWidget {
  final List<FerthModel> ferthList;

  const MolybdenTable({
    super.key,
    required this.ferthList,
  });

  @override
  State<MolybdenTable> createState() => _MolybdenTableState();
}

class _MolybdenTableState extends State<MolybdenTable> {
  final ScrollController _verticalScrollController = ScrollController();

  static final DateTime kDefaultStart = DateTime(2024, 3, 20, 0, 0);
  static const int kToleranceMinutes = 1;

  static const List<String> kCheckTypes = [
    "1H_Oil_Hot",
    "3H_Oil_Cool",
    "24H_Oil_Cool",
    "Aging_7days",
  ];

  static const Map<String, int> estimatedTimes = {
    "1H_Oil_Hot": 60,
    "3H_Oil_Cool": 180,
    "24H_Oil_Cool": 1440,
    "Aging_7days": 10080,
  };

  List<String> getCheckTypesByFerth(String ferth) {
    return List.from(kCheckTypes);
  }

  DateTime toSecond(DateTime t) {
    return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
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

    for (final item in items) {
      if (!kCheckTypes.contains(item.itemCheck)) continue;

      final status = getItemAbnormalStatus(item, previousFinishTime);

      if (status.isError) errorCount++;
      if (status.isOverdue) overdueCount++;

      if (item.finishTime != null) {
        previousFinishTime = item.finishTime!;
      }
    }

    return AbnormalCount(errorCount: errorCount, overdueCount: overdueCount);
  }

  int getCurrentStepIndex(LotModel lot) {
    final filteredItems =
    lot.items.where((e) => kCheckTypes.contains(e.itemCheck)).toList();

    for (int i = 0; i < filteredItems.length; i++) {
      final item = filteredItems[i];

      if (item.startTime != null && item.finishTime == null) {
        return i;
      }

      if (item.startTime == null) {
        return i;
      }
    }

    return filteredItems.length;
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

      final stepA = getCurrentStepIndex(a);
      final stepB = getCurrentStepIndex(b);

      if (stepA != stepB) {
        return stepB.compareTo(stepA);
      }

      final startA = a.items
          .where((e) => kCheckTypes.contains(e.itemCheck))
          .where((e) => e.startTime != null)
          .map((e) => e.startTime!)
          .toList();

      final startB = b.items
          .where((e) => kCheckTypes.contains(e.itemCheck))
          .where((e) => e.startTime != null)
          .map((e) => e.startTime!)
          .toList();

      if (startA.isEmpty && startB.isEmpty) return 0;
      if (startA.isEmpty) return 1;
      if (startB.isEmpty) return -1;

      final earliestA = startA.reduce((a, b) => a.isBefore(b) ? a : b);
      final earliestB = startB.reduce((a, b) => a.isBefore(b) ? a : b);

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

      final hrcNotes = _extractHrcNotes(lot);
      final ferth = lot.info.isNotEmpty ? lot.info.first.ferth : "";

      final rowCells = <Widget>[
        _centerCell("$idCounter", Colors.grey),
        _buildRfidCell(lot, hrcNotes),
        ..._createRowCellsForItem(
          items: lot.items,
          rowId: "$idCounter",
          lot: lot,
          ferth: ferth,
        ),
      ];

      while (rowCells.length < 6) {
        rowCells.add(const SizedBox.shrink());
      }

      rows.add(TableRow(children: rowCells));
      idCounter++;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
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
    );
  }

  Map<int, TableColumnWidth> get _columnWidths => const {
    0: FixedColumnWidth(70),
    1: FixedColumnWidth(100),
    2: FixedColumnWidth(165),
    3: FixedColumnWidth(165),
    4: FixedColumnWidth(165),
    5: FixedColumnWidth(165),
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
              ...kCheckTypes.map((e) => CenteredTitleText(e)).toList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _centerCell(String text, Color color) {
    return Container(
      height: 40,
      alignment: Alignment.center,
      color: color.withOpacity(0.2),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  _HrcNotes _extractHrcNotes(LotModel lot) {
    String hrc1 = "";
    String hrc2 = "";

    final info = lot.info;

    final hrc1Info = info.firstWhereOrNull((e) => e.itemCheckFinal == 'HRC_1');
    final hrc2Info = info.firstWhereOrNull((e) => e.itemCheckFinal == 'HRC_2');

    if (hrc1Info != null) hrc1 = hrc1Info.note ?? "";
    if (hrc2Info != null) hrc2 = hrc2Info.note ?? "";

    return _HrcNotes(hrc1: hrc1, hrc2: hrc2);
  }

  Widget _buildRfidCell(LotModel lot, _HrcNotes hrcNotes) {
    final icNotePart = (() {
      if (hrcNotes.hrc1.isNotEmpty || hrcNotes.hrc2.isNotEmpty) {
        final parts = <String>[];

        if (hrcNotes.hrc1.isNotEmpty) {
          parts.add('HRC BF TEMP: ${hrcNotes.hrc1}');
        }

        if (hrcNotes.hrc2.isNotEmpty) {
          parts.add('HRC AF TEMP: ${hrcNotes.hrc2}');
        }

        return parts.join(' & ');
      }

      return 'HRC BF TEMP';
    })();

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
        icNotePart: icNotePart,
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

    for (final checkType in kCheckTypes) {
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

      final errorInfo = _computeErrors(
        item: item,
        computedStartTime: computedStartTime,
        previousFinishTime: previousFinishTime,
      );

      final isError = errorInfo.isError;
      final errorComment = errorInfo.errorComment;

      // if (isError && !errorItemsProvider.isAlreadyAbnormal(lot.lot)) {
      //   errorItemsProvider.markAbnormal(lot.lot);
      //
      //   // Nếu muốn push abnormal lên API thì mở lại đoạn này
      //   // final batchAbnormalModel = BatchAbnormalModel(
      //   //   batchId: lot.lot,
      //   //   dateadd: DateTime.now(),
      //   //   process: checkType,
      //   //   comment: errorComment,
      //   // );
      //   // ApiService().addBatch(batchAbnormalModel);
      // }

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
          isWarning: false,
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
              isOverdue: progressState.isOverdue,
              computedStartTime: computedStartTime,
              computedFinishTime: computedFinishTime,
            ),
            child: StatusContainer(
              isOverdue: progressState.isOverdue,
              isInProgress: progressState.isInProgress,
              isError: isError,
              isWarning: false,
              progress: progressState.progress,
              progressColors: progressColors,
              computedFinishTime: computedFinishTime,
              startTime: startTime,
              finishTime: finishTime,
              child: buildStatusRow(
                isOverdue: progressState.isOverdue,
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

      // _postFrameSyncErrors(
      //   errorItemsProvider: errorItemsProvider,
      //   currentOverdueItems: currentOverdueItems,
      //   checkType: checkType,
      //   rowId: rowId,
      //   lot: lot,
      //   computedFinishTime: computedFinishTime,
      // );

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

    return _Times(
      start: start,
      finish: finish,
      estimatedMinutes: estimated,
    );
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
    required ItemModel item,
    required DateTime computedStartTime,
    required DateTime previousFinishTime,
  }) {
    bool isError = false;
    String errorComment = "";

    final threshold =
    previousFinishTime.subtract(const Duration(minutes: kToleranceMinutes));

    if (computedStartTime.isBefore(threshold)) {
      isError = true;
      errorComment = "Start time is earlier than allowed";
    }

    return _ErrorInfo(
      isError: isError,
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
    required DateTime computedFinishTime,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      currentOverdueItems.removeWhere(
            (m) =>
        m['checkType'] == checkType &&
            m['lot'] == lot.lot &&
            DateTime.now().isBefore(computedFinishTime),
      );

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
        final rid = m['rowId'];

        if (lotId == null || ct == null || machine == null || rid == null) {
          continue;
        }

        final isNew = !errorItemsProvider.errorItemsByRowId.containsKey(rid);

        if (isNew) {
          errorItemsProvider.updateErrorItems(
            rid,
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
        if (isOverdue)
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

    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}

class _HrcNotes {
  final String hrc1;
  final String hrc2;

  const _HrcNotes({
    required this.hrc1,
    required this.hrc2,
  });
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
  final String errorComment;

  const _ErrorInfo({
    required this.isError,
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