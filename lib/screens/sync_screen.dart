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
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
