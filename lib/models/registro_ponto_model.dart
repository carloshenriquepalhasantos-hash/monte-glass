class RegistroPontoModel {
  final int? id;
  final int funcionarioId;
  final String data;
  final String? horaInicio;
  final String? horaFim;
  final String diaSemana;
  final double desconto;
  final String? observacao;
  final int pago; // 0 = Não pago (Vermelho), 1 = Pago (Verde)

  RegistroPontoModel({
    this.id,
    required this.funcionarioId,
    required this.data,
    this.horaInicio,
    this.horaFim,
    required this.diaSemana,
    this.desconto = 0.0,
    this.observacao,
    this.pago = 0,
  });

  factory RegistroPontoModel.fromMap(Map<String, dynamic> map) {
    return RegistroPontoModel(
      id: map['id'],
      funcionarioId: map['funcionario_id'],
      data: map['data'],
      horaInicio: map['hora_inicio'],
      horaFim: map['hora_fim'],
      diaSemana: map['dia_semana'],
      desconto: (map['desconto'] as num).toDouble(),
      observacao: map['observacao'],
      pago: map['pago'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'funcionario_id': funcionarioId,
      'data': data,
      'hora_inicio': horaInicio,
      'hora_fim': horaFim,
      'dia_semana': diaSemana,
      'desconto': desconto,
      'observacao': observacao,
      'pago': pago,
    };
  }
}
