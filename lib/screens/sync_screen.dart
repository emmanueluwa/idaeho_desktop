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
        syncProgress = (i + 1) / filesToSync.length;
      });
    }

    setState(() {
      isSyncing = false;
      filesToSync.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Synced ${filesToSync.length} files")),
    );

    await _loadStorageInfo();
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
                Icon(Icons.music_note, size: 32),
                SizedBox(width: 12),
                Text(
                  "Idaeho Library",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                if (connectedDevices.isNotEmpty)
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

          Expanded(
            child: !isADBInstalled
                ? _buildADBNotInstalled()
                : connectedDevices.isEmpty
                ? _buildNoDevice()
                : _buildSyncInterface(),
          ),
        ],
      ),
    );
  }

  Widget _buildADBNotInstalled() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.orange),
          SizedBox(height: 16),
          Text(
            "ADB Not Installed",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text("Please install Android Debug Bridge (ADB)"),
        ],
      ),
    );
  }

  Widget _buildNoDevice() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_android_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "No Device Connected",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text("1. Connect your phone via USB"),
          Text("2. Enable USB debugging"),
          Text("3. Click Refresh"),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshDevices,
            icon: Icon(Icons.refresh),
            label: Text("Refresh"),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncInterface() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Files to Sync",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),

                //drop zone
                Expanded(
                  child: GestureDetector(
                    onTap: _pickFiles,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.blue,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.blue[50],
                      ),
                      child: filesToSync.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_upload,
                                    size: 48,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(height: 8),
                                  Text("Drag & drop MP3 files here"),
                                  SizedBox(height: 4),
                                  Text(
                                    "or click to browse",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filesToSync.length,
                              itemBuilder: (context, index) {
                                final file = filesToSync[index];
                                final filename = file.path
                                    .split(Platform.pathSeparator)
                                    .last;

                                return ListTile(
                                  leading: Icon(Icons.audio_file),
                                  title: Text(filename),
                                  trailing: IconButton(
                                    icon: Icon(Icons.close),
                                    onPressed: () {
                                      setState(() {
                                        filesToSync.removeAt(index);
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                //sync button
                if (isSyncing)
                  Column(
                    children: [
                      LinearProgressIndicator(value: syncProgress),
                      SizedBox(height: 8),
                      Text("Syncing ${(syncProgress * 100).toInt()}%"),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: filesToSync.isEmpty ? null : _syncFiles,
                      icon: Icon(Icons.sync),
                      label: Text("Sync ${filesToSync.length} files(s)"),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        //right panel for device info
        Container(
          width: 300,
          margin: EdgeInsets.only(top: 16, right: 16, bottom: 16),
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Device Info",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),

              if (storageInfo.isNotEmpty) ...[
                Text("Storage"),
                SizedBox(height: 8),
                LinearProgressIndicator(
                  value: storageInfo["used"]! / storageInfo["total"]!,
                ),
                SizedBox(height: 8),
                Text(
                  "${_formatBytes(storageInfo["used"]!)} / ${_formatBytes(storageInfo["total"]!)}",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
