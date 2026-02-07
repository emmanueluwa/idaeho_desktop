import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:idaeho_desktop/services/adb_service.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final ADBService _adb = ADBService();

  bool isADBInstalled = false;

  List<String> connectedDevices = [];
  String? selectedDevice;

  List<File> filesToSync = [];
  bool isSyncing = false;
  double syncProgress = 0.0;

  Map<String, int> storageInfo = {};

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  Future<void> _initialize() async {
    //check adb
    final adbInstalled = await _adb.isADBInstalled();

    setState(() {
      isADBInstalled = adbInstalled;
    });

    if (adbInstalled) {
      await _refreshDevices();
    }
  }

  Future<void> _refreshDevices() async {
    final devices = await _adb.getConnectedDevices();

    setState(() {
      connectedDevices = devices;

      if (devices.isNotEmpty && selectedDevice == null) {
        selectedDevice = devices.first;

        _loadStorageInfo();
      }
    });
  }

  Future<void> _loadStorageInfo() async {
    if (selectedDevice == null) return;

    final info = await _adb.getStorageInfo(selectedDevice!);

    setState(() {
      storageInfo = info;
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        filesToSync.addAll(
          result.paths.where((path) => path != null).map((path) => File(path!)),
        );
      });
    }
  }

  Future<void> _syncFiles() async {
    if (selectedDevice == null || filesToSync.isEmpty) return;

    setState(() {
      isSyncing = true;
      syncProgress = 0.0;
    });

    await _adb.createAppDirectory(selectedDevice!);

    for (var i = 0; i < filesToSync.length; i++) {
      final file = filesToSync[i];
      final filename = file.path.split(Platform.pathSeparator).last;

      await _adb.pushFile(
        selectedDevice!,
        file.path,
        "/sdcard/Idaeho/$filename",
      );

      setState(() {
        syncProgress = (1 + 1) / filesToSync.length;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Synced ${filesToSync.length} files")),
      );

      await _loadStorageInfo();
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // header
          Container(
            padding: EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.music_note, size: 13),
                SizedBox(width: 12),
                Text(
                  "Idaeho Library",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                if (connectedDevices.isEmpty)
                  Row(
                    children: [
                      Icon(Icons.phone_android, color: Colors.green),
                      SizedBox(width: 8),
                      Text("Connected", style: TextStyle(color: Colors.green)),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.phone_android, color: Colors.red),
                      SizedBox(width: 8),
                      Text("No device", style: TextStyle(color: Colors.red)),
                      SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: _refreshDevices,
                        icon: Icon(Icons.refresh),
                        label: Text("Refresh"),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
