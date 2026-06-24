import 'package:flutter/material.dart';
import 'package:beam/ui/theme.dart';
import 'package:beam/ui/screens/home_screen.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:beam/core/app_services.dart';

Future<void> logError(String error, StackTrace? stack) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/beam_crash_logs.txt');
    final time = DateTime.now().toIso8601String();
    await file.writeAsString(
      '[$time] $error\n$stack\n\n',
      mode: FileMode.append,
    );
  } catch (e) {
    debugPrint('Failed to write crash log: $e');
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('[Lifecycle] ${state.name}');
    if (state == AppLifecycleState.detached) {
      print('[Lifecycle] App detached but keeping services alive');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) async {
    FlutterError.presentError(details);
    await logError(details.exceptionAsString(), details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logError(error.toString(), stack);
    return true;
  };

  WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
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
