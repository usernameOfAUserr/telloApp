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
          seedColor: const Color(0xff39ff88),
          brightness: Brightness.dark,
          surface: const Color(0xff07150d),
        ),
        scaffoldBackgroundColor: const Color(0xff020805),
        cardTheme: const CardThemeData(
          color: Color(0xff07150d),
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Color(0x6639ff88)),
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
        fontFamily: 'monospace',
        dividerColor: const Color(0x5539ff88),
        useMaterial3: true,
      ),
      home: const ControlScreen(),
    );
  }
}
