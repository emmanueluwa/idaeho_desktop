import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
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

  bool _isDragging = false;

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

  void _onDragEntered() {
    setState(() => _isDragging = true);
  }

  void _onDragExited() {
    setState(() => _isDragging = false);
  }

  Future<void> _onDragDone(DropDoneDetails details) async {
    setState(() => _isDragging = false);

    for (var file in details.files) {
      final path = file.path;

      //only accept audio files
      if (path.toLowerCase().endsWith(".mp3") ||
          path.toLowerCase().endsWith(".m4a") ||
          path.toLowerCase().endsWith(".wav")) {
        setState(() {
          filesToSync.add(File(path));
        });
      }
    }
  }

  Future<void> _syncFiles() async {
    if (selectedDevice == null || filesToSync.isEmpty) return;

    setState(() {
      isSyncing = true;
      syncProgress = 0.0;
    });

    try {
      await _adb.createAppDirectory(selectedDevice!);

      for (var i = 0; i < filesToSync.length; i++) {
        final file = filesToSync[i];
        final filename = file.path.split(Platform.pathSeparator).last;

        final success = await _adb.pushFile(
          selectedDevice!,
          file.path,
          "/sdcard/Idaeho/$filename",
        );

        if (!success) {
          throw Exception("failed to transer $filename");
        }

        setState(() {
          syncProgress = (i + 1) / filesToSync.length;
        });
      }

      final count = filesToSync.length;

      setState(() {
        isSyncing = false;
        filesToSync.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Synced $count file${count > 1 ? "s" : ""}"),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadStorageInfo();
    } catch (e) {
      setState(() {
        isSyncing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("sync failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      filesToSync.removeAt(index);
    });
  }

  void _clearAll() {
    setState(() {
      filesToSync.clear();
    });
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
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.music_note, size: 32, color: Colors.blue),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Idaeho Library",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Tranfer MP3 files to your device",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Spacer(),
                if (connectedDevices.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone_android, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          "Device Connected",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.phone_android, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              "No device",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
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
      child: Container(
        padding: EdgeInsets.all(48),
        constraints: BoxConstraints(maxWidth: 500),
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
            Text(
              "Android Debug Bridge (ADB) is required to connect to your phone",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            SizedBox(height: 32),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Installation",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  SelectableText(
                    "sudo apt install android-tools-adb",
                    style: TextStyle(fontFamily: "monospace"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDevice() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(48),
        constraints: BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_android_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 24),
            Text(
              "No Device Connected",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              "Connect your device to get started",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            SizedBox(height: 32),
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStep("1", "Connect your device via USB"),
                  SizedBox(height: 12),
                  _buildStep("2", "Enable USB debugging"),
                  SizedBox(height: 12),
                  _buildStep("3", 'Tap "Allow" when prompted on phone'),
                  SizedBox(height: 12),
                  _buildStep('4', 'Click Refresh button above'),
                ],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshDevices,
              icon: Icon(Icons.refresh),
              label: Text("Refresh Devices"),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
      ],
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "Files to Sync",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    if (filesToSync.isNotEmpty)
                      TextButton.icon(
                        onPressed: _clearAll,
                        icon: Icon(Icons.clear_all, size: 18),
                        label: Text("Clear All"),
                      ),
                  ],
                ),
                SizedBox(height: 16),

                //drop zone
                Expanded(
                  child: DropTarget(
                    onDragEntered: (details) => _onDragEntered(),
                    onDragExited: (details) => _onDragExited(),
                    onDragDone: _onDragDone,
                    child: GestureDetector(
                      onTap: _pickFiles,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _isDragging
                                ? Colors.blue
                                : Colors.grey[300]!,
                            width: _isDragging ? 3 : 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: _isDragging
                              ? Colors.blue[50]
                              : Colors.grey[50],
                        ),
                        child: filesToSync.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 64,
                                      color: _isDragging
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      _isDragging
                                          ? "Drop files here"
                                          : "Drag & drop MP3 files here",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: _isDragging
                                            ? Colors.blue
                                            : Colors.grey[700],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "or click to browse",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: filesToSync.length,
                                separatorBuilder: (context, index) =>
                                    Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final file = filesToSync[index];
                                  final filename = file.path
                                      .split(Platform.pathSeparator)
                                      .last;
                                  final fileSize = file.lengthSync();

                                  return ListTile(
                                    leading: Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.audio_file,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    title: Text(
                                      filename,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(_formatBytes(fileSize)),
                                    trailing: IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _removeFile(index),
                                      tooltip: "Remove",
                                    ),
                                  );
                                },
                              ),
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
                      Text(
                        "Syncing ${(syncProgress * 100).toInt()}%",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: filesToSync.isEmpty ? null : _syncFiles,
                      icon: Icon(Icons.sync),
                      label: Text(
                        "Sync ${filesToSync.length} file${filesToSync.length != 1 ? "s" : ""}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.phone_android, size: 24, color: Colors.blue),
                  SizedBox(height: 12),
                  Text(
                    "Device Info",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 24),

              if (selectedDevice != null) ...[
                _buildInfoRow("Device ID", selectedDevice!),
                SizedBox(height: 16),
              ],

              if (storageInfo.isNotEmpty) ...[
                Text(
                  "Storage",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: storageInfo["used"]! / storageInfo["total"]!,
                    minHeight: 12,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(Colors.blue),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Used: ${_formatBytes(storageInfo["used"]!)}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      "Total: ${_formatBytes(storageInfo["total"]!)}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  "Available: ${_formatBytes(storageInfo["available"]!)}",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ],

              Spacer(),

              Divider(),
              SizedBox(height: 8),

              Text(
                "Sync Location",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "/sdcard/Idaeho/",
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: "monospace",
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
