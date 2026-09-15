import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/pos_provider.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WorkshopPosApp());
}

class WorkshopPosApp extends StatelessWidget {
  const WorkshopPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PosProvider()),
      ],
      child: MaterialApp(
        title: 'Workshop POS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          scaffoldBackgroundColor: const Color(0xFFF7F9FC),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
