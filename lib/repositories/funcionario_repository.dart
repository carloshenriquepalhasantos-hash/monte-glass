import '../database/database_helper.dart';
import '../models/funcionario_model.dart';

class FuncionarioRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> inserirFuncionario(FuncionarioModel funcionario) async {
    final db = await _dbHelper.database;
    return await db.insert('funcionarios', funcionario.toMap());
  }

  Future<int> atualizarFuncionario(FuncionarioModel funcionario) async {
    final db = await _dbHelper.database;
    return await db.update(
      'funcionarios',
      funcionario.toMap(),
      where: 'id = ?',
      whereArgs: [funcionario.id],
    );
  }

  Future<List<FuncionarioModel>> listarFuncionariosAtivos() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'funcionarios',
      where: 'ativo = ?',
      whereArgs: [1],
      orderBy: 'nome ASC',
    );

    return List.generate(maps.length, (i) => FuncionarioModel.fromMap(maps[i]));
  }
}
