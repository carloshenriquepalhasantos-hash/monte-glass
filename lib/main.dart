import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart'; // <--- Importante para inicializar o pt_BR

import 'database/database_helper.dart';
import 'views/main_navigation_screen.dart';

void main() async {
  // Garante a vinculação dos widgets
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa os dados de localidade (pt_BR) para o pacote intl
  await initializeDateFormatting('pt_BR', null);

  // Inicializa o banco de dados local SQLite
  await DatabaseHelper.instance.database;

  runApp(const MonteGlassApp());
}

class MonteGlassApp extends StatelessWidget {
  const MonteGlassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monte Glass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E293B),
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFF0EA5E9),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const MainNavigationScreen(),
    );
  }
}
