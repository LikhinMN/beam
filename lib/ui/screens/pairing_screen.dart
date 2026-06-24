import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pico/pico.dart';
import 'package:beam/ui/state/app_state.dart';
import 'package:beam/ui/state/store.dart';
import 'package:beam/ui/theme.dart';
import 'package:beam/core/pairing.dart';
import 'package:beam/ui/state/actions.dart' as actions;

/// An overlay widget that displays the pairing UI.
/// Should be placed at the root of the app stack.
class PairingOverlayWidget extends StatelessWidget {
  const PairingOverlayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return PicoBuilder<AppState, ({AsyncValue<void> pairingState, String? incomingPIN})>(
      store: store,
      selector: (state) => (
        pairingState: state.pairingState,
        incomingPIN: state.incomingPIN,
      ),
      builder: (context, data) {
        // Only show if pairing is active (loading or error)
        if (data.pairingState is AsyncData) {
          return const SizedBox.shrink();
        }

        return Container(
          color: Colors.black87,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: BeamColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: data.pairingState.when(
                  data: (_) => const SizedBox.shrink(),
                  loading: () => data.incomingPIN != null
                      ? _ReceiverView(pin: data.incomingPIN!)
                      : const _SenderView(),
                  error: (err, _) => _ErrorView(error: err.toString()),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReceiverView extends StatefulWidget {
  final String pin;
  const _ReceiverView({required this.pin});

  @override
  State<_ReceiverView> createState() => _ReceiverViewState();
}

class _ReceiverViewState extends State<_ReceiverView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Pairing Request', style: BeamTextStyles.headline),
        const SizedBox(height: 16),
        Text(
          'Share this PIN with the sender',
          style: BeamTextStyles.body.copyWith(color: BeamColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CircularProgressIndicator(
                    value: 1.0 - _controller.value,
                    strokeWidth: 4,
                    color: BeamColors.accent,
                    backgroundColor: BeamColors.background,
                  );
                },
              ),
            ),
            Text(
              widget.pin,
              style: BeamTextStyles.mono,
            ),
          ],
        ),
        const SizedBox(height: 32),
        TextButton(
          onPressed: () {
            // Can't easily cancel from receiver without core changes, just dismiss UI
            actions.setPairingState(const AsyncData(null));
            actions.setIncomingPIN(null);
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _SenderView extends StatefulWidget {
  const _SenderView();

  @override
  State<_SenderView> createState() => _SenderViewState();
}

class _SenderViewState extends State<_SenderView> {
  final _pinController = TextEditingController();

  void _submit() {
    final pin = _pinController.text.trim();
    if (pin.length == 6) {
      BeamPairing().submitPin(pin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Enter PIN', style: BeamTextStyles.headline),
        const SizedBox(height: 16),
        Text(
          'Enter the PIN shown on the other device',
          style: BeamTextStyles.body.copyWith(color: BeamColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          textAlign: TextAlign.center,
          style: BeamTextStyles.mono.copyWith(fontSize: 24),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: BeamTextStyles.mono.copyWith(fontSize: 24, color: BeamColors.textSecondary.withOpacity(0.5)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: BeamColors.textSecondary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: BeamColors.accent, width: 2),
            ),
          ),
          onChanged: (val) {
            if (val.length == 6) _submit();
          },
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () {
                actions.setPairingState(const AsyncData(null));
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Submit'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: BeamColors.error, size: 64),
        const SizedBox(height: 16),
        Text('Pairing Failed', style: BeamTextStyles.headline),
        const SizedBox(height: 16),
        Text(
          error,
          style: BeamTextStyles.body.copyWith(color: BeamColors.error),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            actions.setPairingState(const AsyncData(null));
            actions.setIncomingPIN(null);
          },
          child: const Text('Dismiss'),
        ),
      ],
    );
  }
}
