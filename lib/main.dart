import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart'; // Ab ye screen import ho rahi hai

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PopKhataApp());
}

class PopKhataApp extends StatelessWidget {
  const PopKhataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POP Khata',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const DashboardScreen(), // Yahan direct Dashboard open hoga
    );
  }
}
