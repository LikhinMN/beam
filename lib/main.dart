import 'package:flutter/material.dart';
import 'package:beam/ui/theme.dart';
import 'package:beam/ui/screens/home_screen.dart';
import 'package:beam/core/app_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initAppServices();
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
