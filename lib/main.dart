import 'package:flutter/material.dart';
// import 'screens/dashboard_screen.dart'; // Isko baad me uncomment karenge

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
      home: const Scaffold(
        body: Center(
          child: Text('Dashboard Coming Soon...'),
        ),
      ),
      // home: const DashboardScreen(), // Dashboard banne ke baad ye use hoga
    );
  }
}
