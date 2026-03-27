import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'Dashboard_IOT/dashboardIOT_screen.dart';
import 'Dashboard_IOT/error_items_provider.dart';

Future<void> main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ErrorItemsProvider>(
          create: (_) => ErrorItemsProvider(),
        ),
      ],
      child: const MaterialApp(
        title: 'Dashboard Molybden',
        debugShowCheckedModeBanner: false,
        home: DashboardIOTScreen(),
      ),
    );
  }
}
