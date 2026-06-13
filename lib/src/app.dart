import 'package:flutter/material.dart';

import 'screens/control_screen.dart';

class TelloApp extends StatelessWidget {
  const TelloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tello EDU Controller',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff19a7ce),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff08131f),
        cardTheme: const CardThemeData(
          color: Color(0xff122235),
          margin: EdgeInsets.zero,
        ),
        useMaterial3: true,
      ),
      home: const ControlScreen(),
    );
  }
}
