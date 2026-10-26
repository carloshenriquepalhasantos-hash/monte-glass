import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('monte_glass.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // <--- Incrementado para 3 para forçar a criação correta da coluna pago
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE funcionarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        tipo_pagamento TEXT NOT NULL,
        valor_base REAL NOT NULL,
        ativo INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE registros_ponto (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        funcionario_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        hora_inicio TEXT,
        hora_fim TEXT,
        dia_semana TEXT NOT NULL,
        desconto REAL DEFAULT 0.0,
        observacao TEXT,
        pago INTEGER DEFAULT 0,
        FOREIGN KEY (funcionario_id) REFERENCES funcionarios (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      try {
        await db.execute(
          "ALTER TABLE registros_ponto ADD COLUMN pago INTEGER DEFAULT 0;",
        );
      } catch (_) {}
    }
  }
}
