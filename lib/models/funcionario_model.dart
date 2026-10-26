class FuncionarioModel {
  final int? id;
  final String nome;
  final String tipoPagamento; // 'Diária' ou 'Hora'
  final double valorBase;
  final int ativo; // 1 para ativo, 0 para inativo

  FuncionarioModel({
    this.id,
    required this.nome,
    required this.tipoPagamento,
    required this.valorBase,
    this.ativo = 1,
  });

  // Converte um Map do SQLite para o Objeto FuncionarioModel
  factory FuncionarioModel.fromMap(Map<String, dynamic> map) {
    return FuncionarioModel(
      id: map['id'],
      nome: map['nome'],
      tipoPagamento: map['tipo_pagamento'],
      valorBase: (map['valor_base'] as num).toDouble(),
      ativo: map['ativo'] ?? 1,
    );
  }

  // Converte o Objeto FuncionarioModel para um Map compatível com o SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'tipo_pagamento': tipoPagamento,
      'valor_base': valorBase,
      'ativo': ativo,
    };
  }
}
