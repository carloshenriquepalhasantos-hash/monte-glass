import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/funcionario_model.dart';
import '../models/registro_ponto_model.dart';
import '../repositories/funcionario_repository.dart';
import '../repositories/ponto_repository.dart';

class FichaEmpregadoScreen extends StatefulWidget {
  const FichaEmpregadoScreen({super.key});

  @override
  State<FichaEmpregadoScreen> createState() => _FichaEmpregadoScreenState();
}

class _FichaEmpregadoScreenState extends State<FichaEmpregadoScreen> {
  final FuncionarioRepository _funcionarioRepo = FuncionarioRepository();
  final PontoRepository _pontoRepo = PontoRepository();

  List<FuncionarioModel> _funcionarios = [];
  FuncionarioModel? _funcionarioSelecionado;
  List<RegistroPontoModel> _historico = [];

  int _diasTrabalhados = 0;
  double _totalDescontos = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    final lista = await _funcionarioRepo.listarFuncionariosAtivos();

    if (mounted) {
      if (lista.isNotEmpty) {
        _funcionarios = lista;
        _funcionarioSelecionado = lista.first;
        await _atualizarResumoEHistorico(_funcionarioSelecionado!.id!);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _atualizarResumoEHistorico(int funcionarioId) async {
    final dias = await _pontoRepo.contarDiariasTrabalhadas(funcionarioId);
    final descontos = await _pontoRepo.calcularTotalDescontos(funcionarioId);
    final listaHistorico = await _pontoRepo.listarRegistrosPorFuncionario(
      funcionarioId,
    );

    if (mounted) {
      setState(() {
        _diasTrabalhados = dias;
        _totalDescontos = descontos;
        _historico = listaHistorico;
        _isLoading = false;
      });
    }
  }

  Future<void> _pagarTodosDias() async {
    if (_funcionarioSelecionado == null) return;

    for (var item in _historico) {
      if (item.pago == 0 && item.id != null) {
        final regPago = RegistroPontoModel(
          id: item.id,
          funcionarioId: item.funcionarioId,
          data: item.data,
          horaInicio: item.horaInicio,
          horaFim: item.horaFim,
          diaSemana: item.diaSemana,
          desconto: item.desconto,
          observacao: item.observacao,
          pago: 1,
        );
        await _pontoRepo.atualizarRegistroPonto(regPago);
      }
    }

    await _atualizarResumoEHistorico(_funcionarioSelecionado!.id!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Todos os registros pendentes foram marcados como pagos!',
          ),
        ),
      );
    }
  }

  Future<void> _alternarStatusPagamento(RegistroPontoModel item) async {
    if (item.id == null) return;

    int novoStatusPago = item.pago == 1 ? 0 : 1;

    final regAtualizado = RegistroPontoModel(
      id: item.id,
      funcionarioId: item.funcionarioId,
      data: item.data,
      horaInicio: item.horaInicio,
      horaFim: item.horaFim,
      diaSemana: item.diaSemana,
      desconto: item.desconto,
      observacao: item.observacao,
      pago: novoStatusPago,
    );

    await _pontoRepo.atualizarRegistroPonto(regAtualizado);
    await _atualizarResumoEHistorico(_funcionarioSelecionado!.id!);
  }

  Future<void> _excluirRegistro(RegistroPontoModel item) async {
    if (item.id == null) return;

    await _pontoRepo.excluirRegistroPonto(item.id!);
    await _atualizarResumoEHistorico(_funcionarioSelecionado!.id!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registro excluído da memória e do histórico com sucesso!',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _abrirModalAdicionarDesconto() {
    if (_funcionarioSelecionado == null) return;

    final descontoController = TextEditingController();
    final obsController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Desconto / Vale: ${_funcionarioSelecionado!.nome}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descontoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor do Desconto (R\$)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money_off),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: obsController,
                decoration: const InputDecoration(
                  labelText: 'Motivo / Observação',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (descontoController.text.isNotEmpty) {
                  final valorDesconto =
                      double.tryParse(
                        descontoController.text.replaceAll(',', '.'),
                      ) ??
                      0.0;
                  final dataHoje = DateFormat('yyyy-MM-dd')
                      .format(DateTime.now());
                  final diaSemana = DateFormat(
                    'EEEE',
                    'pt_BR',
                  ).format(DateTime.now());

                  await _pontoRepo.inserirRegistroPonto(
                    RegistroPontoModel(
                      funcionarioId: _funcionarioSelecionado!.id!,
                      data: dataHoje,
                      diaSemana: diaSemana,
                      desconto: valorDesconto,
                      pago: 1,
                      observacao: obsController.text.isNotEmpty
                          ? obsController.text
                          : 'Vale / Desconto',
                    ),
                  );

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    await _atualizarResumoEHistorico(
                      _funcionarioSelecionado!.id!,
                    );
                  }
                }
              },
              child: const Text('Aplicar Desconto'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double valorBruto = _funcionarioSelecionado != null
        ? (_diasTrabalhados * _funcionarioSelecionado!.valorBase)
        : 0.0;
    double valorLiquido = valorBruto - _totalDescontos;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ficha & Calendário de Ponto',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _funcionarios.isEmpty
          ? const Center(child: Text('Cadastre funcionários na Home primeiro.'))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<FuncionarioModel>(
                      initialValue: _funcionarioSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Selecione o Funcionário / Aluno',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                        isDense: true,
                      ),
                      items: _funcionarios.map((f) {
                        return DropdownMenuItem(value: f, child: Text(f.nome));
                      }).toList(),
                      onChanged: (novoFunc) async {
                        if (novoFunc != null) {
                          setState(() => _funcionarioSelecionado = novoFunc);
                          await _atualizarResumoEHistorico(novoFunc.id!);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Dias Trabalhados: $_diasTrabalhados',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Bruto: R\$ ${valorBruto.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Descontos / Vales:',
                                  style: TextStyle(fontSize: 13),
                                ),
                                Text(
                                  '- R\$ ${_totalDescontos.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Líquido:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'R\$ ${valorLiquido.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[800],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 36,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                ),
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Pagar Todos os Dias Pendentes',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: _pagarTodosDias,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Calendário / Histórico ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _abrirModalAdicionarDesconto,
                          icon: const Icon(
                            Icons.money_off,
                            size: 14,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Lançar Vale',
                            style: TextStyle(color: Colors.red, fontSize: 11),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    _historico.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(30.0),
                            child: Center(
                              child: Text(
                                'Nenhum registro de ponto encontrado.',
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true, // <-- Essencial para calcular a altura correta dentro do scroll
                            physics: const NeverScrollableScrollPhysics(), // <-- Deixa o Scroll principal controlar a tela
                            itemCount: _historico.length,
                            itemBuilder: (context, index) {
                              final item = _historico[index];
                              final isPontoTrabalho = item.horaInicio != null;
                              final isPago = item.pago == 1;

                              Color corIndicador = Colors.orange;
                              if (isPontoTrabalho) {
                                corIndicador = isPago
                                    ? Colors.green
                                    : Colors.red;
                              }

                              return Dismissible(
                                key: Key(item.id.toString()),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20.0),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      Text(
                                        'Excluir',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                confirmDismiss: (direction) async {
                                  return await showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text("Confirmar Exclusão"),
                                        content: const Text(
                                          "Deseja realmente apagar este registro do histórico e da memória do celular?",
                                        ),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context)
                                                    .pop(false),
                                            child: const Text("Cancelar"),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text("Excluir"),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                onDismissed: (direction) {
                                  _excluirRegistro(item);
                                },
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  elevation: 1,
                                  child: ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      backgroundColor: corIndicador.withAlpha(
                                        50,
                                      ),
                                      radius: 16,
                                      child: Icon(
                                        isPontoTrabalho
                                            ? Icons.calendar_today
                                            : Icons.money_off,
                                        color: corIndicador,
                                        size: 16,
                                      ),
                                    ),
                                    title: Text(
                                      '${item.data} (${item.diaSemana})',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        decoration: isPago
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                        color: isPago
                                            ? Colors.grey[700]
                                            : Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      isPontoTrabalho
                                          ? 'Início: ${item.horaInicio} | Fim: ${item.horaFim ?? 'Em curso'} • ${isPago ? 'PAGO' : 'PENDENTE'}'
                                          : 'Desconto / Vale: R\$ ${item.desconto.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isPontoTrabalho && !isPago
                                            ? Colors.red[700]
                                            : Colors.black87,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        isPago
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: corIndicador,
                                        size: 24,
                                      ),
                                      onPressed: () =>
                                          _alternarStatusPagamento(item),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                    const SizedBox(
                      height: 20,
                    ), // Folga extra de segurança na base
                  ],
                ),
              ),
            ),
    );
  }
}
