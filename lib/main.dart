import 'package:flutter/material.dart';
import 'package:beam/ui/theme.dart';
import 'package:beam/ui/screens/home_screen.dart';

void main() {
  runApp(const BeamApp());
}

class BeamApp extends StatelessWidget {
  const BeamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beam',
      theme: beamTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
