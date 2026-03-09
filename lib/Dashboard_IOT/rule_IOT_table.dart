import 'package:flutter/material.dart';

class FerthRuleRow {
  final String step;
  final String time;
  final bool subBush;
  final bool mainBush;
  final bool newProduct;

  FerthRuleRow({
    required this.step,
    required this.time,
    required this.subBush,
    required this.mainBush,
    required this.newProduct,
  });
}

class FerthRuleTable extends StatefulWidget {
  const FerthRuleTable({super.key});

  @override
  State<FerthRuleTable> createState() => _FerthRuleTableState();
}

class _FerthRuleTableState extends State<FerthRuleTable>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;
  int? _hoveredIndex;

  static final List<FerthRuleRow> data = [
    FerthRuleRow(
        step: "Wash_1",
        time: "60m",
        subBush: true,
        mainBush: true,
        newProduct: true),
    FerthRuleRow(
        step: "Dry_1",
        time: "60m",
        subBush: true,
        mainBush: true,
        newProduct: true),
    FerthRuleRow(
        step: "Cool_Fan_1",
        time: "30m",
        subBush: true,
        mainBush: true,
        newProduct: true),
    FerthRuleRow(
        step: "Molipden_1",
        time: "60m",
        subBush: true,
        mainBush: true,
        newProduct: true),
    FerthRuleRow(
        step: "Vaccum",
        time: "30m",
        subBush: true,
        mainBush: true,
        newProduct: true),
    FerthRuleRow(
        step: "Dry_2",
        time: "3m",
        subBush: true,
        mainBush: true,
        newProduct: true),
    FerthRuleRow(
        step: "Cool_Fan_2",
        time: "10m",
        subBush: true,
        mainBush: true,
        newProduct: true),
    FerthRuleRow(
        step: "Molipden_2",
        time: "60m",
        subBush: true,
        mainBush: true,
        newProduct: true),
    FerthRuleRow(
        step: "Dry_3",
        time: "60-90m",
        subBush: true,
        mainBush: true,
        newProduct: true),
    FerthRuleRow(
        step: "Cool_Fan_3",
        time: "20m",
        subBush: true,
        mainBush: true,
        newProduct: true),
    FerthRuleRow(
        step: "1h Hot Oil",
        time: "60m",
        subBush: true,
        mainBush: true,
        newProduct: false),
    FerthRuleRow(
        step: "3h Cool Oil",
        time: "180m",
        subBush: true,
        mainBush: true,
        newProduct: false),
    FerthRuleRow(
        step: "24h Cool Oil",
        time: "1440m",
        subBush: false,
        mainBush: true,
        newProduct: false),
    FerthRuleRow(
        step: "Aging 7day",
        time: "10080m",
        subBush: false,
        mainBush: false,
        newProduct: true),
  ];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      data.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    _fadeAnimations = _controllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: c, curve: Curves.easeOut),
            ))
        .toList();

    _slideAnimations = _controllers
        .map((c) => Tween<Offset>(
              begin: const Offset(-0.05, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();

    // Staggered row entrance
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: 80 + i * 60), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEAF4FB), Color(0xFFF5F9FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, index) {
                return FadeTransition(
                  opacity: _fadeAnimations[index],
                  child: SlideTransition(
                    position: _slideAnimations[index],
                    child: _buildRow(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D7DB5), Color(0xFF1A3D4F)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x441197D1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _headerCell("⚙  PROCESS", flex: 3),
          _headerCell("⏱  TIME"),
          _headerCell("SUB BUSH"),
          _headerCell("MAIN BUSH"),
          _headerCell("NEW PRODUCT"),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.8,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildRow(int index) {
    final row = data[index];
    final isHovered = _hoveredIndex == index;
    final isEven = index % 2 == 0;

    Color baseColor = isEven ? const Color(0xFFEDF6FB) : Colors.white;
    Color hoverColor = const Color(0xFFD0ECFA);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: isHovered ? hoverColor : baseColor,
          border: Border(
            left: isHovered
                ? const BorderSide(color: Color(0xFF1197D1), width: 4)
                : const BorderSide(color: Colors.transparent, width: 4),
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          boxShadow: isHovered
              ? [
                  const BoxShadow(
                    color: Color(0x221197D1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            // PROCESS
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: isHovered ? 20 : 18,
                    color: isHovered
                        ? const Color(0xFF0D7DB5)
                        : const Color(0xFF1A3D4F),
                    letterSpacing: 0.3,
                  ),
                  child: Text(row.step),
                ),
              ),
            ),

            // TIME badge
            Expanded(
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? const Color(0xFF1197D1)
                        : const Color(0xFF1A3D4F).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    row.time,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: isHovered ? Colors.white : const Color(0xFF0D7DB5),
                    ),
                  ),
                ),
              ),
            ),

            // SUB BUSH
            Expanded(
                child: Center(child: _animatedIcon(row.subBush, index, 0))),

            // MAIN BUSH
            Expanded(
                child: Center(child: _animatedIcon(row.mainBush, index, 1))),

            // NEW PRODUCT
            Expanded(
                child: Center(child: _animatedIcon(row.newProduct, index, 2))),
          ],
        ),
      ),
    );
  }

  Widget _animatedIcon(bool value, int rowIndex, int colIndex) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: Duration(milliseconds: 300 + rowIndex * 50 + colIndex * 30),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: value
              ? const Color(0xFF1DB954) // xanh lá đậm
              : const Color(0xFFE53935), // đỏ đậm
          boxShadow: [
            BoxShadow(
              color: value
                  ? const Color(0xFF1DB954).withOpacity(0.45)
                  : const Color(0xFFE53935).withOpacity(0.40),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          value ? Icons.check_rounded : Icons.close_rounded,
          color: Colors.white, // icon trắng nổi bật trên nền màu
          size: 18,
        ),
      ),
    );
  }
}
