import 'package:flutter/material.dart';
import 'package:pico/pico.dart';
import 'package:beam/core/state.dart';

void main() {
  runApp(const BeamApp());
}

class BeamApp extends StatelessWidget {
  const BeamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beam',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BeamHomePage(),
    );
  }
}

class BeamHomePage extends StatelessWidget {
  const BeamHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Beam - File Sharing'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Use PicoBuilder to rebuild only when isServerRunning changes
            PicoBuilder<AppState, bool>(
              store: store,
              selector: (state) => state.isServerRunning,
              builder: (context, isServerRunning) {
                return Column(
                  children: [
                    Text(
                      isServerRunning ? 'Server is running' : 'Server is stopped',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Mutate state using Pico action
                        setServerRunning(!isServerRunning);
                      },
                      child: Text(isServerRunning ? 'Stop Server' : 'Start Server'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
            
            // Rebuilds only when transfers list changes
            PicoBuilder<AppState, int>(
              store: store,
              selector: (state) => state.transfers.length,
              builder: (context, transferCount) {
                return Text(
                  'Transfers: $transferCount',
                  style: Theme.of(context).textTheme.titleLarge,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
