import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beam/ui/theme.dart';
import 'package:beam/core/pairing.dart';
import 'package:beam/linux/folder_picker_helper.dart';

/// Settings screen allowing user configuration of Beam.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _portController = TextEditingController();
  String _downloadFolder = 'Loading...';
  List<Map<String, dynamic>> _trustedDevices = [];
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Load Name
    final name = _prefs.getString('device_name') ?? 'Beam Device';
    _nameController.text = name;

    // Load Port
    final port = _prefs.getInt('device_port') ?? 9001;
    _portController.text = port.toString();

    // Load Trusted Devices
    final listStr = _prefs.getString('beam_trusted_devices');
    if (listStr != null) {
      try {
        final list = jsonDecode(listStr) as List<dynamic>;
        _trustedDevices = list.map((e) => e as Map<String, dynamic>).toList();
      } catch (_) {}
    }

    setState(() {
      _downloadFolder = 'Default system downloads'; // Abstraction for now
    });
  }

  Future<void> _saveName(String value) async {
    if (value.trim().isNotEmpty) {
      await _prefs.setString('device_name', value.trim());
    }
  }

  Future<void> _savePort(String value) async {
    final port = int.tryParse(value);
    if (port != null && port >= 1024 && port <= 65535) {
      await _prefs.setInt('device_port', port);
    }
  }

  Future<void> _revokeTrust(String deviceName) async {
    await BeamPairing().revokeTrust(deviceName);
    await _loadSettings(); // Reload list
  }

  Future<void> _pickFolder() async {
    if (!Platform.isLinux) return;
    final dir = await FolderPickerHelper.pickDestinationFolder();
    if (dir != null) {
      // Logic to actually save custom download folder not strictly required in sprint, 
      // but we update UI to reflect selection.
      setState(() {
        _downloadFolder = dir.path;
      });
      await _prefs.setString('custom_download_folder', dir.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: BeamColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionTitle('Device Info'),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Device Name',
              hintText: 'My Beam Device',
            ),
            onChanged: _saveName,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _portController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'TCP Port (Requires Restart)',
              hintText: '9001',
            ),
            onChanged: _savePort,
          ),
          const SizedBox(height: 32),
          
          if (Platform.isLinux) ...[
            _buildSectionTitle('Storage'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Download Folder'),
              subtitle: Text(_downloadFolder),
              trailing: ElevatedButton(
                onPressed: _pickFolder,
                child: const Text('Change'),
              ),
            ),
            const SizedBox(height: 32),
          ],

          _buildSectionTitle('Trusted Devices'),
          if (_trustedDevices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No trusted devices.',
                style: BeamTextStyles.body.copyWith(color: BeamColors.textSecondary),
              ),
            )
          else
            ..._trustedDevices.map((device) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(device['deviceName'] ?? 'Unknown'),
                subtitle: Text(device['ip'] ?? 'Unknown IP'),
                trailing: TextButton(
                  onPressed: () => _revokeTrust(device['deviceName'] ?? ''),
                  child: const Text('Revoke', style: TextStyle(color: BeamColors.error)),
                ),
              );
            }),
          
          const SizedBox(height: 32),
          const Center(
            child: Text(
              'Beam Version 1.0.0',
              style: TextStyle(color: BeamColors.textSecondary),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: BeamTextStyles.headline.copyWith(fontSize: 18),
      ),
    );
  }
}
