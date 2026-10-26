import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/registro_ponto_model.dart';

class PontoRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> inserirRegistroPonto(RegistroPontoModel registro) async {
    final db = await _dbHelper.database;
    return await db.insert('registros_ponto', registro.toMap());
  }

  Future<List<RegistroPontoModel>> listarRegistrosPorFuncionario(
    int funcionarioId,
  ) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'registros_ponto',
      where: 'funcionario_id = ?',
      whereArgs: [funcionarioId],
      orderBy: 'data DESC, id DESC',
    );

    return List.generate(
      maps.length,
      (i) => RegistroPontoModel.fromMap(maps[i]),
    );
  }

  Future<int> atualizarRegistroPonto(RegistroPontoModel registro) async {
    final db = await _dbHelper.database;
    return await db.rawUpdate(
      '''
      UPDATE registros_ponto 
      SET funcionario_id = ?, data = ?, hora_inicio = ?, hora_fim = ?, dia_semana = ?, desconto = ?, observacao = ?, pago = ?
      WHERE id = ?
      ''',
      [
        registro.funcionarioId,
        registro.data,
        registro.horaInicio,
        registro.horaFim,
        registro.diaSemana,
        registro.desconto,
        registro.observacao,
        registro.pago,
        registro.id,
      ],
    );
  }

  Future<int> adicionarDesconto({
    required int funcionarioId,
    required String data,
    required double valorDesconto,
    required String diaSemana,
    String? observacao,
  }) async {
    final db = await _dbHelper.database;
    return await db.insert('registros_ponto', {
      'funcionario_id': funcionarioId,
      'data': data,
      'dia_semana': diaSemana,
      'desconto': valorDesconto,
      'pago': 1,
      'observacao': observacao ?? 'Vale / Desconto aplicado',
    });
  }

  Future<double> calcularTotalDescontos(int funcionarioId) async {
    final db = await _dbHelper.database;
    final resultado = await db.rawQuery(
      '''
      SELECT SUM(desconto) as total_desconto 
      FROM registros_ponto 
      WHERE funcionario_id = ?
    ''',
      [funcionarioId],
    );

    if (resultado.isNotEmpty && resultado.first['total_desconto'] != null) {
      return (resultado.first['total_desconto'] as num).toDouble();
    }
    return 0.0;
  }

  Future<int> contarDiariasTrabalhadas(int funcionarioId) async {
    final db = await _dbHelper.database;
    final resultado = await db.rawQuery(
      '''
      SELECT COUNT(*) as total_dias 
      FROM registros_ponto 
      WHERE funcionario_id = ? AND hora_inicio IS NOT NULL
    ''',
      [funcionarioId],
    );

    if (resultado.isNotEmpty && resultado.first['total_dias'] != null) {
      return Sqflite.firstIntValue(resultado) ?? 0;
    }
    return 0;
  }

  Future<int> excluirRegistroPonto(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('registros_ponto', where: 'id = ?', whereArgs: [id]);
  }
}
