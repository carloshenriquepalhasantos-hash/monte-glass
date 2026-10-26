import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/funcionario_model.dart';
import '../models/registro_ponto_model.dart';
import '../repositories/funcionario_repository.dart';
import '../repositories/ponto_repository.dart';

// Gerenciador global robusto de contagem de tempo
class PontoAtivoGlobal {
  static final Map<int, int> segundosAtivos = {};
  static final Map<int, bool> emAndamento = {};
  static Timer? _timerGlobal;

  static void iniciarTrabalho(int funcId) {
    emAndamento[funcId] = true;
    segundosAtivos[funcId] ??= 0;

    _timerGlobal ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      bool temAlguemTrabalhando = false;
      emAndamento.forEach((id, ativo) {
        if (ativo == true) {
          segundosAtivos[id] = (segundosAtivos[id] ?? 0) + 1;
          temAlguemTrabalhando = true;
        }
      });

      // Se ninguém mais estiver trabalhando, cancela o timer global para poupar bateria
      if (!temAlguemTrabalhando) {
        _timerGlobal?.cancel();
        _timerGlobal = null;
      }
    });
  }

  static void pararTrabalho(int funcId) {
    emAndamento[funcId] = false;
    segundosAtivos[funcId] = 0;
  }
}

class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  final FuncionarioRepository _funcionarioRepo = FuncionarioRepository();
  final PontoRepository _pontoRepo = PontoRepository();

  List<FuncionarioModel> _funcionarios = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    _carregarFuncionarios();

    // Atualiza a tela a cada segundo para mover os segundos na lista principal
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && PontoAtivoGlobal.emAndamento.containsValue(true)) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'monte_glass_ponto_channel',
        channelName: 'Ponto Monte Glass',
        channelDescription: 'Notificação de expediente ativo em segundo plano.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> _carregarFuncionarios() async {
    setState(() => _isLoading = true);
    final lista = await _funcionarioRepo.listarFuncionariosAtivos();
    if (mounted) {
      setState(() {
        _funcionarios = lista;
        _isLoading = false;
      });
    }
  }

  void _abrirModalNovoFuncionario() {
    final nomeController = TextEditingController();
    final valorController = TextEditingController();
    String tipoPagamento = 'Diária';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cadastrar Novo Funcionário',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome Completo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: tipoPagamento,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Pagamento',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments),
                ),
                items: ['Diária', 'Hora'].map((tipo) {
                  return DropdownMenuItem(value: tipo, child: Text(tipo));
                }).toList(),
                onChanged: (val) {
                  if (val != null) tipoPagamento = val;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valorController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor Base (R\$)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(modalContext).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (nomeController.text.isNotEmpty &&
                        valorController.text.isNotEmpty) {
                      final valor =
                          double.tryParse(
                            valorController.text.replaceAll(',', '.'),
                          ) ??
                          0.0;
                      final novoFunc = FuncionarioModel(
                        nome: nomeController.text,
                        tipoPagamento: tipoPagamento,
                        valorBase: valor,
                      );

                      final navigator = Navigator.of(modalContext);
                      final messenger = ScaffoldMessenger.of(modalContext);

                      await _funcionarioRepo.inserirFuncionario(novoFunc);

                      if (modalContext.mounted) {
                        navigator.pop();
                        _carregarFuncionarios();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Funcionário cadastrado no SQLite!'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Salvar Funcionário'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrirModalRegistroPonto(FuncionarioModel func) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return PontoCronometroWidget(
          funcionario: func,
          pontoRepo: _pontoRepo,
          onPontoAtualizado: () => setState(() {}),
        );
      },
    );
  }

  String _formatarTempo(int totalSegundos) {
    final horas = (totalSegundos ~/ 3600).toString().padLeft(2, '0');
    final minutos = ((totalSegundos % 3600) ~/ 60).toString().padLeft(2, '0');
    final segundos = (totalSegundos % 60).toString().padLeft(2, '0');
    return '$horas:$minutos:$segundos';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Monte Glass - Ponto & Equipe',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: _abrirModalNovoFuncionario,
            tooltip: 'Registrar Funcionário',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _funcionarios.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nenhum funcionário cadastrado no banco local.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _abrirModalNovoFuncionario,
                    icon: const Icon(Icons.add),
                    label: const Text('Cadastrar Primeiro Funcionário'),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Equipe Cadastrada',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _funcionarios.length,
                      itemBuilder: (context, index) {
                        final func = _funcionarios[index];
                        final id = func.id ?? 0;
                        final estaTrabalhando =
                            PontoAtivoGlobal.emAndamento[id] == true;
                        final segundos =
                            PontoAtivoGlobal.segundosAtivos[id] ?? 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: estaTrabalhando
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.secondary,
                              foregroundColor: Colors.white,
                              child: Text(func.nome[0].toUpperCase()),
                            ),
                            title: Text(
                              func.nome,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              estaTrabalhando
                                  ? 'Trabalhando: ${_formatarTempo(segundos)}'
                                  : '${func.tipoPagamento} • R\$ ${func.valorBase.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: estaTrabalhando
                                    ? Colors.green[700]
                                    : Colors.grey[700],
                                fontWeight: estaTrabalhando
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: ElevatedButton.icon(
                              icon: Icon(
                                estaTrabalhando
                                    ? Icons.timer
                                    : Icons.timer_outlined,
                                size: 18,
                              ),
                              label: Text(
                                estaTrabalhando ? 'Contando' : 'Ponto',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: estaTrabalhando
                                    ? Colors.green[700]
                                    : Theme.of(context).colorScheme.secondary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _abrirModalRegistroPonto(func),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class PontoCronometroWidget extends StatefulWidget {
  final FuncionarioModel funcionario;
  final PontoRepository pontoRepo;
  final VoidCallback onPontoAtualizado;

  const PontoCronometroWidget({
    super.key,
    required this.funcionario,
    required this.pontoRepo,
    required this.onPontoAtualizado,
  });

  @override
  State<PontoCronometroWidget> createState() => _PontoCronometroWidgetState();
}

class _PontoCronometroWidgetState extends State<PontoCronometroWidget> {
  String diaSemana = 'Segunda-feira';
  final List<String> diasSemana = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  final TextEditingController observacaoController = TextEditingController();
  DateTime? _horarioInicio;
  int _segundosIntervalo = 0;
  bool _emIntervalo = false;
  Timer? _timerIntervalo;
  Timer? _modalRefreshTimer;

  @override
  void initState() {
    super.initState();
    try {
      final hoje = DateFormat('EEEE', 'pt_BR').format(DateTime.now());
      final formatado = hoje[0].toUpperCase() + hoje.substring(1);
      if (diasSemana.any(
        (d) => d.toLowerCase().contains(formatado.toLowerCase()),
      )) {
        diaSemana = diasSemana.firstWhere(
          (d) => d.toLowerCase().contains(formatado.toLowerCase()),
        );
      }
    } catch (_) {
      diaSemana = 'Segunda-feira';
    }

    // Atualiza o modal a cada segundo para refletir os segundos globais
    _modalRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timerIntervalo?.cancel();
    _modalRefreshTimer?.cancel();
    observacaoController.dispose();
    super.dispose();
  }

  Future<void> _iniciarJornada() async {
    try {
      await FlutterForegroundTask.requestNotificationPermission();
    } catch (_) {}

    final funcId = widget.funcionario.id ?? 0;
    PontoAtivoGlobal.iniciarTrabalho(funcId);

    setState(() {
      _horarioInicio = DateTime.now();
      _emIntervalo = false;
    });

    widget.onPontoAtualizado();

    try {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Monte Glass - Ponto Ativo',
        notificationText:
            'Expediente em andamento para ${widget.funcionario.nome}',
      );
    } catch (_) {}
  }

  void _alternarIntervalo() {
    final funcId = widget.funcionario.id ?? 0;
    final estaTrabalhando = PontoAtivoGlobal.emAndamento[funcId] == true;

    if (!estaTrabalhando && !_emIntervalo) return;

    if (!_emIntervalo) {
      PontoAtivoGlobal.emAndamento[funcId] = false;
      setState(() => _emIntervalo = true);
      widget.onPontoAtualizado();

      try {
        FlutterForegroundTask.updateService(
          notificationTitle: 'Em Intervalo (Almoço/Descanso)',
          notificationText: 'Funcionário: ${widget.funcionario.nome}',
        );
      } catch (_) {}

      _timerIntervalo = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_emIntervalo && mounted) {
          setState(() => _segundosIntervalo++);
        }
      });
    } else {
      _timerIntervalo?.cancel();
      PontoAtivoGlobal.emAndamento[funcId] = true;
      setState(() => _emIntervalo = false);
      widget.onPontoAtualizado();

      try {
        FlutterForegroundTask.updateService(
          notificationTitle: 'Trabalhando: ${widget.funcionario.nome}',
          notificationText:
              'Tempo: ${_formatarTempo(PontoAtivoGlobal.segundosAtivos[funcId] ?? 0)}',
        );
      } catch (_) {}
    }
  }

  Future<void> _encerrarExpediente() async {
    _timerIntervalo?.cancel();

    final funcId = widget.funcionario.id ?? 0;
    PontoAtivoGlobal.pararTrabalho(funcId);
    widget.onPontoAtualizado();

    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}

    final horaFim = DateTime.now();
    setState(() => _emIntervalo = false);

    final dataHoje = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final formatHora = DateFormat('HH:mm');

    final strInicio = _horarioInicio != null
        ? formatHora.format(_horarioInicio!)
        : '00:00';
    final strFim = formatHora.format(horaFim);

    final novoPonto = RegistroPontoModel(
      funcionarioId: funcId,
      data: dataHoje,
      horaInicio: strInicio,
      horaFim: strFim,
      diaSemana: diaSemana,
      desconto: 0.0,
      observacao: observacaoController.text.isNotEmpty
          ? '${observacaoController.text} (Intervalo: ${(_segundosIntervalo ~/ 60)} min)'
          : 'Intervalo: ${(_segundosIntervalo ~/ 60)} min',
    );

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await widget.pontoRepo.inserirRegistroPonto(novoPonto);

    if (mounted) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Expediente de ${widget.funcionario.nome} encerrado e salvo!',
          ),
        ),
      );
    }
  }

  String _formatarTempo(int totalSegundos) {
    final horas = (totalSegundos ~/ 3600).toString().padLeft(2, '0');
    final minutos = ((totalSegundos % 3600) ~/ 60).toString().padLeft(2, '0');
    final segundos = (totalSegundos % 60).toString().padLeft(2, '0');
    return '$horas:$minutos:$segundos';
  }

  @override
  Widget build(BuildContext context) {
    final formatHora = DateFormat('HH:mm:ss');
    final funcId = widget.funcionario.id ?? 0;
    final estaTrabalhando = PontoAtivoGlobal.emAndamento[funcId] == true;
    final segundosTrabalho = PontoAtivoGlobal.segundosAtivos[funcId] ?? 0;

    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ponto: ${widget.funcionario.nome}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_emIntervalo)
                const Chip(
                  label: Text(
                    'INTERVALO',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  backgroundColor: Colors.blue,
                )
              else if (estaTrabalhando)
                const Chip(
                  label: Text(
                    'TRABALHANDO',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  backgroundColor: Colors.green,
                ),
            ],
          ),
          const Divider(height: 20),
          DropdownButtonFormField<String>(
            initialValue: diaSemana,
            decoration: const InputDecoration(
              labelText: 'Dia da Semana',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
            items: diasSemana
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => diaSemana = val);
            },
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Trabalho',
                        style: TextStyle(fontSize: 11, color: Colors.green),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatarTempo(segundosTrabalho),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      if (_horarioInicio != null)
                        Text(
                          'Início: ${formatHora.format(_horarioInicio!)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Intervalo',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatarTempo(_segundosIntervalo),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const Text(
                        'Descanso',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: observacaoController,
            decoration: const InputDecoration(
              labelText: 'Observação / Obra',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 16),
          if (!estaTrabalhando && !_emIntervalo && segundosTrabalho == 0)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar Expediente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                onPressed: _iniciarJornada,
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: Icon(_emIntervalo ? Icons.play_arrow : Icons.pause),
                      label: Text(_emIntervalo ? 'Voltar' : 'Intervalo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _alternarIntervalo,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.stop),
                      label: const Text('Fim'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _encerrarExpediente,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
