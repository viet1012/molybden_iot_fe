import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerTitle extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color textColor;

  const ShimmerTitle({
    super.key,
    required this.text,
    this.fontSize = 18,
    this.fontWeight = FontWeight.bold,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      period: const Duration(milliseconds: 5000),
      gradient: const LinearGradient(
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
        text,
        style: TextStyle(
          fontWeight: fontWeight,
          fontSize: fontSize,
          color: textColor,
        ),
      ),
    );
  }
}
