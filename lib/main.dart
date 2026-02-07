import 'package:flutter/material.dart';

void main() {
  runApp(const IdaehoDesktopApp());
}

class IdaehoDesktopApp extends StatelessWidget {
  const IdaehoDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Idaeho Desktop Sync",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const SyncScreen(),
    );
  }
}
