import 'package:process_run/shell.dart';

class ADBService {
  final shell = Shell();

  Future<bool> isADBInstalled() async {
    try {
      final result = await shell.run("adb version");

      return result.first.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> getConnectedDevices() async {
    try {
      final result = await shell.run("adb devices");

      final output = result.first.stdout.toString();

      final lines = output.split("\n");
      final devices = <String>[];

      for (var line in lines) {
        if (line.contains("\tdevice")) {
          final deviceId = line.split("\t")[0];
          devices.add(deviceId);
        }
      }

      print("found ${devices.length} devices");
      return devices;
    } catch (e) {
      print("Error getting devices");
      return [];
    }
  }

  //creating app dir on phone
  Future<bool> createAppDirectory(String deviceId) async {
    try {
      await shell.run('adb -s $deviceId shell mkdir -p /sdcard/Idaeho');

      print("created /sdcard/Idaeho dir");
      return true;
    } catch (e) {
      print("error creating directory: $e");

      return false;
    }
  }

  //push file to phone
  Future<bool> pushFile(
    String deviceId,
    String localPath,
    String remotePath,
  ) async {
    try {
      print("pushing: $localPath -> $remotePath");

      final result = await shell.run(
        'adb -s $deviceId push "$localPath" "$remotePath"',
      );

      if (result.first.exitCode == 0) {
        print("file transferred");

        return true;
      }

      return false;
    } catch (e) {
      print("error pushing file: $e");
      return false;
    }
  }

  //files in app directory
  Future<List<String>> listFile(String deviceId) async {
    try {
      final result = await shell.run(
        'adb -s $deviceId shell ls /sdcard/Idaeho/',
      );

      final output = result.first.stdout.toString();

      final files = output
          .split("\n")
          .where((f) => f.isNotEmpty && f.endsWith(".mp3"))
          .toList();

      print("found ${files.length} files on device");

      return files;
    } catch (e) {
      print("error listing files: $e");

      return [];
    }
  }

  Future<bool> deleteFile(String deviceId, String filename) async {
    try {
      await shell.run('adb -s $deviceId shell rm /sdcard/Idaeho/$filename');

      print("deleted $filename");
      return true;
    } catch (e) {
      print("error deleting file: $e");
      return false;
    }
  }

  //get available storage space
  Future<Map<String, int>> getStorageInfo(String deviceId) async {
    try {
      final result = await shell.run('adb -s $deviceId shell df /sdcard');

      final output = result.first.stdout.toString();
      final lines = output.split("\n");

      for (var line in lines) {
        if (line.contains('/sdcard') || line.contains('emulated')) {
          final parts = line.split(RegExp(r'\s+'));

          //trying to extract total and available space
          if (parts.length >= 4) {
            final total = int.tryParse(parts[1]) ?? 0;
            final available = int.tryParse(parts[3]) ?? 0;

            return {
              "total": total * 1024,
              "available": available * 1024,
              "used": (total - available) * 1024,
            };
          }
        }
      }

      return {"total": 0, "available": 0, "used": 0};
    } catch (e) {
      print("error getting storage info: $e");

      return {"total": 0, "available": 0, "used": 0};
    }
  }
}
